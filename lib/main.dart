import 'package:material_ui/material_ui.dart';

import 'data/app_store.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(OneWayLoveApp(store: AppStore()));
}

class OneWayLoveApp extends StatelessWidget {
  const OneWayLoveApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    // TODO: 디자인팀 시안 적용
    return AppScope(
      store: store,
      child: MaterialApp(
        title: '짝사랑 성공 프로젝트',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
