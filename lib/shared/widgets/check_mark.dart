// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 완료 여부를 표시하는 체크 칸, 완료하면 분홍색 칸에 ✓, 못 하고 닫았으면(failed) 회색 ✕
/// 홈(피그마 7번)의 오늘의 미션에 사용
///
///     CheckMark(checked: true)
class CheckMark extends StatelessWidget {
  const CheckMark({
    super.key,
    required this.checked,
    this.failed = false,
    this.onTap,
    this.size = 28,
  });

  final bool checked;

  /// 못 하고 닫음 (✕)
  final bool failed;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: checked
              ? AppColors.peach
              : failed
                  ? AppColors.track
                  : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(
            color: checked
                ? AppColors.peach
                : failed
                    ? AppColors.track
                    : AppColors.border,
          ),
        ),
        child: checked
            ? Icon(Icons.check, size: size * 0.6, color: AppColors.charcoal)
            : failed
                ? Icon(Icons.close, size: size * 0.6, color: AppColors.warmGray)
                : null,
      ),
    );
  }
}
