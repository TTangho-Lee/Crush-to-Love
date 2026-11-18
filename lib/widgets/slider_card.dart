// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 큰 숫자와 슬라이더가 같이 있는 카드
/// 온보딩의 만남 빈도(피그마 4번), 용기 배터리(5번)에 사용
/// 한 칸씩 끊어 움직이려면 divisions에 칸 수, 부드럽게 움직이려면 생략
///
///     SliderCard(
///       valueLabel: '주 2회',
///       value: 2,
///       min: 0,
///       max: 7,
///       divisions: 7,
///       minLabel: '0회',
///       maxLabel: '7회',
///     )
class SliderCard extends StatelessWidget {
  const SliderCard({
    super.key,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.minLabel,
    required this.maxLabel,
    this.onChanged,
  });

  /// 카드에 크게 보여줄 글자
  final String valueLabel;
  final double value;
  final double min;
  final double max;

  /// 슬라이더를 나눌 칸 수
  final int? divisions;

  /// 슬라이더 왼쪽 아래 글자
  final String minLabel;

  /// 슬라이더 오른쪽 아래 글자
  final String maxLabel;

  /// 슬라이더를 움직였을 때
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valueLabel,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            // null이면 슬라이더가 회색이 되므로 빈 함수로
            onChanged: onChanged ?? (_) {},
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: text.labelSmall),
              Text(maxLabel, style: text.labelSmall),
            ],
          ),
        ],
      ),
    );
  }
}
