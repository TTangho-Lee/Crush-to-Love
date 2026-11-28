// 미션에 학습을 붙인 테스트 (flutter test test/learning_mission_test.dart)
// 기대값은 tool/learning/expected_mission.py (같은 계산을 파이썬으로)
// 2026-11-20(금) 14시, 지민 D-20 · 스몰토크 · 친해지기 · 주 2회 · 용기 50
//   켜면: 오늘의 미션은 학습 순서, 주차 구성은 완료 기록 5개부터 (쉬운 미션 최소 1개) / 시연 기록: 이번 주 다시 고르기 · 학습 이유
//   기록: 완료 · 취소 · ↻ · 끝난 주차 / 끄면 지금 규칙 그대로 / 대화 점수 변화 보상 / 지운 상대 정리
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/roadmap/roadmap_db.dart';
import 'package:one_way_love/roadmap/roadmap_learning.dart';
import 'package:one_way_love/roadmap/roadmap_models.dart';
import 'package:one_way_love/roadmap/roadmap_rules.dart';
import 'package:one_way_love/roadmap/roadmap_store.dart';
import 'package:one_way_love/roadmap/roadmap_generator.dart';
import 'package:one_way_love/learning/chat_reward.dart';
import 'package:one_way_love/learning/demo_records.dart';
import 'package:one_way_love/learning/learning_db.dart';
import 'package:one_way_love/learning/learning_store.dart';
import 'package:one_way_love/learning/mission_features.dart';
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

/// 뒤에서 도는 기록 · 저장이 끝날 때까지
Future<void> settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<List<String>> idsOf(RoadmapStore store) => [
      for (final w in store.weeks) [for (final m in w.missions) m.id],
    ];

