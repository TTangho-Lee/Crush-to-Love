// 온보딩 흐름 전용 위젯
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';

/// 시작 화면(피그마 1번)의 D-20 예시 카드
/// 가운데 큰 'D-20' + 그 아래 첫 미션 한 줄
class ExampleDdayCard extends StatelessWidget {
  const ExampleDdayCard({
    super.key,
    required this.dDayText,
    required this.firstMission,
  });

  final String dDayText;
  final String firstMission;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            dDayText,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            firstMission,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
