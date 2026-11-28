// 멘트 학습 분야: 문맥 · 멘트 → 특징 φ (14개), 사전, '학습한 내용' 이름
//   멘트 표시는 대화 분석과 같은 단어 사전(tagMessage)으로 (analysis/chat/line_learning.dart)
//   φ: 1 · 질문 · 제안 · 공유 · 챙김 · 칭찬/애정 · 웃음 · 리액션 · 짧음(15자 이하) · 김(30자 이상) · 때 맞춘 멘트
//      · 질문×상대 답이 짧음 · 제안×호감 높음 · 칭찬/애정×밤
//   사전: 평균 0 (처음엔 지금처럼 섞인 순서), 표시 · 길이는 λ 2, 나머지 λ 6, 탐색 세기 0.15
//   값은 tool/learning/simulate_lines.py로 확인, line_features.py와 같은 순서 · 값
import 'learning_store.dart';

/// 멘트 분야 이름 (기록 · 모델 key)
const lineDomain = 'line';

/// 학습에 쓰는 멘트 표시 이름 (순서가 곧 φ 순서)
const lineTagNames = [
  'question',
  'invite',
  'share',
  'care',
  'warm',
  'laugh',
  'react',
];

/// 특징 이름 (설명 · 테스트용)
const lineFeatureNames = [
  'bias',
  'tag.question',
  'tag.invite',
  'tag.share',
  'tag.care',
  'tag.warm',
  'tag.laugh',
  'tag.react',
  'short',
  'long',
  'timed',
  'questionShortReply',
  'inviteHigh',
  'warmNight',
];

/// 짧은 멘트 최대 · 긴 멘트 최소 글자 수, 상대 답이 짧다고 볼 짧은 대답 비율
const lineShortMax = 15;
const lineLongMin = 30;
const lineShortReplyRate = 0.3;

/// 멘트 하나 (학습용)
class LineArm {
  const LineArm({
    required this.key,
    required this.tags,
    required this.length,
    required this.timed,
  });

  /// 사전 문장 해시 (기록 key)
  final String key;

  /// 표시 이름 (lineTagNames 중)
  final Set<String> tags;

  /// 글자 수
  final int length;

  /// 시간대 · 요일을 단 멘트면 true
  final bool timed;
}

/// 멘트를 고를 때 문맥 (숫자 · 이름만, DB에 JSON으로)
class LineContext {
  const LineContext({this.interest, this.shortRate = 0, this.hour});

  /// 호감 신호 단계 'low' · 'mid' · 'high'
  final String? interest;

  /// 상대 짧은 대답 비율 0 ~ 1
  final double shortRate;

  /// 0 ~ 23
  final int? hour;

  /// 멘트 특징까지 같이 (기록 문맥)
  Map<String, Object?> toJson(LineArm arm) => {
        'interest': ?interest,
        'short': shortRate,
        'hour': ?hour,
        'tags': [for (final t in lineTagNames) if (arm.tags.contains(t)) t],
        'len': arm.length,
        'timed': arm.timed,
      };

  static LineContext? fromJson(Map<String, Object?> j) {
    final short = j['short'];
    if (short is! num) return null;
    return LineContext(
      interest: j['interest'] as String?,
      shortRate: short.toDouble(),
      hour: j['hour'] as int?,
    );
  }

  /// 기록 문맥 속 멘트 특징, 없으면 null
  static LineArm? armFromJson(String key, Map<String, Object?> j) {
    final tags = j['tags'], len = j['len'], timed = j['timed'];
    if (tags is! List || len is! int || timed is! bool) return null;
    return LineArm(
      key: key,
      tags: {for (final t in tags) t as String},
      length: len,
      timed: timed,
    );
  }
}

/// φ (14개)
List<double> lineFeatures(LineContext c, LineArm a) {
  double flag(bool v) => v ? 1.0 : 0.0;
  final hour = c.hour;
  final night = hour != null && (hour >= 23 || hour < 5);
  return [
    1,
    for (final t in lineTagNames) flag(a.tags.contains(t)),
    flag(a.length <= lineShortMax),
    flag(a.length >= lineLongMin),
    flag(a.timed),
    flag(a.tags.contains('question')) * flag(c.shortRate >= lineShortReplyRate),
    flag(a.tags.contains('invite')) * flag(c.interest == 'high'),
    flag(a.tags.contains('warm')) * flag(night),
  ];
}

/// '학습한 내용' 화면에 보여 줄 멘트 종류 (특징 이름 → 짧은 이름)
const Map<String, String> lineTraitLabels = {
  'tag.question': '질문',
  'tag.invite': '제안',
  'tag.share': '내 이야기',
  'tag.care': '챙기기',
  'tag.warm': '칭찬 · 애정',
  'tag.laugh': '웃음',
  'tag.react': '맞장구',
  'short': '짧은 말',
  'long': '긴 말',
  'timed': '때 맞춘 말',
};

/// 멘트 분야 설정
class LineDomain implements LearnDomain {
  const LineDomain();

  @override
  String get name => lineDomain;

  @override
  int get version => 1;

  @override
  int get dim => lineFeatureNames.length;

  @override
  List<double> get priorMean => List.filled(lineFeatureNames.length, 0.0);

  @override
  List<double> get priorPrecision => [
        for (final n in lineFeatureNames)
          n.startsWith('tag.') || n == 'short' || n == 'long' || n == 'timed'
              ? 2.0
              : 6.0,
      ];

  @override
  double get scale => 0.15;

  @override
  List<double>? featuresOf(Map<String, Object?> ctx, String arm) {
    final c = LineContext.fromJson(ctx);
    final a = LineContext.armFromJson(arm, ctx);
    return c == null || a == null ? null : lineFeatures(c, a);
  }
}

/// 자주 고른 멘트 종류 · 잘 안 고른 종류 (각각 최대 count개)
(List<(String, double)>, List<(String, double)>) lineTraits(
  LearningStore store, {
  int count = 3,
}) =>
    learnedTraits(
      store,
      lineDomain,
      names: lineFeatureNames,
      labels: lineTraitLabels,
      count: count,
    );
