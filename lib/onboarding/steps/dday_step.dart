// 피그마 2번 화면의 가운데 내용 (D-Day)
// 태그 목록은 shared/models.dart의 reasonTags
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../../shared/widgets/tag_chip.dart';
import '../widgets/date_field.dart';

class DdayStep extends StatelessWidget {
  const DdayStep({
    super.key,
    required this.dDay,
    required this.reason,
    required this.onDDayChanged,
    required this.onReasonChanged,
  });

  /// 고른 날짜, 아직 안 골랐으면 null
  final DateTime? dDay;

  /// 고른 사유 태그
  final String reason;
  final ValueChanged<DateTime> onDDayChanged;
  final ValueChanged<String> onReasonChanged;

  /// 달력 열기, 고를 수 있는 날은 내일 ~ 1년 뒤
  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: dDay ?? today.add(const Duration(days: 20)),
      firstDate: today.add(const Duration(days: 1)),
      lastDate: DateTime(today.year + 1, today.month, today.day),
      helpText: 'D-Day 선택',
    );
    if (picked != null) onDDayChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('언제까지 함께할 수 있나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('종강이나 입대처럼 만남이 달라지는 날짜를 골라요.', style: text.bodySmall),
        const SizedBox(height: 24),
        DateField(date: dDay, onTap: () => _pickDate(context)),
        const SizedBox(height: 24),
        Text('어떤 날인가요?', style: text.titleSmall),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            for (final tag in reasonTags)
              Expanded(
                child: TagChip(
                  label: tag,
                  selected: tag == reason,
                  onTap: () => onReasonChanged(tag),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
