// 카톡 분석: 대화 텍스트 → ChatStats (피그마 12번)
// 기기(브라우저) 안에서 규칙으로만 계산, 서버 · AI로 보내지 않음
// 읽기는 chat_parser.dart, 메시지 표현 판단 · 주고받기 지표는 rules 폴더
// 화면 카드 숫자도 rules/features.dart 값 그대로 (호감 신호 근거와 같은 숫자)
import 'chat_parser.dart';
import 'chat_stats.dart';
import 'history/chat_record.dart';
import 'rules/features.dart';
import 'rules/inference.dart';

export 'chat_parser.dart';

/// 분석할 수 없을 때 화면에 보여줄 이유
class ChatAnalysisError implements Exception {
  const ChatAnalysisError(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 글자를 읽어서 분석 (테스트 · 짧은 대화용), 9번 화면은 미리 읽은 ParsedChat으로 analyzeParsed
ChatStats analyzeChat(
  String chatText, {
  String? myName,
  String? partnerName,
  Duration range = defaultRange,
  DateTime? now,
}) =>
    analyzeParsed(
      ParsedChat.parse(chatText),
      myName: myName,
      partnerName: partnerName,
      range: range,
      now: now,
    );

/// myName: 내 이름, 비우면 1:1 파일 첫 줄 등으로 추측
/// partnerName: 짝사랑 상대, 비우면 두 명일 때 나머지 한 명 (단톡방은 꼭 골라야 함)
/// range: 지금부터 이만큼 전까지의 대화만 분석, now: 기준 시각 (기본은 지금)
/// 상대를 정하면 나와 상대 메시지만 남기고 다른 사람 메시지는 버림
ChatStats analyzeParsed(
  ParsedChat chat, {
  String? myName,
  String? partnerName,
  Duration range = defaultRange,
  DateTime? now,
}) {
  final messages = chat.messages;
  if (messages.isEmpty) {
    throw const ChatAnalysisError(
      '카카오톡 내보내기 형식의 대화를 찾지 못했어요.\n'
      "'[이름] [오후 1:00] 내용'처럼 시간과 이름이 있는지 확인해 주세요.",
    );
  }

  final senders = {for (final m in messages) m.sender};
  final typed = myName?.trim() ?? '';
  final me = typed.isNotEmpty ? typed : chat.guessMe();
  if (me == null) {
    throw const ChatAnalysisError('여러 명이 있는 대화방이에요. 아래에서 내 이름을 골라 주세요.');
  }
  if (!senders.contains(me)) {
    throw ChatAnalysisError("'$me' 이름이 대화에 없어요. 대화에 나온 이름 그대로 입력해 주세요.");
  }
  if (senders.length < 2) {
    throw const ChatAnalysisError('상대 메시지가 없어요. 두 사람이 주고받은 대화를 붙여넣어 주세요.');
  }

  // 짝사랑 상대: 고른 사람 → 없으면 두 명일 때 나머지 한 명
  final others = {...senders}..remove(me);
  final pickedPartner = partnerName?.trim() ?? '';
  final String partner;
  if (pickedPartner.isNotEmpty) {
    if (pickedPartner == me) {
      throw const ChatAnalysisError('내 이름과 짝사랑 상대가 같아요. 상대를 다시 골라 주세요.');
    }
    if (!others.contains(pickedPartner)) {
      throw ChatAnalysisError("'$pickedPartner' 이름이 대화에 없어요. 아래에서 상대를 골라 주세요.");
    }
    partner = pickedPartner;
  } else if (others.length == 1) {
    partner = others.first;
  } else {
    throw const ChatAnalysisError('여러 명이 있는 대화방이에요. 아래에서 짝사랑 상대를 골라 주세요.');
  }

  // 나와 상대 메시지만, 지금부터 range 전까지만 남김
  final at = now ?? DateTime.now();
  final from = at.subtract(range);
  final recent = [
    for (final m in messages)
      if ((m.sender == me || m.sender == partner) && !m.time.isBefore(from)) m,
  ];
  if (!recent.any((m) => m.sender != me)) {
    throw ChatAnalysisError(
      "최근 ${rangeLabel(range)} 동안 '$partner'님의 메시지가 없어요. 분석 기간을 늘려 보세요.",
    );
  }

  // 규칙 ③ 주고받기 지표 → ④ 점수 · ⑤ 추론 · ⑥ 멘트
  final features = computeFeatures(recent, me);
  // 첫 대화인지는 분석 기간 말고 읽어 온 대화 전체로 봄
  final total =
      messages.where((m) => m.sender == me || m.sender == partner).length;
  final insight = infer(features, now: at, totalMessages: total);
  final them = features.them;
  final reply = them.replyMedianMinutes?.round();

  return ChatStats(
    summary: _summary(reply),
    replyMinutes: reply,
    avgLength: them.avgLength.round(),
    messagesPerDay: _messagesPerDay(recent),
    warmPercent: (them.warmRate * 100).round(),
    change: _describeChange(features.trend),
    hint: insight.hint,
    period: '$partner님과 최근 ${rangeLabel(range)} 대화 · '
        '${_periodLabel(recent.first.time, recent.last.time)}',
    features: features,
    insight: insight,
    record: ChatRecord(
      analyzedAt: at,
      partner: partner,
      lastMessageAt: recent.last.time,
      score: insight.interest.score,
      replyMinutes: them.replyMedianMinutes,
      warmRate: them.warmRate,
      startRate: features.theirStartRate,
      askBackRate: features.askBackRate,
      messageCount: recent.length,
    ),
  );
}

/// '11월 6일 ~ 11월 20일' (하루면 '11월 20일')
String _periodLabel(DateTime from, DateTime to) {
  String md(DateTime d) => '${d.month}월 ${d.day}일';
  final sameDay =
      from.year == to.year && from.month == to.month && from.day == to.day;
  return sameDay ? md(to) : '${md(from)} ~ ${md(to)}';
}

/// 전체 메시지 수 ÷ 첫 메시지 ~ 마지막 메시지 날짜 수 (최소 1개)
int _messagesPerDay(List<ChatMessage> messages) {
  final a = messages.first.time;
  final b = messages.last.time;
  final days = DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays +
      1;
  final perDay = (messages.length / days).round();
  return perDay < 1 ? 1 : perDay;
}

/// 결과 제목 (상대 보통 답장 텀 기준)
String _summary(int? reply) {
  if (reply == null) return '대화를 돌아봤어요';
  if (reply < 10) return '답장이 바로바로 오가요';
  if (reply < 60) return '답장이 오간 리듬';
  return '여유 있게 이어지는 대화';
}

/// 관찰된 변화: 분석 기간 앞 절반 → 뒤 절반 (features.trend, 호감 신호 '최근 …' 근거와 같은 값)
/// 답장 5분 이상, 질문 · 긍정 표현 비율 10%p 이상 차이 날 때만 ('보통 답장 +31분 · 질문 -42%p')
String? _describeChange(Trend? trend) {
  if (trend == null) return null;
  final parts = <String>[];
  String sign(int v) => v > 0 ? '+' : '-';

  final reply = trend.theirReplyChange?.round();
  if (reply != null && reply.abs() >= 5) {
    parts.add('보통 답장 ${sign(reply)}${formatMinutes(reply.abs())}');
  }
  final question = (trend.theirQuestionChange * 100).round();
  if (question.abs() >= 10) {
    parts.add('질문 ${sign(question)}${question.abs()}%p');
  }
  final warmth = (trend.theirWarmthChange * 100).round();
  if (warmth.abs() >= 10) {
    parts.add('긍정 표현 ${sign(warmth)}${warmth.abs()}%p');
  }

  return parts.isEmpty ? null : parts.join(' · ');
}
