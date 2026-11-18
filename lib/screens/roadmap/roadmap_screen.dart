// 피그마 8번 화면 (전체 로드맵)
// 데이터: AppStore의 weeks, currentWeek, daysLeft
import 'package:material_ui/material_ui.dart';

import '../../app/app_colors.dart';
import '../../app/main_shell.dart';
import '../../data/app_store.dart';
import '../../data/models.dart';
import '../../widgets/app_header.dart';
import '../../widgets/info_card.dart';
import '../../widgets/primary_button.dart';
import 'week_detail_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = AppScope.of(context);
    final currentWeekNo = store.currentWeek.weekNo;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(label: dDayLabel(store.daysLeft)),
            const SizedBox(height: 24),
            Text('D-Day까지의 로드맵', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('전체 흐름을 보고, 주차 카드를 눌러 미션을 열어봐요.', style: text.bodySmall),
            const SizedBox(height: 24),
            Column(
              spacing: 12,
              children: [
                for (final week in store.weeks)
                  InfoCard(
                    title: '${week.weekNo}주차 · ${week.title}',
                    description: '${week.periodLabel}  ·  '
                        '${week.doneCount}/${week.missions.length} 완료  ·  미션 보기 ›',
                    color: week.weekNo == currentWeekNo
                        ? AppColors.rose
                        : AppColors.warmWhite,
                    // 피그마 14 · 15 · 16번으로 (하단 탭 없이 전체 화면)
                    onTap: () => Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => WeekDetailScreen(weekNo: week.weekNo),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '오늘의 미션으로',
              // 홈 탭(피그마 7번)으로
              onPressed: () => MainShell.tabIndex.value = 0,
            ),
          ],
        ),
      ),
    );
  }
}