void main() {
  final start = DateTime(2026, 11, 20, 14);
  late DateTime clock;

  setUp(() => clock = start);

  Future<(RoadmapStore, LearningStore, CrushStore)> stores({
    bool enabled = true,
  }) async {
    final learning = LearningStore(
      storage: MemoryLearningStorage(),
      domains: const [MissionDomain()],
      clock: () => clock,
    );
    await learning.load();
    if (!enabled) await learning.setEnabled(false);
    final crushes = CrushStore(storage: MemoryCrushes());
    final store = RoadmapStore(
      storage: MemoryRoadmaps(),
      clock: () => clock,
      loadHistory: () async => [],
    );
    store.attachLearning(learning);
    store.attach(crushes);
    await crushes.add(
      nickname: '지민',
      dDay: DateTime(2026, 12, 10),
      reason: '종강',
      intimacy: Intimacy.smallTalk,
      meetingsPerWeek: 2,
      goal: Goal.friends,
      courage: 50,
    );
    await settle();
    return (store, learning, crushes);
  }

  test('켜도 완료 기록이 5개 미만이면 주차 구성은 지금 순서, 오늘의 미션은 학습 순서', () async {
    final (store, learning, _) = await stores();
    expect(store.learns, isTrue);
    expect(canLearnWeeks(learning), isFalse);
    // 지금 앱과 같음 (돌려 고름)
    expect(idsOf(store), [
      ['topic-2', 'topic-3', 'topic-7'],
      ['follow-0', 'follow-1', 'follow-5'],
      ['often-3', 'often-4', 'often-7'],
    ]);
    // 기록이 없으면 이유는 규칙 이유
    final pick = store.todayPick!;
    expect(pick.mission.id, 'topic-2');
    expect(pick.learned, isFalse);
    // 처음 붙일 땐 이번 주는 그대로 두고 위치만 기억
    expect(learning.meta(composedKey(1)), '1');
    expect(learning.meta(judgedKey(1)), '0');
  });

  test('시연 기록을 넣으면 이번 주를 다시 고르고 이유 줄이 학습 이유로', () async {
    final (store, learning, _) = await stores();
    final before = store.todayPick!;
    final n = await seedDemoRecords(learning);
    expect(n, demoRecordCount);
    expect(demoRecordCount, inInclusiveRange(20, 30));
    expect(learning.events(crushId: 0).length, demoRecordCount);
    expect(canLearnWeeks(learning), isTrue);
    store.refreshLearning();
    await settle();
    // 이번 주: [topic-2, topic-3(혼자 준비), topic-7] → 혼자 준비 대신 스토리 답글
    expect(idsOf(store).first, ['topic-1', 'topic-2', 'topic-7']);
    final pick = store.todayPick!;
    expect(before.mission.id, 'topic-2');
    expect(pick.mission.id, 'topic-1');
    expect(pick.reason, '반응 남기는 미션을 잘 해냈어요');
    expect(pick.learned, isTrue);

    // 잘 해낸 것 · 잘 안 한 것 (가중치가 같으면 특징 순서)
    final (good, bad) = missionTraits(learning);
    expect([for (final t in good) t.$1], ['마음 표현', '인사', '반응 남기기']);
    expect([for (final t in bad) t.$1], ['직접 만나기', '혼자 준비', '챙기기']);
  });

  test('기록: 완료 · 완료 취소 · ↻ · 끝난 주차의 안 한 미션', () async {
    final (store, learning, _) = await stores();
    final pick = store.todayPick!;

    await store.toggleMission(pick.mission.id);
    await settle();
    final done = learning.events(crushId: 1);
    expect(done.map((e) => e.kind), [LearnKind.done]);
    expect(done.single.arm, pick.mission.id);
    expect(done.single.ctx['hour'], 14);

    // 취소하면 기록도 빠짐
    await store.toggleMission(pick.mission.id);
    await settle();
    expect(learning.events(crushId: 1), isEmpty);

    // '↻'는 보던 미션에 약한 −
    final before = store.todayPick!;
    store.rotateToday();
    await settle();
    final skips = learning.events(crushId: 1);
    expect(skips.map((e) => e.kind), [LearnKind.skip]);
    expect(skips.single.arm, before.mission.id);
    expect(skips.single.reward, rewardSkip);
    // 배워도 오늘 순서는 그대로 (↻ 다음 미션)
    expect(store.todayPick!.mission.id, isNot(before.mission.id));

    // 7일 뒤: 1주차가 끝남 → 안 한 3개는 '안 함', 2주차는 학습 순서로 다시 고름
    clock = start.add(const Duration(days: 7));
    await store.checkDay();
    await settle();
    final missed = [
      for (final e in learning.events(crushId: 1))
        if (e.kind == LearnKind.missed) e,
    ];
    expect(missed.length, 3);
    expect(missed.every((e) => e.reward == rewardMissed), isTrue);
    expect(missed.every((e) => !e.ctx.containsKey('hour')), isTrue);
    expect(learning.meta(judgedKey(1)), '1');
    expect(learning.meta(composedKey(1)), '2');
    // 같은 날 다시 확인해도 그대로
    await store.checkDay();
    await settle();
    expect(
      learning.events(crushId: 1).where((e) => e.kind == LearnKind.missed).length,
      3,
    );
  });

  test('완료 기록 5개부터 주차 구성 학습, 학습 순서로 고를 땐 쉬운 미션 최소 1개', () async {
    final learning = LearningStore(
      storage: MemoryLearningStorage(),
      domains: const [MissionDomain()],
      clock: () => clock,
    );
    await learning.load();
    const c = MissionContext(
      rule: 1,
      maxLevel: 2,
      pace: 'onTrack',
      meetings: 2,
      elapsed: 0.2,
    );
    const arm = MissionArm(id: 'topic-2', level: 2, offline: false, tags: {'ask'});
    for (var i = 0; i < 5; i++) {
      expect(canLearnWeeks(learning), isFalse);
      await learning.record(
        domain: missionDomain,
        crushId: 1,
        arm: arm.id,
        ctx: c.toJson(arm),
        reward: 1,
        kind: LearnKind.done,
      );
    }
    expect(canLearnWeeks(learning), isTrue);

    // 용기 2(표준)에 용기 2 미션만 앞에 세운 순서 → 3개 중 하나는 용기 1로 바뀜
    final profile = Profile(
      dDay: DateTime(2026, 12, 10),
      reason: '종강',
      intimacy: Intimacy.smallTalk,
      meetingsPerWeek: 2,
      courage: 50,
      goal: Goal.friends,
    );
    final r = buildRoadmap(crushId: 1, profile: profile, today: clock);
    final order = [1, 2, 4, 5, 6, 8, 0, 3, 7]; // topic 단계: 용기 2 먼저
    final next = recomposeWeek(r, profile: profile, weekIndex: 0, order: order);
    expect(
      [for (final m in next.weeks.first.missions) m.id],
      ['topic-0', 'topic-1', 'topic-2'],
    );
    expect(next.weeks.first.missions.where((m) => m.level == 1).length, 1);
    // 다른 주차는 그대로
    List<List<String>> rest(Roadmap x) => [
          for (final w in x.weeks.skip(1)) [for (final m in w.missions) m.id],
        ];
    expect(rest(next), rest(r));
  });

  test('끄면 지금 규칙 그대로, 기록 안 함', () async {
    final (store, learning, _) = await stores(enabled: false);
    expect(store.learns, isFalse);
    expect(idsOf(store), [
      ['topic-2', 'topic-3', 'topic-7'],
      ['follow-0', 'follow-1', 'follow-5'],
      ['often-3', 'often-4', 'often-7'],
    ]);
    final pick = store.todayPick!;
    expect(
      pick.mission.id,
      rankToday(store.situation, today: clock).first.mission.id,
    );
    await store.toggleMission(pick.mission.id);
    store.rotateToday();
    await settle();
    expect(learning.events(), isEmpty);
  });

  test('다음 분석 점수 변화 → 그 사이 완료한 연락 미션에 나눠 줌', () async {
    final learning = LearningStore(
      storage: MemoryLearningStorage(),
      domains: const [MissionDomain()],
      clock: () => clock,
    );
    await learning.load();
    final t0 = DateTime(2026, 11, 18, 22);

    // 첫 분석: 기억만
    expect(
      await rewardChatDelta(
        learning,
        crushId: 1,
        score: 50,
        lastMessageAt: t0,
        analyzedAt: t0,
      ),
      0,
    );

    // 연락 미션 2개 · 혼자 준비 미션 1개 완료
    const c = MissionContext(
      rule: 1,
      maxLevel: 2,
      pace: 'onTrack',
      meetings: 2,
      elapsed: 0.2,
    );
    for (final (id, tags) in [
      ('topic-2', {'ask'}),
      ('topic-7', {'react', 'ask'}),
      ('topic-3', {'prep'}),
    ]) {
      final arm = MissionArm(id: id, level: 1, offline: false, tags: tags);
      await learning.record(
        domain: missionDomain,
        crushId: 1,
        arm: id,
        ctx: c.toJson(arm),
        reward: 1,
        kind: LearnKind.done,
      );
    }

    // 다시 분석: +10점 → 0.5를 연락 미션 2개에 0.25씩
    final t1 = DateTime(2026, 11, 21, 23);
    expect(
      await rewardChatDelta(
        learning,
        crushId: 1,
        score: 60,
        lastMessageAt: t1,
        analyzedAt: t1,
      ),
      2,
    );
    final chats = [
      for (final e in learning.events(crushId: 1))
        if (e.kind == LearnKind.chat) e,
    ];
    expect(chats.map((e) => e.arm).toSet(), {'topic-2', 'topic-7'});
    expect(chats.every((e) => e.reward == 0.25), isTrue);

    // 같은 대화를 다시 분석하면 그대로
    expect(
      await rewardChatDelta(
        learning,
        crushId: 1,
        score: 70,
        lastMessageAt: t1,
        analyzedAt: t1.add(const Duration(hours: 1)),
      ),
      0,
    );
  });

  test('목록에 없는 상대의 기록 · meta 지우기 (상대 번호 0은 남김)', () async {
    final storage = MemoryLearningStorage();
    final learning = LearningStore(
      storage: storage,
      domains: const [MissionDomain()],
      clock: () => clock,
    );
    await learning.load();
    const c = MissionContext(
      rule: 1,
      maxLevel: 2,
      pace: 'onTrack',
      meetings: 2,
      elapsed: 0.2,
    );
    const arm = MissionArm(id: 'topic-2', level: 2, offline: false, tags: {'ask'});
    for (final id in [0, 1, 2]) {
      await learning.record(
        domain: missionDomain,
        crushId: id,
        arm: arm.id,
        ctx: c.toJson(arm),
        reward: 1,
        kind: LearnKind.done,
      );
    }
    await learning.setMeta(judgedKey(2), '1');
    await learning.setMeta(composedKey(3), '1');

    await learning.keepCrushes({1});
    expect({for (final e in learning.events()) e.crushId}, {0, 1});
    expect(storage.events.any((e) => e.crushId == 2), isFalse);
    expect(learning.meta(judgedKey(2)), isNull);
    expect(learning.meta(composedKey(3)), isNull);
  });
}
