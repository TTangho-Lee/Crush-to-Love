// 로드맵 만들기: 입력값 → 주차별 미션
//   주차 수: 만든 날부터 D-Day까지(그날 포함) 7일씩, 1 ~ maxRoadmapWeeks주 (넘으면 한 주차를 길게)
//   주차 날짜: D-20 ~ D-14 · D-13 ~ D-7 · D-6 ~ D-Day처럼 앞에서부터 같은 길이로
//   단계(mission_lines.dart): 사이에서 시작 · 목표에서 멈춤
//     얼굴만 → 인사할 틈, 스몰토크 → 이야기할 거리, 사적 연락 → 가볍게 약속
//     친해지기 → 연락 자주 주고받기까지, 썸 → 마음 살짝 보여주기까지, 사귀기 → 마음 전하기까지
//     주차가 단계보다 많으면 단계마다 여러 주, 적으면 한 주에 최대 2단계씩만 건너뜀
//     다음 주차부터는 shift만큼 당기거나 늦춤 (진도 · 대화 분석으로 자동 조정, roadmap_rules.dart)
//   주차마다 미션 missionsPerWeek개
//     만남 빈도가 주 0회면 만나야 하는 미션은 빼고, 용기 단계보다 어려운 미션은 모자랄 때만
//     같은 상대 · 같은 주차는 늘 같은 미션 (상대 번호 · 주차로 돌려 고름), 앞 주차와 안 겹치게, 사전 순서(쉬운 것 먼저)로
//     orderFor를 주면 돌려 고르는 순서 대신 그 순서로 (학습 점수 순, roadmap_learning.dart)
//       그때는 쉬운 미션(용기 최대보다 한 단계 아래, 저전력이면 용기 1)을 주차마다 최소 1개
//   다시 짜기
//     입력값이 바뀌면(replanRoadmap): 끝난 주차는 그대로, 이번 주부터 완료한 미션은 남기고 나머지를 새로
//     자동 조정(adaptRoadmap): 끝난 주차 · 이번 주는 그대로, 다음 주부터 단계가 바뀐 주차만 새로
//     주차 다시 고르기(recomposeWeek): 그 주차만 순서대로 새로 (완료한 미션은 남김, 주차가 시작될 때 학습으로)
import 'dart:math';

import '../shared/models.dart';
import 'mission_lines.dart';
import 'roadmap_models.dart';

/// 주차 수 최대
const maxRoadmapWeeks = 8;

/// 주차마다 미션 수
const missionsPerWeek = 3;

/// 주차 미션 고르는 순서 (단계 사전 번호, 앞일수록 먼저), 주차 번호는 1부터
typedef RoadmapOrder = List<int> Function(RoadmapStage stage, int weekNo);

/// 로드맵을 다시 짤지 볼 입력값 (만남 빈도는 0회인지만, 용기는 단계만)
String roadmapPlanKey(Profile profile) => [
      _dateOnly(profile.dDay).toIso8601String(),
      profile.intimacy.name,
      profile.goal.name,
      profile.meetingsPerWeek == 0 ? 'online' : 'meet',
      CourageLevel.of(profile.courage).name,
    ].join('|');

/// 용기 배터리 → 부담 없이 할 수 있는 미션 용기 최대 (저전력 1, 표준 2, 고속충전 · 풀충전 3)
int courageMax(int courage) => switch (CourageLevel.of(courage)) {
      CourageLevel.low => 1,
      CourageLevel.standard => 2,
      CourageLevel.boost || CourageLevel.full => 3,
    };

/// 새 로드맵 (처음 이 상대를 고를 때)
Roadmap buildRoadmap({
  required int crushId,
  required Profile profile,
  required DateTime today,
  RoadmapOrder? orderFor,
}) {
  final startedAt = _dateOnly(today);
  return Roadmap(
    crushId: crushId,
    startedAt: startedAt,
    planKey: roadmapPlanKey(profile),
    weeks: _weeks(
      crushId,
      profile,
      startedAt,
      today: startedAt,
      orderFor: orderFor,
    ),
  );
}

/// 입력값이 바뀐 로드맵 다시 짜기 (피그마 11번 · 설정), 자동 조정은 처음부터
Roadmap replanRoadmap(
  Roadmap old, {
  required Profile profile,
  required DateTime today,
  RoadmapOrder? orderFor,
}) {
  return old.copyWith(
    planKey: roadmapPlanKey(profile),
    weeks: _weeks(
      old.crushId,
      profile,
      old.startedAt,
      today: today,
      old: old,
      orderFor: orderFor,
    ),
    shift: 0,
    clearNote: true,
  );
}

