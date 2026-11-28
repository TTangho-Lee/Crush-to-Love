// 로드맵 · 미션 규칙 테스트 (flutter test test/roadmap_test.dart)
// 주차 나누기 · 단계 · 미션 고르기 · 진척도(목표 · 용기에 따라 다르게) · 오늘의 미션 · 자동 조정 · 상대별 저장
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/rules/lines.dart' show Approach;
import 'package:one_way_love/analysis/chat/rules/scoring.dart'
    show InterestLevel;
import 'package:one_way_love/roadmap/roadmap_db.dart';
import 'package:one_way_love/roadmap/mission_lines.dart';
import 'package:one_way_love/roadmap/roadmap_models.dart';
import 'package:one_way_love/roadmap/roadmap_rules.dart';
import 'package:one_way_love/roadmap/roadmap_store.dart';
import 'package:one_way_love/roadmap/roadmap_generator.dart';
import 'package:one_way_love/onboarding/data/crush_store.dart';
import 'package:one_way_love/shared/models.dart';

/// 상대 목록 메모리 저장소
class MemoryCrushes implements CrushStorage {
  CrushSnapshot? saved;

  @override
  Future<CrushSnapshot?> load() async => saved;

  @override
  Future<void> save(CrushSnapshot snapshot) async => saved = snapshot;

  @override
  Future<void> clear() async => saved = null;
}

/// 로드맵 메모리 저장소
class MemoryRoadmaps implements RoadmapStorage {
  final saved = <int, Roadmap>{};

  @override
  Future<List<Roadmap>> loadAll() async => saved.values.toList();

  @override
  Future<void> save(Roadmap roadmap) async =>
      saved[roadmap.crushId] = roadmap;

  @override
  Future<void> delete(int crushId) async => saved.remove(crushId);
}

