// 규칙 ③ 주고받기 지표: 메시지 목록 → 대화 흐름 숫자
//   차례: 같은 사람이 연달아 보낸 메시지 묶음 (내 차례 → 상대 차례 → …)
//   대화 묶음: sessionGap 넘게 말이 없으면 새 대화로 나눔 (누가 시작 · 끝냈는지)
//   답장 시간: 차례가 바뀔 때 걸린 시간, maxReplyGap 넘으면 새 대화로 보고 뺌
//   평균 대신 중앙값: 밤새 답 안 한 한 번이 전체를 끌어올리지 않게
// 분석기가 나와 짝사랑 상대 메시지만 넘겨줌 (다른 사람이 섞여 있으면 모두 '상대'로 봄)
import '../chat_parser.dart';
import 'lexicon.dart';
import 'normalizer.dart';
import 'tagger.dart';
import 'topics.dart';

/// 이 시간 넘게 말이 없으면 새 대화 묶음
const sessionGap = Duration(hours: 3);

/// 답장 시간으로 셀 최대 간격
const maxReplyGap = Duration(hours: 24);

/// 앞 절반 · 뒤 절반 비교에 필요한 최소 메시지 수 (한쪽당)
const minTrendMessages = 5;

/// 이 글자 수 이상이면 길게 쓴 메시지 (정성 들인 답)
const longMessageLength = 30;

/// 표시가 붙은 메시지
class TaggedMessage {
  const TaggedMessage(this.message, this.tags, {required this.mine});

  final ChatMessage message;
  final Set<MessageTag> tags;

  /// 내가 보낸 메시지면 true
  final bool mine;

  DateTime get time => message.time;

  /// 글자 내용이 있는 메시지 (사진 · 이모티콘 · 삭제 제외)
  bool get hasText => !isPlaceholder(message.text);

  bool has(MessageTag tag) => tags.contains(tag);
}

/// 한 사람(또는 '상대' 전체) 쪽 숫자
class SideFeatures {
  const SideFeatures({
    required this.count,
    required this.textCount,
    required this.avgLength,
    required this.replyMedianMinutes,
    required this.tagRates,
    required this.warmRate,
    required this.longRate,
  });

  /// 메시지 수
  final int count;

  /// 글자 있는 메시지 수
  final int textCount;

  /// 평균 글자 수 (글자 있는 메시지 기준)
  final double avgLength;

  /// 다른 쪽 메시지 뒤 이쪽이 답하기까지 걸린 시간 중앙값 (분), 답이 없으면 null
  final double? replyMedianMinutes;

  /// 표시별 비율 0~1 (사진 · 이모티콘은 전체 메시지 기준, 나머지는 글자 있는 메시지 기준)
  final Map<MessageTag, double> tagRates;

  /// 따뜻한 표현(웃음 · 긍정 · 고마움 · 칭찬 · 챙김)이 하나라도 있는 메시지 비율 0~1
  final double warmRate;

  /// 길게 쓴 메시지(longMessageLength자 이상) 비율 0~1 (글자 있는 메시지 기준)
  final double longRate;

  double rate(MessageTag tag) => tagRates[tag] ?? 0;
}

/// 따뜻한 표현으로 보는 표시
const warmTags = {
  MessageTag.laugh,
  MessageTag.positive,
  MessageTag.thanks,
  MessageTag.compliment,
  MessageTag.care,
};

/// 앞 절반 → 뒤 절반 변화 (뒤 − 앞)
class Trend {
  const Trend({
    required this.theirReplyChange,
    required this.theirShareChange,
    required this.theirQuestionChange,
    required this.theirWarmthChange,
  });

  /// 상대 답장 시간 변화 (분), 음수면 빨라짐, 한쪽에 답이 없으면 null
  final double? theirReplyChange;

  /// 상대 메시지 비율 변화
  final double theirShareChange;

  /// 상대 질문 비율 변화
  final double theirQuestionChange;

  /// 상대 따뜻한 표현 비율 변화 (warmRate와 같은 기준)
  final double theirWarmthChange;
}

