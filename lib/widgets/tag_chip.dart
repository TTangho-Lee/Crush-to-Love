// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 눌러서 고르는 작은 태그, 선택되면 진한 분홍색
/// 온보딩의 사유 태그(피그마 2번), 하단 탭에 사용
/// 기본은 글자 길이만큼, 한 줄을 나눠 꽉 채우려면 Expanded로 감싸기
///
///     TagChip(label: '종강', selected: true)
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.ivory,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}
