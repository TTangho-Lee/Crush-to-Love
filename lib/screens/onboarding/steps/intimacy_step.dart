// 피그마 3번 화면의 가운데 내용 (친밀도)
// 선택지는 data/models.dart의 Intimacy
import 'package:material_ui/material_ui.dart';

import '../../../data/models.dart';
import '../../../widgets/option_card.dart';

class IntimacyStep extends StatelessWidget {
  const IntimacyStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const selected = Intimacy.smallTalk; // 피그마 예시

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('지금은 어떤 사이인가요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('지금 편하게 할 수 있는 행동을 기준으로 골라요.', style: text.bodySmall),
        const SizedBox(height: 24),
        Column(
          spacing: 12,
          children: [
            for (final level in Intimacy.values)
              OptionCard(
                title: level.label,
                description: level.description,
                selected: level == selected,
              ),
          ],
        ),
      ],
    );
  }
}