/// 자동 조정: 다음 주차부터 shift만큼 당기거나 늦춤, 단계가 실제로 바뀐 주차가 있을 때만 note를 남김
Roadmap adaptRoadmap(
  Roadmap old, {
  required Profile profile,
  required DateTime today,
  required int shift,
  required String note,
  RoadmapOrder? orderFor,
}) {
  final weeks = _weeks(
    old.crushId,
    profile,
    old.startedAt,
    today: today,
    old: old,
    shift: shift,
    futureOnly: true,
    orderFor: orderFor,
  );
  final changed = [for (final w in weeks) w.stage].join() !=
      [for (final w in old.weeks) w.stage].join();
  return old.copyWith(
    weeks: weeks,
    shift: shift,
    note: changed ? note : null,
    noteAt: changed ? _dateOnly(today) : null,
  );
}

/// 주차 하나만 order 순서로 다시 고르기 (완료한 미션은 남기고, 다른 주차 미션과 안 겹치게)
Roadmap recomposeWeek(
  Roadmap r, {
  required Profile profile,
  required int weekIndex,
  required List<int> order,
}) {
  final week = r.weeks[weekIndex];
  final used = {
    for (var i = 0; i < r.weeks.length; i++)
      if (i != weekIndex)
        for (final m in r.weeks[i].missions) m.id,
  };
  final missions = _pick(
    week.stage,
    seed: r.crushId * 31 + (weekIndex + 1) * 7,
    canMeet: profile.meetingsPerWeek > 0,
    maxLevel: courageMax(profile.courage),
    used: used,
    keep: [
      for (final m in week.missions)
        if (m.done) m,
    ],
    order: order,
  );
  return r.copyWith(weeks: [
    for (var i = 0; i < r.weeks.length; i++)
      i == weekIndex ? week.copyWith(missions: missions) : r.weeks[i],
  ]);
}

/// 주차 날짜 (from, to): D-from ~ D-to, totalDaysLeft는 만든 날 기준 남은 날
List<(int, int)> weekRanges(int totalDaysLeft) {
  final total = max(totalDaysLeft, 0);
  final days = total + 1; // D-Day 포함
  final count = ((days + 6) ~/ 7).clamp(1, maxRoadmapWeeks);
  final length = (days + count - 1) ~/ count;
  return [
    for (var i = 0; i < count; i++)
      (total - i * length, max(total - (i + 1) * length + 1, 0)),
  ];
}

/// 오늘이 든 주차 순서 (0부터), D-Day가 지났으면 마지막
int currentWeekIndex(List<(int, int)> ranges, int daysLeft) {
  if (daysLeft > ranges.first.$1) return 0;
  final i = ranges.indexWhere((r) => daysLeft <= r.$1 && daysLeft >= r.$2);
  return i < 0 ? ranges.length - 1 : i;
}

/// 주차별 단계 (자동 조정 전)
List<RoadmapStage> stagesFor(Profile profile, int weekCount) {
  final end = goalStage(profile.goal).index;
  final start = min(_startOf(profile.intimacy).index, end);
  final span = end - start + 1;
  return [
    for (var i = 0; i < weekCount; i++)
      RoadmapStage.values[weekCount >= span
          ? start + i * span ~/ weekCount
          : weekCount == 1
              ? start
              : min(
                  start + 2 * i,
                  start + (i * (span - 1) / (weekCount - 1)).round(),
                )],
  ];
}

/// 목표에 닿는 마지막 단계
RoadmapStage goalStage(Goal goal) => switch (goal) {
      Goal.friends => RoadmapStage.often,
      Goal.some => RoadmapStage.show,
      Goal.dating => RoadmapStage.confess,
    };

RoadmapStage _startOf(Intimacy intimacy) => switch (intimacy) {
      Intimacy.faceOnly => RoadmapStage.greet,
      Intimacy.smallTalk => RoadmapStage.topic,
      Intimacy.close => RoadmapStage.plan,
    };

