// 미션 규칙 (대화 분석 rules처럼 AI 없이 규칙으로): 지금 상황 → 진척도 · 진도 · 한 줄 진단 → 오늘의 미션 → 다음 주차 조정
//   ① 상황(readSituation): 남은 날 · 이번 주차 · 진척도 · 기대 진척도 · 진도 · 쉰 날 · 용기 단계 · 대화 분석 신호
//   ② 진척도: 미션 점수 = 단계 무게(뒤 단계일수록 크게, stageWeight) × 용기 무게(어려울수록 조금 더, 1 · 1.25 · 1.5)
//       용기 단계보다 어려운 미션을 해내면 1.5배 (brave)
//       목표가 높을수록(사귀기) 뒤 단계 미션이 많아서 쉬운 미션 하나로 오르는 폭이 작음
//       기대 진척도 = 날짜로 보면 지금쯤 했어야 할 만큼, 둘의 차이로 진도 (Pace)
//   ③ 한 줄 진단(summaryOf): 위에서부터 처음 맞는 규칙 하나
//   ④ 오늘의 미션(rankToday): 이번 주 안 한 미션마다 규칙 점수(missionRuleTerms)를 더해 높은 순, 이유는 점수를 가장 많이 올린 규칙
//       학습을 켜면 이 순서를 학습 점수로 다시 줄 세움 (roadmap_learning.dart, 규칙 점수는 특징 하나)
//       용기 단계보다 어려우면 크게 깎음 (진도가 늦으면 한 단계 위까지는 '용기 내기'로 추천)
//       대화 분석 추천 방향과 같은 행동 +, 상대 반응이 조심스러우면 먼저 연락 · 약속 · 마음 표현 -
//       이번 주를 다 했으면 다음 주 미션을 미리
//   ⑤ 다음 주차 조정(adaptShift): 대화로 본 사이가 더 가깝거나 진도가 빠르면 한 단계 당김,
//       상대 반응이 조심스러우면 한 단계 늦춤 (당긴 건 반응이 나빠질 때만 되돌림)
import 'dart:math';

import '../analysis/chat/rules/lines.dart' show Approach;
import '../analysis/chat/rules/scoring.dart'
    show InterestLevel, highScore, midScore;
import '../shared/models.dart';
import 'mission_lines.dart';
import 'roadmap_models.dart';
import 'roadmap_generator.dart';

/// 대화 분석에서 가져온 신호 (지금 상대와의 대화일 때만)
class ChatSignal {
  const ChatSignal({
    required this.interest,
    this.approach,
    this.intimacy,
    this.lastTalkAt,
  });

  /// 호감 신호 점수 단계
  final InterestLevel interest;

  /// 다음 대화 추천 방향 (이번에 켠 동안 분석한 대화일 때만)
  final Approach? approach;

  /// 대화로 본 지금 사이 (이번에 켠 동안 분석한 대화일 때만)
  final Intimacy? intimacy;

  /// 마지막 메시지 시각
  final DateTime? lastTalkAt;

  /// 지난 분석 기록 점수 → 단계 (scoring.dart와 같은 기준)
  static InterestLevel levelOf(int score) => score >= highScore
      ? InterestLevel.high
      : score >= midScore
          ? InterestLevel.mid
          : InterestLevel.low;
}

/// 진도 (진척도 − 기대 진척도)
enum Pace {
  ahead('여유 있어요'),
  onTrack('잘 가고 있어요'),
  behind('조금 서둘러요');

  const Pace(this.label);

  final String label;
}

/// 용기 단계 짧은 이름 ('표준')
String courageName(CourageLevel level) => level.label.split(' · ').first;

/// 단계 무게 (인사 1 → 마음 전하기 4.5, 뒤 단계일수록 큼)
double stageWeight(RoadmapStage stage) => 1 + stage.index * 0.5;

/// 미션 점수 (진척도 계산용), earned면 해낸 점수 (용기 낸 미션 1.5배)
double missionPoints(RoadmapMission m, RoadmapStage stage, {bool earned = false}) =>
    (0.75 + 0.25 * m.level) *
    stageWeight(stage) *
    (earned && m.brave ? 1.5 : 1);

/// 지금 상황
class MissionSituation {
  const MissionSituation({
    required this.profile,
    required this.roadmap,
    required this.daysLeft,
    required this.weekIndex,
    required this.progress,
    required this.expected,
    required this.pace,
    required this.doneCount,
    required this.totalCount,
    required this.elapsed,
    this.restDays,
    this.chat,
  });

  final Profile profile;
  final Roadmap roadmap;

  /// D-Day까지 남은 날 (지나면 음수)
  final int daysLeft;

