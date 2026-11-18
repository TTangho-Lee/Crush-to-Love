// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app/app_colors.dart';

/// 흰 입력칸, 비어 있을 때 안내 글자(hint)
/// 대화 붙여넣기(피그마 9번)에 사용
///
///     AppTextField(hint: '[나] [오후 1:00] 오늘 수업 어땠어?', maxLines: 5)
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.hint,
    this.maxLines = 1,
    this.controller,
  });

  final String hint;

  /// 몇 줄 높이로 보일지
  final int maxLines;

  /// 입력한 글자를 읽을 때 사용
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.border),
    );

    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: AppColors.warmGray),
        filled: true,
        fillColor: AppColors.warmWhite,
        contentPadding: const EdgeInsets.all(14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.peach),
        ),
      ),
    );
  }
}
