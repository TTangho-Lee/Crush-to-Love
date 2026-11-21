// 분석 기록: 분석할 때마다 숫자만 남기고, 같은 상대의 지난 기록과 비교
// 대화 원문 · 메시지는 저장하지 않음 (상대 이름과 숫자만)
import '../chat_parser.dart';

/// 분석 기록 한 번
class ChatRecord {
  const ChatRecord({
    required this.analyzedAt,
    required this.partner,
    required this.lastMessageAt,
    required this.score,
    required this.replyMinutes,
    required this.warmRate,
    required this.startRate,
    required this.askBackRate,
    required this.messageCount,
  });

  /// 분석한 시각
  final DateTime analyzedAt;

  /// 짝사랑 상대 이름 (상대별로 기록을 모음)
  final String partner;

  /// 분석한 대화의 마지막 메시지 시각 (같은 대화를 다시 분석했는지 구분용)
  final DateTime lastMessageAt;

  /// 호감 신호 점수 0~100
  final int score;

  /// 상대 보통 답장 시간 (분), 답이 없었으면 null
  final double? replyMinutes;

  /// 상대 따뜻한 표현 비율 0~1
  final double warmRate;

  /// 상대가 먼저 말을 건 비율 0~1
  final double startRate;

  /// 내 질문에 되물은 비율 0~1, 내 질문이 없었으면 null
  final double? askBackRate;

  /// 분석한 메시지 수 (나 + 상대)
  final int messageCount;

  Map<String, Object?> toRow() => {
        'analyzed_at': analyzedAt.toIso8601String(),
        'partner': partner,
        'last_message_at': lastMessageAt.toIso8601String(),
        'score': score,
        'reply_minutes': replyMinutes,
        'warm_rate': warmRate,
        'start_rate': startRate,
        'ask_back_rate': askBackRate,
        'message_count': messageCount,
      };

  factory ChatRecord.fromRow(Map<String, Object?> row) => ChatRecord(
        analyzedAt: DateTime.parse(row['analyzed_at'] as String),
        partner: row['partner'] as String,
        lastMessageAt: DateTime.parse(row['last_message_at'] as String),
        score: row['score'] as int,
        replyMinutes: (row['reply_minutes'] as num?)?.toDouble(),
        warmRate: (row['warm_rate'] as num).toDouble(),
        startRate: (row['start_rate'] as num).toDouble(),
        askBackRate: (row['ask_back_rate'] as num?)?.toDouble(),
        messageCount: row['message_count'] as int,
      );
}

/// 지난 분석과 비교한 결과 (피그마 12번 '지난 분석과 비교' 카드)
class ChatComparison {
  const ChatComparison({
    required this.previous,
    required this.current,
    required this.recentScores,
  });

  final ChatRecord previous;
  final ChatRecord current;

  /// 최근 점수들 (오래된 → 지금, 최대 5개)
  final List<int> recentScores;

  /// 점수 차이 (지금 − 지난번)
  int get scoreDiff => current.score - previous.score;

  /// 카드 제목 ('지난 분석보다 호감 신호 +8점')
  String get title {
    final d = scoreDiff;
    if (d == 0) return '지난 분석과 호감 신호가 같아요';
    return '지난 분석보다 호감 신호 ${d > 0 ? '+' : ''}$d점';
  }

  /// 카드 설명 줄들
  List<String> get lines {
    final p = previous;
    final c = current;
    final out = <String>['지난 분석 · ${_md(p.lastMessageAt)}까지'];

    final pr = p.replyMinutes;
    final cr = c.replyMinutes;
    if (pr != null && cr != null && (pr - cr).abs() >= 1) {
      out.add('보통 답장 ${formatMinutes(pr.round())} → ${formatMinutes(cr.round())}');
    }
    if ((c.startRate - p.startRate).abs() >= 0.1) {
      out.add('상대가 먼저 말 걸기 ${_percent(p.startRate)} → ${_percent(c.startRate)}');
    }
    if ((c.warmRate - p.warmRate).abs() >= 0.1) {
      out.add('긍정 표현 ${_percent(p.warmRate)} → ${_percent(c.warmRate)}');
    }
    if (recentScores.length >= 3) {
      out.add('최근 점수 ${recentScores.join(' → ')}');
    }
    return out;
  }
}

/// 같은 상대의 지난 기록들(마지막 메시지 시각 순)과 이번 기록 비교, 지난 기록이 없으면 null
ChatComparison? compareWithHistory(
  List<ChatRecord> previous,
  ChatRecord current,
) {
  if (previous.isEmpty) return null;
  final scores = [for (final r in previous) r.score, current.score];
  return ChatComparison(
    previous: previous.last,
    current: current,
    recentScores: scores.length > 5 ? scores.sublist(scores.length - 5) : scores,
  );
}

String _md(DateTime d) => '${d.month}월 ${d.day}일';

String _percent(double v) => '${(v * 100).round()}%';
