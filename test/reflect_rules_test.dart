// 실패 돌아보기 규칙 테스트 (flutter test test/reflect_rules_test.dart)
// 내가 쓴 글 → 부족했던 점, 이미 한 일은 빼고, 못 찾으면 용기 배터리로
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/outcome/reflect_rules.dart';

void main() {
  test('글에서 부족했던 점 찾기 (많이 나온 순)', () {
    expect(
      reasonsFromText('먼저 말 거는 게 무서웠고 망설이다가 타이밍을 놓쳤어').first,
      FailReason.courage,
    );
    expect(reasonsFromText('답장을 늦게 하고 단답만 했어'), [FailReason.reply]);
    expect(
      reasonsFromText('리액션도 별로 없고 적극적이지 못했어'),
      [FailReason.active],
    );
  });

  test("'용기 내서 고백했는데'처럼 이미 한 일은 부족했던 점이 아님", () {
    expect(
      reasonsFromText('용기 내서 고백했는데 성격이 안 맞는대'),
      [FailReason.fit],
    );
  });

  test('글에서 못 찾으면 데이터로, 데이터도 없으면 빈 목록', () {
    expect(reasonsFromText('그냥 잘 모르겠어'), isEmpty);
    expect(reflectOn('그냥 잘 모르겠어', courage: 20), [FailReason.courage]);
    expect(reflectOn('그냥 잘 모르겠어', courage: 70), isEmpty);
    // 글에서 찾으면 데이터는 안 봄
    expect(reflectOn('성격이 달랐어', courage: 20), [FailReason.fit]);
  });
}
