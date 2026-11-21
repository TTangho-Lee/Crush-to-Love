// 규칙 ② 단어 사전 적용: 메시지 하나 → 표시(태그) 묶음
//   1. 사진 · 이모티콘 같은 자리표시면 그 표시 하나만
//   2. wordTable 단어가 있으면 그 표시
//   3. 부정어가 붙으면('안 좋아', '안 예뻐', '안 보고 싶어') 긍정 쪽 표시 대신 부정
//   4. 질문 → 되묻기 · 사적인 질문 · 제안처럼 질문과 엮인 표시 ('다음에 또'는 제안 아님)
//      일상 공유는 내 이야기를 들려주는 것이라 질문이면 뺌 ('퇴근했어?'는 공유 아님)
//   5. 말투 (애교, 존댓말)
//   6. 짧은 메시지만 보는 표시 (수락, 짧은 대답)
import 'lexicon.dart';
import 'normalizer.dart';

/// 메시지 글자 → 표시 묶음
Set<MessageTag> tagMessage(String raw) {
  if (isMediaPlaceholder(raw)) return {MessageTag.media};
  if (isStickerPlaceholder(raw)) return {MessageTag.sticker};
  if (isDeletedPlaceholder(raw)) return {};

  final c = normalize(raw).compact;
  if (c.isEmpty) return {};

  final tags = <MessageTag>{
    for (final entry in _wordPatterns.entries)
      if (entry.value.hasMatch(c)) entry.key,
  };

  // '안 좋아', '안 예뻐', '안 궁금해' 같은 뒤집힌 표현
  if (_negation.hasMatch(c)) {
    tags
      ..removeAll(_flippedByNegation)
      ..add(MessageTag.negative);
  }

  final isQuestion = c.contains('?') || _questionEnding.hasMatch(c);
  if (isQuestion) {
    tags
      ..add(MessageTag.question)
      ..remove(MessageTag.share);
    if (_askBack.hasMatch(c)) tags.add(MessageTag.askBack);
    if (_personal.hasMatch(c)) tags.add(MessageTag.personal);
  }

  // '다음에 또 보자'처럼 다음을 기약하는 말은 지금 하는 제안이 아님
  if (!tags.contains(MessageTag.future) &&
      (_inviteEnding.hasMatch(c) || (isQuestion && _together.hasMatch(c)))) {
    tags.add(MessageTag.invite);
  }

  if (_aegyo.hasMatch(c)) tags.add(MessageTag.aegyo);
  if (_honorificEnding.hasMatch(c) || _honorificWord.hasMatch(c)) {
    tags.add(MessageTag.honorific);
  }

  if (c.runes.length <= agreeMaxLength &&
      !isQuestion &&
      _agreeStart.hasMatch(c)) {
    tags.add(MessageTag.agree);
  }

  if (_shortReply.hasMatch(c)) tags.add(MessageTag.shortReply);

  return tags;
}

// ---------- 단어 사전 → 정규식 (처음 한 번만 만듦) ----------

/// 끝에 붙는 웃음 · 물결 · 느낌표는 무시하고 끝말을 봄
const _tail = r'[.!~ㅋㅎㅠㅜ^♡♥]*';

/// 존댓말 끝말 뒤에 붙는 글자 (물음표 포함, '그렇죠?')
const _politeTail = r'[.!?~ㅋㅎㅠㅜ^♡♥]*';

/// 부정어가 붙으면 빼는 표시
const _flippedByNegation = {
  MessageTag.positive,
  MessageTag.compliment,
  MessageTag.affection,
  MessageTag.interest,
  MessageTag.empathy,
};

final _wordPatterns = {
  for (final entry in wordTable.entries)
    entry.key: RegExp(entry.value.join('|')),
};
final _negation = RegExp(negations.join('|'));
final _questionEnding = RegExp('(${questionEndings.join('|')})$_tail\$');
final _askBack = RegExp(askBackWords.join('|'));
final _personal = RegExp(personalWords.join('|'));
final _inviteEnding = RegExp('(${inviteEndings.join('|')})$_tail\\??$_tail\$');
final _together = RegExp(togetherWords.join('|'));
final _aegyo = RegExp(aegyoPatterns.join('|'));
final _honorificEnding =
    RegExp('(${honorificEndings.join('|')})$_politeTail\$');
final _honorificWord = RegExp(honorificWords.join('|'));
// 수락 말 다음엔 끝 · 문장부호 · 웃음 · 다른 수락 말만 ('그래서~'는 수락 아님)
final _agreeWords = agreeStarts.join('|');
final _agreeStart =
    RegExp('^($_agreeWords)요?($_tail\$|[!~,.ㅋㅎ]|$_agreeWords)');
final _shortReply = RegExp('^(${shortReplies.join('|')})$_tail\$');