List<RoadmapWeek> _weeks(
  int crushId,
  Profile profile,
  DateTime startedAt, {
  required DateTime today,
  Roadmap? old,
  int shift = 0,
  bool futureOnly = false,
  RoadmapOrder? orderFor,
}) {
  final ranges = weekRanges(daysUntil(profile.dDay, now: startedAt));
  final base = stagesFor(profile, ranges.length);
  final end = goalStage(profile.goal).index;
  final left = daysUntil(profile.dDay, now: today);
  final nowIndex = currentWeekIndex(ranges, left);
  final oldWeeks = {for (final w in old?.weeks ?? const <RoadmapWeek>[]) w.weekNo: w};
  final used = <String>{};
  final weeks = <RoadmapWeek>[];
  // 이번 주부터는 앞 주차보다 낮은 단계로 돌아가지 않게
  var floor = 0;

  for (var i = 0; i < ranges.length; i++) {
    final (from, to) = ranges[i];
    final prev = oldWeeks[i + 1];
    final ended = to > left;

    // 끝난 주차 · (자동 조정이면) 이번 주차는 그대로
    if (prev != null && (ended || (futureOnly && i <= nowIndex))) {
      weeks.add(prev.copyWith(fromDDay: from, toDDay: to));
      used.addAll(prev.missions.map((m) => m.id));
      if (!ended) floor = max(floor, prev.stage.index);
      continue;
    }

    final target = i > nowIndex ? base[i].index + shift : base[i].index;
    final stage = RoadmapStage.values[target.clamp(floor, max(floor, end))];
    floor = stage.index;

    // 자동 조정인데 단계가 그대로면 미션도 그대로
    if (prev != null && futureOnly && prev.stage == stage) {
      weeks.add(prev.copyWith(fromDDay: from, toDDay: to));
      used.addAll(prev.missions.map((m) => m.id));
      continue;
    }

    final missions = _pick(
      stage,
      seed: crushId * 31 + (i + 1) * 7,
      canMeet: profile.meetingsPerWeek > 0,
      maxLevel: courageMax(profile.courage),
      used: used,
      keep: [
        for (final m in prev?.missions ?? const <RoadmapMission>[])
          if (m.done) m,
      ],
      order: orderFor?.call(stage, i + 1),
    );
    used.addAll(missions.map((m) => m.id));
    weeks.add(RoadmapWeek(
      weekNo: i + 1,
      stage: stage,
      fromDDay: from,
      toDDay: to,
      missions: missions,
    ));
  }

  // 주차가 줄었으면 없어진 주차의 완료 미션은 마지막 주차에 남김
  final extra = [
    for (final w in oldWeeks.values)
      if (w.weekNo > ranges.length)
        for (final m in w.missions)
          if (m.done && !used.contains(m.id)) m,
  ];
  if (extra.isNotEmpty) {
    final last = weeks.removeLast();
    weeks.add(last.copyWith(missions: [...last.missions, ...extra]));
  }
  return weeks;
}

/// 한 주차 미션 고르기: keep(남길 완료 미션) 먼저, 모자란 만큼 사전에서
/// order: 사전 번호 순서 (학습), 없거나 모양이 안 맞으면 돌려 고르는 순서
List<RoadmapMission> _pick(
  RoadmapStage stage, {
  required int seed,
  required bool canMeet,
  required int maxLevel,
  required Set<String> used,
  List<RoadmapMission> keep = const [],
  List<int>? order,
}) {
  final lines = missionLines[stage]!;
  String idOf(int i) => '${stage.name}-$i';
  bool allowed(int i) => canMeet || !lines[i].offline;

  // 돌려 고르는 순서 (5와 사전 길이 7 · 8 · 9는 서로소라 빠짐없이 한 번씩)
  final given = order;
  final learned = given != null &&
      given.length == lines.length &&
      given.toSet().length == lines.length &&
      given.every((i) => i >= 0 && i < lines.length);
  final orderOf = learned
      ? given
      : [
          for (var i = 0; i < lines.length; i++) (i * 5 + seed) % lines.length,
        ];
  // 먼저 용기에 맞고 안 쓴 것 → 용기 상관없이 안 쓴 것 → 앞 주차에 쓴 것
  final tiers = <bool Function(int)>[
    (i) => allowed(i) && lines[i].level <= maxLevel && !used.contains(idOf(i)),
    (i) => allowed(i) && !used.contains(idOf(i)),
    allowed,
  ];

  final picked = <int>[];
  final keptIds = {for (final m in keep) m.id};
  for (final tier in tiers) {
    for (final i in orderOf) {
      if (keep.length + picked.length >= missionsPerWeek) break;
      if (tier(i) && !picked.contains(i) && !keptIds.contains(idOf(i))) {
        picked.add(i);
      }
    }
  }
  // 학습 순서면 쉬운 미션을 최소 1개 (없으면 학습 점수가 가장 낮은 것과 바꿈)
  if (learned && picked.isNotEmpty) {
    final easyMax = max(1, maxLevel - 1);
    bool easy(int i) => lines[i].level <= easyMax;
    final hasEasy =
        keep.any((m) => m.level <= easyMax) || picked.any(easy);
    if (!hasEasy) {
      for (final i in orderOf) {
        if (easy(i) &&
            allowed(i) &&
            !used.contains(idOf(i)) &&
            !picked.contains(i) &&
            !keptIds.contains(idOf(i))) {
          picked[picked.length - 1] = i;
          break;
        }
      }
    }
  }
  picked.sort();
  return [
    ...keep,
    for (final i in picked)
      RoadmapMission(id: idOf(i), title: lines[i].title, tip: lines[i].tip),
  ];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
