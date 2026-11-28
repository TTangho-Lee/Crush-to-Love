// 피그마 14 · 15 · 16번 화면 (주차 상세)
//   모양이 같아서 파일 하나, weekNo로 몇 주차인지 정함
//   맨 위: 날짜 · n/m 완료, 이번 주 할 일 한 줄 (단계 설명)
//   미션: 체크 칸 · 제목 · 팁 · 용기 ●●○ · 방법, 누르면 완료 · 취소 (DB에 저장)
//   왼쪽 위 ‹로 되돌아가기 (홈 · 로드맵 어디서 열었든)
import 'package:material_ui/material_ui.dart';

import '../shared/app_colors.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/check_mark.dart';
import 'roadmap_models.dart';
import 'roadmap_store.dart';
import 'roadmap_generator.dart';
import 'roadmap_widgets.dart';

class RoadmapWeekScreen extends StatelessWidget {
  const RoadmapWeekScreen({super.key, required this.weekNo});

  /// 1부터
  final int weekNo;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = RoadmapScope.of(context);
    final weeks = store.weeks;
    // 상대를 바꿔서 이 주차가 없으면 첫 주차
    final week = weeks.firstWhere(
      (w) => w.weekNo == weekNo,
      orElse: () => weeks.first,
    );
    final maxLevel = courageMax(store.profile.courage);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('${week.label} · ${week.title}', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '${dateRangeOf(store, week)}  ·  ${week.doneCount}/${week.missions.length} 완료',
              style: text.bodySmall,
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, size: 15, color: AppColors.charcoal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(week.stage.description, style: text.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Column(
              spacing: 12,
              children: [
                for (final m in week.missions)
                  _MissionTile(
                    mission: m,
                    brave: (!m.done && m.level > maxLevel) || m.brave,
                    onTap: () => store.toggleMission(m.id),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 미션 한 장: 체크 칸 · 제목 · 팁 · 용기 · 방법 (완료하면 분홍 바탕)
class _MissionTile extends StatelessWidget {
  const _MissionTile({
    required this.mission,
    required this.brave,
    required this.onTap,
  });

  final RoadmapMission mission;
  final bool brave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = mission.done;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? AppColors.rose : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: done ? AppColors.rose : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckMark(checked: done, onTap: onTap, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mission.title, style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text(mission.tip, style: text.bodySmall),
                  const SizedBox(height: 8),
                  MissionMeta(mission: mission, brave: brave),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
