// 규칙 ⑦ 말투 맞추기: 예시 멘트 · 데이트 한마디 팁 · 만난 뒤 톡의 웃음(ㅋㅋ · ㅎㅎ)을 내 말투에 맞게
//   대화에 맞춤(기본): 대화 속 내 메시지에서 웃음을 얼마나 · 어떤 글자 · 몇 글자로 쓰는지 봄 (toneOf)
//     한 번에 보이는 멘트 중 웃음이 붙는 줄 수 ≈ 내 메시지 중 웃음 비율
//       3줄이면 17% 미만 0줄 · 50% 미만 1줄 · 83% 미만 2줄 · 그 이상 3줄
//     ㅋ · ㅎ 중 내가 60% 넘게 쓰는 글자로, 길이는 내가 자주 쓰는 길이(2 ~ 4글자)로 바꿈
//     내 메시지가 minToneMessages개보다 적으면 기본값 (defaultLaughRate, 글자 그대로)
//   설정에서 직접(LaughStyle): ㅋㅋ · ㅎㅎ (3줄 중 1줄 이상) · 안 씀
//   웃음을 뺀 자리는 띄어쓰기 하나로 ('알아? ㅋㅋ 너랑' → '알아? 너랑')
//   말 높이(반말 · 존댓말)는 멘트를 고를 때 따로 (SpeechLevel, lines.dart의 formal)
import 'dart:math';

import '../../../shared/models.dart';

/// 내 메시지가 이보다 적으면 말투를 보지 않고 기본값
const minToneMessages = 10;

/// 기본 웃음 비율 (3줄 중 1줄)
const defaultLaughRate = 0.2;

/// 설정에서 ㅋㅋ · ㅎㅎ를 고르면 최소 이 비율 (3줄 중 1줄 이상)
const chosenLaughRate = 0.34;

/// 멘트 속 웃음 (ㅋㅋ · ㅎㅎ · ㅋㅋㅋ …)
final _laughRun = RegExp('[ㅋㅎ]{2,}');

/// 내 메시지 속 웃음: 두 글자 이상, 또는 앞뒤에 다른 자모가 없는 한 글자 ('ㅎㅇ' 같은 줄임말은 빼고)
final _myLaugh = RegExp('[ㅋㅎ]{2,}|(?<![ㄱ-ㅣ])[ㅋㅎ](?![ㄱ-ㅣ])');

/// 웃음을 뺀 뒤 문장부호 앞에 남은 띄어쓰기
final _spaceBeforeMark = RegExp(r' +([?!.,~])');

/// 멘트 말투 (웃음 표현)
class Tone {
  const Tone({this.laughRate = defaultLaughRate, this.laugh, this.laughLength});

  /// 멘트를 그대로 둠 (테스트 · 말투를 따로 정하지 않은 가이드)
  static const keep = Tone(laughRate: 1);

  /// 웃음이 붙는 멘트 비율 0 ~ 1
  final double laughRate;

  /// 'ㅋ' · 'ㅎ', 비우면 멘트 글자 그대로
  final String? laugh;

  /// 웃음 글자 수 2 ~ 4, 비우면 멘트 길이 그대로
  final int? laughLength;

  /// 설정 '웃음 표현'을 반영한 말투 (대화에 맞춤이면 그대로)
  Tone withStyle(LaughStyle style) => switch (style) {
        LaughStyle.auto => this,
        LaughStyle.none => const Tone(laughRate: 0),
        LaughStyle.kk => Tone(
            laughRate: max(laughRate, chosenLaughRate),
            laugh: 'ㅋ',
            laughLength: laughLength ?? 2,
          ),
        LaughStyle.hh => Tone(
            laughRate: max(laughRate, chosenLaughRate),
            laugh: 'ㅎ',
            laughLength: laughLength ?? 2,
          ),
      };
}

/// 대화 속 내 메시지 글자 → 내 말투 (사진 · 이모티콘 같은 자리표시는 빼고 넘김)
Tone toneOf(Iterable<String> myTexts) {
  var total = 0, laughing = 0, kCount = 0, hCount = 0;
  final lengths = <int>[];
  for (final text in myTexts) {
    total++;
    final runs = [for (final m in _myLaugh.allMatches(text)) m[0]!];
    if (runs.isEmpty) continue;
    laughing++;
    for (final run in runs) {
      final k = 'ㅋ'.allMatches(run).length;
      kCount += k;
      hCount += run.length - k;
      lengths.add(run.length);
    }
  }
  if (total < minToneMessages) return const Tone();

  final all = kCount + hCount;
  final laugh = all == 0
      ? null
      : kCount >= all * 0.6
          ? 'ㅋ'
          : hCount >= all * 0.6
              ? 'ㅎ'
              : null;
  lengths.sort();
  return Tone(
    laughRate: laughing / total,
    laugh: laugh,
    laughLength:
        lengths.isEmpty ? null : lengths[lengths.length ~/ 2].clamp(2, 4),
  );
}

/// 멘트 목록에 말투 입히기: 웃음을 남길 줄만 남기고(seed로 돌려 고름) 나머지는 웃음을 뺌
/// 웃음을 빼서 빈 줄이 되면 뺌
List<String> applyTone(List<String> lines, Tone tone, {int seed = 0}) => [
      for (final line in applyToneEach(lines, tone, seed: seed))
        if (line.isNotEmpty) line,
    ];

/// applyTone과 같되 줄 수를 그대로 (웃음을 빼서 빈 줄이 되면 빈 글자, 원래 멘트와 짝 맞추기용)
List<String> applyToneEach(List<String> lines, Tone tone, {int seed = 0}) {
  final laughing = [
    for (var i = 0; i < lines.length; i++)
      if (_laughRun.hasMatch(lines[i])) i,
  ];
  final keepCount =
      min((tone.laughRate * lines.length).round(), laughing.length);
  final keep = {
    for (var k = 0; k < keepCount; k++)
      laughing[(seed + k) % laughing.length],
  };
  return [
    for (var i = 0; i < lines.length; i++)
      keep.contains(i) ? _restyle(lines[i], tone) : stripLaugh(lines[i]),
  ];
}

/// 웃음 빼기 ('알아? ㅋㅋ 너랑' → '알아? 너랑', '뭐야 ㅋㅋ?' → '뭐야?')
String stripLaugh(String line) => line
    .replaceAll(_laughRun, ' ')
    .replaceAll(RegExp(' {2,}'), ' ')
    .replaceAllMapped(_spaceBeforeMark, (m) => m[1]!)
    .trim();

/// 웃음 글자 · 길이를 내 말투로
String _restyle(String line, Tone tone) {
  final laugh = tone.laugh;
  final length = tone.laughLength;
  if (laugh == null && length == null) return line;
  return line.replaceAllMapped(
    _laughRun,
    (m) => (laugh ?? m[0]![0]) * (length ?? m[0]!.length),
  );
}
