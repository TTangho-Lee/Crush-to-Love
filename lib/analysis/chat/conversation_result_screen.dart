// 피그마 12번 화면 (대화 분석 결과)
// 데이터: ChatStore의 stats, comparison
// 위에서부터 결론 → 근거 → 할 일 → 자세한 숫자 순서
//   호감 신호: 점수 + 막대 + 점수를 올리고 내린 근거 (rules/scoring.dart)
//   다음 대화: 추천 방향 + 자주 나온 이야기 + 예시 멘트 3개 (누르면 복사, 복사 아이콘으로만 표시)
//     멘트 웃음(ㅋㅋ · ㅎㅎ) · 말 높이는 내 말투에 맞춤, 설정에서 고르면 그 값 (rules/tone.dart)
//     '↻ 다른 추천 보기': 같은 방향으로 다른 멘트, 약속 방향이면 '데이트 준비하기 →' (주제에 맞는 장소를 미리 고름)
//     맞춤 추천을 켜면 멘트 순서를 학습 순서로 (line_learning.dart, 이 화면이 열려 있는 동안 고정), 복사하면 기록
//   지금 사이: 대화로 본 친밀도 + 홈에서 관계 업데이트
//   대화 숫자: 4칸, 누르면 아래에 설명 (ⓘ 아이콘으로만 표시, rules/features.dart 값)
//   달라진 점: 분석 기간 안 변화 + 지난 분석과 비교 (history 폴더)
//   카톡 이름이 아직 어느 상대에도 연결 안 됐으면 맨 위에 '이 대화 상대는 누구예요?' (상대를 고르면 다음부터 안 물음, '분석만'은 이번 결과에서만 닫음)
//     골라 두고 '확인'을 누르면 연결, 고른 상대가 지금 상대가 됨, 별명과 카톡 이름이 똑같으면 묻지 않고 연결 (CrushStore.followChat)
//   맨 아래 '분석 기록 모아보기' (history/history_screen.dart)
// 기호로 알 수 있는 건 글자로 따로 안 씀 (복사 · 설명 · 증감은 아이콘 · +/- · →)
import 'package:material_ui/material_ui.dart';

