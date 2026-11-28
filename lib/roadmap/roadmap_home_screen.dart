// 피그마 7번 화면 (홈)
//   맨 위 한 줄 진단 (roadmap_rules.dart summaryOf)
//   목표 카드: 사유 D-n · 목표 진척도 % · 주차별 막대 · 진도 · 용기 단계 · '업데이트 ›'(11번)
//   미션 카드 하나 (_MissionPanel): 주차 제목 · n/m (누르면 주차 상세 14~16번)
//     맨 위 큰 상세 칸: 처음엔 오늘의 미션(규칙 · 맞춤 추천으로 고른 한 개, ↻로 바꾸기)
//       고른 이유(학습에서 나온 이유면 아이콘이 다름), 완료 · 취소는 이 칸의 버튼으로만
//     아래 한 줄 목록: 용기에 맞는 것 → 용기 보너스(어려운 것) → 다 한 것 순, 같은 칸 안에선 규칙 · 학습 순서
//       줄을 누르면 그 미션이 위 상세 칸으로 열림 (⇕ 아이콘으로 암시), 연 미션은 목록에서 빠짐
//     이번 주를 다 했으면 이번 주는 한 줄로 접고 다음 주 미션을 미리
//   D-Day가 지났으면 결과 입력(17번), 다 했으면 축하 카드
import 'package:material_ui/material_ui.dart';

import '../onboarding/data/crush_store.dart';
import '../outcome/outcome_screen.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/check_mark.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/secondary_button.dart';
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
                  '${(s.progress * 100).round()}%',
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
            child: SegmentBar(weeks: s.roadmap.weeks, currentIndex: s.weekIndex),
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