  /// 이번 주차 순서 (0부터)
  final int weekIndex;

  /// 목표까지 진척도 0 ~ 1
  final double progress;

  /// 날짜로 보면 지금쯤 됐을 진척도 0 ~ 1
  final double expected;
  final Pace pace;
  final int doneCount;
  final int totalCount;

  /// 로드맵을 만든 날부터 D-Day까지 중 지난 비율 0 ~ 1
  final double elapsed;

  /// 마지막으로 미션을 한 뒤 지난 날, 한 번도 안 했으면 null
  final int? restDays;
  final ChatSignal? chat;

  CourageLevel get courage => CourageLevel.of(profile.courage);
  RoadmapWeek get week => roadmap.weeks[weekIndex];
  bool get allDone => doneCount == totalCount;
  bool get passed => daysLeft < 0;

  /// 마지막 대화가 며칠 전인지, 모르면 null
  int? talkGapAt(DateTime today) {
    final at = chat?.lastTalkAt;
    return at == null ? null : daysUntil(today, now: at);
  }
}

MissionSituation readSituation({
  required Profile profile,
  required Roadmap roadmap,
  required DateTime today,
  ChatSignal? chat,
}) {
  final weeks = roadmap.weeks;
  final left = daysUntil(profile.dDay, now: today);
  final weekIndex = currentWeekIndex(
    [for (final w in weeks) (w.fromDDay, w.toDDay)],
    left,
  );

  var total = 0.0, earned = 0.0, expected = 0.0;
  var done = 0, count = 0;
  DateTime? lastDone;
  for (var i = 0; i < weeks.length; i++) {
    final w = weeks[i];
    final points = w.missions.fold(0.0, (s, m) => s + missionPoints(m, w.stage));
    total += points;
    for (final m in w.missions) {
      count++;
      if (!m.done) continue;
      done++;
      earned += missionPoints(m, w.stage, earned: true);
      final at = m.doneAt;
      if (at != null && (lastDone == null || at.isAfter(lastDone))) lastDone = at;
    }
    // 끝난 주차는 전부, 이번 주차는 지난 날 비율만큼
    if (w.toDDay > left) {
      expected += points;
    } else if (i == weekIndex) {
      final length = w.fromDDay - w.toDDay + 1;
      expected += points * (w.fromDDay - left).clamp(0, length) / length;
    }
  }

  final progress = total == 0 ? 0.0 : min(1.0, earned / total);
  final expectedRate = total == 0 ? 0.0 : expected / total;
  final diff = progress - expectedRate;
  final pace = expectedRate < 0.05
      ? Pace.onTrack // 아직 이르면 판단 안 함
      : diff >= 0.08
          ? Pace.ahead
          : diff <= -0.15
              ? Pace.behind
              : Pace.onTrack;

  final span = daysUntil(profile.dDay, now: roadmap.startedAt);
  final passedDays = daysUntil(today, now: roadmap.startedAt);
  return MissionSituation(
    profile: profile,
    roadmap: roadmap,
    daysLeft: left,
    weekIndex: weekIndex,
    progress: progress,
    expected: expectedRate,
    pace: pace,
    doneCount: done,
    totalCount: count,
    elapsed: span <= 0 ? 1 : (passedDays / span).clamp(0, 1).toDouble(),
    restDays: lastDone == null ? null : daysUntil(today, now: lastDone),
    chat: chat,
  );
}

// ---------- ③ 한 줄 진단 ----------

/// 홈 맨 위 한 줄 (위에서부터 처음 맞는 것)
String summaryOf(MissionSituation s, {required DateTime today}) {
  final chat = s.chat;
  final rest = s.restDays;
  final talkGap = s.talkGapAt(today);
  if (s.passed) return 'D-Day가 지났어요. 어떻게 됐는지 알려 주세요.';
  if (s.allDone) {
    return switch (s.profile.goal) {
      Goal.friends => '친해지기 미션을 모두 마쳤어요! 이제 편하게 연락하는 사이예요.',
      Goal.some => '썸 타기 미션을 모두 마쳤어요! 서로 마음이 통하는지 살펴봐요.',
      Goal.dating => '사귀기 미션을 모두 마쳤어요! 결과를 알려 주세요.',
    };
  }
  if (chat?.interest == InterestLevel.low) {
    return '상대 반응이 조심스러운 편이에요. 부담 없는 미션 위주로 골랐어요.';
  }
  if (rest != null && rest >= 3) {
    return '$rest일째 쉬고 있어요. 가벼운 미션 하나로 다시 시작해요.';
  }
  if (s.doneCount == 0 && s.elapsed >= 0.15) {
    return '아직 시작 전이에요. 오늘 한 가지만 해 봐요.';
  }
  if (talkGap != null && talkGap >= 3) {
    return '마지막 대화가 $talkGap일 전이에요. 가볍게 먼저 연락해 봐요.';
  }
  if (s.pace == Pace.behind) {
    return '${dDayLabel(s.daysLeft)}, 진도가 조금 늦어요. 이번 주에 하나만 더 해 봐요.';
  }
  if (chat?.interest == InterestLevel.high) {
    return '대화 분위기가 좋아요. 지금 흐름을 이어 가요.';
  }
  if (s.pace == Pace.ahead) {
    return '진도가 빨라요! 이대로면 ${s.profile.goal.label}까지 충분해요.';
  }
  if (s.courage == CourageLevel.low) {
    return '오늘은 용기가 적은 날이에요. 마음 편한 미션부터 해요.';
  }
  return '이번 주는 ‘${s.week.title}’ — ${s.week.stage.description}';
}