/// 대화 흐름 숫자 전체
class ConversationFeatures {
  const ConversationFeatures({
    required this.me,
    required this.them,
    required this.theirShare,
    required this.lengthBalance,
    required this.sessionCount,
    required this.theirStartRate,
    required this.theirEndRate,
    required this.askBackRate,
    required this.answerRate,
    required this.inviteAcceptRate,
    required this.lateNightRate,
    required this.theirBurstRate,
    required this.trend,
    required this.topics,
    required this.lastMessageAt,
    required this.recentMetUp,
  });

  final SideFeatures me;
  final SideFeatures them;

  /// 전체 메시지 중 상대 메시지 비율 0~1
  final double theirShare;

  /// 상대 평균 글자 수 ÷ 내 평균 글자 수 (1보다 크면 상대가 더 길게 씀)
  final double lengthBalance;

  /// 대화 묶음 수
  final int sessionCount;

  /// 상대가 먼저 말을 건 대화 묶음 비율 0~1
  final double theirStartRate;

  /// 상대 메시지로 끝난 대화 묶음 비율 0~1
  final double theirEndRate;

  /// 내 질문 차례에 상대가 질문으로 되물은 비율, 내 질문이 없으면 null
  final double? askBackRate;

  /// 내 질문 차례에 상대가 하루 안에 답한 비율, 내 질문이 없으면 null
  final double? answerRate;

  /// 내 제안에 상대가 수락한 비율, 내 제안이 없으면 null
  final double? inviteAcceptRate;

  /// 밤 11시 ~ 새벽 4시 메시지 비율 0~1
  final double lateNightRate;

  /// 상대 차례 중 3개 이상 연달아 보낸 비율 0~1
  final double theirBurstRate;

  /// 앞 절반 → 뒤 절반 변화, 메시지가 적으면 null
  final Trend? trend;

  /// 두 사람 대화에 자주 나온 주제 (많은 순, 최대 3개), rules/topics.dart
  final List<Topic> topics;

  /// 마지막 메시지 시각 (오랜만에 연락하는 상황인지 볼 때)
  final DateTime lastMessageAt;

  /// 마지막 대화 묶음에 '만난 뒤 인사'(잘 들어갔어? · 오늘 즐거웠어)가 있음 (누가 보냈든)
  final bool recentMetUp;

  /// 설명 · 디버그용 (숫자는 소수 둘째 자리까지)
  Map<String, Object?> toMap() => {
        'myCount': me.count,
        'theirCount': them.count,
        'theirShare': _round(theirShare),
        'myAvgLength': _round(me.avgLength),
        'theirWarmRate': _round(them.warmRate),
        'theirAvgLength': _round(them.avgLength),
        'theirLongRate': _round(them.longRate),
        'lengthBalance': _round(lengthBalance),
        'myReplyMedianMin': _roundOrNull(me.replyMedianMinutes),
        'theirReplyMedianMin': _roundOrNull(them.replyMedianMinutes),
        'sessionCount': sessionCount,
        'theirStartRate': _round(theirStartRate),
        'theirEndRate': _round(theirEndRate),
        'askBackRate': _roundOrNull(askBackRate),
        'answerRate': _roundOrNull(answerRate),
        'inviteAcceptRate': _roundOrNull(inviteAcceptRate),
        'lateNightRate': _round(lateNightRate),
        'theirBurstRate': _round(theirBurstRate),
        'theirTagRates': {
          for (final e in them.tagRates.entries)
            if (e.value > 0) e.key.name: _round(e.value),
        },
        'myTagRates': {
          for (final e in me.tagRates.entries)
            if (e.value > 0) e.key.name: _round(e.value),
        },
        'topics': [for (final t in topics) t.name],
        'lastMessageAt': lastMessageAt.toIso8601String(),
        'recentMetUp': recentMetUp,
        if (trend != null)
          'trend': {
            'theirReplyChangeMin': _roundOrNull(trend!.theirReplyChange),
            'theirShareChange': _round(trend!.theirShareChange),
            'theirQuestionChange': _round(trend!.theirQuestionChange),
            'theirWarmthChange': _round(trend!.theirWarmthChange),
          },
      };
}

