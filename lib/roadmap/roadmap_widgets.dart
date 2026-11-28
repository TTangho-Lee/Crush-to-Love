// 미션 화면들이 같이 쓰는 작은 위젯
//   SegmentBar: 주차마다 칸을 나눈 진척도 막대 (칸 너비 = 그 주차 점수, 뒤 주차일수록 넓음)
//     출발점이 있으면 맨 앞에 꽉 찬 칸 하나 (사이로 이미 지나온 몫)
//   MissionMeta: 필요한 용기 ●●○ · 하는 방법(톡으로 · 만나서 · 혼자) · 용기 보너스
//   Pill: 아이콘 + 짧은 글자 칩
//   dateRangeOf: '11.20 ~ 11.26', 마지막 주차는 끝에 'D-Day'
import 'package:material_ui/material_ui.dart';

import '../shared/app_colors.dart';
import 'mission_lines.dart';
import 'roadmap_models.dart';
import 'roadmap_rules.dart';
import 'roadmap_store.dart';

/// 주차별로 나눈 진척도 막대
class SegmentBar extends StatelessWidget {
  const SegmentBar({
    super.key,
    required this.weeks,
    required this.currentIndex,
    this.start = 0,
  });

  final List<RoadmapWeek> weeks;

  /// 출발점 0 ~ 1 (맨 앞 꽉 찬 칸 너비)
  final double start;

  /// 이번 주차 순서 (테두리로 표시)
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final all = weeks.fold(0.0, (s, w) => s + _points(w));
    final head = start <= 0 || start >= 1 ? 0.0 : all * start / (1 - start);
    return Row(
      spacing: 3,
      children: [
        if (head > 0)
          Expanded(
            flex: (head * 10).round().clamp(1, 100000),
            child: const _Segment(fill: 1, current: false),
          ),
        for (var i = 0; i < weeks.length; i++)
          Expanded(
            flex: (_points(weeks[i]) * 10).round().clamp(1, 1000),
            child: _Segment(
              fill: _fill(weeks[i]),
              current: i == currentIndex,
            ),
          ),
      ],
    );
  }

  double _points(RoadmapWeek w) =>
      w.missions.fold(0.0, (s, m) => s + missionPoints(m, w.stage));

  double _fill(RoadmapWeek w) {
    final total = _points(w);
    if (total == 0) return 0;
    final earned = w.missions
        .where((m) => m.done)
        .fold(0.0, (s, m) => s + missionPoints(m, w.stage, earned: true));
    return (earned / total).clamp(0, 1).toDouble();
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fill, required this.current});

  final double fill;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.track,
        borderRadius: BorderRadius.circular(4),
        border: current ? Border.all(color: AppColors.peach, width: 1.5) : null,
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fill,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// 필요한 용기 ●●○ · 하는 방법 · (용기 보너스)
class MissionMeta extends StatelessWidget {
  const MissionMeta({super.key, required this.mission, this.brave = false});

  final RoadmapMission mission;

  /// 지금 용기보다 어려운 미션이면 '×1.5' 표시
  final bool brave;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.warmGray,
          fontWeight: FontWeight.w500,
        );
    final tags = mission.line?.tags ?? const <MissionTag>{};
    final (icon, how) = mission.offline
        ? (Icons.directions_walk, '만나서')
        : tags.contains(MissionTag.prep) && tags.length == 1
            ? (Icons.edit_note, '혼자')
            : (Icons.chat_bubble_outline, '톡으로');

    // 좁은 칸에선 다음 줄로 (넘치지 않게)
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            Text('용기', style: small),
            for (var i = 1; i <= 3; i++)
              Icon(
                i <= mission.level ? Icons.circle : Icons.circle_outlined,
                size: 7,
                color: i <= mission.level ? AppColors.charcoal : AppColors.warmGray,
              ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            Icon(icon, size: 13, color: AppColors.warmGray),
            Text(how, style: small),
          ],
        ),
        if (brave)
          const Pill(
            icon: Icons.bolt,
            label: '용기 보너스 ×1.5',
            color: AppColors.blush,
          ),
      ],
    );
  }
}

/// 아이콘 + 짧은 글자 칩
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppColors.warmWhite,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 3,
        children: [
          Icon(icon, size: 12, color: AppColors.charcoal),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

/// 진도 아이콘
IconData paceIcon(Pace pace) => switch (pace) {
      Pace.ahead => Icons.trending_up,
      Pace.onTrack => Icons.check_circle_outline,
      Pace.behind => Icons.schedule,
    };

/// '11.20 ~ 11.26', D-Day가 든 주차는 끝에 'D-Day'
String dateRangeOf(RoadmapStore store, RoadmapWeek week) {
  String md(DateTime d) => '${d.month}.${d.day}';
  final from = store.dateOf(week.fromDDay);
  final to = store.dateOf(week.toDDay);
  final range = from == to ? md(from) : '${md(from)} ~ ${md(to)}';
  return week.toDDay == 0 ? '$range D-Day' : range;
}
