// 앱 틀
// 하단 탭 4개 (홈 / 로드맵 / 대화 / 데이트)
// 탭마다 화면 이동 기록을 따로 가짐 (대화 탭에서 결과 화면으로 가도 하단 탭 유지)
// 다른 화면에서 탭 바꾸기: MainShell.tabIndex.value = 1
// 탭을 바꾸면 탭들이 옆으로 나란히 있는 것처럼 밀려 넘어감 (먼 탭은 사이 탭을 지나 더 빠르게, _TabSlider)
// 지금 탭을 다시 누르면 그 탭 첫 화면으로 돌아가 맨 위로 (입력 · 고른 것은 그대로)
// D-Day가 지났는데 결과를 안 고른 지금 상대가 있으면 피그마 17번을 한 번 띄움 (OutcomeAsker, 예시 모드 빼고)
import 'package:material_ui/material_ui.dart';

import '../analysis/chat/conversation_input_screen.dart';
import '../analysis/date/date_prep_screen.dart';
import '../mission/home/home_screen.dart';
import '../mission/roadmap/roadmap_screen.dart';
import '../outcome/outcome_screen.dart';
import '../shared/app_colors.dart';
import '../shared/widgets/bottom_tab_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, this.example = false});

  /// true면 'D-20 예시 보기'로 들어온 예시 모드, 맨 위에 '나가기' 띠 표시
  final bool example;

  /// 지금 탭 (0 홈, 1 로드맵, 2 대화, 3 데이트)
  static final tabIndex = ValueNotifier<int>(0);

  /// 지금 탭을 다시 누름 (탭 번호, 누른 횟수), 탭 첫 화면이 맨 위로 올라감 (_TabRoot)
  static final reselected = ValueNotifier<(int, int)>((0, 0));

  static const List<Widget> _tabs = [
    HomeScreen(),
    RoadmapScreen(),
    ConversationInputScreen(),
    DatePrepScreen(),
  ];

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  /// 탭마다 화면 이동 기록
  final _navigators = [
    for (var i = 0; i < MainShell._tabs.length; i++) GlobalKey<NavigatorState>(),
  ];

  /// 다른 탭이면 그 탭으로, 지금 탭이면 첫 화면으로 돌아가 맨 위로 (입력 · 고른 것은 그대로)
  void _onTap(int i) {
    if (i != MainShell.tabIndex.value) {
      MainShell.tabIndex.value = i;
      return;
    }
    _navigators[i].currentState?.popUntil((route) => route.isFirst);
    final (_, count) = MainShell.reselected.value;
    MainShell.reselected.value = (i, count + 1);
  }

  @override
  Widget build(BuildContext context) {
    final shell = ValueListenableBuilder<int>(
      valueListenable: MainShell.tabIndex,
      builder: (context, index, _) {
        final tabs = _TabSlider(
          index: index,
          children: [
            for (var i = 0; i < MainShell._tabs.length; i++)
              Navigator(
                key: _navigators[i],
                onGenerateRoute: (_) => MaterialPageRoute(
                  builder: (_) => _TabRoot(index: i, child: MainShell._tabs[i]),
                ),
              ),
          ],
        );

        return Scaffold(
          body: widget.example
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
            onTap: _onTap,
          ),
        );
      },
    );
    return widget.example ? shell : OutcomeAsker(child: shell);
  }
}

/// 탭 화면들 (모두 살려 둔 채 지금 탭만 보임), 탭이 바뀌면 새 탭이 밀려 들어오고 앞 탭이 밀려 나감
class _TabSlider extends StatefulWidget {
  const _TabSlider({required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<_TabSlider> createState() => _TabSliderState();
}

class _TabSliderState extends State<_TabSlider>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: _durationFor(1),
    value: 1,
  );

  /// 넘어가는 시간: 바로 옆 탭 280ms, 한 칸 멀어질 때마다 60ms씩
  /// 먼 탭은 사이 탭들을 지나가며 더 긴 거리를 가서, 시간은 조금만 늘어도 훨씬 빠르게 보임
  static Duration _durationFor(int distance) =>
      Duration(milliseconds: 220 + 60 * distance);

  /// 바뀌기 전 탭
  late int _from = widget.index;

  @override
  void didUpdateWidget(_TabSlider old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
      _anim.duration = _durationFor((widget.index - _from).abs());
      _anim.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_anim.value);
          // 지금 보이는 위치 (탭 번호 단위), 앞 탭 → 새 탭으로 움직임
          final pos = _anim.isAnimating
              ? _from + (widget.index - _from) * t
              : widget.index.toDouble();
          return Stack(
            children: [
              for (var i = 0; i < widget.children.length; i++)
                // 화면에 걸친 탭만 보임 (사이 탭은 지나가며 잠깐 보임)
                _page(
                  widget.children[i],
                  (i - pos).abs() < 1 ? Offset(i - pos, 0) : null,
                ),
            ],
          );
        },
      ),
    );
  }

  /// offset이 null이면 숨김 (상태는 그대로)
  Widget _page(Widget child, Offset? offset) {
    final visible = offset != null;
    return Positioned.fill(
      child: Offstage(
        offstage: !visible,
        child: TickerMode(
          enabled: visible,
          child: FractionalTranslation(
            translation: offset ?? Offset.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 탭 첫 화면: 지금 탭을 다시 누르면 맨 위로 부드럽게 올라감
/// 첫 화면의 ListView가 이 스크롤을 물려받음 (그 위에 열린 화면은 안 물려받음)
class _TabRoot extends StatefulWidget {
  const _TabRoot({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_TabRoot> createState() => _TabRootState();
}

class _TabRootState extends State<_TabRoot> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    MainShell.reselected.addListener(_toTop);
  }

  void _toTop() {
    if (MainShell.reselected.value.$1 != widget.index || !_scroll.hasClients) {
      return;
    }
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    MainShell.reselected.removeListener(_toTop);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryScrollController(
      controller: _scroll,
      // 웹 · PC에서도 물려받게
      automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
      child: widget.child,
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
