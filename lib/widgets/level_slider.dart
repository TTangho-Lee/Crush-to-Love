import 'package:material_ui/material_ui.dart';

/// 단계형 스크롤바 + 단계별 예시 문구.
class LevelSlider extends StatelessWidget {
  const LevelSlider({
    super.key,
    required this.label,
    required this.descriptions,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<String> descriptions;

  /// 1부터 시작
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final max = descriptions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value / $max단계',
            style: Theme.of(context).textTheme.titleSmall),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: max.toDouble(),
          divisions: max - 1,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Text('예: ${descriptions[value - 1]}'),
      ],
    );
  }
}
