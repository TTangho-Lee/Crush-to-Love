// 대화 분석 흐름의 데이터 모양
import '../../shared/models.dart';
import 'history/chat_record.dart';
import 'rules/features.dart';
import 'rules/inference.dart';
import 'rules/scoring.dart';

/// 대화 분석 결과 (피그마 12번)
class ChatStats {
  const ChatStats({
    required this.summary,
    required this.replyMinutes,
    required this.avgLength,
    required this.messagesPerDay,
    required this.warmPercent,
    this.change,
    required this.hint,
    required this.period,
    this.features,
    this.insight,
    this.record,
    this.isExample = false,
  });

  /// 결과 한 줄 (피그마 12번 제목, 답장 속도에 따라 바뀜)
  final String summary;

  /// 상대 보통 답장 텀 (분, 중앙값), 내 메시지 뒤 상대 답장이 한 번도 없으면 null
  /// 평균은 밤새 답 안 한 한 번에 크게 흔들려서 중앙값 사용 (호감 신호 근거와 같은 값)
  final int? replyMinutes;

  /// 상대 평균 답장 길이 (글자 수)
  final int avgLength;

  /// 하루 메시지 수 (나 + 상대)
  final int messagesPerDay;

  /// 상대 메시지 중 따뜻한 표현(웃음 · 긍정 · 고마움 · 칭찬 · 챙김) 비율 (%)
  /// 호감 신호 점수의 '웃음 · 긍정 표현' 근거와 같은 값
  final int warmPercent;

  /// 관찰된 변화 (예: '분석 기간 앞쪽보다 상대 답장이 5분 빨라졌어요.'), 비교할 만큼 대화가 없으면 null
  final String? change;

  /// 다음 대화 힌트 (insight가 있으면 insight.hint와 같음)
  final String hint;

  /// 분석한 상대와 기간 (예: '지민님과 최근 7일 대화 · 11월 13일 ~ 11월 20일')
  final String period;

  /// 주고받기 지표 전체 (rules/features.dart), 예시 결과엔 없음
  final ConversationFeatures? features;

  /// 규칙으로 해석한 결과 (호감 신호 · 지금 사이 · 다음 대화), rules/inference.dart
  final Insight? insight;

  /// 기록용 숫자 (history/chat_record.dart), 예시 결과엔 없음
  final ChatRecord? record;

  /// '예시 결과 보기'로 연 가짜 결과면 true (머리글에 '예시')
  final bool isExample;
}

/// 가짜 데이터 (피그마 예시 그대로)
const fakeChatStats = ChatStats(
  summary: '답장이 오간 리듬',
  replyMinutes: 25,
  avgLength: 17,
  messagesPerDay: 6,
  warmPercent: 67,
  change: '분석 기간 앞쪽보다 상대 답장이 18분 빨라졌고, 질문이 35%p 늘었어요.',
  hint: _fakeHint,
  period: '예시 · 최근 7일 대화',
  insight: Insight(
    interest: InterestScore(
      score: 72,
      level: InterestLevel.high,
      confidence: 0.9,
      signals: [
        Signal('내 질문에 자주 되물어요', 10),
        Signal('웃음 · 긍정 표현이 많아요', 8),
        Signal('답장이 빠른 편이에요 (보통 25분)', 5),
        Signal('짧은 대답이 종종 있어요', -4),
        Signal('최근 답장이 빨라졌어요', 3),
      ],
    ),
    intimacy: Intimacy.close,
    intimacyReason: '서로 사적인 이야기를 나누고 있어요',
    strategy: '약속 제안해보기',
    hint: _fakeHint,
    lines: [
      '이번 주에 시간 되면 같이 밥 먹을래?',
      '저번에 얘기한 거 같이 가볼래? ㅎㅎ',
    ],
  ),
  isExample: true,
);

const _fakeHint = '호감 신호가 좋아요. 대화에서 나온 관심사로 가볍게 만날 약속을 제안해보세요.';

/// 예시 결과의 '지난 분석과 비교' 카드
final fakeComparison = ChatComparison(
  previous: ChatRecord(
    analyzedAt: DateTime(2026, 11, 13),
    partner: '예시',
    lastMessageAt: DateTime(2026, 11, 13),
    score: 64,
    replyMinutes: 43,
    warmRate: 0.48,
    startRate: 0.2,
    askBackRate: 0.3,
    messageCount: 38,
  ),
  current: ChatRecord(
    analyzedAt: DateTime(2026, 11, 20),
    partner: '예시',
    lastMessageAt: DateTime(2026, 11, 20),
    score: 72,
    replyMinutes: 25,
    warmRate: 0.67,
    startRate: 0.4,
    askBackRate: 0.5,
    messageCount: 42,
  ),
  recentScores: const [58, 64, 72],
);
