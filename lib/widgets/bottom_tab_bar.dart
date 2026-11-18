// 공통 위젯
import 'package:material_ui/material_ui.dart';

import 'tag_chip.dart';

/// 화면 맨 아래 '홈 / 로드맵 / 대화 / 데이트' 탭
/// MainShell에 이미 들어가 있어서 화면에서 따로 쓸 일 없음
class BottomTabBar extends StatelessWidget {
  const BottomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _labels = ['홈', '로드맵', '대화', '데이트'];

  /// 선택된 탭 (0 홈, 1 로드맵, 2 대화, 3 데이트)
  final int currentIndex;

  /// 탭을 눌렀을 때 (몇 번째 탭인지 받음)
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Row(
          spacing: 8,
          children: [
            for (var i = 0; i < _labels.length; i++)
              Expanded(
                child: TagChip(
                  label: _labels[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
