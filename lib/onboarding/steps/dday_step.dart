// 피그마 2번 화면의 가운데 내용 (상대 별명 + D-Day)
// 별명: 앱에서 부를 이름 (머리글 '지민 ▾', 상대 목록), 카톡 이름과 달라도 됨
// 태그 목록은 shared/models.dart의 reasonTags, '기타'를 고르면 어떤 날인지 직접 입력
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/tag_chip.dart';
import '../widgets/date_field.dart';

class DdayStep extends StatelessWidget {
  const DdayStep({
    super.key,
    required this.nicknameController,
    required this.customReasonController,
    required this.dDay,
    required this.reasonTag,
    required this.onDDayChanged,
    required this.onReasonChanged,
  });

  /// 상대 별명 입력칸
  final TextEditingController nicknameController;

  /// '기타'일 때 어떤 날인지 입력칸
  final TextEditingController customReasonController;

  /// 고른 날짜, 아직 안 골랐으면 null
  final DateTime? dDay;

  /// 고른 사유 태그 (reasonTags 중 하나)
  final String reasonTag;
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
        Text('누구와, 언제까지 함께할 수 있나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('종강이나 입대처럼 만남이 달라지는 날짜를 골라요.', style: text.bodySmall),
        const SizedBox(height: 24),
        Text('상대를 뭐라고 부를까요?', style: text.titleSmall),
        const SizedBox(height: 8),
        AppTextField(
          hint: '예: 지민, 같은 수업 그 사람',
          controller: nicknameController,
        ),
        const SizedBox(height: 20),
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
                  selected: tag == reasonTag,
                  onTap: () => onReasonChanged(tag),
                ),
              ),
          ],
        ),
        if (reasonTag == otherReason) ...[
          const SizedBox(height: 10),
          AppTextField(
            hint: '예: 이사, 교환학생 출국',
            controller: customReasonController,
          ),
        ],
      ],
    );
  }
}
