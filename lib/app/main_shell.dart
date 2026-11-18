// 앱 틀
// 하단 탭 4개 (홈 / 로드맵 / 대화 / 데이트)
// 탭마다 화면 이동 기록을 따로 가짐 (대화 탭에서 결과 화면으로 가도 하단 탭 유지)
// 다른 화면에서 탭 바꾸기: MainShell.tabIndex.value = 1
import 'package:material_ui/material_ui.dart';

import '../analysis/chat/conversation_input_screen.dart';
import '../analysis/date/date_prep_screen.dart';
import '../mission/home/home_screen.dart';
import '../mission/roadmap/roadmap_screen.dart';
import '../shared/widgets/bottom_tab_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  /// 지금 탭 (0 홈, 1 로드맵, 2 대화, 3 데이트)
  static final tabIndex = ValueNotifier<int>(0);

  static const List<Widget> _tabs = [
    HomeScreen(),
    RoadmapScreen(),
    ConversationInputScreen(),
    DatePrepScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, index, _) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: [
              for (final tab in _tabs)
                Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => tab),
                ),
            ],
          ),
          bottomNavigationBar: BottomTabBar(
            currentIndex: index,
            onTap: (i) => tabIndex.value = i,
          ),
        );
      },
    );
  }
}
