// 실패 돌아보기 규칙 (피그마 19 → 20): 내가 쓴 글 → 부족했던 점
//   AI 없이 단어 사전으로만, 쓴 글은 저장 · 전송하지 않음
//   글에서 찾은 단어가 많은 순 (같으면 FailReason 순서)
//   '용기 냈는데'처럼 이미 한 일을 말한 부분은 먼저 지우고 찾음 (_done)
//   글에서 하나도 못 찾으면 데이터로 (reasonsFromData)
//     용기 배터리가 저전력 단계 → 용기 내기
//     마지막 대화 분석이 이 상대 대화면: 내 답장이 1시간 넘게 · 상대보다 1.5배 넘게 늦음 → 문자 답장
//                                     내가 먼저 말을 건 대화가 30% 미만 → 적극적인 태도
import '../analysis/chat/rules/features.dart';
import '../analysis/chat/rules/normalizer.dart';
import '../shared/models.dart';

/// 부족했던 점 (피그마 20번 카드 제목 · 설명)
enum FailReason {
  courage('용기 내기', '용기가 좀 더 필요했던 것 같아요'),
  reply('문자 답장', '문자를 늦게 읽거나 늦게 답한 적이 많았어요'),
  active('적극적인 태도', '매력을 다 보여 주지 못한 것 같아요'),
  fit('성격', '관심사나 성격이 잘 맞지 않았던 것 같아요');

  const FailReason(this.label, this.description);

  final String label;
  final String description;
}

/// 부족했던 점마다 찾을 단어 (띄어쓰기를 뺀 글자에서 찾음)
const Map<FailReason, List<String>> _words = {
  FailReason.courage: [
    '용기', '소심', '겁', '무서', '두려', '망설', '주저', '긴장', '떨려', '떨렸', '부끄', '쑥스', '자신감',
    '자신이없', '눈치보', '눈치를보', '미루', '미뤘', '타이밍을놓', '타이밍놓', '기회를놓', '기회놓',
    '다가가지못', '못다가', '말을못', '말도못', '말못', '고백을못', '고백못', '표현을못', '표현못', '먼저못',
    '먼저연락을못', '쫄',
  ],
  FailReason.reply: [
    '답장을늦', '답장이늦', '답장을못', '답장을안', '답장을잘안', '늦게답', '답을늦', '답이늦', '답을안',
    '답을잘안', '읽씹', '안읽', '늦게읽', '늦게봤', '늦게확인', '확인을늦', '단답', '칼답을못', '칼답못',
    '연락을잘안', '연락을자주안', '연락이뜸', '연락을안', '연락을못', '톡을늦', '카톡을늦', '문자를늦',
    '메시지를늦', '메세지를늦',
  ],
  FailReason.active: [
    '적극', '소극', '매력', '어필', '관심표현', '관심을표현', '표현을', '표현이', '리액션', '반응을', '질문을',
    '먼저말', '먼저다가', '먼저연락', '선톡', '수동', '노력', '티를', '티안', '무관심', '재미없', '지루',
    '대화거리', '말주변', '말재주', '꾸미', '외모', '자기관리', '센스', '배려', '챙겨', '챙기',
  ],
  FailReason.fit: [
    '성격', '취향', '관심사', '안맞', '맞지않', '맞지가않', '달랐', '서로달', '너무달', '코드가', '가치관',
    '스타일', '이상형', '타입이', '성향', '공통점', '공감대', '대화가안통', '말이안통', '잘안통', '케미',
  ],
};

/// 이미 한 일 (찾기 전에 지움, '용기 냈는데 …'가 용기 내기로 잡히지 않게)
const _done = [
  '용기냈', '용기를냈', '용기는냈', '용기내서', '용기를내서', '용기내고', '용기를내고', '고백했', '고백은했',
  '고백을했', '칼답했', '답장은잘', '답장을잘했', '답은잘', '적극적이었', '적극적으로했', '노력했', '노력은했',
  '표현했', '표현은했', '표현을했',
];

/// 내가 쓴 글에서 찾은 부족했던 점 (많이 나온 순), 못 찾으면 빈 목록
List<FailReason> reasonsFromText(String text) {
  var compact = normalize(text).compact;
  for (final phrase in _done) {
    compact = compact.replaceAll(phrase, ' ');
  }
  final hits = {
    for (final reason in FailReason.values)
      reason: _words[reason]!.where(compact.contains).length,
  };
  final found = [
    for (final reason in FailReason.values)
      if (hits[reason]! > 0) reason,
  ];
  // 같은 수면 FailReason 순서 그대로
  found.sort((a, b) {
    final byHits = hits[b]!.compareTo(hits[a]!);
    return byHits != 0 ? byHits : a.index.compareTo(b.index);
  });
  return found;
}

/// 글에서 못 찾았을 때 데이터로 본 부족했던 점
/// courage: 용기 배터리 0 ~ 100, chat: 마지막 대화 분석 (이 상대 대화일 때만 넘김)
List<FailReason> reasonsFromData({
  required int courage,
  ConversationFeatures? chat,
}) {
  final myReply = chat?.me.replyMedianMinutes;
  final theirReply = chat?.them.replyMedianMinutes;
  final slowReply = myReply != null &&
      myReply >= 60 &&
      (theirReply == null || myReply >= theirReply * 1.5);
  final rarelyStarted = chat != null &&
      chat.sessionCount >= 3 &&
      1 - chat.theirStartRate < 0.3;
  return [
    if (CourageLevel.of(courage) == CourageLevel.low) FailReason.courage,
    if (slowReply) FailReason.reply,
    if (rarelyStarted) FailReason.active,
  ];
}

/// 피그마 20번에 보여줄 부족했던 점: 글에서 먼저, 못 찾으면 데이터로 (둘 다 없으면 빈 목록)
List<FailReason> reflectOn(
  String text, {
  required int courage,
  ConversationFeatures? chat,
}) {
  final fromText = reasonsFromText(text);
  return fromText.isNotEmpty
      ? fromText
      : reasonsFromData(courage: courage, chat: chat);
}
