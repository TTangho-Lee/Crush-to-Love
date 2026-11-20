// 규칙 ① 정리: 메시지 글자를 비교하기 쉬운 모양으로
//   소문자로, 공백 하나로, 같은 글자 3번 이상 → 2번 (ㅋㅋㅋㅋㅋ → ㅋㅋ, !!!! → !!)
//   compact: 띄어쓰기를 다 뺀 글자 ('뭐 해?' = '뭐해?'로 같이 찾기 위해)
// 사진 · 이모티콘 같은 카톡 자리표시 글자 구분도 여기서

/// 정리된 메시지 글자
class NormalizedText {
  const NormalizedText(this.text, this.compact);

  /// 공백 정리 · 소문자 · 반복 글자 줄인 글자
  final String text;

  /// text에서 띄어쓰기를 모두 뺀 글자 (단어 사전은 여기서 찾음)
  final String compact;
}

final _spaces = RegExp(r'\s+');
final _repeated = RegExp(r'(.)\1{2,}');

NormalizedText normalize(String raw) {
  var t = raw.trim().toLowerCase().replaceAll(_spaces, ' ');
  t = t.replaceAllMapped(_repeated, (m) => '${m[1]}${m[1]}');
  return NormalizedText(t, t.replaceAll(' ', ''));
}

// ---------- 카톡 자리표시 글자 ----------

/// 사진 · 동영상 · 파일 같은 첨부 (내용이 없는 메시지)
const _mediaPlaceholders = {'사진', '동영상', '파일', '음성메시지', '음성 메시지'};
final _photoCount = RegExp(r'^사진 \d+장$');

/// 삭제된 메시지
const _deletedPlaceholders = {'삭제된 메시지입니다.', '메시지가 삭제되었습니다.'};

bool isMediaPlaceholder(String text) {
  final t = text.trim();
  return _mediaPlaceholders.contains(t) || _photoCount.hasMatch(t);
}

bool isStickerPlaceholder(String text) => text.trim() == '이모티콘';

bool isDeletedPlaceholder(String text) =>
    _deletedPlaceholders.contains(text.trim());

/// 글자 내용이 없는 자리표시 메시지면 true (길이 · 표현 계산에서 뺌)
bool isPlaceholder(String text) =>
    isMediaPlaceholder(text) ||
    isStickerPlaceholder(text) ||
    isDeletedPlaceholder(text);

/// 글자 수 (이모지도 1글자로 셈)
int textLength(String text) => text.trim().runes.length;
