// 온보딩 흐름 전용 위젯
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/models.dart';

/// D-Day 날짜 칸 (피그마 2번), 누르면 달력
/// date가 없으면 'YYYY. MM. DD.' + '날짜를 선택해 주세요', 있으면 날짜 + 'D-20'
///
///     DateField(date: dDay, onTap: () {})
class DateField extends StatelessWidget {
  const DateField({super.key, this.date, this.onTap});

  final DateTime? date;
  final VoidCallback? onTap;

  /// 오늘부터 남은 날 수 (시간 무시, 날짜만 비교)
  static int _daysFromToday(DateTime d) {
    final now = DateTime.now();
    return DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(now.year, now.month, now.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = date;
    final label = d == null
        ? 'YYYY. MM. DD.'
        : '${d.year}. ${d.month.toString().padLeft(2, '0')}. '
            '${d.day.toString().padLeft(2, '0')}.';
    final subLabel = d == null ? '날짜를 선택해 주세요' : dDayLabel(_daysFromToday(d));

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
            Text(subLabel, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}