void main() {
  final today = DateTime(2026, 11, 20);

  Profile profileOf({
    int daysLeft = 20,
    Intimacy intimacy = Intimacy.smallTalk,
    Goal goal = Goal.friends,
    int meetings = 2,
    int courage = 50,
  }) =>
      Profile(
        dDay: today.add(Duration(days: daysLeft)),
        reason: '종강',
        intimacy: intimacy,
        meetingsPerWeek: meetings,
        courage: courage,
        goal: goal,
      );

  Roadmap build(Profile p) =>
      buildRoadmap(crushId: 1, profile: p, today: today);

  /// 한 주차 미션을 모두 완료로
  Roadmap doneWeek(Roadmap r, int index, {bool brave = false}) =>
      r.copyWith(weeks: [
        for (var i = 0; i < r.weeks.length; i++)
          i == index
              ? r.weeks[i].copyWith(missions: [
                  for (final m in r.weeks[i].missions)
                    m.mark(true, at: today, brave: brave),
                ])
              : r.weeks[i],
      ]);

  test('주차 나누기: D-20이면 피그마처럼 3주, 아주 멀면 8단계까지', () {
    expect(weekRanges(20), [(20, 14), (13, 7), (6, 0)]);
    expect(weekRanges(0), [(0, 0)]);
    final far = weekRanges(100);
    expect(far.length, maxRoadmapWeeks);
    expect(far.first.$1, 100);
    expect(far.last.$2, 0);
    expect(build(profileOf(daysLeft: 100)).weeks.first.label, '1단계');
    expect(build(profileOf()).weeks.first.label, '1주차');
  });

  test('단계: 사이에서 시작해 목표에서 멈춤', () {
    expect([for (final w in build(profileOf()).weeks) w.stage], [
      RoadmapStage.topic,
      RoadmapStage.follow,
      RoadmapStage.often,
    ]);
    // 얼굴만 아는 사이 → 사귀기, 3주면 한 주에 2단계까지만
    expect(
      stagesFor(
        profileOf(intimacy: Intimacy.faceOnly, goal: Goal.dating),
        3,
      ),
      [RoadmapStage.greet, RoadmapStage.follow, RoadmapStage.plan],
    );
  });

  test('미션: 주차마다 3개, 겹치지 않고, 만남 0회 · 낮은 용기 반영', () {
    final roadmap = build(profileOf());
    final ids = [
      for (final w in roadmap.weeks)
        for (final m in w.missions) m.id,
    ];
    expect(roadmap.weeks.every((w) => w.missions.length == 3), isTrue);
    expect(ids.toSet().length, ids.length);

    for (final w in build(profileOf(meetings: 0, goal: Goal.dating)).weeks) {
      for (final m in w.missions) {
        expect(m.offline, isFalse, reason: m.title);
      }
    }
    for (final w in build(profileOf(courage: 10)).weeks) {
      for (final m in w.missions) {
        expect(m.level, 1, reason: m.title);
      }
    }
  });

  test('진척도: 목표가 높을수록 같은 미션으로 덜 오르고, 용기 낸 미션은 1.5배', () {
    double progressOf(Roadmap r, Profile p) =>
        readSituation(profile: p, roadmap: r, today: today).progress;

    final friends = profileOf();
    final dating = profileOf(goal: Goal.dating);
    final f = progressOf(doneWeek(build(friends), 0), friends);
    final d = progressOf(doneWeek(build(dating), 0), dating);
    expect(f, greaterThan(d));

    final brave = progressOf(doneWeek(build(friends), 0, brave: true), friends);
    expect(brave, closeTo(f * 1.5, 0.001));
  });

  test('오늘의 미션: 용기 · 대화 분석 추천 · 상대 반응에 맞춰 고름', () {
    // 사적 연락 · 썸 → 1주차 '가볍게 약속 잡기' (준비 · 여럿이 놀 자리 · 약속 전날 확인)
    final p = profileOf(intimacy: Intimacy.close, goal: Goal.some);
    final r = build(p);
    expect(r.weeks.first.stage, RoadmapStage.plan);

    TodayPick first(ChatSignal? chat, {Profile? profile}) => rankToday(
          readSituation(
            profile: profile ?? p,
            roadmap: profile == null ? r : build(profile),
            today: today,
            chat: chat,
          ),
          today: today,
        ).first;

    // 추천 방향과 같은 행동이 먼저
    final comfort = first(const ChatSignal(
      interest: InterestLevel.mid,
      approach: Approach.comfort,
    ));
    expect(comfort.mission.line!.tags, contains(MissionTag.care));
    expect(comfort.reason, contains(Approach.comfort.label));
    final invite = first(const ChatSignal(
      interest: InterestLevel.mid,
      approach: Approach.invite,
    ));
    expect(invite.mission.line!.tags, contains(MissionTag.invite));

    // 반응이 조심스러우면 먼저 연락 · 약속 · 마음 표현은 뒤로
    final careful = first(const ChatSignal(interest: InterestLevel.low));
    expect(
      careful.mission.line!.tags
          .intersection({MissionTag.push, MissionTag.invite, MissionTag.express}),
      isEmpty,
    );

    // 용기가 적으면 가벼운 미션
    expect(first(null, profile: profileOf(courage: 10)).mission.level, 1);
  });

  test('한 줄 진단: D-Day 지남 · 시작 전 · 진도', () {
    final p = profileOf();
    final r = build(p);
    expect(
      summaryOf(
        readSituation(profile: p, roadmap: r, today: today.add(const Duration(days: 21))),
        today: today,
      ),
      contains('D-Day가 지났어요'),
    );
    final later = today.add(const Duration(days: 5));
    expect(
      summaryOf(readSituation(profile: p, roadmap: r, today: later), today: later),
      contains('아직 시작 전'),
    );
  });

  test('자동 조정: 진도가 빠르면 다음 주부터 한 단계 당기고, 반응이 조심스러우면 늦춤', () {
    final p = profileOf(goal: Goal.some);
    final r = doneWeek(build(p), 0);
    expect([for (final w in r.weeks) w.stage], [
      RoadmapStage.topic,
      RoadmapStage.often,
      RoadmapStage.alone,
    ]);

    // 3일 만에 1주차를 다 함 → 진도 빠름
    final day3 = today.add(const Duration(days: 3));
    final fast = readSituation(profile: p, roadmap: r, today: day3);
    expect(fast.pace, Pace.ahead);
    final (shift, note) = adaptShift(fast)!;
    expect(shift, 1);
    final ahead = adaptRoadmap(r, profile: p, today: day3, shift: shift, note: note);
    expect([for (final w in ahead.weeks) w.stage], [
      RoadmapStage.topic,
      RoadmapStage.plan,
      RoadmapStage.show,
    ]);
    expect(ahead.note, note);
    expect(ahead.weeks.first.missions, r.weeks.first.missions); // 이번 주는 그대로
    // 한 번 당기면 진도만으로는 더 안 바꿈
    expect(
      adaptShift(readSituation(profile: p, roadmap: ahead, today: day3)),
      isNull,
    );

    // 상대 반응이 조심스러우면 한 단계 늦춤 (이번 주보다 낮게는 안 감)
    final careful = adaptShift(readSituation(
      profile: p,
      roadmap: ahead,
      today: day3,
      chat: const ChatSignal(interest: InterestLevel.low),
    ))!;
    expect(careful.$1, -1);
    final slow = adaptRoadmap(
      ahead,
      profile: p,
      today: day3,
      shift: careful.$1,
      note: careful.$2,
    );
    expect([for (final w in slow.weeks) w.stage], [
      RoadmapStage.topic,
      RoadmapStage.follow,
      RoadmapStage.plan,
    ]);
  });

  test('상대별 로드맵 저장 · 완료 저장 · 다시 짜도 완료 미션 남김 · 지운 상대 정리', () async {
    final crushes = CrushStore(storage: MemoryCrushes());
    final roadmaps = MemoryRoadmaps();
    final store = RoadmapStore(
      storage: roadmaps,
      clock: () => today,
      loadHistory: () async => [],
    );
    store.attach(crushes);

    // 상대가 없으면 예시 (피그마 1/9 완료, 저장 안 함)
    expect(store.isExample, isTrue);
    expect(store.situation.doneCount, 1);
    expect(store.situation.totalCount, 9);
    expect(roadmaps.saved, isEmpty);

    final jimin = await crushes.add(
      nickname: '지민',
      dDay: today.add(const Duration(days: 20)),
      reason: '종강',
      intimacy: Intimacy.smallTalk,
      meetingsPerWeek: 2,
      goal: Goal.friends,
      courage: 50,
    );
    expect(store.isExample, isFalse);
    expect(roadmaps.saved[jimin.id], isNotNull);
    expect(store.daysLeft, 20);
    expect(store.currentWeek.weekNo, 1);
    expect(store.situation.doneCount, 0);

    final pick = store.todayPick!;
    await store.toggleMission(pick.mission.id);
    expect(store.situation.doneCount, 1);
    final saved = roadmaps.saved[jimin.id]!.weeks.first.missions
        .firstWhere((m) => m.id == pick.mission.id);
    expect(saved.done, isTrue);
    expect(saved.doneAt, today);

    // '↻ 다른 미션'은 남은 미션 중 다른 것
    final before = store.todayPick!.mission.id;
    store.rotateToday();
    expect(store.todayPick!.mission.id, isNot(before));

    // 다른 상대로 바꾸면 그 상대 로드맵, 돌아오면 그대로
    final minji = await crushes.add(
      nickname: '민지',
      dDay: today.add(const Duration(days: 10)),
      reason: '방학',
      intimacy: Intimacy.close,
      meetingsPerWeek: 1,
      goal: Goal.some,
      courage: 50,
    );
    expect(store.weeks.length, 2);
    expect(store.situation.doneCount, 0);
    await crushes.select(jimin.id);
    expect(store.situation.doneCount, 1);

    // 사이가 바뀌면 다시 짬 (완료한 미션은 그 주차에 남음)
    await crushes.update(crushes.current!.copyWith(intimacy: Intimacy.close));
    final week1 = store.weeks.first;
    expect(week1.missions.any((m) => m.id == pick.mission.id && m.done), isTrue);
    expect(week1.missions.length, 3);
    expect(week1.stage, RoadmapStage.often);

    // 용기 단계가 바뀌어도 다시 짬 (저전력이면 이번 주 남은 미션이 가벼운 것으로)
    await crushes.setCourage(10);
    for (final m in store.weeks.first.missions) {
      if (!m.done) expect(m.level, 1, reason: m.title);
    }

    // DB에서 다시 불러와도 같음
    final again = RoadmapStore(
      storage: roadmaps,
      clock: () => today,
      loadHistory: () async => [],
    );
    await again.load();
    again.attach(crushes);
    expect(again.situation.doneCount, 1);

    // 지운 상대 로드맵은 지움
    await crushes.remove(minji.id);
    expect(roadmaps.saved.containsKey(minji.id), isFalse);
    expect(roadmaps.saved.containsKey(jimin.id), isTrue);
  });
}
