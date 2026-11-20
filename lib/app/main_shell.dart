// 앱 틀
// 하단 탭 4개 (홈 / 로드맵 / 대화 / 데이트)
// 탭마다 화면 이동 기록을 따로 가짐 (대화 탭에서 결과 화면으로 가도 하단 탭 유지)
// 다른 화면에서 탭 바꾸기: MainShell.tabIndex.value = 1
import 'package:material_ui/material_ui.dart';

import '../analysis/chat/conversation_input_screen.dart';
import '../analysis/date/date_prep_screen.dart';
import '../mission/home/home_screen.dart';
import '../mission/roadmap/roadmap_screen.dart';
import '../shared/app_colors.dart';
import '../shared/widgets/bottom_tab_bar.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, this.example = false});

  /// true면 'D-20 예시 보기'로 들어온 예시 모드, 맨 위에 '나가기' 띠 표시
  final bool example;

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
        final tabs = IndexedStack(
          index: index,
          children: [
            for (final tab in _tabs)
              Navigator(
                onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => tab),
              ),
          ],
        );

        return Scaffold(
          body: example
              ? Column(
                  children: [
                    const _ExampleBar(),
                    // 띠가 상태 표시줄 여백을 이미 차지하므로 탭 화면에선 위쪽 여백 제거
                    Expanded(
                      child: MediaQuery.removePadding(
                        context: context,
                        removeTop: true,
                        child: tabs,
                      ),
                    ),
                  ],
                )
              : tabs,
          bottomNavigationBar: BottomTabBar(
            currentIndex: index,
            onTap: (i) => tabIndex.value = i,
          ),
        );
      },
    );
  }
}

/// 예시 모드 맨 위 띠, '나가기'를 누르면 시작 화면(피그마 1번)으로
class _ExampleBar extends StatelessWidget {
  const _ExampleBar();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text('D-20 예시 화면이에요', style: text.bodySmall),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('나가기', style: text.titleSmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
