// 피그마 4번 화면의 가운데 내용 (만남 빈도)
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/slider_card.dart';

class MeetingStep extends StatelessWidget {
  const MeetingStep({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 주 0 ~ 7회
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('일주일에 몇 번 만나나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('직접 만날 기회에 맞춰 미션을 구성해요.', style: text.bodySmall),
        const SizedBox(height: 24),
        SliderCard(
          valueLabel: '주 $value회',
          value: value.toDouble(),
          min: 0,
          max: 7,
          divisions: 7,
          minLabel: '0회',
          maxLabel: '7회',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
