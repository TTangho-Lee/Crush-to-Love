// 미션 학습 분야: 문맥 · 미션 → 특징 φ (22개), 사전, 학습 이유 문장
//   팀원 미션 흐름으로 옮길 땐 MissionContext · MissionArm만 만들어 넘기면 됨 (dummy는 dummy_mission_learning.dart)
//   φ: 규칙 점수/5 · 1 · 용기 차이 · 대면 · 대면×주말 · 대면×만남 빈도 · 태그 9개
//      · 연락×대화 뜸함 · 과감×호감 높음 · 과감×호감 낮음 · 어려움×진도 늦음 · 가벼움×쉰 뒤 · 온라인×저녁 · 어려움×D-Day 가까움
//   사전: 규칙 점수에만 가중치 1 (처음엔 지금 규칙 순서), 태그 · 대면은 λ 2 (빨리 배움), 나머지 λ 6
//   값은 tool/learning/simulate.py · tune.py로 고름 (RESULTS.md), mission_features.py와 같은 순서 · 값
import 'learning_store.dart';

/// 미션 분야 이름 (기록 · 모델 key)
const missionDomain = 'mission';

/// 미션 태그 이름 (dummy MissionTag.name과 같은 순서)
const missionTagNames = [
  'prep',
  'greet',
  'react',
  'ask',
  'share',
  'care',
  'push',
  'invite',
  'express',
];

/// 과감한 행동 (먼저 연락 · 약속 · 마음 표현)
const boldTagNames = {'push', 'invite', 'express'};

/// 미션 하나 (학습용)
class MissionArm {
  const MissionArm({
    required this.id,
    required this.level,
    required this.offline,
    required this.tags,
  });

  final String id;

  /// 필요한 용기 1 ~ 3
  final int level;

  /// 직접 만나야 하면 true
  final bool offline;

  /// 태그 이름 (missionTagNames 중)
  final Set<String> tags;

  bool get bold => tags.any(boldTagNames.contains);
}

/// 고를 때 문맥 (숫자 · 이름만, DB에 JSON으로)
class MissionContext {
  const MissionContext({
    required this.rule,
    required this.maxLevel,
    required this.pace,
    required this.meetings,
    required this.elapsed,
    this.restDays,
    this.talkGap,
    this.interest,
    this.weekday,
    this.hour,
  });

  /// 이 미션의 규칙 점수 (dummy_mission_rules.dart ruleTerms 합)
  final double rule;

  /// 부담 없이 할 수 있는 용기 최대 1 ~ 3
  final int maxLevel;

  /// 'behind' · 'onTrack' · 'ahead'
  final String pace;

  /// 만남 빈도 주 0 ~ 7회
  final int meetings;

  /// 로드맵 지난 비율 0 ~ 1
  final double elapsed;

  /// 마지막 미션 뒤 지난 날, 없으면 null
  final int? restDays;

  /// 마지막 대화 뒤 지난 날, 모르면 null
  final int? talkGap;

  /// 'low' · 'mid' · 'high', 대화 분석이 없으면 null
  final String? interest;

  /// 1(월) ~ 7(일), 주차 구성처럼 그날이 아니면 null (평균값)
  final int? weekday;

  /// 0 ~ 23, 모르면 null (평균값)
  final int? hour;

  /// 시각을 지운 문맥 (주차 구성 · 주차 끝 판정)
  MissionContext withoutTime() => MissionContext(
        rule: rule,
        maxLevel: maxLevel,
        pace: pace,
        meetings: meetings,
        elapsed: elapsed,
        restDays: restDays,
        talkGap: talkGap,
        interest: interest,
      );

  /// 미션 특징까지 같이 (기록 문맥)
  Map<String, Object?> toJson(MissionArm arm) => {
        'rule': rule,
        'maxLv': maxLevel,
        'pace': pace,
        'meet': meetings,
        'elapsed': elapsed,
        'rest': ?restDays,
        'gap': ?talkGap,
        'interest': ?interest,
        'weekday': ?weekday,
        'hour': ?hour,
        'lv': arm.level,
        'off': arm.offline,
        'tags': [for (final t in missionTagNames) if (arm.tags.contains(t)) t],
      };

