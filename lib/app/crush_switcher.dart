// 지금 상대 바꾸기 · 새 상대 추가
//   showCrushSwitcher: 머리글 '지민 ▾'를 누르면 아래에서 올라오는 목록 (골라서 '확인'으로 바꾸기 · 설정, 새 상대는 설정 안에)
//   startNewCrush: 새 상대 온보딩 바로 시작 (지금 상대는 그대로 두고, 보관 · 지우기는 설정에서)
import 'package:material_ui/material_ui.dart';

import '../onboarding/data/crush_store.dart';
import '../onboarding/onboarding_screen.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/primary_button.dart';
import 'settings_screen.dart';

/// 목록에서 고른 것
enum _Pick { select, settings }

/// 상대 목록 (아래에서 올라옴)
Future<void> showCrushSwitcher(BuildContext context) async {
  final crushes = CrushScope.read(context);
  if (crushes == null) return;
  final picked = await showModalBottomSheet<(_Pick, int?)>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.warmWhite,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _CrushSheet(crushes: crushes),
  );
  if (picked == null || !context.mounted) return;
  final (pick, id) = picked;
  switch (pick) {
    case _Pick.select:
      if (id != null) await crushes.select(id);
    case _Pick.settings:
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
  }
}

/// 새 상대 온보딩 시작 (설정 · 대화 분석 결과)
/// chatName: 대화 분석 결과에서 '새 상대'를 누른 카톡 이름 (별명 칸에 미리 채우고 연결)
Future<void> startNewCrush(BuildContext context, {String? chatName}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (_) => OnboardingScreen(chatName: chatName),
    ),
  );
}

/// 상대 목록 내용, 상대를 골라 두고 '확인'을 눌러야 바뀜 (상대가 한 명이면 '확인' 없음)
class _CrushSheet extends StatefulWidget {
  const _CrushSheet({required this.crushes});

  final CrushStore crushes;

  @override
  State<_CrushSheet> createState() => _CrushSheetState();
}

class _CrushSheetState extends State<_CrushSheet> {
  /// 골라 둔 상대 (처음엔 지금 상대)
  late int? _picked = widget.crushes.current?.id;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = widget.crushes;
    final current = crushes.current;
    final active = crushes.active;
    final archivedCount = crushes.archived.length;
    final picked = _picked;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('짝사랑 상대', style: text.titleSmall),
            ),
            for (final c in active)
              _SheetRow(
                icon: c.id == picked
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                title: c.nickname,
                subtitle: crushSummary(c),
                bold: c.id == current?.id,
                onTap: () => setState(() => _picked = c.id),
              ),
            if (active.length > 1) ...[
              const SizedBox(height: 8),
              PrimaryButton(
                label: '확인',
                onPressed: picked == null || picked == current?.id
                    ? null
                    : () => Navigator.pop(context, (_Pick.select, picked)),
              ),
            ],
            const Divider(height: 24, color: AppColors.border),
            _SheetRow(
              icon: Icons.settings_outlined,
              title: '설정',
              subtitle: archivedCount > 0 ? '보관한 상대 $archivedCount명' : null,
              onTap: () => Navigator.pop(context, (_Pick.settings, null)),
            ),
          ],
        ),
      ),
    );
  }
}

/// '종강까지 D-20 · 인사·스몰토크 가능'
String crushSummary(Crush c) =>
    '${c.reason}까지 ${dDayLabel(daysUntil(c.dDay))} · ${c.intimacy.label}';

/// 목록 한 줄
class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.bold = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool bold;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.charcoal),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: bold ? text.titleSmall : text.bodyMedium,
                  ),
                  if (subtitle != null) Text(subtitle, style: text.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
