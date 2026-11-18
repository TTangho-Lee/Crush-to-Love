// 피그마 2번 화면의 가운데 내용 (D-Day)
// 태그 목록은 shared/models.dart의 reasonTags
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../../shared/widgets/tag_chip.dart';
import '../widgets/date_field.dart';

class DdayStep extends StatelessWidget {
  const DdayStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const selectedTag = '종강'; // 피그마 예시

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('언제까지 함께할 수 있나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('종강이나 입대처럼 만남이 달라지는 날짜를 골라요.', style: text.bodySmall),
        const SizedBox(height: 24),
        const DateField(),
        const SizedBox(height: 24),
        Text('어떤 날인가요?', style: text.titleSmall),
        const SizedBox(height: 12),
        Row(
          spacing: 8,
          children: [
            for (final tag in reasonTags)
              Expanded(
                child: TagChip(label: tag, selected: tag == selectedTag),
              ),
          ],
        ),
      ],
    );
  }
}