  static MissionContext? fromJson(Map<String, Object?> j) {
    final rule = j['rule'], maxLv = j['maxLv'], pace = j['pace'];
    final meet = j['meet'], elapsed = j['elapsed'];
    if (rule is! num || maxLv is! int || pace is! String) return null;
    if (meet is! int || elapsed is! num) return null;
    return MissionContext(
      rule: rule.toDouble(),
      maxLevel: maxLv,
      pace: pace,
      meetings: meet,
      elapsed: elapsed.toDouble(),
      restDays: j['rest'] as int?,
      talkGap: j['gap'] as int?,
      interest: j['interest'] as String?,
      weekday: j['weekday'] as int?,
      hour: j['hour'] as int?,
    );
  }

  /// 기록 문맥 속 미션 특징, 없으면 null
  static MissionArm? armFromJson(String id, Map<String, Object?> j) {
    final lv = j['lv'], off = j['off'], tags = j['tags'];
    if (lv is! int || off is! bool || tags is! List) return null;
    return MissionArm(
      id: id,
      level: lv,
      offline: off,
      tags: {for (final t in tags) t as String},
    );
  }
}

/// 시각을 모를 때 주말 · 저녁 평균값
const _weekendAvg = 3 / 7;
const _eveningAvg = 0.5;

/// 특징 이름 (설명 · 테스트용, 순서가 곧 φ 순서)
const missionFeatureNames = [
  'rule',
  'bias',
  'levelGap',
  'offline',
  'offlineWeekend',
  'offlineMeet',
  'tag.prep',
  'tag.greet',
  'tag.react',
  'tag.ask',
  'tag.share',
  'tag.care',
  'tag.push',
  'tag.invite',
  'tag.express',
  'contactGap',
  'boldHigh',
  'boldLow',
  'hardBehind',
  'easyRested',
  'onlineEvening',
  'hardLate',
];

/// φ (22개)
List<double> missionFeatures(MissionContext c, MissionArm m) {
  final off = m.offline ? 1.0 : 0.0;
  final bold = m.bold ? 1.0 : 0.0;
  final contact = m.tags.any((t) => t != 'prep') ? 1.0 : 0.0;
  final weekday = c.weekday;
  final hour = c.hour;
  final weekend = weekday == null ? _weekendAvg : (weekday >= 5 ? 1.0 : 0.0);
  final evening =
      hour == null ? _eveningAvg : (hour >= 17 || hour < 5 ? 1.0 : 0.0);
  double flag(bool v) => v ? 1.0 : 0.0;
  return [
    c.rule / 5,
    1,
    (m.level - c.maxLevel) / 2,
    off,
    off * weekend,
    off * c.meetings / 7,
    for (final t in missionTagNames) flag(m.tags.contains(t)),
    contact * flag((c.talkGap ?? 0) >= 3),
    bold * flag(c.interest == 'high'),
    bold * flag(c.interest == 'low'),
    flag(m.level >= 2) * flag(c.pace == 'behind'),
    flag(m.level == 1) * flag((c.restDays ?? 0) >= 3),
    (1 - off) * evening,
    (m.level - 1) / 2 * c.elapsed,
  ];
}

/// 학습 이유 문장 (특징 이름 → 배워서 이 미션 점수가 오른 까닭), 없는 특징은 이유로 안 씀
const Map<String, String> missionReasons = {
  'offline': '직접 만나서 하는 미션을 잘 해냈어요',
  'offlineWeekend': '주말엔 직접 만나는 미션을 잘 해냈어요',
  'offlineMeet': '자주 보는 사이라 직접 하는 미션을 잘 해냈어요',
  'tag.prep': '혼자 준비하는 미션을 잘 해냈어요',
  'tag.greet': '인사 미션을 잘 해냈어요',
  'tag.react': '반응 남기는 미션을 잘 해냈어요',
  'tag.ask': '질문하는 미션을 잘 해냈어요',
  'tag.share': '내 이야기를 나누는 미션을 잘 해냈어요',
  'tag.care': '챙겨 주는 미션을 잘 해냈어요',
  'tag.push': '먼저 연락하는 미션을 잘 해냈어요',
  'tag.invite': '약속 잡는 미션을 잘 해냈어요',
  'tag.express': '마음을 표현하는 미션을 잘 해냈어요',
  'contactGap': '연락이 뜸할 때 먼저 다가가는 미션을 해냈어요',
  'boldHigh': '대화 분위기가 좋을 때 한 걸음 더 나갔어요',
  'hardBehind': '진도가 늦을 때 큰 미션을 해냈어요',
  'easyRested': '쉬다가 다시 시작할 땐 가벼운 미션을 해냈어요',
  'onlineEvening': '저녁엔 만나지 않고 하는 미션을 잘 해냈어요',
  'hardLate': 'D-Day가 다가올수록 어려운 미션도 해냈어요',
};

