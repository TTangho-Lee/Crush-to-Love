// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../../app/crush_switcher.dart';
import '../../onboarding/data/crush_store.dart';
import '../app_colors.dart';

/// 모든 화면 맨 위에 들어가는 '♥ DueDate' 머리글
/// 지금 상대가 있으면 'DueDate' 옆에 '지민 ▾' (누르면 상대 바꾸기 · 설정)
/// 오른쪽에 '1 / 5', 'D-20' 같은 작은 글자 (label), onBack이 있으면 오른쪽 끝에 되돌아가기 버튼
/// '예시'는 예시 화면(지금 상대가 없을 때)에서만 보임
///
///     const AppHeader(label: 'D-20')
///
/// 오른쪽 글자가 없으면 `const AppHeader()`, 상대를 숨기려면 showCrush: false (온보딩 · 설정)
class AppHeader extends StatelessWidget {
  const AppHeader({super.key, this.label, this.showCrush = true, this.onBack});

  final String? label;

  /// 지금 상대 '지민 ▾' 보이기 (지금 상대가 없으면 원래 안 보임)
  final bool showCrush;

  /// 되돌아가기 (설정 · 분석 기록처럼 하단 탭 없이 연 화면), 없으면 버튼 없음
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = CrushScope.maybeOf(context);
    final current = showCrush ? crushes?.current : null;
    // 실제로 쓰는 중(상대가 있음)이면 '예시'는 안 보임
    final label = this.label == exampleLabel && crushes?.current != null
        ? null
        : this.label;
    final onBack = this.onBack;

    return Row(
      children: [
        const Icon(Icons.favorite, size: 16, color: AppColors.charcoal),
        const SizedBox(width: 6),
        Text('DueDate', style: text.titleMedium),
        if (current != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: _CrushChip(
              name: current.nickname,
              onTap: () => showCrushSwitcher(context),
            ),
          ),
        ],
        const Spacer(),
        if (label != null) Text(label, style: text.labelSmall),
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _HeaderIcon(
              // U턴 화살표를 옆으로 돌린 모양 (되돌아가기)
              icon: Icons.u_turn_left,
              quarterTurns: 1,
              tooltip: '돌아가기',
              onTap: onBack,
            ),
          ),
      ],
    );
  }
}

/// 예시 화면 머리글 글자
const exampleLabel = '예시';

/// 지금 상대 '지민 ▾'
class _CrushChip extends StatelessWidget {
  const _CrushChip({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 3, 4, 3),
        decoration: BoxDecoration(
          color: AppColors.rose,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12),
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.charcoal),
          ],
        ),
      ),
    );
  }
}

/// 머리글 오른쪽 작은 아이콘 버튼
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.quarterTurns = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  /// 아이콘을 90도씩 돌리기
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: RotatedBox(
            quarterTurns: quarterTurns,
            child: Icon(icon, size: 20, color: AppColors.charcoal),
          ),
        ),
      ),
    );
  }
}
