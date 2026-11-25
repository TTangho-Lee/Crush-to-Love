// D-Day 알림 글자 · 시각 테스트 (flutter test test/dday_notifier_test.dart)
// 실제 예약은 기기에서만 되니 글자와 시각 계산만 확인
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/app/dday_notifier.dart';

void main() {
  test('알림 글자 (받침에 따라 이에요 · 예요, 기타는 D-Day)', () {
    expect(reminderText('종강', 3), '종강까지 3일 남았어요. 오늘 미션 하나 해볼까요?');
    expect(reminderText('종강', 1), '내일이 종강이에요. 오늘 한마디 건네 볼까요?');
    expect(reminderText('군 입대', 1), '내일이 군 입대예요. 오늘 한마디 건네 볼까요?');
    expect(reminderText('기타', 1), '내일이 D-Day예요. 오늘 한마디 건네 볼까요?');
  });

  test('알림 시각은 D-Day 며칠 전 저녁 8시 (달이 바뀌어도)', () {
    expect(reminderTime(DateTime(2026, 12, 1), 3), DateTime(2026, 11, 28, 20));
    expect(reminderTime(DateTime(2026, 12, 20), 1), DateTime(2026, 12, 19, 20));
  });
}