/// 학습 이유로 쓰는 최소 몫 · 근거 수 (같은 특징이 켜진 채 보상이 +였던 기록 3번 이상)
const reasonMinGain = 0.08;
const reasonMinEvidence = 3;

/// '학습한 내용' 화면에 보여 줄 미션 종류 (특징 이름 → 짧은 이름)
const Map<String, String> missionTraitLabels = {
  'tag.prep': '혼자 준비',
  'tag.greet': '인사',
  'tag.react': '반응 남기기',
  'tag.ask': '질문',
  'tag.share': '내 이야기',
  'tag.care': '챙기기',
  'tag.push': '먼저 연락',
  'tag.invite': '약속 잡기',
  'tag.express': '마음 표현',
  'offline': '직접 만나기',
  'offlineWeekend': '주말에 만나기',
  'onlineEvening': '저녁에 만나지 않고',
};

/// 종류마다 배운 가중치 (μ − μ₀), 이 만큼 안 되면 안 보여 줌
const traitMinWeight = 0.05;

/// 미션 분야 설정
class MissionDomain implements LearnDomain {
  const MissionDomain();

  @override
  String get name => missionDomain;

  @override
  int get version => 1;

  @override
  int get dim => missionFeatureNames.length;

  @override
  List<double> get priorMean => [
        1.0,
        for (var i = 1; i < missionFeatureNames.length; i++) 0.0,
      ];

  @override
  List<double> get priorPrecision => [
        for (final n in missionFeatureNames)
          n == 'rule'
              ? 5.0
              : n.startsWith('tag.') || n.startsWith('offline')
                  ? 2.0
                  : 6.0,
      ];

  @override
  double get scale => 0.15;

  @override
  List<double>? featuresOf(Map<String, Object?> ctx, String arm) {
    final c = MissionContext.fromJson(ctx);
    final m = MissionContext.armFromJson(arm, ctx);
    return c == null || m == null ? null : missionFeatures(c, m);
  }
}

/// 이 미션을 학습으로 고른 이유 한 줄: 배워서 오른 몫이 큰 순서로, 근거가 쌓인 첫 특징
/// 없으면 null (그땐 규칙 이유)
String? missionLearnedReason(LearningStore store, List<double> phi) {
  final part = store.learnedPart(missionDomain, phi);
  final cands = [
    for (var i = 0; i < part.length; i++)
      if (missionReasons.containsKey(missionFeatureNames[i]) &&
          part[i] >= reasonMinGain)
        i,
  ]..sort((a, b) {
      final byPart = part[b].compareTo(part[a]);
      return byPart != 0 ? byPart : a.compareTo(b);
    });
  for (final i in cands) {
    if (store.evidence(missionDomain, i) >= reasonMinEvidence) {
      return missionReasons[missionFeatureNames[i]];
    }
  }
  return null;
}

/// 배운 미션 종류 (이름, 가중치): (잘 해낸 것 큰 순, 잘 안 한 것 작은 순), 각각 최대 count개
(List<(String, double)>, List<(String, double)>) missionTraits(
  LearningStore store, {
  int count = 3,
}) =>
    learnedTraits(
      store,
      missionDomain,
      names: missionFeatureNames,
      labels: missionTraitLabels,
      minWeight: traitMinWeight,
      count: count,
    );
