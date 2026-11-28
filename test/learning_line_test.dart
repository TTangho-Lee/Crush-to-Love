// 멘트 학습 · 결과 보상 테스트 (flutter test test/learning_line_test.dart)
// 기대값은 tool/learning/expected_lines.py (단어 사전 · 멘트 사전을 파이썬으로 옮겨 같은 계산)
//   멘트 표시 · 특징 / 학습 순서 (기록이 없을 때 · 질문 멘트를 복사한 뒤) / 복사 기록
//   다음 분석 점수 변화 → 복사한 멘트 / 짝사랑 결과 → 완료 미션
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/line_learning.dart';
import 'package:one_way_love/analysis/chat/rules/lines.dart';
import 'package:one_way_love/analysis/chat/rules/topics.dart';
import 'package:one_way_love/learning/chat_reward.dart';
import 'package:one_way_love/learning/learning_db.dart';
import 'package:one_way_love/learning/learning_store.dart';
import 'package:one_way_love/learning/line_features.dart';
import 'package:one_way_love/learning/linear_ts.dart';
import 'package:one_way_love/learning/mission_features.dart';
import 'package:one_way_love/learning/outcome_reward.dart';
import 'package:one_way_love/shared/models.dart';

void main() {
  /// 2026-11-20(금) 21시
  final now = DateTime(2026, 11, 20, 21);

  Future<LearningStore> newStore() async {
    final store = LearningStore(
      storage: MemoryLearningStorage(),
      domains: const [MissionDomain(), LineDomain()],
      clock: () => now,
    );
    await store.load();
    return store;
  }

  LineDeck deckOf(
    LearningStore store, {
    Approach approach = Approach.common,
    Topic? topic = Topic.food,
    int seed = 123,
  }) =>
      LineDeck.build(
        store,
        approach: approach,
        seed: seed,
        now: now,
        topic: topic,
        interest: 'mid',
        shortRate: 0.1,
      );

  List<String> textsOf(List<Line> lines) => [for (final l in lines) l.text];

  test('멘트 표시 · 특징: 파이썬과 같은 값', () {
    final cases = {
      '요즘 많이 바쁘지? 무리하지 말고 밥 잘 챙겨 먹어!': ({'question', 'care'}, 29),
      '바쁜 거 끝나면 맛있는 거 먹으러 가자 ㅎㅎ': ({'invite', 'laugh'}, 24),
      '아 그렇구나! 완전 괜찮아 ㅎㅎ': ({'laugh', 'react'}, 17),
      '그 와중에 다 해내는 거 진짜 대단하다': ({'warm', 'react'}, 21),
      '자기 전에 너랑 얘기하니까 좋다 ㅎㅎ': ({'share', 'laugh'}, 20),
      '오늘 진짜 고생 많았어': ({'care'}, 12),
    };
    for (final MapEntry(key: text, value: (tags, length)) in cases.entries) {
      final arm = lineArmOf(Line(text));
      expect(arm.tags, tags, reason: text);
      expect(arm.length, length, reason: text);
      expect(arm.timed, isFalse);
    }
    // 기록 key = 사전 문장 해시
    expect(lineArmOf(Line(cases.keys.first)).key, '3077332498');
    expect(
      lineArmOf(const Line('오늘도 고생 많았어! 푹 쉬어 ㅎㅎ', slot: TimeSlot.evening)).timed,
      isTrue,
    );

    // 호감 높음 · 밤 23시, 제안 + 웃음 멘트
    const c = LineContext(interest: 'high', shortRate: 0.4, hour: 23);
    final arm = lineArmOf(const Line('바쁜 거 끝나면 맛있는 거 먹으러 가자 ㅎㅎ'));
    expect(lineFeatures(c, arm), [1, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]);
    expect(lineFeatureNames.length, 14);
    // 기록 문맥 JSON으로 저장했다가 읽어도 같음
    expect(const LineDomain().featuresOf(c.toJson(arm), arm.key), lineFeatures(c, arm));
  });

  test('학습 순서: 기록이 없으면 섞인 순서 (같은 대화는 같은 순서), 화면마다 주제 1 + 방향 2', () async {
    final store = await newStore();
    final deck = deckOf(store);
    expect(deck.topic.length, 15);
    expect(deck.generic.length, 38);
    expect(textsOf(deck.round(0)), [
      '혼밥도 잘하는 편이야?',
      '혹시 좋아하는 음식 있어? 나는 떡볶이면 다 좋아 ㅋㅋ',
      '쉬는 날엔 집에 있는 게 좋아, 밖에 나가는 게 좋아? ㅋㅋ',
    ]);
    expect(textsOf(deck.round(1)), [
      '탕수육은 부먹이야 찍먹이야? ㅋㅋ',
      '요즘 보는 드라마나 예능 있어? 같이 보고 싶어서 ㅎㅎ',
      '웹툰 보는 거 있어? 추천해줘 ㅋㅋ',
    ]);
    expect(textsOf(deckOf(store).round(0)), textsOf(deck.round(0)));
    // 방향 멘트는 한 바퀴 돌 때까지 겹치지 않음
    final seen = <String>{};
    for (var r = 0; r < 19; r++) {
      for (final l in deck.round(r).skip(1)) {
        expect(seen.add(l.text), isTrue, reason: l.text);
      }
    }
    // 주제가 없으면 방향 멘트 3개
    expect(deckOf(store, topic: null).round(0).length, 3);
  });

  test('질문 멘트를 복사하면 다른 대화에서도 질문 멘트가 먼저', () async {
    final store = await newStore();
    final deck = deckOf(store);
    final questions = [
      for (final l in approachLines[Approach.common]!)
        if (lineArmOf(l).tags.contains('question')) l,
    ].take(5);
    for (final l in questions) {
      final e = await recordCopy(store, deck, l, crushId: 1);
      expect(e!.kind, LearnKind.copy);
      expect(e.ctx['hour'], 21);
      expect(e.arm, '${fnv1a(l.text)}');
    }
    expect(store.events(domain: lineDomain).length, 5);

    final next = deckOf(store, approach: Approach.react, topic: null, seed: 7);
    final shown = next.round(0);
    expect(textsOf(shown), [
      'ㅋㅋㅋ 상상만 해도 웃기다 그다음은?',
      '오 이거 맛 어땠어? 솔직 후기 궁금해 ㅋㅋ',
      '오 좋은 하루 보냈네 ㅎㅎ 제일 좋았던 게 뭐야?',
    ]);
    expect(shown.every((l) => lineArmOf(l).tags.contains('question')), isTrue);
    expect(lineTraits(store).$1.first.$1, '질문');
  });

  test('다음 분석 점수 변화 → 그 사이 복사한 멘트에도 나눠 줌', () async {
    final store = await newStore();
    final t0 = DateTime(2026, 11, 18, 22);
    await rewardChatDelta(store, crushId: 1, score: 50, lastMessageAt: t0, analyzedAt: t0);
    final deck = deckOf(store);
    for (final l in deck.round(0).take(2)) {
      await recordCopy(store, deck, l, crushId: 1);
    }
    final t1 = DateTime(2026, 11, 21, 23);
    // −8점 → −0.4를 멘트 2개에 −0.2씩
    expect(
      await rewardChatDelta(store, crushId: 1, score: 42, lastMessageAt: t1, analyzedAt: t1),
      2,
    );
    final chats = [
      for (final e in store.events(domain: lineDomain))
        if (e.kind == LearnKind.chat) e,
    ];
    expect(chats.length, 2);
    for (final e in chats) {
      expect(e.reward, closeTo(-0.2, 1e-12));
    }
  });

  test('짝사랑 결과: 성공 +0.3 · 실패 −0.1, 바꾸면 앞 결과를 빼고 새로', () async {
    final store = await newStore();
    const c = MissionContext(
      rule: 1,
      maxLevel: 2,
      pace: 'onTrack',
      meetings: 2,
      elapsed: 0.5,
    );
    for (final id in ['topic-2', 'topic-7']) {
      final arm = MissionArm(id: id, level: 1, offline: false, tags: const {'ask'});
      await store.record(
        domain: missionDomain,
        crushId: 1,
        arm: id,
        ctx: c.toJson(arm),
        reward: 1,
        kind: LearnKind.done,
      );
    }
    List<double> outcomes() => [
          for (final e in store.events(crushId: 1))
            if (e.kind == LearnKind.outcome) e.reward,
        ];

    expect(await rewardOutcome(store, crushId: 1, outcome: CrushOutcome.success), 2);
    expect(outcomes(), [outcomeRewardSuccess, outcomeRewardSuccess]);
    // 같은 결과는 한 번만
    expect(await rewardOutcome(store, crushId: 1, outcome: CrushOutcome.success), 0);
    // 실패로 바꾸면 성공 보상은 빠지고 실패 보상
    expect(await rewardOutcome(store, crushId: 1, outcome: CrushOutcome.fail), 2);
    expect(outcomes(), [outcomeRewardFail, outcomeRewardFail]);
    expect(store.meta(outcomeKey(1)), 'fail');
  });
}
