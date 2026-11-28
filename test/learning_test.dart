// 학습 엔진 테스트 (flutter test test/learning_test.dart)
// 기대값은 tool/learning/expected.py (같은 계산을 파이썬으로), 소수는 1e-9까지
// 해시 · 난수 · 특징 · 모델 평균 · 뽑기 · 취소 · 상대 지우기 · 저장 · 켜기/끄기 · 파이썬 규칙 옮긴 것 확인
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/dummy/dummy_roadmap_generator.dart';
import 'package:one_way_love/learning/learning_db.dart';
import 'package:one_way_love/learning/learning_store.dart';
import 'package:one_way_love/learning/linear_ts.dart';
import 'package:one_way_love/learning/mission_features.dart';
import 'package:one_way_love/shared/models.dart';

const eps = 1e-9;

/// expected.py C1 · A1 (토요일 밤, 진도 늦음, 호감 높음, 용기보다 어려운 먼저 연락 · 약속 미션)
const c1 = MissionContext(
  rule: 3.5,
  maxLevel: 2,
  pace: 'behind',
  meetings: 2,
  elapsed: 0.5,
  restDays: 4,
  talkGap: 3,
  interest: 'high',
  weekday: 6,
  hour: 21,
);
const a1 = MissionArm(
  id: 'often-0',
  level: 3,
  offline: false,
  tags: {'push', 'invite'},
);

/// expected.py C2 · A2 (시각 모름, 호감 낮음, 가벼운 대면 인사 미션)
const c2 = MissionContext(
  rule: -1,
  maxLevel: 1,
  pace: 'onTrack',
  meetings: 0,
  elapsed: 0.25,
  interest: 'low',
);
const a2 = MissionArm(id: 'greet-0', level: 1, offline: true, tags: {'greet'});

