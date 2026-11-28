// 피그마 7번 화면 (홈)
//   맨 위 한 줄 진단 (roadmap_rules.dart summaryOf)
//   목표 카드: 사유 D-n · 목표 진척도 % · 주차별 막대 · 진도 · 용기 단계 · '업데이트 ›'(11번)
//   미션 카드 하나 (_MissionPanel): 주차 제목 · n/m (누르면 주차 상세 14~16번)
//     주차 미션을 순서 그대로 위아래로, 한 번에 하나만 펼침 (아코디언, ⌄ · ⌃ 아이콘으로 암시)
//       처음엔 오늘의 미션(규칙 · 맞춤 추천으로 고른 한 개)이 펼쳐짐, 다른 줄을 누르면 그게 펼쳐지고 나머지는 접힘
//       접힌 줄: 체크 · 이름 · 용기 ●●○ · ⌄, 펼친 칸: 용기 · 방법 · 팁만 (간결하게)
//       체크 칸을 누르면 완료 · 취소, 줄 나머지를 누르면 펼치기 · 접기
//     이번 주를 다 했으면 다 한 주차들은 한 줄(✓)씩 접고 남은 가장 가까운 주차 미션을 미리
//     전 주차를 다 했으면 이번 주부터 마지막 주차까지 한 줄(✓)씩만 (누르면 주차 상세에서 취소 가능)
//   D-Day가 지났으면 결과 입력(17번), 다 했으면 축하 카드
import 'package:material_ui/material_ui.dart';

import '../onboarding/data/crush_store.dart';
import '../outcome/outcome_screen.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/check_mark.dart';
import '../shared/widgets/primary_button.dart';
import 'roadmap_generator.dart';
import 'roadmap_models.dart';
import 'roadmap_rules.dart';
import 'roadmap_store.dart';
import 'roadmap_relation_screen.dart';
import 'roadmap_week_screen.dart';
import 'roadmap_widgets.dart';

class RoadmapHomeScreen extends StatelessWidget {
  const RoadmapHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = RoadmapScope.of(context);
    final s = store.situation;
    final pick = store.todayPick;
    final crush = CrushScope.maybeOf(context)?.current;
    final askOutcome = s.passed && crush != null && crush.outcome == null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // 예시 화면(지금 상대가 없을 때)에서만 오른쪽에 '예시'
            AppHeader(label: store.isExample ? exampleLabel : null),
            const SizedBox(height: 24),
            Text('오늘, 말 걸 타이밍', style: text.headlineSmall),
            const SizedBox(height: 8),
            _Summary(store.summary),
            const SizedBox(height: 20),
            _GoalCard(store: store, situation: s),
            const SizedBox(height: 28),
            if (askOutcome)
              _NoticeCard(
                title: 'D-Day가 지났어요',
                body: '어떻게 됐는지 알려 주면 다음을 같이 준비해요.',
                action: '결과 알려 주기',
                onPressed: () => showOutcome(context, crush),
              )
            else if (pick == null)
              _NoticeCard(
                title: '로드맵 미션을 모두 마쳤어요!',
                body: '${s.profile.goal.label}까지 할 수 있는 건 다 했어요.',
                action: crush == null ? null : '결과 알려 주기',
                onPressed:
                    crush == null ? null : () => showOutcome(context, crush),
              ),
            if (askOutcome || pick == null) const SizedBox(height: 28),
            _MissionPanel(
              key: ValueKey(s.roadmap.crushId),
              store: store,
              week: s.week,
              pick: askOutcome ? null : pick,
            ),
          ],
        ),
      ),
    );
  }
}

/// 한 줄 진단 (반짝이 아이콘 + 글자)
class _Summary extends StatelessWidget {
  const _Summary(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.auto_awesome, size: 15, color: AppColors.peach),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// 목표 카드: '종강 D-12' · '썸 타기 진척도 42%' · 주차별 막대 · 진도 · 용기 · 업데이트
class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.store, required this.situation});

  final RoadmapStore store;
  final MissionSituation situation;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final s = situation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${s.profile.reason} ${dDayLabel(s.daysLeft)}',
            style: text.labelSmall?.copyWith(color: AppColors.warmGray),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    '${s.profile.goal.label} 진척도',
                    style: text.titleSmall,
                  ),
                ),
                Text(
                  '${(s.goalProgress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentBar(
              weeks: s.roadmap.weeks,
              currentIndex: s.weekIndex,
              start: s.start,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 좁은 화면에선 칩이 다음 줄로 (넘치지 않게)
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Pill(icon: paceIcon(s.pace), label: s.pace.label),
                    Pill(
                      icon: Icons.battery_charging_full,
                      label: '용기 ${courageName(s.courage)}',
                    ),
                  ],
                ),
              ),
              TextButton(
                // 피그마 11번 (하단 탭 없이 전체 화면)
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const RoadmapRelationScreen(),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  textStyle: text.labelSmall,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('업데이트 ›'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 연분홍 알림 카드 (D-Day 지남 · 다 함)
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.body,
    this.action,
    this.onPressed,
  });

  final String title;
  final String body;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final action = this.action;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text(body, style: text.bodySmall),
          if (action != null) ...[
            const SizedBox(height: 14),
            PrimaryButton(label: action, onPressed: onPressed),
          ],
        ],
      ),
    );
  }
}

