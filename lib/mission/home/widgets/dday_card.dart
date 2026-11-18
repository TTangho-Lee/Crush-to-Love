// 홈 흐름 전용 위젯
import 'package:material_ui/material_ui.dart';

import '../../../shared/app_colors.dart';
import '../../../shared/models.dart';
import '../../../shared/widgets/progress_bar.dart';

/// 홈(피그마 7번)의 D-Day 카드
/// '종강까지 D-20', 미션 진행률, 진행 바, '친해지기 목표 · 1/9 완료'
class DdayCard extends StatelessWidget {
  const DdayCard({
    super.key,
    required this.reason,
    required this.daysLeft,
    required this.progress,
    required this.goalLabel,
    required this.doneCount,
    required this.totalCount,
  });

  /// D-Day 사유 (예: 종강)
  final String reason;
  final int daysLeft;

  /// 미션 진행률 0 ~ 1
  final double progress;
  final String goalLabel;
  final int doneCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$reason까지  ${dDayLabel(daysLeft)}',
            style: text.titleSmall?.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '미션 진행률 · ${(progress * 100).round()}%',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 12),
          ProgressBar(value: progress),
          const SizedBox(height: 8),
          Text(
            '$goalLabel 목표 · $doneCount/$totalCount 완료',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