void main() {
  final phi1 = missionFeatures(c1, a1);
  final phi2 = missionFeatures(c2, a2);
  const domain = MissionDomain();

  /// expected.py의 기록 순서 (φ, 보상, 상대)
  final seq = [
    (c1, a1, 1.0, 1),
    (c2, a2, -0.5, 2),
    (c1, a1, -0.2, 1),
    (c2, a2, 1.0, 2),
    (c1, a1, 1.0, 1),
  ];

  test('해시 · 난수: 파이썬과 같은 값', () {
    expect(fnv1a('a'), 3826002220);
    expect(fnv1a('mission|1|20261120'), 1943858516);
    expect(fnv1a('지민'), 533634841);
    final rng = LearnRng(12345);
    expect(
      [rng.nextUint32(), rng.nextUint32(), rng.nextUint32()],
      [3336926330, 1697253807, 2816511904],
    );
    final normal = LearnRng(fnv1a('x'));
    expect(normal.normal(), closeTo(0.9555994542137393, eps));
    expect(normal.normal(), closeTo(0.8841276135839495, eps));
  });

  test('특징: 22개, 파이썬과 같은 값 · 순서', () {
    expect(phi1.length, missionFeatureNames.length);
    expect(missionFeatureNames.length, 22);
    expect(phi1, [
      0.7, 1, 0.5, 0, 0, 0, //
      0, 0, 0, 0, 0, 0, 1, 1, 0, // 태그: push · invite
      1, 1, 0, 1, 0, 1, 0.5,
    ]);
    expect(phi2[0], closeTo(-0.2, eps));
    expect(phi2[3], 1);
    expect(phi2[4], closeTo(3 / 7, eps)); // 시각 모름 → 주말 평균
    expect(phi2[7], 1); // greet
    expect(phi2.where((v) => v != 0).length, 5);
    // 문맥 JSON으로 저장했다가 읽어도 같음
    expect(domain.featuresOf(c1.toJson(a1), a1.id), phi1);
    expect(domain.featuresOf(c2.toJson(a2), a2.id), phi2);
    expect(domain.featuresOf(const {'rule': 1}, 'x'), isNull);
  });

  test('모델: 사전 · 평균 · 뽑기 · 취소', () {
    expect(domain.priorPrecision.take(4).toList(), [5, 6, 6, 2]);
    final prior = LinearModel.prior(domain.priorMean, domain.priorPrecision);
    // 기록이 없으면 평균 = 사전 (규칙 점수 가중치만 1)
    expect(prior.mean()[0], closeTo(1, eps));
    expect(dot(prior.mean(), phi1), closeTo(0.7, eps));

    final m = LinearModel.prior(domain.priorMean, domain.priorPrecision);
    for (final (c, a, r, _) in seq) {
      m.update(missionFeatures(c, a), r);
    }
    final mu = m.mean();
    expect(mu[0], closeTo(0.9815222680781553, eps));
    expect(mu[1], closeTo(0.03356392508724765, eps));
    expect(mu[2], closeTo(-0.0048251805096782485, eps));
    expect(mu[3], closeTo(0.12964285831981276, eps));
    expect(dot(mu, phi1), closeTo(0.619300722038713, eps));
    expect(dot(mu, phi2), closeTo(0.12035714168018728, eps));

    final theta = m.sample(LearnRng(fnv1a('mission|t')), 0.15);
    expect(theta[0], closeTo(1.1133658060498361, eps));
    expect(theta[1], closeTo(-0.03124611738898958, eps));
    expect(theta[2], closeTo(0.025576316574755332, eps));
    expect(dot(theta, phi1), closeTo(0.5087195750057488, eps));
    // 같은 seed면 같은 값
    expect(m.sample(LearnRng(fnv1a('mission|t')), 0.15), theta);

    // 마지막 기록 빼기 = 4개만 넣은 것
    m.update(phi1, 1, weight: -1);
    final m4 = LinearModel.prior(domain.priorMean, domain.priorPrecision);
    for (final (c, a, r, _) in seq.take(4)) {
      m4.update(missionFeatures(c, a), r);
    }
    for (var i = 0; i < m.dim; i++) {
      expect(m.mean()[i], closeTo(m4.mean()[i], 1e-12));
    }
    expect(m.count, 4);

    // JSON으로 저장했다가 읽어도 같음
    final back = LinearModel.fromJson(m.toJson())!;
    expect(dot(back.mean(), phi1), closeTo(dot(m.mean(), phi1), 1e-12));
  });

  group('LearningStore', () {
    Future<LearningStore> storeWith(
      MemoryLearningStorage storage, {
      bool record = true,
    }) async {
      final store = LearningStore(storage: storage, domains: const [domain]);
      await store.load();
      if (!record) return store;
      for (final (c, a, r, crush) in seq) {
        await store.record(
          domain: missionDomain,
          crushId: crush,
          arm: a.id,
          ctx: c.toJson(a),
          reward: r,
          kind: r > 0 ? LearnKind.done : LearnKind.missed,
        );
      }
      return store;
    }

    test('기록하면 모델에 반영, 다시 불러와도 같음 (캐시 · 다시 계산 둘 다)', () async {
      final storage = MemoryLearningStorage();
      final store = await storeWith(storage);
      expect(store.events().length, 5);
      expect(dot(store.meanOf(missionDomain), phi1),
          closeTo(0.619300722038713, eps));

      // 캐시로
      final again = await storeWith(storage, record: false);
      expect(dot(again.meanOf(missionDomain), phi1),
          closeTo(0.619300722038713, eps));

      // 캐시가 없어도 기록으로 다시 계산
      storage.models.clear();
      final rebuilt = await storeWith(storage, record: false);
      expect(dot(rebuilt.meanOf(missionDomain), phi1),
          closeTo(0.619300722038713, eps));
    });

    test('취소: 한 번만, 취소한 기록은 목록에서 빠짐', () async {
      final store = await storeWith(MemoryLearningStorage());
      final last = store.events().last;
      await store.cancel(last);
      await store.cancel(last);
      expect(store.events().length, 4);

      final m4 = LinearModel.prior(domain.priorMean, domain.priorPrecision);
      for (final (c, a, r, _) in seq.take(4)) {
        m4.update(missionFeatures(c, a), r);
      }
      expect(dot(store.meanOf(missionDomain), phi1),
          closeTo(dot(m4.mean(), phi1), 1e-12));
    });

    test('상대를 지우면 그 상대 기록 없이 다시 계산', () async {
      final storage = MemoryLearningStorage();
      final store = await storeWith(storage);
      await store.forgetCrush(2);
      expect(store.events(crushId: 2), isEmpty);
      expect(storage.events.any((e) => e.crushId == 2), isFalse);
      expect(dot(store.meanOf(missionDomain), phi1),
          closeTo(0.6141964792731403, eps));
    });

    test('끄면 기록 안 함, 켜기/끄기는 저장 · 학습 지우기에도 남음', () async {
      final storage = MemoryLearningStorage();
      final store = await storeWith(storage);
      await store.setEnabled(false);
      final none = await store.record(
        domain: missionDomain,
        crushId: 1,
        arm: a1.id,
        ctx: c1.toJson(a1),
        reward: 1,
        kind: LearnKind.done,
      );
      expect(none, isNull);
      expect(store.events().length, 5);

      await store.setMeta('judged:1', '2');
      await store.clear();
      expect(store.events(), isEmpty);
      expect(store.meta('judged:1'), isNull);
      expect(dot(store.meanOf(missionDomain), phi1), closeTo(0.7, eps));

      final again = await storeWith(storage, record: false);
      expect(again.enabled, isFalse);
    });

    test('학습 이유: 같은 사건 3번 이상', () async {
      final store = await storeWith(MemoryLearningStorage(), record: false);
      // 토요일 밤 질문 미션(톡)을 4번 해냄 → 가장 많이 오른 태그(질문)가 이유
      const arm = MissionArm(id: 'often-1', level: 1, offline: false, tags: {'ask'});
      const night = MissionContext(
        rule: 1,
        maxLevel: 2,
        pace: 'onTrack',
        meetings: 2,
        elapsed: 0.3,
        weekday: 6,
        hour: 22,
      );
      final phi = missionFeatures(night, arm);
      expect(missionLearnedReason(store, phi), isNull);
      // 2번까지는 몫이 커도(0.29) 근거가 모자라 규칙 이유, 3번째부터 학습 이유
      for (var i = 1; i <= 3; i++) {
        await store.record(
          domain: missionDomain,
          crushId: 1,
          arm: arm.id,
          ctx: night.toJson(arm),
          reward: 1,
          kind: LearnKind.done,
        );
        expect(
          missionLearnedReason(store, phi),
          i < 3 ? isNull : '질문하는 미션을 잘 해냈어요',
        );
      }
      expect(store.evidence(missionDomain, missionFeatureNames.indexOf('tag.ask')), 3);
    });
  });

  test('파이썬으로 옮긴 규칙과 같은 로드맵 (tool/learning/dart_rules.py)', () {
    final today = DateTime(2026, 11, 20);
    final r = buildDummyRoadmap(
      crushId: 1,
      profile: Profile(
        dDay: today.add(const Duration(days: 20)),
        reason: '종강',
        intimacy: Intimacy.smallTalk,
        meetingsPerWeek: 2,
        courage: 50,
        goal: Goal.friends,
      ),
      today: today,
    );
    expect([
      for (final w in r.weeks) [for (final m in w.missions) m.id],
    ], [
      ['topic-2', 'topic-3', 'topic-7'],
      ['follow-0', 'follow-1', 'follow-5'],
      ['often-3', 'often-4', 'often-7'],
    ]);
  });
}
