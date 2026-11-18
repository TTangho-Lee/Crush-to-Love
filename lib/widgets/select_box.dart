// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 눌러서 고르는 칸 (스피너), 지금 값 + ▾
/// 우리 사이 업데이트(피그마 11번)의 '이번 목표'에 사용
/// 누르면 고를 목록이 뜰 자리 (지금은 비어 있음)
///
///     SelectBox(value: '친해지기')
class SelectBox extends StatelessWidget {
  const SelectBox({super.key, required this.value, this.onTap});

  /// 지금 고른 값
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: AppColors.charcoal,
            ),
          ],
        ),
      ),
    );
  }
}
