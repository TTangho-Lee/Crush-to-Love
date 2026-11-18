// 피그마 14 · 15 · 16번 화면 (주차 상세)
// 모양이 같아서 파일 하나, weekNo로 몇 주차인지 정함 (1주차 = 14번, 2주차 = 15번, 3주차 = 16번)
// 데이터: MissionStore의 weeks
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/models.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/secondary_button.dart';
import '../data/mission_store.dart';

class WeekDetailScreen extends StatelessWidget {
  const WeekDetailScreen({super.key, required this.weekNo});

  /// 1, 2, 3
  final int weekNo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final weeks = MissionScope.of(context).weeks;
    final week = weeks.firstWhere(
      (w) => w.weekNo == weekNo,
      orElse: () => weeks.first,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('${week.weekNo}주차 · ${week.title}', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${dDayLabel(week.fromDDay)} ~ ${dDayLabel(week.toDDay)}  ·  '
              '${week.doneCount}/${week.missions.length} 완료',
              style: text.bodySmall,
            ),
            const SizedBox(height: 24),
            Column(
              spacing: 12,
              children: [
                for (final mission in week.missions)
                  InfoCard(
                    title: mission.title,
                    description: mission.tip,
                    icon: mission.done ? Icons.check : Icons.circle_outlined,
                    color: mission.done ? AppColors.rose : AppColors.ivory,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: '← 전체 로드맵',
              // 피그마 8번으로 돌아가기
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
