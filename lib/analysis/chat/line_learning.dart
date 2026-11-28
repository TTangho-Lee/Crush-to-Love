// 멘트 학습 연결 (lib/learning/line_features.dart ↔ 대화 분석 결과 화면)
//   멘트 하나 → LineArm: 대화 분석과 같은 단어 사전(tagMessage)으로 질문 · 제안 · 공유 · 챙김 · 칭찬/애정 · 웃음 · 리액션,
//     글자 수, 시간대 · 요일을 단 멘트인지
//   LineDeck: 분석 결과 하나의 멘트 순서 (결과 화면이 열려 있는 동안 고정)
//     지금 시각에 맞는 주제 멘트 · 방향 멘트를 따로 학습 점수 순으로, 같으면 지금 앱처럼 seed로 돌려 고른 순서
//     화면마다 주제 멘트 1 + 방향 멘트 2 (주제 멘트가 없으면 방향 멘트 3), '↻'로 다음 화면 (한 바퀴 돌면 처음부터)
//     seed = 분석 seed · 말 높이 (같은 대화는 같은 순서)
//   기록: 복사 +1 (화면마다 한 줄에 한 번)
//     '↻'에 복사 안 한 줄의 약한 −는 시뮬레이션에서 오히려 나빠져서 안 씀 (tool/learning/simulate_lines.py)
import '../../learning/learning_db.dart';
import '../../learning/learning_store.dart';
import '../../learning/line_features.dart';
import '../../learning/linear_ts.dart';
import 'rules/lexicon.dart';
import 'rules/lines.dart';
import 'rules/normalizer.dart';
import 'rules/tagger.dart';
import 'rules/topics.dart';

/// 복사 보상
const rewardCopy = 1.0;

/// 멘트 사전 한 줄 (화면에서 Line 이름이 겹치지 않게)
typedef DeckLine = Line;

/// 멘트 → 학습용 멘트
LineArm lineArmOf(Line line) {
  final t = tagMessage(line.text);
  final has = <String, bool>{
    'question': t.contains(MessageTag.question),
    'invite': t.contains(MessageTag.invite),
    'share': t.contains(MessageTag.share),
    'care': t.contains(MessageTag.care),
    'warm': t.contains(MessageTag.compliment) || t.contains(MessageTag.affection),
    'laugh': t.contains(MessageTag.laugh),
    'react': t.contains(MessageTag.surprise) || t.contains(MessageTag.empathy),
  };
  return LineArm(
    key: '${fnv1a(line.text)}',
    tags: {for (final n in lineTagNames) if (has[n] == true) n},
    length: textLength(line.text),
    timed: line.slot != null || line.weekend != null,
  );
}

/// 분석 결과 하나의 멘트 순서
class LineDeck {
  const LineDeck._(this.topic, this.generic, this.context);

  /// 학습 순서로 만들기
  /// interest: 호감 신호 단계 이름, shortRate: 상대 짧은 대답 비율
  factory LineDeck.build(
    LearningStore store, {
    required Approach approach,
    required int seed,
    required DateTime now,
    Topic? topic,
    bool formal = false,
    String? interest,
    double shortRate = 0,
  }) {
    final (topicPool, generic) =
        linePools(approach, now: now, topic: topic, formal: formal);
    final ctx = LineContext(
      interest: interest,
      shortRate: shortRate,
      hour: now.hour,
    );
    final theta = store.sampleOf(lineDomain, 'deck|$seed|${formal ? 1 : 0}');
    List<Line> order(List<Line> pool) {
      final rows = <(double, int, Line)>[
        for (var i = 0; i < pool.length; i++)
          (
            dot(theta, lineFeatures(ctx, lineArmOf(pool[i]))),
            // 지금 앱의 돌려 고르는 순서 (seed번째가 처음)
            (i - seed) % pool.length,
            pool[i],
          ),
      ];
      rows.sort((a, b) {
        final byScore = b.$1.compareTo(a.$1);
        return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
      });
      return [for (final r in rows) r.$3];
    }

    return LineDeck._(order(topicPool), order(generic), ctx);
  }

  /// 주제 멘트 (학습 순서)
  final List<Line> topic;

  /// 방향 멘트 (학습 순서)
  final List<Line> generic;

  /// 이 분석의 문맥 (기록용)
  final LineContext context;

  /// round번째 화면 멘트 (사전 문장 그대로, 말투는 화면에서)
  List<Line> round(int round) {
    final out = <Line>[];
    final k = topic.isEmpty ? 3 : 2;
    if (topic.isNotEmpty) out.add(topic[round % topic.length]);
    final g = generic.length;
    for (var i = 0; i < k && i < g; i++) {
      final line = generic[(k * round + i) % g];
      if (out.every((l) => l.text != line.text)) out.add(line);
    }
    return out;
  }
}

/// 멘트 복사 기록
Future<LearnEvent?> recordCopy(
  LearningStore store,
  LineDeck deck,
  Line line, {
  required int crushId,
}) {
  final arm = lineArmOf(line);
  return store.record(
    domain: lineDomain,
    crushId: crushId,
    arm: arm.key,
    ctx: deck.context.toJson(arm),
    reward: rewardCopy,
    kind: LearnKind.copy,
  );
}
