// 규칙 ⑤ 추론: 지표 · 점수 → 지금 사이 추정, 다음 대화 방향, 예시 멘트
//   지금 사이: 온보딩 · 11번과 같은 3단계(Intimacy) 중 하나로 추정 + 이유
//   다음 대화 방향: 먼저 지금 상황(오랜만 · 만난 뒤 · 첫 대화)을 보고, 아니면 _rules에서 처음 맞는 것 하나
//   설명 · 예시 멘트: lines.dart의 멘트 사전에서 (주제 · 시간대 · 존댓말 사이 반영)
//   예시 멘트 웃음(ㅋㅋ · ㅎㅎ)은 내 말투에 맞춰 화면에 낼 때 입힘 (linesAt, tone.dart)
import '../../../shared/models.dart';
import 'features.dart';
import 'lexicon.dart';
import 'lines.dart';
import 'scoring.dart';
import 'tone.dart';
import 'topics.dart';

/// 대화 분석 해석 결과 (피그마 12번 아래쪽 카드)
class Insight {
  const Insight({
    required this.interest,
    required this.intimacy,
    required this.intimacyReason,
    required this.strategy,
    required this.hint,
    required this.lines,
    this.topics = const [],
    this.approach,
    this.topic,
    this.formal = false,
    this.seed = 0,
    this.tone = const Tone(),
  });

  /// 호감 신호 점수
  final InterestScore interest;

  /// 대화로 본 지금 사이
  final Intimacy intimacy;

  /// 그렇게 본 이유 한 줄
  final String intimacyReason;

  /// 다음 대화 방향 이름 (예: '약속 제안해보기')
  final String strategy;

  /// 다음 대화 방향 설명
  final String hint;

  /// 예시 멘트 (최대 3개), 사전 문장 그대로 (화면에는 linesAt으로 말투를 입혀서)
  final List<String> lines;

  /// 대화에 자주 나온 주제 이름 (예: '맛집·음식'), 최대 3개
  final List<String> topics;

  /// 다음 대화 방향, 예시 결과엔 없음 (있으면 '다른 추천 보기'로 멘트를 다시 고름)
  final Approach? approach;

  /// 예시 멘트에 쓴 주제 (가장 자주 나온 것)
  final Topic? topic;

  /// 존댓말 멘트를 썼으면 true
  final bool formal;

  /// 멘트를 고를 때 쓴 seed
  final int seed;

  /// 대화 속 내 말투 (웃음 표현)
  final Tone tone;

  /// '다른 추천 보기' round번째 멘트에 말투를 입혀서 (0이면 처음 멘트, 방향을 모르면 처음 멘트 그대로)
  /// 한 번에 lines 개수만큼 건너뛰어서 앞 멘트와 겹치지 않게
  /// formal · tone: 설정에서 고른 말 높이 · 웃음 표현 (비우면 대화에서 본 값)
  List<String> linesAt(
    int round, {
    DateTime? now,
    bool? formal,
    Tone? tone,
  }) {
    final approach = this.approach;
    final useFormal = formal ?? this.formal;
    final same = round == 0 && useFormal == this.formal;
    final picked = same || approach == null || lines.isEmpty
        ? lines
        : pickLines(
            approach,
            now: now ?? DateTime.now(),
            seed: seed + round * lines.length,
            topic: topic,
            formal: useFormal,
            count: lines.length,
          );
    return applyTone(picked, tone ?? this.tone, seed: seed + round);
  }
}

/// 마지막 메시지 뒤 이만큼 말이 없으면 '오랜만에 연락하기'
const reconnectGap = Duration(days: 3);

/// 지금까지 주고받은 메시지가 이보다 적으면 '첫 대화 시작하기'
const firstTalkMessages = 15;

