// 데이트 가이드 말해볼 문장 학습 테스트 (flutter test test/learning_date_test.dart)
// 기대값은 tool/learning/chat_rules.py · line_features.py로 같은 계산 (seed 20776 ~ 20778 모두 같은 결과)
//   켜면: 한마디 팁 · 만난 뒤 톡이 학습 순서, '다른 추천 보기'로 다음 것, 복사하면 한 번 기록
//   질문 멘트를 복사해 두면 만난 뒤 톡 첫 줄이 질문('잘 들어갔어?')
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/line_learning.dart';
import 'package:one_way_love/analysis/chat/rules/lines.dart';
import 'package:one_way_love/analysis/date/date_guide.dart';
import 'package:one_way_love/analysis/date/date_store.dart';
import 'package:one_way_love/learning/learning_db.dart';
import 'package:one_way_love/learning/learning_store.dart';
import 'package:one_way_love/learning/line_features.dart';
import 'package:one_way_love/learning/mission_features.dart';
import 'package:one_way_love/shared/models.dart';

void main() {
  /// 2026-11-20(금) 21시, 저녁 · 둘이 · 감성 카페
  final now = DateTime(2026, 11, 20, 21);
  const basis = GuideBasis(
    intimacy: Intimacy.smallTalk,
    courage: CourageLevel.standard,
    goal: Goal.friends,
  );

  Future<(DateStore, LearningStore)> stores() async {
    final learning = LearningStore(
      storage: MemoryLearningStorage(),
      domains: const [MissionDomain(), LineDomain()],
      clock: () => now,
    );
    await learning.load();
    final store = DateStore(clock: () => now)..attachLearning(learning);
    store.choose(const DateChoice(time: MeetTime.evening));
    return (store, learning);
  }

  test('켜면 말해볼 문장이 학습 순서, 다른 추천 보기로 다음 것, 복사는 한 번 기록', () async {
    final (store, learning) = await stores();
    final guide = store.build(basis);
    final tip = guide.tip!;
    expect(guide.sayings[tip], isNotNull);
    expect(guide.afterLines.length, 2);
    for (final line in guide.afterLines) {
      expect(guide.sayings[line], isNotNull, reason: line);
    }

    // 다음 추천: 팁 · 만난 뒤 톡이 다른 문장
    store.shuffle();
    final next = store.guide!;
    expect(next.tip, isNot(tip));
    expect(next.afterLines.toSet().intersection(guide.afterLines.toSet()), isEmpty);

    // 복사 기록: 한 문장에 한 번, 가이드에 없는 글자는 안 함
    await store.recordSaying(next.afterLines.first, crushId: 1);
    await store.recordSaying(next.afterLines.first, crushId: 1);
    await store.recordSaying('없는 문장', crushId: 1);
    final copies = learning.events(domain: lineDomain);
    expect(copies.map((e) => e.kind), [LearnKind.copy]);
    expect(copies.single.ctx['hour'], 21);
  });

  test('질문 멘트를 복사해 두면 만난 뒤 톡 첫 줄이 질문', () async {
    final (store, learning) = await stores();
    final deck = LineDeck.build(
      learning,
      approach: Approach.common,
      seed: 123,
      now: now,
      topic: null,
      interest: 'mid',
      shortRate: 0.1,
    );
    final questions = [
      for (final l in approachLines[Approach.common]!)
        if (lineArmOf(l).tags.contains('question')) l,
    ].take(5);
    for (final l in questions) {
      await recordCopy(learning, deck, l, crushId: 1);
    }
    final guide = store.build(basis);
    expect(guide.afterLines.first, '잘 들어갔어?');
  });

  test('끄면 말해볼 문장도 지금처럼 돌려 고름 (학습 순서 없이)', () async {
    final (store, learning) = await stores();
    await learning.setEnabled(false);
    final guide = store.build(basis);
    // 지금 앱과 같은 고르기: 만난 뒤 톡은 사전 순서로 이어진 두 줄
    final pool = [
      for (final l in approachLines[Approach.afterMeet]!)
        if (l.fits(DateTime(2026, 11, 20, 21))) l.text,
    ];
    final i = pool.indexOf(guide.afterLines.first);
    expect(i, greaterThanOrEqualTo(0));
    expect(guide.afterLines[1], pool[(i + 1) % pool.length]);
  });
}
