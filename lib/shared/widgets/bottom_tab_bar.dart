// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 화면 맨 아래 '홈 / 로드맵 / 대화 / 데이트' 탭 (아이콘 + 이름)
/// 고른 탭은 아이콘 뒤에 분홍 알약 모양 + 채운 아이콘
/// MainShell에 이미 들어가 있어서 화면에서 따로 쓸 일 없음
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// (이름, 안 고른 아이콘, 고른 아이콘)
  static const _tabs = [
    ('홈', Icons.home_outlined, Icons.home),
    ('로드맵', Icons.map_outlined, Icons.map),
    ('대화', Icons.forum_outlined, Icons.forum),
    ('데이트', Icons.favorite_border, Icons.favorite),
  ];

  /// 선택된 탭 (0 홈, 1 로드맵, 2 대화, 3 데이트)
  final int currentIndex;

  /// 탭을 눌렀을 때 (몇 번째 탭인지 받음)
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.warmWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    label: _tabs[i].$1,
                    icon: i == currentIndex ? _tabs[i].$3 : _tabs[i].$2,
                    selected: i == currentIndex,
                    style: text.labelSmall,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 탭 하나 (누르는 범위는 칸 전체)
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final TextStyle? style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 4,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 28,
              decoration: BoxDecoration(
                color: selected ? AppColors.rose : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 20,
                color: selected ? AppColors.charcoal : AppColors.warmGray,
              ),
            ),
            Text(
              label,
              style: style?.copyWith(
                fontSize: 11,
                color: selected ? AppColors.charcoal : AppColors.warmGray,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