/// now: 시간대 · 요일에 맞는 멘트 고르기 · 오랜만인지 보기 (기본은 지금)
/// totalMessages: 분석 기간과 상관없이 나와 상대가 주고받은 메시지 수 (비우면 첫 대화인지 안 봄)
/// tone: 대화 속 내 말투 (비우면 멘트 그대로, 테스트용)
Insight infer(
  ConversationFeatures f, {
  DateTime? now,
  int? totalMessages,
  Tone tone = Tone.keep,
}) {
  final at = now ?? DateTime.now();
  final interest = scoreInterest(f);
  final (intimacy, reason) = _estimateIntimacy(f, interest);
  final approach = _pickApproach(f, interest, at, totalMessages);
  final topic = f.topics.isEmpty ? null : f.topics.first;
  // 같은 대화는 같은 설명 · 멘트, 메시지 수가 달라지면 다른 것
  final seed = f.me.count * 7 + f.them.count * 13 + f.sessionCount;
  final formal = f.me.rate(MessageTag.honorific) >= 0.5;
  return Insight(
    interest: interest,
    intimacy: intimacy,
    intimacyReason: reason,
    strategy: approach.label,
    hint: pickHint(approach, seed: seed),
    lines: pickLines(
      approach,
      now: at,
      seed: seed,
      topic: topic,
      formal: formal,
    ),
    topics: [for (final t in f.topics) t.label],
    approach: approach,
    topic: topic,
    formal: formal,
    seed: seed,
    tone: tone,
  );
}

// ---------- 지금 사이 추정 ----------

(Intimacy, String) _estimateIntimacy(
  ConversationFeatures f,
  InterestScore interest,
) {
  final them = f.them;
  final accept = f.inviteAcceptRate;

  if (accept != null && accept >= 0.5) {
    return (Intimacy.close, '따로 만나자는 제안을 받아들였어요');
  }
  if (them.rate(MessageTag.plan) > 0) {
    return (Intimacy.close, '만날 시간 · 장소를 같이 정하고 있어요');
  }
  if (them.rate(MessageTag.metUp) > 0 || f.me.rate(MessageTag.metUp) > 0) {
    return (Intimacy.close, '실제로 만나서 시간을 보낸 사이예요');
  }
  if (them.rate(MessageTag.invite) > 0) {
    return (Intimacy.close, '상대가 먼저 무언가를 하자고 제안해요');
  }
  if (them.rate(MessageTag.affection) > 0) {
    return (Intimacy.close, '보고 싶다 · 생각났다는 말이 오가는 사이예요');
  }
  if (them.rate(MessageTag.personal) > 0 && interest.score >= midScore) {
    return (Intimacy.close, '서로 사적인 이야기를 나누고 있어요');
  }
  if (f.lateNightRate >= 0.2 && interest.score >= 60) {
    return (Intimacy.close, '밤늦게까지 편하게 대화를 이어가요');
  }
  if ((them.rate(MessageTag.tease) >= 0.05 ||
          them.rate(MessageTag.aegyo) >= 0.1) &&
      interest.score >= 55) {
    return (Intimacy.close, '장난과 애교가 오갈 만큼 편한 사이예요');
  }
  if (them.rate(MessageTag.honorific) >= 0.6 &&
      f.me.rate(MessageTag.honorific) >= 0.6) {
    return (
      them.textCount < 10 ? Intimacy.faceOnly : Intimacy.smallTalk,
      '서로 존댓말을 쓰는 조심스러운 사이예요',
    );
  }
  if (interest.score < 35 && them.textCount < 10) {
    return (Intimacy.faceOnly, '아직 주고받은 대화가 적고 반응도 짧아요');
  }
  if (them.rate(MessageTag.share) >= 0.15) {
    return (Intimacy.smallTalk, '일상 이야기를 편하게 주고받고 있어요');
  }
  if (them.rate(MessageTag.greeting) > 0 && them.textCount < 15) {
    return (Intimacy.smallTalk, '인사 위주로 짧게 주고받고 있어요');
  }
  return (Intimacy.smallTalk, '인사와 가벼운 대화를 주고받고 있어요');
}

// ---------- 다음 대화 방향 ----------

/// 지금 상황 먼저 (오랜만 → 만난 뒤 → 첫 대화), 아니면 _rules
Approach _pickApproach(
  ConversationFeatures f,
  InterestScore interest,
  DateTime now,
  int? totalMessages,
) {
  if (now.difference(f.lastMessageAt) >= reconnectGap) {
    return Approach.reconnect;
  }
  if (f.recentMetUp) return Approach.afterMeet;
  if (totalMessages != null && totalMessages < firstTalkMessages) {
    return Approach.firstTalk;
  }
  return _rules.firstWhere((r) => r.$2(f, interest)).$1;
}