import '../../app/crush_switcher.dart';
import '../../app/main_shell.dart';
import '../../learning/learning_store.dart';
import '../../onboarding/data/crush_store.dart';
import '../../shared/app_colors.dart';
import '../../shared/models.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/copy_bubble.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/progress_bar.dart';
import '../date/date_guide_rules.dart';
import '../date/date_store.dart';
import 'chat_analyzer.dart';
import 'chat_stats.dart';
import 'chat_store.dart';
import 'history/chat_record.dart';
import 'history/history_screen.dart';
import 'line_learning.dart';
import 'rules/inference.dart';
import 'rules/lexicon.dart';
import 'rules/lines.dart';
import 'rules/scoring.dart';
import 'rules/tone.dart';

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
    // 이 카톡 이름을 어느 상대로 볼지 아직 안 정했으면 물어봄
    final crushes = CrushScope.maybeOf(context);
    final partner = stats.record?.partner;
    final askLink = !stats.isExample &&
        crushes != null &&
        crushes.active.isNotEmpty &&
        partner != null &&
        crushes.crushForChatName(partner) == null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // 예시 결과일 때만 오른쪽에 '예시'
            // 오른쪽 위 되돌아가기 → 9번 (입력한 대화는 그대로)
            AppHeader(
              label: stats.isExample ? '예시' : null,
              onBack: () => Navigator.pop(context),
            ),
            const SizedBox(height: 24),
            Text(stats.summary, style: text.headlineSmall),
            const SizedBox(height: 6),
            Text(stats.period, style: text.bodySmall),
            const SizedBox(height: 20),
            Column(
              spacing: 12,
              children: [
                // askLink가 true면 partner · crushes는 null이 아님 (Dart가 알아서 좁혀 줌)
                if (askLink) _LinkCard(partner: partner, crushes: crushes),
                if (insight != null) ...[
                  _ScoreCard(interest: insight.interest),
                  // 새 분석이면 '다른 추천 보기' 횟수를 처음부터
                  _NextTalkCard(key: ObjectKey(insight), insight: insight),
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
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                // 하단 탭 없이 전체 화면
                onPressed: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                ),
                child: Text('분석 기록 모아보기 ›', style: text.titleSmall),
              ),
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

/// '이 대화 상대(지민)는 누구예요?' [앱의 상대들] [+ 새 상대] [분석만] → '확인'
/// 골라 두고 '확인'을 눌러야 정해짐, 상대를 고르면 연결하고 그 상대가 지금 상대가 됨
/// 다음 분석부터 그 상대를 자동으로 고름, '분석만'은 이번 결과에서만 카드를 닫음 (다음 분석 때 다시 물음)
class _LinkCard extends StatefulWidget {
  const _LinkCard({required this.partner, required this.crushes});

  /// 카톡 이름
  final String partner;
  final CrushStore crushes;

  @override
  State<_LinkCard> createState() => _LinkCardState();
}

/// 고른 것 (상대 · 새 상대 · 분석만)
enum _Link { crush, newCrush, skip }

class _LinkCardState extends State<_LinkCard> {
  /// 고른 것, 상대면 그 상대 id (아직 안 골랐으면 null)
  (_Link, int?)? _picked;

  /// '분석만'으로 이번 결과에서 닫았으면 true
  bool _closed = false;

  Future<void> _confirm() async {
    final picked = _picked;
    if (picked == null) return;
    final crushes = widget.crushes;
    final partner = widget.partner;
    switch (picked) {
      case (_Link.crush, final int id):
        await crushes.linkChatName(id, partner);
        if (id != crushes.current?.id) await crushes.select(id);
      case (_Link.newCrush, _):
        await startNewCrush(context, chatName: partner);
      case (_Link.skip, _):
        setState(() => _closed = true);
      case (_Link.crush, null):
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_closed) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;

    Widget choice(String label, (_Link, int?) value) {
      final selected = _picked == value;
      return OutlinedButton(
        onPressed: () => setState(() => _picked = value),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? AppColors.rose : AppColors.warmWhite,
          foregroundColor: AppColors.charcoal,
          side: BorderSide(color: selected ? AppColors.peach : AppColors.border),
          textStyle: text.titleSmall?.copyWith(fontSize: 12),
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      );
    }

    return _Box(
      color: AppColors.roseSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("이 대화 상대 '${widget.partner}'는 누구예요?", style: text.titleSmall),
          const SizedBox(height: 4),
          Text('연결해 두면 다음 분석부터 상대를 자동으로 골라요.', style: text.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in widget.crushes.active)
                choice(c.nickname, (_Link.crush, c.id)),
              choice('+ 새 상대', (_Link.newCrush, null)),
              choice('분석만', (_Link.skip, null)),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: '확인',
            onPressed: _picked == null ? null : _confirm,
          ),
        ],
      ),
    );
  }
}

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

/// 데이트 준비로 이어지는 방향 (약속 제안 · 구체화)
const _toDateApproaches = {Approach.invite, Approach.fixPlan};

/// 다음 대화: 추천 방향 + 설명 + 예시 멘트 (누르면 복사) + 다른 추천 · 데이트 준비
class _NextTalkCard extends StatefulWidget {
  const _NextTalkCard({super.key, required this.insight});

  final Insight insight;

  @override
  State<_NextTalkCard> createState() => _NextTalkCardState();
}

class _NextTalkCardState extends State<_NextTalkCard> {
  /// '다른 추천 보기'를 누른 횟수
  int _round = 0;

  /// 학습 순서 (맞춤 추천을 켰을 때만, 말 높이가 바뀌면 다시)
  LineDeck? _deck;
  bool? _deckFormal;

  /// 이번 화면에서 복사해서 기록한 멘트 (화면마다 한 번)
  final Set<String> _copied = {};

