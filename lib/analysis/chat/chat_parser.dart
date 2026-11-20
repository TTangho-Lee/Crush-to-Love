// 카톡 내보내기 텍스트 읽기: 텍스트 → 메시지 목록 (분석은 chat_analyzer.dart)
//
// 읽을 수 있는 카카오톡 내보내기 형식
//   안드로이드  배명우 님과 카카오톡 대화              ← 1:1이면 첫 줄에 상대 이름
//               저장한 날짜 : 2026년 11월 20일 오후 3:42
//               2026년 11월 19일 오후 6:23             ← 날짜 구분 줄 (버림)
//               2026년 11월 19일 오후 6:23, 이승호 : ㅇㅇ
//               2026년 11월 12일 오후 6:25, 이승호님이 … 초대했습니다.  ← 시스템 줄 (버림)
//   점 형식     2024. 1. 5. 오후 3:21, 홍길동 : 메시지
//   PC          --------------- 2024년 1월 5일 금요일 ---------------
//               [홍길동] [오후 3:21] 메시지
// 시간 없는 줄은 앞 메시지의 다음 줄 (여러 줄 메시지), '메시지가 삭제되었습니다.'는 버림
// 날짜 줄이 없는 PC 형식(일부만 복사)은 오늘 대화로 보고, 시간이 거꾸로 가면 다음 날로 넘김
// 단톡방은 분석할 때 짝사랑 상대를 골라 나와 그 사람 메시지만 계산 (chat_analyzer.dart)
// 카톡 내보내기는 처음부터 전체 대화라서, 지금부터 range(며칠 · 몇 시간) 전까지만 계산

/// 분석 기간 기본값 (9번 화면에서 바꿀 수 있음)
const defaultRange = Duration(days: 7);

/// 받아 둘 최대 기간 (일), 분석 기간 최대(30일 23시간)를 덮도록 31일
/// 파일 · 공유로 받은 대화는 이보다 오래된 부분을 읽기 전에 버림 (몇 년치 대화도 멈추지 않게)
/// 안드로이드 공유는 MainActivity.kt의 KEEP_DAYS가 같은 기준으로 먼저 자름
const keepDays = 31;

// 줄 맨 앞 날짜: '2026년 11월 20일 …', '2026. 11. 20. …', PC 날짜 줄 '----- 2026년 11월 20일 금요일 -----'
final _datePrefix =
    RegExp(r'^-*\s*(\d{4})(?:년 |\. ?)(\d{1,2})(?:월 |\. ?)(\d{1,2})');

/// 오늘에서 keepDays일 전 0시보다 오래된 줄 버리기 (첫 줄 같은 머리말은 유지)
/// 카톡 내보내기는 시간 순이라, 날짜로 시작하는 줄이 처음 기간 안에 들면 그 뒤는 그대로
/// 날짜 줄이 없으면 (날짜 없이 복사한 PC 대화) 그대로
String dropOldLines(String chatText, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final cutoff = DateTime(today.year, today.month, today.day - keepDays);
  final lines = chatText.split('\n');
  final firstDated = lines.indexWhere(_datePrefix.hasMatch);
  if (firstDated == -1) return chatText;

  var start = lines.length;
  for (var i = firstDated; i < lines.length; i++) {
    final m = _datePrefix.firstMatch(lines[i]);
    if (m == null) continue;
    final day = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    if (!day.isBefore(cutoff)) {
      start = i;
      break;
    }
  }
  if (start == firstDated) return chatText;
  return [...lines.take(firstDated), ...lines.skip(start)].join('\n');
}

/// '3일 5시간', '7일', '12시간'
String rangeLabel(Duration range) {
  final days = range.inDays;
  final hours = range.inHours % 24;
  if (days == 0) return '$hours시간';
  if (hours == 0) return '$days일';
  return '$days일 $hours시간';
}

/// 분 → '1분 안', '25분', '2시간', '1시간 30분'
String formatMinutes(int minutes) {
  if (minutes < 1) return '1분 안';
  if (minutes < 60) return '$minutes분';
  final h = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$h시간' : '$h시간 $rest분';
}

/// 메시지 한 개
class ChatMessage {
  const ChatMessage({
    required this.sender,
    required this.time,
    required this.text,
  });

  final String sender;
  final DateTime time;
  final String text;
}

/// 한 번 읽은 대화: 같은 글자를 여러 번 읽지 않도록 읽은 결과를 묶어 둠
/// 9번 화면은 파일을 받으면 compute(ParsedChat.parse, 글자)로 백그라운드에서 한 번만 읽음
class ParsedChat {
  ParsedChat._(this._lines, this.messages, this.titlePartner);

  /// 카톡 텍스트 읽기 (몇 년치 대화면 오래 걸릴 수 있음)
  static ParsedChat parse(String chatText) {
    final lines = _scan(chatText);
    return ParsedChat._(
      lines,
      _messagesFrom(lines),
      _partnerFromTitle(chatText),
    );
  }

  final List<_Line> _lines;

