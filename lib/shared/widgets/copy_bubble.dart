// 공통 위젯
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../app_colors.dart';

/// 누르면 글자가 복사되는 말풍선 (오른쪽 복사 아이콘)
/// 대화 분석 예시 멘트(피그마 12번), 데이트 가이드 만난 뒤 톡(13번)에 사용
///
///     CopyBubble('오늘 진짜 즐거웠어 ㅎㅎ')
class CopyBubble extends StatelessWidget {
  const CopyBubble(this.text, {super.key});

  final String text;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('복사했어요'),
          duration: Duration(milliseconds: 1500),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copy(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          border: Border.all(color: AppColors.border),
          // 말풍선 모양 (왼쪽 아래만 덜 둥글게)
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 16, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}
