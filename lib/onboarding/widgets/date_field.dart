// 온보딩 흐름 전용 위젯
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';

/// D-Day 날짜 칸 (피그마 2번), 누르면 달력이 뜰 자리
/// date가 없으면 'YYYY. MM. DD.'
///
///     const DateField()
class DateField extends StatelessWidget {
  const DateField({super.key, this.date, this.onTap});

  final DateTime? date;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = date;
    final label = d == null
        ? 'YYYY. MM. DD.'
        : '${d.year}. ${d.month.toString().padLeft(2, '0')}. '
            '${d.day.toString().padLeft(2, '0')}.';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.roseSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: text.titleMedium),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: AppColors.charcoal,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('날짜를 선택해 주세요', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