  /// 메시지 목록 (시간 순)
  final List<ChatMessage> messages;

  /// 1:1 안드로이드 파일 첫 줄 'OOO 님과 카카오톡 대화'의 OOO, 없으면 null
  final String? titlePartner;

  /// 대화에 나온 이름 (메시지 많은 순), from이 있으면 그 시각 이후 메시지만
  List<String> senders({DateTime? from}) {
    final counts = <String, int>{};
    for (final m in messages) {
      if (from != null && m.time.isBefore(from)) continue;
      counts[m.sender] = (counts[m.sender] ?? 0) + 1;
    }
    return counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
  }

  /// 내 이름 추측 (입력칸 미리 채우기용), 1:1 파일이 아니면 null
  /// 첫 줄의 OOO가 상대 → 나머지 한 명이 나
  String? guessMyName() {
    final partner = titlePartner;
    if (partner == null) return null;
    final others = {for (final m in messages) m.sender}..remove(partner);
    return others.length == 1 ? others.first : null;
  }

  /// 나 정하기 (내 이름 입력이 없을 때): 1:1 파일 첫 줄 → '나' → 두 명이면 첫 발신자
  /// 세 명 이상(단톡방)이면 알 수 없어서 null
  String? guessMe() {
    final fromTitle = guessMyName();
    if (fromTitle != null) return fromTitle;
    final senders = {for (final m in messages) m.sender};
    if (senders.contains('나')) return '나';
    if (senders.length > 2 || messages.isEmpty) return null;
    return messages.first.sender;
  }

  /// 지금부터 range 전까지 부분만 남긴 대화 글자 (첫 줄 같은 머리말은 유지)
  /// 형식을 못 찾으면 원래 글자 그대로, 기간 안에 대화가 없으면 머리말만
  String keepRecent({Duration range = defaultRange, DateTime? now}) {
    final lines = _lines;
    final firstTimed = lines.indexWhere((l) => l.time != null);
    if (firstTimed == -1) return [for (final l in lines) l.raw].join('\n');

    final from = (now ?? DateTime.now()).subtract(range);
    var start =
        lines.indexWhere((l) => l.time != null && !l.time!.isBefore(from));
    if (start == -1) start = lines.length;
    // PC 형식 메시지는 날짜가 앞 날짜 줄에 있어서, 바로 앞 날짜 줄부터 남김
    if (start < lines.length && !lines[start].selfDated) {
      final dateLine = lines.lastIndexWhere(
        (l) => l.kind == _Kind.stamp,
        start,
      );
      if (dateLine >= firstTimed) start = dateLine;
    }
    return [
      for (final l in lines.take(firstTimed)) l.raw,
      for (final l in lines.skip(start)) l.raw,
    ].join('\n');
  }
}

// ---------- 한 번만 쓸 때 간단히 부르는 함수 (매번 새로 읽음) ----------

/// 카톡 내보내기 텍스트 → 메시지 목록
List<ChatMessage> parseKakaoChat(String chatText) =>
    ParsedChat.parse(chatText).messages;

/// 대화에 나온 이름 (메시지 많은 순)
List<String> sendersOf(String chatText) => ParsedChat.parse(chatText).senders();

/// 내 이름 추측, 1:1 대화방 파일이 아니면 null
String? guessMyName(String chatText) =>
    ParsedChat.parse(chatText).guessMyName();

/// 지금부터 range 전까지 부분만 남긴 대화 글자
String keepRecent(
  String chatText, {
  Duration range = defaultRange,
  DateTime? now,
}) =>
    ParsedChat.parse(chatText).keepRecent(range: range, now: now);

final _oneOnOneTitle = RegExp(r'^(.+?) 님과 카카오톡 대화$');

/// 첫 줄 'OOO 님과 카카오톡 대화'에서 OOO (1:1 대화방 안드로이드 파일)
String? _partnerFromTitle(String chatText) {
  final firstLine = chatText
      .replaceFirst('\uFEFF', '')
      .trimLeft()
      .split(RegExp(r'\r?\n'))
      .first
      .trim();
  return _oneOnOneTitle.firstMatch(firstLine)?[1]?.trim();
}

// ---------- 읽기 ----------

/// 줄 종류: 메시지 / 시간만 있는 줄(날짜 구분 · 시스템) / 그 밖 (머리말 · 여러 줄 메시지의 다음 줄)
enum _Kind { message, stamp, other }

class _Line {
  const _Line(
    this.raw,
    this.kind, {
    this.time,
    this.sender,
    this.text,
    this.selfDated = true,
  });

  final String raw;
  final _Kind kind;
  final DateTime? time;
  final String? sender;
  final String? text;

  /// 줄 안에 날짜가 있으면 true (PC 형식 메시지는 시간만 있어서 false)
  final bool selfDated;
}

