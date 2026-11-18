import 'package:material_ui/material_ui.dart';

import 'analysis/chat/chat_store.dart';
import 'analysis/date/date_store.dart';
import 'app/app_theme.dart';
import 'mission/data/mission_store.dart';
import 'onboarding/start_screen.dart';

void main() {
  runApp(const DueDateApp());
}

class DueDateApp extends StatefulWidget {
  const DueDateApp({super.key});

  @override
  State<DueDateApp> createState() => _DueDateAppState();
}

class _DueDateAppState extends State<DueDateApp> {
  // 흐름별 데이터. 화면에서는 MissionScope / ChatScope / DateScope.of(context)로 꺼내 씀
  final _missionStore = MissionStore();
  final _chatStore = ChatStore();
  final _dateStore = DateStore();

  @override
  void dispose() {
    _missionStore.dispose();
    _chatStore.dispose();
    _dateStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MissionScope(
      store: _missionStore,
      child: ChatScope(
        store: _chatStore,
        child: DateScope(
          store: _dateStore,
          child: MaterialApp(
            title: 'DueDate',
            theme: AppTheme.light,
            home: const StartScreen(),
          ),
        ),
      ),
    );
  }
}
