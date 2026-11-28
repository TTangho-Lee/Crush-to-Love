// 미션 학습 연결 (lib/learning ↔ lib/roadmap), 다른 미션 흐름으로 옮길 땐 이 파일만 새로 만들면 됨
//   미션 → MissionArm, 상황 → MissionContext (lib/learning/mission_features.dart)
//   오늘의 미션: 규칙 순서(rankToday)를 학습 점수로 다시 줄 세움 (seed = 상대 · 날짜, 같은 날은 같은 순서)
//     안전 규칙: 용기보다 2단계 이상 어려운 미션 · 반응이 조심스러울 때 과감한 미션은 1순위로 안 올림
//     이유 줄: 배워서 오른 몫이 크고 근거가 쌓인 특징이 있으면 그 문장 (없으면 규칙 이유 그대로)
//   주차 구성: 완료 기록이 learnedWeekMinDone개 쌓인 뒤에만 그 단계 미션을 학습 점수 순서로 (그 전엔 지금 순서)
//     seed = 상대 · 주차 번호, 쉬운 미션 최소 1개 (roadmap_generator.dart의 order)
//   기록: 완료 +1 · 완료 취소(그 미션 기록을 빼서 되돌림) · '↻' −0.2 · 주차가 끝날 때까지 안 함 −0.5
//   값은 tool/learning/simulate.py · tune.py로 고름, 같은 계산이 tool/learning/expected_mission.py
import '../learning/learning_db.dart';
import '../learning/learning_store.dart';
import '../learning/linear_ts.dart';
import '../learning/mission_features.dart';
import '../shared/models.dart';
import 'mission_lines.dart';
import 'roadmap_models.dart';
import 'roadmap_rules.dart';
import 'roadmap_generator.dart';

/// 보상
const rewardDone = 1.0;
const rewardMissed = -0.5;
const rewardSkip = -0.2;

/// 주차 구성을 학습 순서로 고르기 시작하는 완료 기록 수 (모든 상대 · 시연 기록 합)
const learnedWeekMinDone = 5;

/// 완료 기록이 충분히 쌓였으면 true (주차 구성을 학습 순서로)
bool canLearnWeeks(LearningStore store) =>
    store
        .events(domain: missionDomain)
        .where((e) => e.kind == LearnKind.done)
        .length >=
    learnedWeekMinDone;

/// 미션 → 학습용 미션
MissionArm missionArmOf(RoadmapMission m) => MissionArm(
      id: m.id,
      level: m.level,
      offline: m.offline,
      tags: {for (final t in m.line?.tags ?? const <MissionTag>{}) t.name},
    );

/// 상황 → 학습 문맥 (at: 고르는 시각, 없으면 시각 모름)
MissionContext missionContextOf(
  MissionSituation s,
  double rule, {
  required DateTime today,
  DateTime? at,
}) =>
    MissionContext(
      rule: rule,
      maxLevel: courageMax(s.profile.courage),
      pace: s.pace.name,
      meetings: s.profile.meetingsPerWeek,
      elapsed: s.elapsed,
      restDays: s.restDays,
      talkGap: s.talkGapAt(today),
      interest: s.chat?.interest.name,
      weekday: at?.weekday,
      hour: at?.hour,
    );

/// '20261120'
String dayKey(DateTime t) =>
    '${t.year}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';

/// 학습이 1순위로 못 올리는 미션 (안전 규칙)
bool _forbiddenTop(MissionArm m, MissionContext c) =>
    m.level >= c.maxLevel + 2 || (c.interest == 'low' && m.bold);

/// 오늘의 미션 학습 순서 (미션 id), picks는 규칙 순서
List<String> learnedTodayOrder(
  LearningStore store,
  List<TodayPick> picks,
  MissionSituation s, {
  required DateTime now,
  required int crushId,
}) {
  final theta = store.sampleOf(missionDomain, 'today|$crushId|${dayKey(now)}');
  final rows = <(bool, double, int, String)>[];
  for (var i = 0; i < picks.length; i++) {
    final p = picks[i];
    final arm = missionArmOf(p.mission);
    final ctx = missionContextOf(s, p.score, today: now, at: now);
    rows.add((
      _forbiddenTop(arm, ctx),
      dot(theta, missionFeatures(ctx, arm)),
      i,
      p.mission.id,
    ));
  }
  // 안전 규칙에 걸린 것은 뒤로 → 학습 점수 높은 순 → 규칙 순서
  rows.sort((a, b) {
    if (a.$1 != b.$1) return a.$1 ? 1 : -1;
    final byScore = b.$2.compareTo(a.$2);
    return byScore != 0 ? byScore : a.$3.compareTo(b.$3);
  });
  return [for (final r in rows) r.$4];
}

/// 학습 이유가 있으면 이유 줄을 바꿈 (다음 주 미리 하기는 그대로)
TodayPick explainPick(
  LearningStore store,
  TodayPick p,
  MissionSituation s, {
  required DateTime now,
}) {
  if (p.early) return p;
  final phi = missionFeatures(
    missionContextOf(s, p.score, today: now, at: now),
    missionArmOf(p.mission),
  );
  final why = missionLearnedReason(store, phi);
  return why == null ? p : p.withReason(why, learned: true);
}