final _mobileMessage = RegExp(
  r'^(\d{4})년 (\d{1,2})월 (\d{1,2})일 (?:(오전|오후) )?(\d{1,2}):(\d{2}), (.+?) : (.*)$',
);
final _dotMessage = RegExp(
  r'^(\d{4})\. ?(\d{1,2})\. ?(\d{1,2})\.? (?:(오전|오후) )?(\d{1,2}):(\d{2}), (.+?) : (.*)$',
);
// 시간은 있지만 보낸 사람이 없는 줄: 날짜 구분 줄, '…님을 초대했습니다.' 같은 시스템 줄
final _mobileStamp = RegExp(
  r'^(\d{4})년 (\d{1,2})월 (\d{1,2})일 (?:(오전|오후) )?(\d{1,2}):(\d{2})(?:,.*)?$',
);
final _dotStamp = RegExp(
  r'^(\d{4})\. ?(\d{1,2})\. ?(\d{1,2})\.? (?:(오전|오후) )?(\d{1,2}):(\d{2})(?:,.*)?$',
);
final _pcMessage =
    RegExp(r'^\[(.+?)\] \[(?:(오전|오후) )?(\d{1,2}):(\d{2})\] ?(.*)$');
final _dateLine = RegExp(r'^-*\s*(\d{4})년 (\d{1,2})월 (\d{1,2})일 \S+요일\s*-*$');

/// 한 줄씩 종류와 시간 붙이기
List<_Line> _scan(String chatText) {
  final out = <_Line>[];
  final now = DateTime.now();
  var day = DateTime(now.year, now.month, now.day);
  var hasDate = false;
  DateTime? lastTime;

  // 파일 맨 앞의 BOM(보이지 않는 글자) 제거
  final body = chatText.replaceFirst('\uFEFF', '');
  for (final raw in body.split(RegExp(r'\r?\n'))) {
    final line = raw.trimRight();

    var m = _mobileMessage.firstMatch(line) ?? _dotMessage.firstMatch(line);
    if (m != null) {
      day = DateTime(_int(m[1]), _int(m[2]), _int(m[3]));
      hasDate = true;
      final time = _at(day, m[4], _int(m[5]), _int(m[6]));
      lastTime = time;
      out.add(_Line(raw, _Kind.message,
          time: time, sender: m[7]!.trim(), text: m[8]!));
      continue;
    }

    m = _mobileStamp.firstMatch(line) ?? _dotStamp.firstMatch(line);
    if (m != null) {
      day = DateTime(_int(m[1]), _int(m[2]), _int(m[3]));
      hasDate = true;
      out.add(_Line(raw, _Kind.stamp,
          time: _at(day, m[4], _int(m[5]), _int(m[6]))));
      continue;
    }

    m = _pcMessage.firstMatch(line);
    if (m != null) {
      var time = _at(day, m[2], _int(m[3]), _int(m[4]));
      // 날짜 줄 없이 복사한 대화: 시간이 앞 메시지보다 이르면 다음 날
      if (!hasDate && lastTime != null && time.isBefore(lastTime)) {
        day = day.add(const Duration(days: 1));
        time = time.add(const Duration(days: 1));
      }
      lastTime = time;
      out.add(_Line(raw, _Kind.message,
          time: time, sender: m[1]!.trim(), text: m[5]!, selfDated: false));
      continue;
    }

    m = _dateLine.firstMatch(line);
    if (m != null) {
      day = DateTime(_int(m[1]), _int(m[2]), _int(m[3]));
      hasDate = true;
      out.add(_Line(raw, _Kind.stamp, time: day));
      continue;
    }

    out.add(_Line(raw, _Kind.other));
  }
  return out;
}

/// 줄 목록 → 메시지 목록
List<ChatMessage> _messagesFrom(List<_Line> lines) {
  final messages = <ChatMessage>[];
  // 시스템 줄 바로 뒤의 시간 없는 줄은 메시지에 붙이지 않음
  var afterStamp = false;

  for (final l in lines) {
    if (l.kind == _Kind.message) {
      messages.add(ChatMessage(sender: l.sender!, time: l.time!, text: l.text!));
      afterStamp = false;
    } else if (l.kind == _Kind.stamp) {
      afterStamp = true;
    } else {
      final t = l.raw.trim();
      if (t.isEmpty || t == '메시지가 삭제되었습니다.') continue;
      if (afterStamp || messages.isEmpty) continue; // 머리말 · 시스템 줄의 다음 줄
      // 여러 줄 메시지의 다음 줄
      final last = messages.removeLast();
      messages.add(ChatMessage(
        sender: last.sender,
        time: last.time,
        text: '${last.text}\n${l.raw.trimRight()}',
      ));
    }
  }
  return messages;
}

int _int(String? s) => int.parse(s!);

/// 날짜 + '오전/오후' + 시 · 분 → DateTime (오전/오후가 없으면 24시간제)
DateTime _at(DateTime day, String? ampm, int hour, int minute) {
  var h = hour;
  if (ampm == '오전' && h == 12) h = 0;
  if (ampm == '오후' && h != 12) h += 12;
  return DateTime(day.year, day.month, day.day, h, minute);
}
