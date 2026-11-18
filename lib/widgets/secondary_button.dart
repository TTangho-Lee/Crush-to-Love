// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 흰 바탕에 얇은 테두리가 있는 버튼 ('이전', '취소하고 홈으로' 같은 보조 버튼)
///
///     SecondaryButton(label: '이전', onPressed: () {})
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
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
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.warmWhite,
          foregroundColor: AppColors.charcoal,
          disabledForegroundColor: AppColors.warmGray,
          side: const BorderSide(color: AppColors.border),
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
