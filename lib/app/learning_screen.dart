// 학습한 내용 (설정 '기록'에서, 하단 탭 없이 전체 화면, 오른쪽 위 되돌아가기)
//   기록 수 · 맞춤 추천 켜기/끄기 (스위치, 바로 적용) · 잘 해낸 미션 · 잘 안 한 미션 · 자주 고른 멘트
//     (배운 가중치 큰 순, 막대 길이 = 크기, 분야마다 따로)
//   학습 기록 지우기 (한 번 더 묻기)
import 'package:material_ui/material_ui.dart';

import '../learning/learning_store.dart';
import '../learning/line_features.dart';
import '../learning/mission_features.dart';
import '../shared/app_colors.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/panel_card.dart';
import '../shared/widgets/progress_bar.dart';

class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final learning = LearningScope.of(context);
    final events = learning.events();
    final (good, bad) = missionTraits(learning);
    final (liked, _) = lineTraits(learning);
    // 막대 길이 기준 (분야마다 가장 큰 가중치)
    double maxOf(List<(String, double)> list) =>
        list.fold(0.0, (m, t) => t.$2.abs() > m ? t.$2.abs() : m);
    final top = maxOf([...good, ...bad]);
    final lineTop = maxOf(liked);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(showCrush: false, onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('학습한 내용', style: text.headlineSmall),
            const SizedBox(height: 6),
            Text('기록 ${events.length}개', style: text.bodySmall),
            const SizedBox(height: 16),
            PanelCard(
              child: Row(
                children: [
                  Expanded(child: Text('맞춤 추천', style: text.titleSmall)),
                  Switch(
                    value: learning.enabled,
                    onChanged: learning.setEnabled,
                  ),
                ],
              ),
            ),
            if (good.isEmpty && bad.isEmpty && liked.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 24, 4, 0),
                child: Text('아직 배운 게 없어요', style: text.bodySmall),
              ),
            if (good.isNotEmpty) ...[
              const _Title('잘 해낸 미션'),
              PanelCard(
                child: Column(
                  spacing: 10,
                  children: [
                    for (final (label, w) in good)
                      _TraitRow(label: label, value: top == 0 ? 0 : w / top),
                  ],
                ),
              ),
            ],
            if (bad.isNotEmpty) ...[
              const _Title('잘 안 한 미션'),
              PanelCard(
                child: Column(
                  spacing: 10,
                  children: [
                    for (final (label, w) in bad)
                      _TraitRow(label: label, value: top == 0 ? 0 : -w / top),
                  ],
                ),
              ),
            ],
            if (liked.isNotEmpty) ...[
              const _Title('자주 고른 멘트'),
              PanelCard(
                child: Column(
                  spacing: 10,
                  children: [
                    for (final (label, w) in liked)
                      _TraitRow(label: label, value: lineTop == 0 ? 0 : w / lineTop),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (events.isNotEmpty)
              Center(
                child: TextButton(
                  onPressed: () => _confirmClear(context, learning),
                  child: Text('학습 기록 지우기', style: text.bodySmall),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, LearningStore learning) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        content: const Text('학습한 기록을 모두 지울까요?\n되돌릴 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok == true) await learning.clear();
  }
}

/// 미션 종류 한 줄 (이름 + 크기 막대)
class _TraitRow extends StatelessWidget {
  const _TraitRow({required this.label, required this.value});

  final String label;

  /// 0 ~ 1
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        SizedBox(width: 120, child: ProgressBar(value: value)),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