/// 메시지 목록 + 내 이름 → 대화 흐름 숫자 (messages는 시간 순, 비어 있으면 안 됨)
ConversationFeatures computeFeatures(List<ChatMessage> messages, String me) {
  if (messages.isEmpty) {
    throw ArgumentError.value(messages, 'messages', '메시지가 없음');
  }
  final tagged = [
    for (final m in messages)
      TaggedMessage(m, tagMessage(m.text), mine: m.sender == me),
  ];
  final turns = _turns(tagged);
  final sessions = _sessions(tagged);

  final myReplies = <double>[];
  final theirReplies = <double>[];
  for (var i = 1; i < turns.length; i++) {
    // 같은 쪽이 대화를 다시 시작한 건 답장이 아님
    if (turns[i].mine == turns[i - 1].mine) continue;
    final minutes = _gapMinutes(turns[i - 1].last.time, turns[i].first.time);
    if (minutes == null) continue;
    (turns[i].mine ? myReplies : theirReplies).add(minutes);
  }

  final mine = [for (final t in tagged) if (t.mine) t];
  final theirs = [for (final t in tagged) if (!t.mine) t];
  final meSide = _side(mine, myReplies);
  final themSide = _side(theirs, theirReplies);

  // 내 질문 · 제안 차례 → 바로 다음 상대 차례의 반응
  var myQuestionTurns = 0, answered = 0, askedBack = 0;
  var myInviteTurns = 0, accepted = 0;
  for (var i = 0; i < turns.length; i++) {
    final turn = turns[i];
    if (!turn.mine) continue;
    final next = i + 1 < turns.length ? turns[i + 1] : null;
    // 바로 다음이 하루 안에 온 상대 차례일 때만 '반응'으로 봄
    final reply = next != null &&
            !next.mine &&
            _gapMinutes(turn.last.time, next.first.time) != null
        ? next
        : null;

    if (turn.any(MessageTag.question)) {
      myQuestionTurns++;
      if (reply != null) {
        answered++;
        if (reply.any(MessageTag.question)) askedBack++;
      }
    }
    if (turn.any(MessageTag.invite)) {
      myInviteTurns++;
      if (reply != null && reply.any(MessageTag.agree)) accepted++;
    }
  }

  final theirTurns = [for (final t in turns) if (!t.mine) t];
  final lengthBalance =
      meSide.avgLength == 0 ? 1.0 : themSide.avgLength / meSide.avgLength;

  return ConversationFeatures(
    me: meSide,
    them: themSide,
    theirShare: theirs.length / tagged.length,
    lengthBalance: lengthBalance,
    sessionCount: sessions.length,
    theirStartRate: _ratio(sessions.where((s) => !s.first.mine).length,
        sessions.length),
    theirEndRate:
        _ratio(sessions.where((s) => !s.last.mine).length, sessions.length),
    askBackRate: myQuestionTurns == 0 ? null : askedBack / myQuestionTurns,
    answerRate: myQuestionTurns == 0 ? null : answered / myQuestionTurns,
    inviteAcceptRate: myInviteTurns == 0 ? null : accepted / myInviteTurns,
    lateNightRate: _ratio(
      tagged.where((t) => t.time.hour >= 23 || t.time.hour < 4).length,
      tagged.length,
    ),
    theirBurstRate: _ratio(
      theirTurns.where((t) => t.messages.length >= 3).length,
      theirTurns.length,
    ),
    trend: _trend(tagged),
    topics: detectTopics([
      for (final t in tagged)
        if (t.hasText) normalize(t.message.text).compact,
    ]),
    lastMessageAt: tagged.last.time,
    recentMetUp: sessions.last.any((t) => t.has(MessageTag.metUp)),
  );
}

// ---------- 묶기 ----------

/// 같은 쪽이 연달아 보낸 메시지 묶음
class _Turn {
  _Turn(this.mine);

  final bool mine;
  final messages = <TaggedMessage>[];

  TaggedMessage get first => messages.first;
  TaggedMessage get last => messages.last;

  bool any(MessageTag tag) => messages.any((m) => m.has(tag));
}

/// 보낸 쪽이 바뀌거나 sessionGap 넘게 말이 없으면 새 차례
List<_Turn> _turns(List<TaggedMessage> tagged) {
  final turns = <_Turn>[];
  for (final t in tagged) {
    final last = turns.isEmpty ? null : turns.last;
    if (last == null ||
        last.mine != t.mine ||
        t.time.difference(last.last.time) > sessionGap) {
      turns.add(_Turn(t.mine));
    }
    turns.last.messages.add(t);
  }
  return turns;
}

