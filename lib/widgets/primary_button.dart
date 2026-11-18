// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 화면 아래쪽 분홍색 큰 버튼 ('다음 →', '첫 미션 받기 →' 같은 버튼)
/// onPressed가 null이면 흐려지고 눌리지 않음
///
///     PrimaryButton(label: '다음 →', onPressed: () {})
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.blush,
          foregroundColor: AppColors.charcoal,
          disabledBackgroundColor: AppColors.ivory,
          disabledForegroundColor: AppColors.warmGray,
          textStyle: Theme.of(context).textTheme.titleSmall,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
