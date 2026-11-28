// 공통 위젯
import 'package:material_ui/material_ui.dart';

import '../../app/crush_switcher.dart';
import '../../onboarding/data/crush_store.dart';
import '../app_colors.dart';

/// 모든 화면 맨 위 머리글
///   탭 첫 화면: 왼쪽 '♥ DueDate' (+ 지금 상대가 있으면 '지민 ▾', 누르면 상대 바꾸기 · 설정)
///   안으로 들어간 화면(onBack): 왼쪽 위 ‹ 되돌아가기만 (DueDate · 상대 이름 없음, 보통 앱처럼)
///   오른쪽에 '1 / 5', 'D-20' 같은 작은 글자 (label)
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

  /// 되돌아가기 (분석 결과 · 설정 · 분석 기록처럼 안으로 들어간 화면), 있으면 왼쪽 위 ‹ 하나만
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

    // 안으로 들어간 화면: 왼쪽 위 ‹ · 오른쪽 작은 글자
    if (onBack != null) {
      return Row(
        children: [
          Transform.translate(
            // 아이콘 둘레 여백만큼 왼쪽으로 (화면 글자와 왼쪽 끝 맞춤)
            offset: const Offset(-4, 0),
            child: _HeaderIcon(
              icon: Icons.arrow_back_ios_new,
              tooltip: '돌아가기',
              onTap: onBack,
            ),
          ),
          const Spacer(),
          if (label != null) Text(label, style: text.labelSmall),
        ],
      );
    }

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

/// 머리글 작은 아이콘 버튼 (되돌아가기)
class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: AppColors.charcoal),
        ),
      ),
    );
  }
}
