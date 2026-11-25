import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    show databaseFactoryFfiWeb;

import 'analysis/chat/chat_store.dart';
import 'analysis/chat/share_receiver.dart';
import 'analysis/date/date_store.dart';
import 'app/app_theme.dart';
import 'app/dday_notifier.dart';
import 'app/main_shell.dart';
import 'mission/data/mission_store.dart';
import 'onboarding/data/crush_store.dart';
import 'onboarding/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹(크롬)에서는 브라우저용 SQLite 사용, DB 열기 전에 한 번만
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;

  // 저장해 둔 상대 목록 · 내 용기 (지금 상대가 있으면 홈부터)
  // DB를 못 열어도 앱은 켜지게 (그땐 시작 화면부터, 원인은 Run 창에 출력)
  final crushes = CrushStore();
  try {
    await crushes.load();
  } catch (e) {
    debugPrint('상대 목록 불러오기 실패: $e');
  }

  runApp(DueDateApp(crushes: crushes));
}

class DueDateApp extends StatefulWidget {
  const DueDateApp({super.key, this.crushes});

  /// 불러 둔 상대 목록, 지금 상대가 있으면 홈(피그마 7번) · 없으면 시작 화면(피그마 1번)부터
  /// 비우면 빈 목록 (테스트)
  final CrushStore? crushes;

  @override
  State<DueDateApp> createState() => _DueDateAppState();
}

class _DueDateAppState extends State<DueDateApp> {
  // 흐름별 데이터. 화면에서는 CrushScope / MissionScope / ChatScope / DateScope.of(context)로 꺼내 씀
  late final CrushStore _crushStore = widget.crushes ?? CrushStore();
  final _missionStore = MissionStore();
  final _chatStore = ChatStore();
  final _dateStore = DateStore();

  /// 마지막으로 미션 흐름 · 알림에 넘긴 지금 상대 (같은 값이면 다시 안 넘김)
  String? _syncedKey;

  @override
  void initState() {
    super.initState();
    _crushStore.addListener(_syncCurrent);
    _syncCurrent();
    // 안드로이드 공유로 받은 카톡 대화 → 대화 탭(피그마 9번)에서 바로 분석
    ShareReceiver.listen((text) {
      _chatStore.receiveSharedText(text);
      MainShell.tabIndex.value = 2;
    });
  }

  /// 지금 상대(+ 내 용기)가 바뀌면 미션 흐름 · D-Day 알림에 넘김
  /// 미션 흐름: 홈 D-Day · 목표, 로드맵이 이 값으로 (팀원 MissionStore.saveOnboarding)
  /// TODO(합치기): 팀원 로드맵이 상대별로 저장 · 불러오기 되면 상대를 바꿀 때 그 상대의 로드맵을 불러오게
  ///   (지금 saveOnboarding은 받을 때마다 로드맵을 새로 짬)
  void _syncCurrent() {
    final crush = _crushStore.current;
    final profile = _crushStore.profile;
    if (crush == null || profile == null) return;
    final key = [
      crush.id,
      crush.dDay.toIso8601String(),
      crush.reason,
      crush.intimacy.name,
      crush.meetingsPerWeek,
      crush.goal.name,
      _crushStore.courage,
    ].join('|');
    if (key == _syncedKey) return;
    _syncedKey = key;
    _missionStore.saveOnboarding(profile);
    // 첫 화면이 뜬 뒤에 (알림 권한 창이 화면 위에 뜨게)
    WidgetsBinding.instance
        .addPostFrameCallback((_) => DdayNotifier.schedule(profile));
  }

  @override
  void dispose() {
    _crushStore.removeListener(_syncCurrent);
    _crushStore.dispose();
    _missionStore.dispose();
    _chatStore.dispose();
    _dateStore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CrushScope(
      store: _crushStore,
      child: MissionScope(
        store: _missionStore,
        child: ChatScope(
          store: _chatStore,
          child: DateScope(
            store: _dateStore,
            child: MaterialApp(
              title: 'DueDate',
              theme: AppTheme.light,
              // 오른쪽 위 'DEBUG' 띠 숨김
              debugShowCheckedModeBanner: false,
              // 달력 같은 기본 위젯 글자를 한국어로
              locale: const Locale('ko'),
              supportedLocales: const [Locale('ko')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: _crushStore.current != null
                  ? const MainShell()
                  : const StartScreen(),
            ),
          ),
        ),
      ),
    );
  }
}