/// 주차 구성 학습 순서 (그 단계 사전 번호, 앞일수록 먼저)
List<int> learnedWeekOrder(
  LearningStore store,
  MissionSituation s,
  RoadmapStage stage, {
  required int crushId,
  required int weekNo,
  required DateTime today,
}) {
  final theta = store.sampleOf(missionDomain, 'week|$crushId|$weekNo');
  final lines = missionLines[stage]!;
  final rows = <(double, int)>[];
  for (var i = 0; i < lines.length; i++) {
    final m = RoadmapMission(
      id: '${stage.name}-$i',
      title: lines[i].title,
      tip: lines[i].tip,
    );
    final rule = missionRuleScore(s, m, stage, today: today);
    final ctx = missionContextOf(s, rule, today: today);
    rows.add((dot(theta, missionFeatures(ctx, missionArmOf(m))), i));
  }
  rows.sort((a, b) {
    final byScore = b.$1.compareTo(a.$1);
    return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
  });
  return [for (final r in rows) r.$2];
}

/// 완료 기록 (바꾸기 전 상황으로), 다 끝난 주차라 '안 함'으로 기록된 게 있으면 취소
Future<void> recordDone(
  LearningStore store,
  MissionSituation before,
  RoadmapMission m,
  RoadmapStage stage, {
  required int crushId,
  required DateTime now,
}) async {
  for (final e in store.events(domain: missionDomain, crushId: crushId)) {
    if (e.arm == m.id && e.kind == LearnKind.missed) await store.cancel(e);
  }
  final rule = missionRuleScore(before, m, stage, today: now);
  final arm = missionArmOf(m);
  await store.record(
    domain: missionDomain,
    crushId: crushId,
    arm: m.id,
    ctx: missionContextOf(before, rule, today: now, at: now).toJson(arm),
    reward: rewardDone,
    kind: LearnKind.done,
  );
}

/// 완료 취소: 그 미션의 마지막 완료 기록과 그 뒤 늦은 보상까지 빼기
Future<void> recordUndo(
  LearningStore store,
  String missionId, {
  required int crushId,
}) async {
  final mine = [
    for (final e in store.events(domain: missionDomain, crushId: crushId))
      if (e.arm == missionId) e,
  ];
  final dones = [for (final e in mine) if (e.kind == LearnKind.done) e];
  if (dones.isEmpty) return;
  final last = dones.last;
  await store.cancel(last);
  for (final e in mine) {
    if (e.kind == LearnKind.chat && !e.at.isBefore(last.at)) {
      await store.cancel(e);
    }
  }
}

/// '↻ 다른 미션': 보던 미션에 약한 −
Future<void> recordSkip(
  LearningStore store,
  TodayPick pick,
  MissionSituation s, {
  required int crushId,
  required DateTime now,
}) {
  final arm = missionArmOf(pick.mission);
  return store.record(
    domain: missionDomain,
    crushId: crushId,
    arm: pick.mission.id,
    ctx: missionContextOf(s, pick.score, today: now, at: now).toJson(arm),
    reward: rewardSkip,
    kind: LearnKind.skip,
  );
}

/// 주차 판정 meta 이름
String judgedKey(int crushId) => 'judged:$crushId';

/// 끝난 주차의 안 한 미션 → '안 함' 기록 (그 주 마지막 날 문맥, 시각 모름)
/// 처음 붙일 땐 지난 주차는 판정하지 않음 (학습 전 기록이라 완료가 빠져 있어서)
Future<void> judgeEndedWeeks(
  LearningStore store, {
  required int crushId,
  required Profile profile,
  required Roadmap roadmap,
  required DateTime today,
  ChatSignal? chat,
}) async {
  final left = daysUntil(profile.dDay, now: today);
  final ended = [
    for (final w in roadmap.weeks)
      if (w.toDDay > left) w,
  ];
  final last = ended.fold(0, (m, w) => w.weekNo > m ? w.weekNo : m);
  final saved = int.tryParse(store.meta(judgedKey(crushId)) ?? '');
  if (saved != null && last <= saved) return;
  // 먼저 위치를 옮겨 둠 (같은 주차를 두 번 판정하지 않게)
  final pending = store.setMeta(judgedKey(crushId), '$last');
  if (saved == null) return pending;
  for (final w in ended) {
    if (w.weekNo <= saved) continue;
    final d = profile.dDay;
    final lastDay = DateTime(d.year, d.month, d.day - w.toDDay);
    final s = readSituation(
      profile: profile,
      roadmap: roadmap,
      today: lastDay,
      chat: chat,
    );
    for (final m in w.missions) {
      if (m.closed) continue;
      final rule = missionRuleScore(s, m, w.stage, today: lastDay);
      final arm = missionArmOf(m);
      await store.record(
        domain: missionDomain,
        crushId: crushId,
        arm: m.id,
        ctx: missionContextOf(s, rule, today: lastDay).toJson(arm),
        reward: rewardMissed,
        kind: LearnKind.missed,
      );
    }
  }
  await pending;
}

/// 주차 다시 고르기 meta 이름 (마지막으로 다시 고른 주차 번호)
String composedKey(int crushId) => 'composed:$crushId';