// ---------- ④ 오늘의 미션 ----------

/// 오늘의 미션 후보 하나
class TodayPick {
  const TodayPick({
    required this.mission,
    required this.week,
    required this.reason,
    required this.brave,
    this.early = false,
    this.score = 0,
    this.learned = false,
  });

  final RoadmapMission mission;

  /// 미션이 든 주차
  final RoadmapWeek week;

  /// 이 미션을 고른 이유 한 줄
  final String reason;

  /// 지금 용기 단계보다 어려운 미션 (해내면 진척도 1.5배)
  final bool brave;

  /// 이번 주를 다 해서 다음 주 미션을 미리 하는 중이면 true
  final bool early;

  /// 규칙 점수 합 (학습 특징)
  final double score;

  /// 이유가 학습에서 나왔으면 true (홈 이유 줄 아이콘)
  final bool learned;

  TodayPick withReason(String reason, {required bool learned}) => TodayPick(
        mission: mission,
        week: week,
        reason: reason,
        brave: brave,
        early: early,
        score: score,
        learned: learned,
      );
}

/// 대화 분석 추천 방향 → 잘 맞는 행동
Set<MissionTag> _tagsFor(Approach approach) => switch (approach) {
      Approach.rest || Approach.patience => {MissionTag.prep, MissionTag.react},
      Approach.comfort => {MissionTag.care},
      Approach.fixPlan || Approach.invite => {MissionTag.invite},
      Approach.breakIce || Approach.firstTalk => {MissionTag.greet, MissionTag.ask},
      Approach.openUp => {MissionTag.share, MissionTag.express},
      Approach.askBack || Approach.common => {MissionTag.ask},
      Approach.react || Approach.tempo => {MissionTag.react},
      Approach.light => {MissionTag.greet, MissionTag.react, MissionTag.share},
      Approach.lighten || Approach.laughTopic => {MissionTag.share},
      Approach.routine => {MissionTag.care, MissionTag.push},
      Approach.reconnect => {MissionTag.push, MissionTag.care},
      Approach.afterMeet => {MissionTag.care, MissionTag.express},
    };

/// 상대 반응이 조심스러울 때 피할 행동 · 고를 행동
const _bold = {MissionTag.push, MissionTag.invite, MissionTag.express};
const _gentle = {MissionTag.prep, MissionTag.react, MissionTag.care};

