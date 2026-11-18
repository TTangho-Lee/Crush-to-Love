import 'package:material_ui/material_ui.dart';

import 'app/app_theme.dart';
import 'data/app_store.dart';
import 'screens/start/start_screen.dart';

void main() {
  runApp(DueDateApp(store: AppStore()));
}

class DueDateApp extends StatelessWidget {
  const DueDateApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: MaterialApp(
        title: 'DueDate',
        theme: AppTheme.light,
        home: const StartScreen(),
      ),
    );
  }
}
