// 피그마 6번 화면의 가운데 내용 (목표)
// 선택지는 shared/models.dart의 Goal
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../../shared/widgets/option_card.dart';

class GoalStep extends StatelessWidget {
  const GoalStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const selected = Goal.friends; // 피그마 예시

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('어디까지 가까워지고 싶나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('지금의 목표를 골라요. 나중에 언제든 바꿀 수 있어요.', style: text.bodySmall),
        const SizedBox(height: 24),
        Column(
          spacing: 12,
          children: [
            for (final goal in Goal.values)
              OptionCard(
                title: goal.label,
                description: goal.description,
                selected: goal == selected,
              ),
          ],
        ),
      ],
    );
  }
}
