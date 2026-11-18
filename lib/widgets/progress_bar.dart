// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 진행 정도를 보여주는 가로 막대
/// 온보딩 맨 위 단계 표시, 홈의 미션 진행률에 사용
/// value는 0부터 1 사이 숫자 (0.5면 절반)
///
///     ProgressBar(value: 1 / 5)
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: Container(
        height: 6,
        color: AppColors.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0.0, 1.0).toDouble(),
          heightFactor: 1,
          child: const ColoredBox(color: AppColors.peach),
        ),
      ),
    );
  }
}
