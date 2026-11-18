// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 여러 개 중 하나를 고르는 카드, 왼쪽에 ○ / ● 표시, 선택되면 분홍 바탕
/// 온보딩의 친밀도·목표 고르기(피그마 3, 6번), 우리 사이 업데이트(11번)에 사용
///
///     OptionCard(
///       title: '인사·스몰토크 가능',
///       description: '마주치면 인사하고 짧게 이야기할 수 있어요.',
///       selected: true,
///     )
///
/// 설명 줄이 필요 없으면 description 생략 (피그마 11번 형태)
class OptionCard extends StatelessWidget {
  const OptionCard({
    super.key,
    required this.title,
    this.description,
    required this.selected,
    this.onTap,
  });

  final String title;
  final String? description;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = this.description;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: description == null ? 12 : 14,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.rose : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? Icons.circle : Icons.circle_outlined,
                  size: 13,
                  color: selected ? AppColors.charcoal : AppColors.warmGray,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: description == null && !selected
                        ? text.bodyMedium
                        : text.titleSmall,
                  ),
                ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(description, style: text.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}
