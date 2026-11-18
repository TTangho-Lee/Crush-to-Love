// 피그마 5번 화면의 가운데 내용 (용기 배터리)
import 'package:material_ui/material_ui.dart';

import '../../../widgets/info_card.dart';
import '../../../widgets/slider_card.dart';

class CourageStep extends StatelessWidget {
  const CourageStep({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('오늘의 용기는 얼마나 찼나요?', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('지금 편안하게 시도할 수 있는 정도를 고르면 돼요.', style: text.bodySmall),
        const SizedBox(height: 24),
        const SliderCard(
          valueLabel: '50%', // 피그마 예시
          value: 50,
          min: 0,
          max: 100,
          minLabel: '0%',
          maxLabel: '100%',
        ),
        const SizedBox(height: 12),
        // 용기 단계 설명
        const InfoCard(
          title: '표준 · 가벼운 대화',
          description: '먼저 톡을 보내거나 공통 관심사를 가볍게 물어봐요.',
        ),
      ],
    );
  }
}
