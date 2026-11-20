// 규칙 ⑤ 추론 + ⑥ 멘트: 지표 · 점수 → 지금 사이 추정, 다음 대화 방향, 예시 멘트
//   지금 사이: 온보딩 · 11번과 같은 3단계(Intimacy) 중 하나로 추정 + 이유
//   다음 대화 방향: 위에서부터 처음 맞는 상황 하나 (_strategies 순서가 우선순위)
//   예시 멘트: 상황마다 미리 써둔 문장 중 2개 (기획 팀이 문장만 고치면 됨)
import '../../../shared/models.dart';
import 'features.dart';
import 'lexicon.dart';
import 'scoring.dart';

/// 대화 분석 해석 결과 (피그마 12번 아래쪽 카드)
class Insight {
  const Insight({
    required this.interest,
    required this.intimacy,
    required this.intimacyReason,
    required this.strategy,
    required this.hint,
    required this.lines,
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

  /// 예시 멘트 (최대 2개)
  final List<String> lines;
}

Insight infer(ConversationFeatures f) {
  final interest = scoreInterest(f);
  final (intimacy, reason) = _estimateIntimacy(f, interest);
  final strategy = _strategies.firstWhere((s) => s.when(f, interest));
  return Insight(
    interest: interest,
    intimacy: intimacy,
    intimacyReason: reason,
    strategy: strategy.name,
    hint: strategy.hint,
    lines: strategy.lines.take(2).toList(),
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
  if (them.rate(MessageTag.invite) > 0) {
    return (Intimacy.close, '상대가 먼저 무언가를 하자고 제안해요');
  }
  if (them.rate(MessageTag.personal) > 0 && interest.score >= midScore) {
    return (Intimacy.close, '서로 사적인 이야기를 나누고 있어요');
  }
  if (f.lateNightRate >= 0.2 && interest.score >= 60) {
    return (Intimacy.close, '밤늦게까지 편하게 대화를 이어가요');
  }
  if (interest.score < 35 && them.textCount < 10) {
    return (Intimacy.faceOnly, '아직 주고받은 대화가 적고 반응도 짧아요');
  }
  return (Intimacy.smallTalk, '인사와 가벼운 대화를 주고받고 있어요');
}

// ---------- 다음 대화 방향 ----------

class _Strategy {
  const _Strategy({
    required this.name,
    required this.hint,
    required this.lines,
    required this.when,
  });

  final String name;
  final String hint;
  final List<String> lines;
  final bool Function(ConversationFeatures f, InterestScore s) when;
}

/// 위에서부터 처음 맞는 것 하나, 마지막은 항상 맞음
final _strategies = <_Strategy>[
  _Strategy(
    name: '잠시 쉬어가기',
    hint: '최근 바쁘다거나 어렵다는 말이 있었어요. 이번엔 제안보다 응원 한마디로 부담을 덜어주세요.',
    lines: [
      '요즘 많이 바쁘지? 무리하지 말고 밥 잘 챙겨 먹어!',
      '바쁜 거 끝나면 맛있는 거 먹으러 가자 ㅎㅎ',
    ],
    when: (f, s) =>
        f.them.rate(MessageTag.busy) > 0 ||
        (f.them.rate(MessageTag.decline) > 0 && (f.inviteAcceptRate ?? 0) < 0.5),
  ),
  _Strategy(
    name: '약속 제안해보기',
    hint: '호감 신호가 좋아요. 대화에서 나온 관심사로 가볍게 만날 약속을 제안해보세요.',
    lines: [
      '이번 주에 시간 되면 같이 밥 먹을래?',
      '저번에 얘기한 거 같이 가볼래? ㅎㅎ',
    ],
    when: (f, s) =>
        s.score >= highScore &&
        ((f.inviteAcceptRate ?? 0) >= 0.5 ||
            f.them.rate(MessageTag.invite) > 0 ||
            f.them.rate(MessageTag.personal) > 0 ||
            (f.askBackRate ?? 0) >= 0.3),
  ),
  _Strategy(
    name: '질문 주고받기',
    hint: '상대도 나를 궁금해하고 있어요. 대답 끝에 질문을 하나 붙여 대화를 이어가세요.',
    lines: [
      '나는 요즘 산책하는 재미에 빠졌어 ㅋㅋ 너는 요즘 뭐 재밌게 봐?',
      '주말엔 보통 뭐 하면서 쉬어?',
    ],
    when: (f, s) =>
        (f.askBackRate ?? 0) >= 0.3 || f.them.rate(MessageTag.question) >= 0.25,
  ),
  _Strategy(
    name: '가볍게 말 걸기',
    hint: '답이 짧은 편이에요. 길게 쓰지 않아도 답할 수 있는 가벼운 질문부터 건네보세요.',
    lines: [
      '오늘 점심 뭐 먹었어?',
      '이 노래 들어봤어? 요즘 계속 듣는 중 ㅎㅎ',
    ],
    when: (f, s) =>
        f.them.rate(MessageTag.shortReply) >= 0.3 ||
        (f.them.textCount > 0 && f.them.avgLength < 6),
  ),
  _Strategy(
    name: '여유 있게 기다리기',
    hint: '답장에 시간이 걸리는 편이에요. 여러 개 보내기보다 한 번에 하나만 보내고 기다려 주세요.',
    lines: [
      '시간 날 때 편하게 답해줘 ㅎㅎ',
      '오늘 하루 어땠어? 생각나서 연락했어',
    ],
    when: (f, s) => (f.them.replyMedianMinutes ?? 0) >= 120,
  ),
  _Strategy(
    name: '웃었던 주제 이어가기',
    hint: '반응이 따뜻한 편이에요. 지난 대화에서 같이 웃었던 주제로 먼저 말을 걸어보세요.',
    lines: [
      '저번에 얘기한 그거 생각나서 연락했어 ㅋㅋ',
      '이거 보자마자 네 생각났어 ㅋㅋ',
    ],
    when: (f, s) => f.them.warmRate >= 0.3,
  ),
  _Strategy(
    name: '공통 관심사 찾기',
    hint: '대화가 꾸준히 오가고 있어요. 공통 관심사 하나를 골라 조금 더 깊게 물어보세요.',
    lines: [
      '요즘 제일 재밌는 게 뭐야?',
      '너는 시험 끝나면 제일 먼저 뭐 하고 싶어?',
    ],
    when: (f, s) => true,
  ),
];
