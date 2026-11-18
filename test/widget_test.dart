import 'package:flutter_test/flutter_test.dart';

import 'package:one_way_love/data/app_store.dart';
import 'package:one_way_love/main.dart';

void main() {
  testWidgets('시작 화면이 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(DueDateApp(store: AppStore()));

    expect(find.text('첫 미션 받기 →'), findsOneWidget);
  });
}
