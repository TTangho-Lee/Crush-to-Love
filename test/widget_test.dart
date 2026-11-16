import 'package:flutter_test/flutter_test.dart';

import 'package:one_way_love/data/app_store.dart';
import 'package:one_way_love/main.dart';

void main() {
  testWidgets('첫 화면에 등록 안내가 뜬다', (WidgetTester tester) async {
    await tester.pumpWidget(OneWayLoveApp(store: AppStore()));

    expect(find.text('짝사랑 성공 프로젝트'), findsOneWidget);
    expect(find.text('아직 등록된 상대가 없어요'), findsOneWidget);
  });
}
