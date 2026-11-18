// 피그마 7번 화면 (홈)
// 데이터: MissionStore의 profile, daysLeft, progress, doneCount, totalCount, todayMissions
// 체크 칸에서 쓸 데이터 메서드: MissionStore.toggleMission(missionId)
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/secondary_button.dart';
import '../data/mission_store.dart';
import 'relation_update_screen.dart';
import 'widgets/dday_card.dart';
import 'widgets/mission_row.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = MissionScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(label: '예시'),
            const SizedBox(height: 24),
            Text('오늘, 말 걸 타이밍', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('지금 사이에서 꺼내기 편한 미션을 골라요.', style: text.bodySmall),
            const SizedBox(height: 24),
            DdayCard(
              reason: store.profile.reason,
              daysLeft: store.daysLeft,
              progress: store.progress,
              goalLabel: store.profile.goal.label,
              doneCount: store.doneCount,
              totalCount: store.totalCount,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '관계 진척도 업데이트',
              // 피그마 11번으로 (하단 탭 없이 전체 화면)
              onPressed: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const RelationUpdateScreen()),
              ),
            ),
            const SizedBox(height: 24),
            Text('오늘의 미션', style: text.titleMedium),
            const SizedBox(height: 12),
            Column(
              spacing: 8,
              children: [
                for (final mission in store.todayMissions)
                  MissionRow(title: mission.title, done: mission.done),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
