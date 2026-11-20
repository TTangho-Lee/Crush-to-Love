import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'analysis/chat/chat_store.dart';
import 'analysis/chat/share_receiver.dart';
import 'analysis/date/date_store.dart';
import 'app/app_theme.dart';
import 'app/main_shell.dart';
import 'mission/data/mission_store.dart';
import 'onboarding/data/profile_db.dart';
import 'onboarding/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹(크롬)에서는 브라우저용 SQLite 사용, DB 열기 전에 한 번만
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;

  // 온보딩을 끝낸 적 있으면 홈부터
  // DB를 못 열어도 앱은 켜지게 (그땐 시작 화면부터, 원인은 Run 창에 출력)
  var onboarded = false;
  try {
    onboarded = await ProfileDb.load() != null;
  } catch (e) {
    debugPrint('ProfileDb.load 실패: $e');
  }

  runApp(DueDateApp(onboarded: onboarded));
}

class DueDateApp extends StatefulWidget {
  const DueDateApp({super.key, this.onboarded = false});

  /// true면 홈(피그마 7번), false면 시작 화면(피그마 1번)부터
  final bool onboarded;

  @override
  State<DueDateApp> createState() => _DueDateAppState();
}

class _DueDateAppState extends State<DueDateApp> {
  // 흐름별 데이터. 화면에서는 MissionScope / ChatScope / DateScope.of(context)로 꺼내 씀
  final _missionStore = MissionStore();
  final _chatStore = ChatStore();
  final _dateStore = DateStore();

  @override
  void initState() {
    super.initState();
    // 안드로이드 공유로 받은 카톡 대화 → 대화 탭(피그마 9번)에서 바로 분석
    ShareReceiver.listen((text) {
      _chatStore.receiveSharedText(text);
      MainShell.tabIndex.value = 2;
    });
  }

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
            // 달력 같은 기본 위젯 글자를 한국어로
            locale: const Locale('ko'),
            supportedLocales: const [Locale('ko')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: widget.onboarded ? const MainShell() : const StartScreen(),
          ),
        ),
      ),
    );
  }
}
