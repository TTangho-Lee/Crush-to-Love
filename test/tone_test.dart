// 말투 맞추기 테스트 (flutter test test/tone_test.dart)
// 내 메시지 → 웃음 비율 · 글자 · 길이, 멘트에 입히기 (빼기 · 하나만 남기기 · 글자 바꾸기), 설정 덮어쓰기
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/rules/tone.dart';
import 'package:one_way_love/shared/models.dart';

void main() {
  const lines = [
    '요즘 뭐 하고 지내? ㅎㅎ',
    '너 진짜 웃긴 거 알아? ㅋㅋ 너랑 얘기하면 기분 좋아져',
    '이번 주에 시간 되면 같이 밥 먹을래?',
  ];

  test('웃음 빼기: 뺀 자리는 띄어쓰기 하나, 문장부호 앞 띄어쓰기 없음', () {
    expect(stripLaugh('요즘 뭐 하고 지내? ㅎㅎ'), '요즘 뭐 하고 지내?');
    expect(stripLaugh('알아? ㅋㅋ 너랑'), '알아? 너랑');
    expect(stripLaugh('뭐야 ㅋㅋ?'), '뭐야?');
    expect(stripLaugh('웃겨ㅋㅋㅋ반칙'), '웃겨 반칙');
    expect(stripLaugh('ㅠㅠ 힘내'), 'ㅠㅠ 힘내');
  });

  test('내 메시지 말투: 웃음 비율 · 많이 쓰는 글자 · 길이', () {
    final often = toneOf([
      for (var i = 0; i < 10; i++) i.isEven ? '진짜 ㅋㅋㅋ' : '그치',
    ]);
    expect(often.laughRate, 0.5);
    expect(often.laugh, 'ㅋ');
    expect(often.laughLength, 3);

    final rare = toneOf([
      '응 ㅎㅎ',
      for (var i = 0; i < 11; i++) '알겠어',
    ]);
    expect(rare.laughRate, lessThan(0.17));
    expect(rare.laugh, 'ㅎ');

    // 'ㅎㅇ'(인사)는 웃음 아님
    final hello = toneOf([for (var i = 0; i < 10; i++) 'ㅎㅇ 뭐해']);
    expect(hello.laughRate, 0);

    // 메시지가 적으면 기본값
    expect(toneOf(['ㅋㅋ']).laughRate, defaultLaughRate);
  });

  test('멘트에 입히기: 비율만큼만 웃음을 남기고 글자 · 길이를 내 말투로', () {
    // 거의 안 웃음 → 다 뺌
    final none = applyTone(lines, const Tone(laughRate: 0.1));
    expect(none.any((l) => l.contains(RegExp('[ㅋㅎ]'))), isFalse);
    expect(none.length, lines.length);

    // 3줄 중 1줄만
    final some = applyTone(lines, const Tone(laughRate: 0.3), seed: 1);
    expect(some.where((l) => l.contains(RegExp('[ㅋㅎ]{2}'))).length, 1);

    // 자주 · ㅋ 3글자
    final often =
        applyTone(lines, const Tone(laughRate: 0.9, laugh: 'ㅋ', laughLength: 3));
    expect(often[0], '요즘 뭐 하고 지내? ㅋㅋㅋ');
    expect(often[1], contains('알아? ㅋㅋㅋ 너랑'));
    expect(often[2], lines[2]);

    // 그대로
    expect(applyTone(lines, Tone.keep), lines);
  });

  test('설정 웃음 표현이 대화 말투를 덮어씀', () {
    const rare = Tone(laughRate: 0.05, laugh: 'ㅋ', laughLength: 3);
    expect(rare.withStyle(LaughStyle.auto).laughRate, 0.05);
    expect(rare.withStyle(LaughStyle.none).laughRate, 0);
    final hh = rare.withStyle(LaughStyle.hh);
    expect(hh.laugh, 'ㅎ');
    expect(hh.laughRate, chosenLaughRate);
    expect(applyTone(lines, hh).where((l) => l.contains('ㅎㅎㅎ')).length, 1);
  });

  test('설정 말 높이', () {
    expect(SpeechLevel.auto.formalOr(true), isTrue);
    expect(SpeechLevel.casual.formalOr(true), isFalse);
    expect(SpeechLevel.formal.formalOr(false), isTrue);
  });
}
