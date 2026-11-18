// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 모든 화면 맨 위에 들어가는 '♥ DueDate' 머리글
/// 오른쪽에 '1 / 5', 'D-20', '예시' 같은 작은 글자 (label)
///
///     const AppHeader(label: '예시')
///
/// 오른쪽 글자가 없으면 `const AppHeader()`
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final label = this.label;

    return Row(
      children: [
        const Icon(Icons.favorite, size: 16, color: AppColors.charcoal),
        const SizedBox(width: 6),
        Text('DueDate', style: text.titleMedium),
        const Spacer(),
        if (label != null) Text(label, style: text.labelSmall),
      ],
    );
  }
}