/// 미션 하나의 규칙 (점수, 이유), 이유가 빈 글자면 이유로 안 씀
/// stage: 미션이 든 주차 단계
List<(double, String)> missionRuleTerms(
  MissionSituation s,
  RoadmapMission m,
  RoadmapStage stage, {
  required DateTime today,
}) {
  final maxLevel = courageMax(s.profile.courage);
  final chat = s.chat;
  final approach = chat?.approach;
  final talkGap = s.talkGapAt(today);
  final rest = s.restDays;
  final meetings = s.profile.meetingsPerWeek;
  final tags = m.line?.tags ?? const <MissionTag>{};
  final rules = <(double, String)>[];
  void rule(double score, String why) => rules.add((score, why));

  // 용기
  if (m.level == maxLevel && maxLevel >= 2) {
    rule(1.5, '지금 용기(${courageName(s.courage)})에 딱 맞는 도전이에요');
  } else if (m.level < maxLevel || m.level == 1) {
    rule(1, '지금 용기로 부담 없이 할 수 있어요');
  } else if (s.pace == Pace.behind && m.level == maxLevel + 1) {
    rule(1.2, '용기를 조금 내면 진척도가 1.5배로 올라요');
  } else {
    rule(-3, '');
  }
  // 대화 분석
  if (approach != null && tags.intersection(_tagsFor(approach)).isNotEmpty) {
    rule(2, '대화 분석 추천(${approach.label})과 같은 방향이에요');
  }
  if (chat?.interest == InterestLevel.low) {
    if (tags.intersection(_bold).isNotEmpty) rule(-2, '');
    if (tags.intersection(_gentle).isNotEmpty) {
      rule(1, '상대 반응이 조심스러워서 부담 없는 걸로 골랐어요');
    }
  }
  if (chat?.interest == InterestLevel.high &&
      stage.index >= RoadmapStage.often.index &&
      tags.intersection(_bold).isNotEmpty) {
    rule(1.5, '대화 분위기가 좋아서 한 걸음 더 나가 봐요');
  }
  if (talkGap != null &&
      talkGap >= 3 &&
      tags.intersection({MissionTag.push, MissionTag.care, MissionTag.greet})
          .isNotEmpty) {
    rule(1.5, '마지막 대화가 $talkGap일 전이라 먼저 연락하기 좋아요');
  }
  // 내 진도 · 쉰 날
  if (rest != null && rest >= 3 && m.level == 1) {
    rule(1, '며칠 쉬었으니 가벼운 것부터 해요');
  }
  if (s.pace == Pace.behind && m.level >= 2) {
    rule(0.3 * m.level, '진척도를 크게 올릴 수 있는 미션이에요');
  }
  if (s.courage == CourageLevel.low && tags.contains(MissionTag.prep)) {
    rule(0.5, '혼자 준비하는 미션이라 부담이 없어요');
  }
  // 만남 빈도
  if (m.offline && meetings >= 3) rule(1, '자주 만나는 사이라 직접 해 보기 좋아요');
  if (m.offline && meetings == 1) rule(-0.5, '');
  return rules;
}

/// 미션 하나의 규칙 점수 합
double missionRuleScore(
  MissionSituation s,
  RoadmapMission m,
  RoadmapStage stage, {
  required DateTime today,
}) =>
    missionRuleTerms(s, m, stage, today: today)
        .fold(0.0, (sum, r) => sum + r.$1);

/// 오늘 할 만한 미션 (좋은 순), 다 했으면 빈 목록
List<TodayPick> rankToday(MissionSituation s, {required DateTime today}) {
  final weeks = s.roadmap.weeks;
  var week = s.week;
  var early = false;
  if (week.allDone && s.weekIndex + 1 < weeks.length) {
    week = weeks[s.weekIndex + 1];
    early = true;
  }

  final maxLevel = courageMax(s.profile.courage);
  final scored = <(double, String, int, RoadmapMission)>[];
  for (var i = 0; i < week.missions.length; i++) {
    final m = week.missions[i];
    if (m.done) continue;
    final rules = missionRuleTerms(s, m, week.stage, today: today);
    final total = rules.fold(0.0, (sum, r) => sum + r.$1);
    final best = rules.where((r) => r.$1 > 0 && r.$2.isNotEmpty).fold<(double, String)?>(
          null,
          (b, r) => b == null || r.$1 > b.$1 ? r : b,
        );
    scored.add((
      total,
      best?.$2 ?? '이번 주 목표 ‘${week.title}’에 맞는 미션이에요',
      i,
      m,
    ));
  }

  // 점수 높은 순, 같으면 사전 순서(쉬운 것 먼저)
  scored.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
  });
  return [
    for (final (score, reason, _, m) in scored)
      TodayPick(
        mission: m,
        week: week,
        reason: early ? '이번 주 미션을 다 했어요. 다음 주 미션을 미리 해 봐요' : reason,
        brave: m.level > maxLevel,
        early: early,
        score: score,
      ),
  ];
}

// ---------- ⑤ 다음 주차 조정 ----------

/// 새 shift와 이유, 바꿀 게 없으면 null
(int, String)? adaptShift(MissionSituation s) {
  final current = s.roadmap.shift;
  final chat = s.chat;
  if (s.passed) return null;
  if (chat != null && chat.interest == InterestLevel.low) {
    return current == -1 ? null : (-1, '상대 반응이 조심스러워서 다음 주부터 한 단계 천천히 가요');
  }
  if (current < 0 && chat != null) {
    return (0, '상대 반응이 나아져서 원래 속도로 돌아왔어요');
  }
  if (current >= 1) return null;
  final seen = chat?.intimacy;
  if (seen != null && seen.index > s.profile.intimacy.index) {
    return (1, '대화를 보니 생각보다 가까운 사이예요. 다음 주부터 한 단계 앞당겼어요');
  }
  if (s.pace == Pace.ahead && s.courage.index >= CourageLevel.standard.index) {
    return (1, '진도가 빨라서 다음 주부터 한 단계 앞당겼어요');
  }
  return null;
}