/// sessionGap 넘게 말이 없으면 나눈 대화 묶음
List<List<TaggedMessage>> _sessions(List<TaggedMessage> tagged) {
  final sessions = <List<TaggedMessage>>[];
  for (final t in tagged) {
    final last = sessions.isEmpty ? null : sessions.last.last;
    if (last == null || t.time.difference(last.time) > sessionGap) {
      sessions.add([t]);
    } else {
      sessions.last.add(t);
    }
  }
  return sessions;
}

// ---------- 계산 ----------

SideFeatures _side(List<TaggedMessage> list, List<double> replies) {
  final texts = [for (final t in list) if (t.hasText) t];
  return SideFeatures(
    count: list.length,
    textCount: texts.length,
    avgLength: texts.isEmpty
        ? 0
        : texts.fold(0, (sum, t) => sum + textLength(t.message.text)) /
            texts.length,
    replyMedianMinutes: _median(replies),
    tagRates: {
      for (final tag in MessageTag.values)
        tag: tag == MessageTag.media || tag == MessageTag.sticker
            ? _ratio(list.where((t) => t.has(tag)).length, list.length)
            : _ratio(texts.where((t) => t.has(tag)).length, texts.length),
    },
    warmRate: _ratio(
      texts.where((t) => t.tags.any(warmTags.contains)).length,
      texts.length,
    ),
    longRate: _ratio(
      texts
          .where((t) => textLength(t.message.text) >= longMessageLength)
          .length,
      texts.length,
    ),
  );
}

/// 앞 절반 vs 뒤 절반 (시간 기준), 어느 쪽이든 메시지가 적으면 null
Trend? _trend(List<TaggedMessage> tagged) {
  final first = tagged.first.time;
  final mid = first.add(tagged.last.time.difference(first) ~/ 2);
  final before = [for (final t in tagged) if (!t.time.isAfter(mid)) t];
  final after = [for (final t in tagged) if (t.time.isAfter(mid)) t];
  if (before.length < minTrendMessages || after.length < minTrendMessages) {
    return null;
  }

  final a = _halfStats(before);
  final b = _halfStats(after);
  final replyA = a.theirReply;
  final replyB = b.theirReply;
  return Trend(
    theirReplyChange:
        replyA == null || replyB == null ? null : replyB - replyA,
    theirShareChange: b.theirShare - a.theirShare,
    theirQuestionChange: b.theirQuestion - a.theirQuestion,
    theirWarmthChange: b.theirWarmth - a.theirWarmth,
  );
}

class _HalfStats {
  const _HalfStats(
    this.theirReply,
    this.theirShare,
    this.theirQuestion,
    this.theirWarmth,
  );

  final double? theirReply;
  final double theirShare;
  final double theirQuestion;
  final double theirWarmth;
}

_HalfStats _halfStats(List<TaggedMessage> half) {
  final turns = _turns(half);
  final replies = <double>[];
  for (var i = 1; i < turns.length; i++) {
    if (turns[i].mine || !turns[i - 1].mine) continue;
    final minutes = _gapMinutes(turns[i - 1].last.time, turns[i].first.time);
    if (minutes != null) replies.add(minutes);
  }
  final theirTexts = [for (final t in half) if (!t.mine && t.hasText) t];
  return _HalfStats(
    _median(replies),
    _ratio(half.where((t) => !t.mine).length, half.length),
    _ratio(theirTexts.where((t) => t.has(MessageTag.question)).length,
        theirTexts.length),
    _ratio(
      theirTexts.where((t) => t.tags.any(warmTags.contains)).length,
      theirTexts.length,
    ),
  );
}

/// 두 시각 사이 분, maxReplyGap 넘거나 거꾸로면 null
double? _gapMinutes(DateTime from, DateTime to) {
  final gap = to.difference(from);
  if (gap.isNegative || gap > maxReplyGap) return null;
  return gap.inSeconds / 60;
}

double _ratio(int part, int whole) => whole == 0 ? 0 : part / whole;

double? _median(List<double> values) {
  if (values.isEmpty) return null;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

double _round(double v) => (v * 100).round() / 100;

double? _roundOrNull(double? v) => v == null ? null : _round(v);
