// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 굵은 제목 한 줄 + 작은 설명 한 줄 카드
/// 로드맵 주차 카드(피그마 8번), 주차 상세 미션(14~16번), 데이트 조건·가이드(10, 13번), 대화 분석(12번)에 사용
///
///     InfoCard(
///       title: '평균 답장 텀 · 25분',
///       description: '내 메시지 다음에 온 상대 답장 기준',
///     )
///
/// 바탕색은 color (기본 흰색), 제목 앞 아이콘은 icon
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.description,
    this.color = AppColors.warmWhite,
    this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final Color color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final icon = this.icon;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          // 분홍 카드는 테두리 없음
          border: Border.all(
            color: color == AppColors.rose ? AppColors.rose : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: AppColors.charcoal),
                  const SizedBox(width: 8),
                ],
                Expanded(child: Text(title, style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: 6),
            Text(description, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
