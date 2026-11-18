// 홈 화면 전용 위젯
import 'package:material_ui/material_ui.dart';

import '../../../app/app_colors.dart';
import '../../../widgets/check_mark.dart';

/// 홈(피그마 7번) 오늘의 미션 한 줄 (왼쪽 체크 칸 + 미션 글자)
/// 완료한 줄은 연분홍 바탕
class MissionRow extends StatelessWidget {
  const MissionRow({
    super.key,
    required this.title,
    required this.done,
    this.onCheck,
  });

  final String title;
  final bool done;

  /// 체크 칸을 눌렀을 때
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? AppColors.roseSoft : AppColors.ivory,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CheckMark(checked: done, onTap: onCheck),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
