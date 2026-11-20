// 피그마 12번 화면 (대화 분석 결과)
// 데이터: ChatStore의 stats, comparison
// 위에서부터 결론 → 근거 → 할 일 → 자세한 숫자 순서
//   호감 신호: 점수 + 막대 + 점수를 올리고 내린 근거 (rules/scoring.dart)
//   다음 대화: 추천 방향 + 예시 멘트 (누르면 복사)
//   지금 사이: 대화로 본 친밀도 + 홈에서 관계 업데이트
//   대화 숫자: 4칸, 누르면 아래에 설명 (rules/features.dart 값)
//   달라진 점: 분석 기간 안 변화 + 지난 분석과 비교 (history 폴더)
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/main_shell.dart';
import '../../shared/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/progress_bar.dart';
import '../../shared/widgets/secondary_button.dart';
import 'chat_analyzer.dart';
import 'chat_stats.dart';
import 'chat_store.dart';
import 'history/chat_record.dart';
import 'rules/inference.dart';
import 'rules/scoring.dart';

class ConversationResultScreen extends StatelessWidget {
  const ConversationResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = ChatScope.of(context);
    final stats = store.stats;
    final insight = stats.insight;
    final canClear = !stats.isExample &&
        stats.record != null &&
        (store.comparison != null || store.isFirstAnalysis);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // 예시 결과일 때만 오른쪽에 '예시'
            AppHeader(label: stats.isExample ? '예시' : null),
            const SizedBox(height: 24),
            Text(stats.summary, style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(stats.period, style: text.bodySmall),
            const SizedBox(height: 20),
            Column(
              spacing: 12,
              children: [
                if (insight != null) ...[
                  _ScoreCard(interest: insight.interest),
                  _NextTalkCard(insight: insight),
                  _IntimacyCard(insight: insight),
                ] else
                  _Box(
                    child: Text(stats.hint, style: text.bodyMedium),
                  ),
                _StatGrid(stats: stats),
                _ChangeCard(
                  change: stats.change,
                  comparison: store.comparison,
                  isFirst: store.isFirstAnalysis,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: '대화 다시 입력하기',
              // 피그마 9번으로 돌아가기 (입력한 대화는 그대로 남아 있음)
              onPressed: () => Navigator.pop(context),
            ),
            if (canClear)
              Center(
                child: TextButton(
                  onPressed: () => _confirmClear(context, store),
                  child: Text('이 상대의 분석 기록 지우기', style: text.bodySmall),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, ChatStore store) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('이 상대의 지난 분석 숫자를 모두 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (ok == true) await store.clearHistory();
  }
}

// ---------- 카드 ----------

/// 결과 화면 카드 바탕 (기본 흰 바탕 + 테두리)
class _Box extends StatelessWidget {
  const _Box({required this.child, this.color = AppColors.warmWhite});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color == AppColors.warmWhite ? AppColors.border : color,
        ),
      ),
      child: child,
    );
  }
}

/// 카드 맨 위 작은 이름 ('호감 신호', '다음 대화 추천')
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelSmall);
}

/// 호감 신호: 큰 점수 + 막대 + 근거 (올린 것 3개, 내린 것 2개)
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.interest});

  final InterestScore interest;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plus = interest.plus.take(3).toList();
    final minus = interest.minus.take(2).toList();

    return _Box(
      color: AppColors.rose,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('호감 신호'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${interest.score}',
                style: const TextStyle(
                  fontSize: 40,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(width: 4),
              Text('/ 100', style: text.labelSmall),
              const Spacer(),
              _Pill(interest.level.label),
            ],
          ),
          const SizedBox(height: 12),
          ProgressBar(value: interest.score / 100),
          const SizedBox(height: 16),
          if (plus.isEmpty && minus.isEmpty)
            Text('아직 뚜렷한 신호가 없어요.', style: text.bodySmall)
          else
            Column(
              spacing: 6,
              children: [
                for (final s in plus) _SignalRow(s.label, up: true),
                for (final s in minus) _SignalRow(s.label, up: false),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            '대화 패턴으로 본 추정이에요 · 자료 ${interest.confidenceLabel}',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// 둥근 작은 표시 ('높음')
class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// 근거 한 줄 (+ 올린 근거, − 내린 근거)
class _SignalRow extends StatelessWidget {
  const _SignalRow(this.label, {required this.up});

  final String label;
  final bool up;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          up ? Icons.add_circle : Icons.remove_circle_outline,
          size: 16,
          color: up ? AppColors.peach : AppColors.warmGray,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
          ),
        ),
      ],
    );
  }
}

/// 다음 대화: 추천 방향 + 설명 + 예시 멘트 (누르면 복사)
class _NextTalkCard extends StatelessWidget {
  const _NextTalkCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _Box(
      color: AppColors.ivory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('다음 대화 추천'),
          const SizedBox(height: 6),
          Text(insight.strategy, style: text.titleMedium),
          const SizedBox(height: 6),
          Text(insight.hint, style: text.bodySmall),
          if (insight.lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('이렇게 보내 보세요 · 누르면 복사', style: text.labelSmall),
            const SizedBox(height: 8),
            Column(
              spacing: 8,
              children: [for (final line in insight.lines) _LineBubble(line)],
            ),
          ],
        ],
      ),
    );
  }
}

