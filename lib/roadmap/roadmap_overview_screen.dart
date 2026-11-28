// 피그마 8번 화면 (전체 로드맵)
//   맨 위: 목표 진척도 · 진도, 자동 조정했으면 그 이유 한 줄 (7일 동안)
//   주차 타임라인: 지난 주차 ✓ · 이번 주차(분홍, '지금') · 다음 주차, 날짜 · 미션 점(●○)
//   주차를 누르면 14 · 15 · 16번 (하단 탭 없이 전체 화면), '오늘의 미션으로' → 홈 탭
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/primary_button.dart';
import 'roadmap_models.dart';
import 'roadmap_store.dart';
import 'roadmap_week_screen.dart';
import 'roadmap_widgets.dart';

/// 자동 조정 이유를 보여 줄 기간
const _noteDays = 7;

/// 주차 상태
enum _WeekState { past, now, next }

class RoadmapOverviewScreen extends StatelessWidget {
  const RoadmapOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = RoadmapScope.of(context);
    final s = store.situation;
    final roadmap = s.roadmap;
    final note = roadmap.note;
    final noteAt = roadmap.noteAt;
    final showNote = note != null &&
        noteAt != null &&
        DateTime.now().difference(noteAt).inDays < _noteDays;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(label: dDayLabel(s.daysLeft)),
            const SizedBox(height: 24),
            Text('D-Day까지의 로드맵', style: text.headlineSmall),
            const SizedBox(height: 8),
            Row(
              spacing: 6,
              children: [
                Text(
                  '${s.profile.goal.label} 진척도 ${(s.goalProgress * 100).round()}%',
                  style: text.bodyMedium,
                ),
                Pill(
                  icon: paceIcon(s.pace),
                  label: s.pace.label,
                  color: AppColors.rose,
                ),
              ],
            ),
            if (showNote) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ivory,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, size: 14, color: AppColors.peach),
                    const SizedBox(width: 6),
                    Expanded(child: Text(note, style: text.bodySmall)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            for (var i = 0; i < roadmap.weeks.length; i++)
              _TimelineRow(
                week: roadmap.weeks[i],
                dates: dateRangeOf(store, roadmap.weeks[i]),
                state: i < s.weekIndex
                    ? _WeekState.past
                    : i == s.weekIndex
                        ? _WeekState.now
                        : _WeekState.next,
                last: i == roadmap.weeks.length - 1,
              ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '오늘의 미션으로',
              onPressed: () => MainShell.tabIndex.value = 0,
            ),
          ],
        ),
      ),
    );
  }
}

/// 타임라인 한 줄: 왼쪽 동그라미 + 세로줄, 오른쪽 주차 카드
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.week,
    required this.dates,
    required this.state,
    required this.last,
  });

  final RoadmapWeek week;
  final String dates;
  final _WeekState state;

  /// 마지막 주차면 아래 세로줄 없음
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = state == _WeekState.now;
    final dim = state == _WeekState.next;

    final dot = switch (state) {
      _WeekState.past => Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: AppColors.peach,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, size: 14, color: AppColors.charcoal),
        ),
      _WeekState.now => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.peach, width: 6),
          ),
        ),
      _WeekState.next => Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.warmWhite,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.track, width: 2),
          ),
        ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                const SizedBox(height: 14),
                dot,
                if (!last)
                  Expanded(
                    child: Container(width: 2, color: AppColors.track),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RoadmapWeekScreen(weekNo: week.weekNo),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: now ? AppColors.rose : AppColors.warmWhite,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: now ? AppColors.rose : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              spacing: 6,
                              children: [
                                Text(week.label, style: text.labelSmall),
                                if (now)
                                  const Pill(
                                    icon: Icons.place_outlined,
                                    label: '지금',
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              week.title,
                              style: text.titleSmall?.copyWith(
                                color: dim ? AppColors.warmGray : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(dates, style: text.bodySmall),
                          ],
                        ),
                      ),
                      // 미션 점 (완료 ●, 남음 ○)
                      Row(
                        spacing: 3,
                        children: [
                          for (final m in week.missions)
                            Icon(
                              m.done ? Icons.circle : Icons.circle_outlined,
                              size: 9,
                              color: m.done ? AppColors.peach : AppColors.warmGray,
                            ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AppColors.warmGray,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
