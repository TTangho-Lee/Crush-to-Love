// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 눌러서 고르는 작은 태그, 선택되면 진한 분홍색
/// 온보딩의 사유 태그(피그마 2번), 하단 탭에 사용
/// 기본은 글자 길이만큼, 한 줄을 나눠 꽉 채우려면 Expanded로 감싸기
/// 칸이 좁으면 줄을 바꾸지 않고 글자를 조금 작게 ('군 입대'가 '군 입 / 대'로 안 갈리게)
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
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.ivory,
          borderRadius: BorderRadius.circular(12),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13),
          ),
        ),
      ),
    );
  }
}