/// 예시 멘트 말풍선, 누르면 복사
class _LineBubble extends StatelessWidget {
  const _LineBubble(this.line);

  final String line;

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: line));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('복사했어요'),
          duration: Duration(milliseconds: 1500),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _copy(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          border: Border.all(color: AppColors.border),
          // 말풍선 모양 (왼쪽 아래만 덜 둥글게)
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                line,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 16, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}

/// 지금 사이: 대화로 본 친밀도 + 홈에서 관계 업데이트
class _IntimacyCard extends StatelessWidget {
  const _IntimacyCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('대화로 본 지금 사이'),
          const SizedBox(height: 6),
          Text(insight.intimacy.label, style: text.titleSmall),
          const SizedBox(height: 4),
          Text(insight.intimacyReason, style: text.bodySmall),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              // 홈 탭(피그마 7번)으로, 거기서 '관계 진척도 업데이트' → 11번
              onPressed: () => MainShell.tabIndex.value = 0,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.charcoal,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
              ),
              child: Text('다르면 홈에서 미션 다시 짜기 ›', style: text.titleSmall),
            ),
          ),
        ],
      ),
    );
  }
}

/// 숫자 칸 하나의 내용
class _Stat {
  const _Stat(this.label, this.value, this.description);

  final String label;
  final String value;

  /// 칸을 누르면 아래에 보이는 설명
  final String description;
}

/// 대화 숫자 4칸 (2 × 2), 칸을 누르면 아래에 설명, 한 번 더 누르면 닫힘
class _StatGrid extends StatefulWidget {
  const _StatGrid({required this.stats});

  final ChatStats stats;

  @override
  State<_StatGrid> createState() => _StatGridState();
}

class _StatGridState extends State<_StatGrid> {
  /// 설명을 펼친 칸 번호, 없으면 null
  int? _open;

  List<_Stat> get _items {
    final s = widget.stats;
    final reply = s.replyMinutes;
    return [
      _Stat(
        '보통 답장',
        reply == null ? '기록 없음' : formatMinutes(reply),
        '내 메시지 다음에 상대가 답하기까지 걸린 시간의 중간값이에요. '
            '하루 넘게 걸린 답은 새 대화로 보고 빼요.',
      ),
      _Stat(
        '답장 길이',
        '${s.avgLength}자',
        '상대 메시지 한 개의 평균 글자 수예요. 사진 · 이모티콘은 빼요.',
      ),
      _Stat(
        '하루 메시지',
        '${s.messagesPerDay}개',
        '나와 상대가 하루에 주고받은 메시지 수예요. 첫 메시지 날부터 마지막 메시지 날까지로 나눠요.',
      ),
      _Stat(
        '긍정 표현',
        '${s.warmPercent}%',
        '상대 메시지 중 웃음 · 고마움 · 칭찬 · 챙김 같은 따뜻한 표현이 담긴 비율이에요.',
      ),
    ];
  }

  void _toggle(int i) => setState(() => _open = _open == i ? null : i);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _items;
    final open = _open;

    Widget cell(int i) => Expanded(
          child: _StatCell(
            stat: items[i],
            selected: open == i,
            onTap: () => _toggle(i),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Row(
            children: [
              Text('대화 숫자', style: text.titleSmall),
              const Spacer(),
              Text('눌러서 설명 보기', style: text.labelSmall),
            ],
          ),
        ),
        Row(children: [cell(0), const SizedBox(width: 8), cell(1)]),
        const SizedBox(height: 8),
        Row(children: [cell(2), const SizedBox(width: 8), cell(3)]),
        // 고른 칸 설명 (부드럽게 열고 닫기)
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.ivory,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items[open].label} · ${items[open].description}',
                    style: text.bodySmall,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 숫자 칸 (작은 이름 + 큰 숫자), 고르면 분홍 바탕
class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.stat,
    required this.selected,
    required this.onTap,
  });

  final _Stat stat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.rose : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(stat.label, style: text.bodySmall)),
                Icon(
                  selected ? Icons.info : Icons.info_outline,
                  size: 14,
                  color: AppColors.warmGray,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stat.value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 달라진 점: 분석 기간 안 변화 + 지난 분석과 비교, 보여줄 게 없으면 안 그림
class _ChangeCard extends StatelessWidget {
  const _ChangeCard({
    required this.change,
    required this.comparison,
    required this.isFirst,
  });

  final String? change;
  final ChatComparison? comparison;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final change = this.change;
    final comparison = this.comparison;
    if (change == null && comparison == null && !isFirst) {
      return const SizedBox.shrink();
    }

    return _Box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          const _Label('달라진 점'),
          if (change != null)
            _ChangeRow(
              icon: Icons.trending_up,
              title: '이번 기간 안에서',
              lines: [change],
            ),
          if (comparison != null)
            _ChangeRow(
              icon: Icons.history,
              title: comparison.title,
              lines: comparison.lines,
            )
          else if (isFirst)
            const _ChangeRow(
              icon: Icons.history,
              title: '지난 분석과 비교',
              lines: ['이 상대와의 첫 분석이에요. 며칠 뒤 다시 분석하면 달라진 점을 보여드려요.'],
            ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.peach),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 4),
              Text(lines.join('\n'), style: text.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
