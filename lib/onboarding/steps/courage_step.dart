// 피그마 5번 화면의 가운데 내용 (용기 배터리)
// 단계 구분은 shared/models.dart의 CourageLevel
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/slider_card.dart';

class CourageStep extends StatelessWidget {
  const CourageStep({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// 0 ~ 100%, 10% 단위
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = CourageLevel.of(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 용기는 얼마나 찼나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('지금 편안하게 시도할 수 있는 정도를 고르면 돼요.', style: text.bodySmall),
        const SizedBox(height: 24),
        SliderCard(
          valueLabel: '$value%',
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 10,
          minLabel: '0%',
          maxLabel: '100%',
          onChanged: (v) => onChanged(v.round()),
        ),
        const SizedBox(height: 12),
        // 지금 용기 단계 설명
        InfoCard(title: level.label, description: level.description),
      ],
    );
  }
}