  /// 학습 순서 멘트 (사전 문장, 말투 입힌 글자), 학습을 안 쓰면 null
  List<(DeckLine, String)>? _learnedLines(
    LearningStore? learning, {
    required bool formal,
    required Tone tone,
  }) {
    final insight = widget.insight;
    final approach = insight.approach;
    final stats = ChatScope.of(context).stats;
    if (learning == null ||
        !learning.enabled ||
        approach == null ||
        stats.isExample) {
      return null;
    }
    if (_deck == null || _deckFormal != formal) {
      _deck = LineDeck.build(
        learning,
        approach: approach,
        seed: insight.seed,
        now: DateTime.now(),
        topic: insight.topic,
        formal: formal,
        interest: insight.interest.level.name,
        shortRate: stats.features?.them.rate(MessageTag.shortReply) ?? 0,
      );
      _deckFormal = formal;
    }
    final shown = _deck!.round(_round);
    final toned = applyToneEach(
      [for (final l in shown) l.text],
      tone,
      seed: insight.seed + _round,
    );
    return [
      for (var i = 0; i < shown.length; i++)
        if (toned[i].isNotEmpty) (shown[i], toned[i]),
    ];
  }

  /// 복사한 멘트 기록 (화면마다 한 줄에 한 번)
  void _onCopied(LearningStore learning, DeckLine line, int crushId) {
    final deck = _deck;
    if (deck == null || !_copied.add(line.text)) return;
    recordCopy(learning, deck, line, crushId: crushId);
  }

  /// 데이트 탭으로, 자주 나온 주제에 맞는 장소가 있으면 미리 고름
  void _openDate() {
    final topic = widget.insight.topic;
    final place = topic == null ? null : placeForTopic(topic);
    if (place != null) {
      final date = DateScope.of(context);
      date.choose(date.choice.copyWith(place: place));
    }
    MainShell.tabIndex.value = 3;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final insight = widget.insight;
    // 설정에서 고른 이 대화 상대의 말 높이 · 내 웃음 표현 (대화에 맞춤이면 대화 기준)
    final crushes = CrushScope.maybeOf(context);
    final partner = ChatScope.of(context).stats.record?.partner;
    final crush = crushes == null || partner == null
        ? null
        : crushes.crushForChatName(partner) ??
            (crushes.chatBelongsToCurrent(partner) ? crushes.current : null);
    final formal = crush?.speech.formalOr(insight.formal) ?? insight.formal;
    final tone = insight.tone.withStyle(crushes?.laughStyle ?? LaughStyle.auto);
    final learning = LearningScope.maybeOf(context);
    final learned = _learnedLines(learning, formal: formal, tone: tone);
    final lines = learned == null
        ? insight.linesAt(_round, formal: formal, tone: tone)
        : [for (final (_, text) in learned) text];
    final canShuffle = insight.approach != null && lines.isNotEmpty;
    final toDate = _toDateApproaches.contains(insight.approach);

    final buttonStyle = TextButton.styleFrom(
      foregroundColor: AppColors.charcoal,
      textStyle: text.titleSmall?.copyWith(fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      minimumSize: const Size(0, 32),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

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
          // 예시 멘트가 이 주제에 맞춰져 있음 (rules/topics.dart)
          if (insight.topics.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '자주 나온 이야기: ${insight.topics.join(', ')}',
              style: text.labelSmall,
            ),
          ],
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('이렇게 보내 보세요', style: text.labelSmall),
            const SizedBox(height: 8),
            Column(
              spacing: 8,
              children: [
                if (learned != null && learning != null)
                  for (final (raw, text) in learned)
                    CopyBubble(
                      text,
                      onCopied: () =>
                          _onCopied(learning, raw, crush?.id ?? 0),
                    )
                else
                  for (final line in lines) CopyBubble(line),
              ],
            ),
          ],
          if (canShuffle || toDate) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (canShuffle)
                  TextButton(
                    onPressed: () => setState(() {
                      _round++;
                      _copied.clear();
                    }),
                    style: buttonStyle,
                    child: const Text('↻ 다른 추천 보기'),
                  ),
                const Spacer(),
                if (toDate)
                  TextButton(
                    onPressed: _openDate,
                    style: buttonStyle,
                    child: const Text('데이트 준비하기 →'),
                  ),
              ],
            ),
          ],
        ],
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
        reply == null ? '-' : formatMinutes(reply),
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
          child: Text('대화 숫자', style: text.titleSmall),
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
                  // 고른 칸이 분홍이라 이름은 다시 안 붙임
                  child: Text(items[open].description, style: text.bodySmall),
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
              title: '분석 기간 앞쪽 → 뒤쪽',
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
              lines: ['첫 분석이에요. 며칠 뒤 다시 분석하면 비교해 드려요.'],
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