typedef _When = bool Function(ConversationFeatures f, InterestScore s);

/// 위에서부터 처음 맞는 것 하나, 마지막은 항상 맞음
/// 방향 이름 · 설명 · 멘트는 lines.dart
final List<(Approach, _When)> _rules = [
  // 바쁘거나 지쳤거나, 제안을 받아주지 못하는 상황이면 쉬어가기
  (
    Approach.rest,
    (f, s) =>
        f.them.rate(MessageTag.busy) > 0 ||
        f.them.rate(MessageTag.tired) >= 0.2 ||
        (f.them.rate(MessageTag.decline) > 0 && (f.inviteAcceptRate ?? 0) < 0.5),
  ),
  // 속상해하거나 기분이 상해 있으면 위로부터
  (
    Approach.comfort,
    (f, s) =>
        f.them.rate(MessageTag.sad) >= 0.2 ||
        f.them.rate(MessageTag.negative) >= 0.2,
  ),
  // 만나자는 이야기가 이미 오갔으면 구체적으로
  (
    Approach.fixPlan,
    (f, s) =>
        (f.inviteAcceptRate ?? 0) >= 0.5 ||
        f.them.rate(MessageTag.invite) > 0 ||
        f.them.rate(MessageTag.plan) > 0,
  ),
  // 호감 신호가 높고 사적인 대화가 오가면 제안
  (
    Approach.invite,
    (f, s) =>
        s.score >= highScore &&
        (f.them.rate(MessageTag.personal) > 0 ||
            (f.askBackRate ?? 0) >= 0.3 ||
            f.them.rate(MessageTag.affection) > 0 ||
            f.lateNightRate >= 0.2),
  ),
  // 상대가 존댓말이면 말 편하게
  (Approach.breakIce, (f, s) => f.them.rate(MessageTag.honorific) >= 0.5),
  // 설레는 분위기면 마음 살짝
  (
    Approach.openUp,
    (f, s) =>
        s.score >= 60 &&
        (f.them.rate(MessageTag.affection) > 0 ||
            f.them.rate(MessageTag.aegyo) >= 0.1 ||
            f.them.rate(MessageTag.tease) >= 0.05 ||
            f.them.rate(MessageTag.compliment) > 0),
  ),
  // 상대도 나를 궁금해하면 질문 주고받기
  (
    Approach.askBack,
    (f, s) =>
        (f.askBackRate ?? 0) >= 0.3 || f.them.rate(MessageTag.question) >= 0.25,
  ),
  // 상대가 자기 이야기를 먼저 하면 리액션
  (
    Approach.react,
    (f, s) =>
        f.them.rate(MessageTag.share) >= 0.15 ||
        f.them.rate(MessageTag.recommend) > 0,
  ),
  // 답이 짧으면 가벼운 질문부터
  (
    Approach.light,
    (f, s) =>
        f.them.rate(MessageTag.shortReply) >= 0.3 ||
        (f.them.textCount > 0 && f.them.avgLength < 6),
  ),
  // 내 메시지만 길면 길이 맞추기
  (
    Approach.lighten,
    (f, s) => f.them.textCount > 0 && f.lengthBalance < 0.5,
  ),
  // 답이 늦으면 여유 있게
  (Approach.patience, (f, s) => (f.them.replyMedianMinutes ?? 0) >= 120),
  // 늘 내가 먼저 시작하면 템포 맞추기
  (
    Approach.tempo,
    (f, s) => f.sessionCount >= 3 && f.theirStartRate == 0,
  ),
  // 반응이 따뜻하면 웃었던 주제
  (Approach.laughTopic, (f, s) => f.them.warmRate >= 0.3),
  // 대화가 드물면 인사 습관
  (
    Approach.routine,
    (f, s) => f.sessionCount <= 2 && f.them.count < 15,
  ),
  (Approach.common, (f, s) => true),
];