/// 큰 상세 칸: '오늘' · 용기 ●●○ · 방법 · 제목 · 팁 · 고른 이유 · '했어요' (다 했으면 '완료 취소')
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.mission,
    required this.brave,
    required this.onToggle,
    this.reason,
    this.learned = false,
    this.today = false,
    this.onRotate,
  });

  final RoadmapMission mission;

  /// 지금 용기보다 어려운 미션 ('용기 보너스 ×1.5')
  final bool brave;

  /// 완료 · 취소
  final VoidCallback onToggle;

  /// 고른 이유 한 줄 (다 한 미션이면 null)
  final String? reason;

  /// 이유가 학습에서 나왔으면 true (아이콘이 다름)
  final bool learned;

  /// 오늘의 미션이면 true ('오늘' 표시)
  final bool today;

  /// 다른 미션으로 바꾸기 (오늘의 미션이고 바꿀 게 있을 때만, 아니면 ↻ 숨김)
  final VoidCallback? onRotate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final m = mission;
    final reason = this.reason;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: m.done ? AppColors.roseSoft : AppColors.warmWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (today) ...[
                const Pill(
                  icon: Icons.auto_awesome,
                  label: '오늘',
                  color: AppColors.blush,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(child: MissionMeta(mission: m, brave: brave)),
              if (onRotate != null)
                IconButton(
                  onPressed: onRotate,
                  icon: const Icon(Icons.refresh, size: 18),
                  color: AppColors.warmGray,
                  visualDensity: VisualDensity.compact,
                  tooltip: '다른 미션',
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(m.title, style: text.titleMedium),
          const SizedBox(height: 4),
          Text(m.tip, style: text.bodySmall),
          if (reason != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.ivory,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 학습에서 나온 이유면 다른 아이콘
                  Icon(
                    learned ? Icons.insights : Icons.auto_awesome,
                    size: 13,
                    color: AppColors.peach,
                  ),
                  const SizedBox(width: 6),
                  Expanded(child: Text(reason, style: text.bodySmall)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          m.done
              ? SecondaryButton(label: '완료 취소', onPressed: onToggle)
              : PrimaryButton(label: '했어요 ✓', onPressed: onToggle),
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

/// 미션 카드 하나: 주차 제목 줄 · 큰 상세 칸 · 한 줄 목록
/// 이번 주를 다 해서 다음 주를 미리 하면 이번 주는 한 줄(✓)로 접고 다음 주를 보여 줌
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
  /// 목록에서 눌러 연 미션 (null이면 오늘의 미션)
  String? _openId;

  void _toggle(RoadmapMission m) {
    // 끝낸 미션은 닫고 다음 오늘의 미션으로, 취소는 그대로 열어 둠
    if (!m.done) setState(() => _openId = null);
    widget.store.toggleMission(m.id);
  }

  void _rotate() {
    setState(() => _openId = null);
    widget.store.rotateToday();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pick = widget.pick;
    final early = pick != null && pick.early;
    final shown = pick != null && pick.early ? pick.week : widget.week;
    final maxLevel = courageMax(store.situation.profile.courage);

    // 연 미션: 누른 것이 이 주차에 있으면 그것, 아니면 오늘의 미션
    final byId = {for (final m in shown.missions) m.id: m};
    final open = byId[_openId] ?? pick?.mission;
    final today = open != null && open.id == pick?.mission.id ? pick : null;

    // 고른 이유 · 순서 (규칙 · 학습)
    final ranked = store.ranked;
    final rankOf = {
      for (var i = 0; i < ranked.length; i++) ranked[i].mission.id: i,
    };
    final reasonOf = {for (final p in ranked) p.mission.id: p.reason};

    // 용기에 맞는 것 → 어려운 것 → 다 한 것, 같은 칸 안에선 규칙 · 학습 순서 (없으면 사전 순서)
    int tier(RoadmapMission m) => m.done ? 2 : (m.level > maxLevel ? 1 : 0);
    final rows = [
      for (final (i, m) in shown.missions.indexed)
        if (m.id != open?.id) (i, m),
    ]..sort((a, b) {
        final byTier = tier(a.$2).compareTo(tier(b.$2));
        if (byTier != 0) return byTier;
        final ra = rankOf[a.$2.id] ?? 1000 + a.$1;
        final rb = rankOf[b.$2.id] ?? 1000 + b.$1;
        return ra.compareTo(rb);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (early) ...[
          _WeekTitle(week: widget.week, done: true),
          const SizedBox(height: 12),
        ],
        _WeekTitle(week: shown, early: early),
        const SizedBox(height: 10),
        if (open != null) ...[
          _DetailCard(
            mission: open,
            brave: open.level > maxLevel,
            reason: today?.reason ?? (open.done ? null : reasonOf[open.id]),
            learned: today?.learned ?? false,
            today: today != null,
            onRotate: today != null && store.canRotate ? _rotate : null,
            onToggle: () => _toggle(open),
          ),
          const SizedBox(height: 8),
        ],
        Column(
          spacing: 8,
          children: [
            for (final (_, m) in rows)
              _CheckRow(
                mission: m,
                today: m.id == pick?.mission.id,
                brave: !m.done && m.level > maxLevel,
                onTap: () => setState(() => _openId = m.id),
              ),
          ],
        ),
      ],
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

/// 한 줄 미션: 체크 표시(보기만) · 이름 · 용기 ●●○ · ⇕ (누르면 위 상세 칸으로 열림)
/// 다 한 미션은 연분홍 바탕 · 흐린 글자, 오늘의 미션은 ✦, 어려운 미션은 ⚡
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.mission,
    required this.onTap,
    this.today = false,
    this.brave = false,
  });

  final RoadmapMission mission;
  final VoidCallback onTap;
  final bool today;
  final bool brave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final done = mission.done;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          color: done ? AppColors.roseSoft : AppColors.ivory,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // 완료 · 취소는 위 상세 칸에서만, 여기선 표시만 (누르면 줄과 같이 열림)
            CheckMark(checked: done, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mission.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: done ? AppColors.warmGray : AppColors.charcoal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (today && !done)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: AppColors.peach,
                ),
              ),
            if (brave)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.bolt, size: 14, color: AppColors.peach),
              ),
            for (var i = 1; i <= 3; i++)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Icon(
                  i <= mission.level ? Icons.circle : Icons.circle_outlined,
                  size: 6,
                  color: AppColors.warmGray,
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.unfold_more, size: 18, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}