/// 미션 카드 하나: 주차 제목 줄 · 미션 아코디언 (한 번에 하나만 펼침)
/// 이번 주를 다 해서 다음 주를 미리 하면 이번 주부터 다 한 주차들은 한 줄(✓)씩 접고 미리 하는 주차를 보여 줌
class _MissionPanel extends StatefulWidget {
  const _MissionPanel({
    super.key,
    required this.store,
    required this.week,
    this.pick,
  });

  final RoadmapStore store;

  /// 이번 주
  final RoadmapWeek week;

  /// 오늘의 미션 (D-Day 지남 · 다 함이면 null)
  final TodayPick? pick;

  @override
  State<_MissionPanel> createState() => _MissionPanelState();
}

class _MissionPanelState extends State<_MissionPanel> {
  /// 직접 고른 펼칠 미션 (null이면 다 접음), _chosen이 false면 오늘의 미션을 펼침
  String? _openId;
  bool _chosen = false;

  void _tap(String id, String? openNow) => setState(() {
        _chosen = true;
        _openId = openNow == id ? null : id;
      });

  void _toggle(RoadmapMission m, String? openId) {
    // 펼친 미션을 끝내면 다음 오늘의 미션을 펼침
    if (!m.done && m.id == openId) setState(() => _chosen = false);
    widget.store.toggleMission(m.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pick = widget.pick;
    final early = pick != null && pick.early;
    final shown = pick != null && pick.early ? pick.week : widget.week;
    final maxLevel = courageMax(store.situation.profile.courage);
    final openId = _chosen ? _openId : pick?.mission.id;

    // 이번 주부터 끝까지 다 했으면 주차 줄(✓)만
    final rest = [
      for (final w in store.weeks)
        if (w.weekNo >= widget.week.weekNo) w,
    ];
    if (pick == null && rest.every((w) => w.allDone)) {
      return Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final w in rest) _WeekTitle(week: w, done: true)],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 이번 주부터 미리 하는 주차 앞까지 (다 한 주차)
        if (early)
          for (final w in store.weeks)
            if (w.weekNo >= widget.week.weekNo && w.weekNo < shown.weekNo) ...[
              _WeekTitle(week: w, done: true),
              const SizedBox(height: 12),
            ],
        _WeekTitle(week: shown, early: early),
        const SizedBox(height: 10),
        Column(
          spacing: 8,
          children: [
            for (final m in shown.missions)
              _MissionItem(
                mission: m,
                open: m.id == openId,
                brave: !m.done && m.level > maxLevel,
                onTap: () => _tap(m.id, openId),
                onToggle: () => _toggle(m, openId),
              ),
          ],
        ),
      ],
    );
  }
}

/// 미션 한 칸: 체크(누르면 완료 · 취소) · 이름 · 용기 ●●○ · ⌄
/// 펼치면 그 아래 용기 · 방법 · 팁, 맨 윗줄을 누르면 접힘(⌃)
class _MissionItem extends StatelessWidget {
  const _MissionItem({
    required this.mission,
    required this.open,
    required this.onTap,
    required this.onToggle,
    this.brave = false,
  });

  final RoadmapMission mission;
  final bool open;

  /// 줄 누름 (펼치기 · 접기)
  final VoidCallback onTap;

  /// 완료 · 취소 (체크 칸)
  final VoidCallback onToggle;

  /// 지금 용기보다 어려운 미션 (펼친 칸에 '용기 보너스 ×1.5')
  final bool brave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = mission;
    final done = m.done;

    final head = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        child: Row(
          children: [
            // 체크 칸만 완료 · 취소 (누르기 쉽게 둘레까지), 나머지는 펼치기 · 접기
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CheckMark(checked: done, size: 24),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                m.title,
                maxLines: open ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: (open ? text.titleSmall : text.bodyMedium)?.copyWith(
                  color: done ? AppColors.warmGray : AppColors.charcoal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!open) ...[
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Icon(
                    i <= m.level ? Icons.circle : Icons.circle_outlined,
                    size: 6,
                    color: AppColors.warmGray,
                  ),
                ),
              const SizedBox(width: 6),
            ],
            Icon(
              open ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.warmGray,
            ),
          ],
        ),
      ),
    );

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MissionMeta(mission: m, brave: brave),
          const SizedBox(height: 8),
          Text(m.tip, style: text.bodySmall),
        ],
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: open
            ? AppColors.warmWhite
            : (done ? AppColors.roseSoft : AppColors.ivory),
        borderRadius: BorderRadius.circular(open ? 16 : 12),
        border: Border.all(color: open ? AppColors.border : Colors.transparent),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [head, if (open) body],
        ),
      ),
    );
  }
}

/// 주차 제목 줄 ('1주차 · 인사 트기  2/4 ›'), 누르면 주차 상세
/// done: 다 한 주차를 접은 줄 (✓ · 흐린 글자), early: 미리 하는 다음 주차 (앞에 ⏩)
class _WeekTitle extends StatelessWidget {
  const _WeekTitle({required this.week, this.done = false, this.early = false});

  final RoadmapWeek week;
  final bool done;
  final bool early;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = done
        ? text.titleSmall?.copyWith(color: AppColors.warmGray)
        : text.titleMedium;

    return InkWell(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => RoadmapWeekScreen(weekNo: week.weekNo),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (done || early) ...[
              Icon(
                done ? Icons.check_circle : Icons.fast_forward,
                size: 18,
                color: done ? AppColors.peach : AppColors.charcoal,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                '${week.label} · ${week.title}',
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${week.doneCount}/${week.missions.length}',
              style: text.labelSmall,
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}
