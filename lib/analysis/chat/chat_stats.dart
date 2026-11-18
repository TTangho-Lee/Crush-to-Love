// 대화 분석 흐름의 데이터 모양

/// 대화 분석 결과 (피그마 12번)
class ChatStats {
  const ChatStats({
    required this.summary,
    required this.avgReplyMinutes,
    required this.avgLength,
    required this.messagesPerDay,
    required this.positivePercent,
  });

  /// 결과 한 줄 (피그마 12번 제목)
  final String summary;

  /// 평균 답장 텀 (분)
  final int avgReplyMinutes;

  /// 평균 답장 길이 (글자 수)
  final int avgLength;

  /// 하루 메시지 수
  final int messagesPerDay;

  /// 긍정 표현 비율 (%)
  final int positivePercent;
}

/// 가짜 데이터 (피그마 예시 그대로)
const fakeChatStats = ChatStats(
  summary: '답장이 오간 리듬',
  avgReplyMinutes: 25,
  avgLength: 17,
  messagesPerDay: 6,
  positivePercent: 67,
);
