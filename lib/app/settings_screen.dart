// 설정 (머리글 '지민 ▾' 목록의 '설정', 하단 탭 없이 전체 화면, 왼쪽 위 되돌아가기)
//   지금 상대: 별명 · D-Day · 사유 · 지금 사이 · 만남 빈도 · 목표 · 말 높이 · 결과(피그마 17번) 고치기, 연결한 카톡 이름 끊기
//     고르는 창은 골라 두고 '확인'을 눌러야 저장 (_choose)
//   나: 용기 배터리 (손을 떼면 저장), 예시 멘트 웃음 표현 (analysis/chat/rules/tone.dart)
//   상대 관리: 라디오 버튼으로 골라 두고 '확인'으로 지금 상대 바꾸기 (_CrushList)
//     보관 · 지우기는 한 번 더 묻고, 꺼내기, 새 상대 (상대가 한 명뿐이면 보관 · 지우기 안 됨)
//   기록: 분석 기록 모아보기 · 학습한 내용 (맞춤 추천 켜기/끄기 · 학습 기록 지우기, learning_screen.dart)
import 'package:material_ui/material_ui.dart';

import '../analysis/chat/chat_store.dart';
import '../analysis/chat/history/chat_history_db.dart';
import '../analysis/chat/history/history_screen.dart';
import '../learning/learning_store.dart';
import '../onboarding/data/crush_store.dart';
import '../outcome/outcome_screen.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/panel_card.dart';
import '../shared/widgets/primary_button.dart';
import 'crush_switcher.dart';
import 'learning_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = CrushScope.of(context);
    final current = crushes.current;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(showCrush: false, onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('설정', style: text.headlineSmall),
            if (current != null) ...[
              const _SectionTitle('지금 상대'),
              PanelCard(
                child: Column(
                  children: [
                    _Row(
                      title: '별명',
                      value: current.nickname,
                      onTap: () => _editNickname(context, current),
                    ),
                    _Row(
                      title: 'D-Day',
                      value: '${_date(current.dDay)} · '
                          '${dDayLabel(daysUntil(current.dDay))}',
                      onTap: () => _editDDay(context, current),
                    ),
                    _Row(
                      title: '어떤 날',
                      value: current.reason,
                      onTap: () => _editReason(context, current),
                    ),
                    _Row(
                      title: '지금 사이',
                      value: current.intimacy.label,
                      onTap: () => _pick<Intimacy>(
                        context,
                        title: '지금은 어떤 사이인가요?',
                        options: [for (final v in Intimacy.values) (v, v.label)],
                        selected: current.intimacy,
                        onPicked: (v) => current.copyWith(intimacy: v),
                      ),
                    ),
                    _Row(
                      title: '만남 빈도',
                      value: '주 ${current.meetingsPerWeek}회',
                      onTap: () => _pick<int>(
                        context,
                        title: '일주일에 몇 번 만나나요?',
                        options: [for (var i = 0; i <= 7; i++) (i, '주 $i회')],
                        selected: current.meetingsPerWeek,
                        onPicked: (v) => current.copyWith(meetingsPerWeek: v),
                      ),
                    ),
                    _Row(
                      title: '목표',
                      value: current.goal.label,
                      onTap: () => _pick<Goal>(
                        context,
                        title: '어디까지 가까워지고 싶나요?',
                        options: [for (final v in Goal.values) (v, v.label)],
                        selected: current.goal,
                        onPicked: (v) => current.copyWith(goal: v),
                      ),
                    ),
                    _Row(
                      title: '말 높이',
                      value: current.speech.label,
                      onTap: () => _pick<SpeechLevel>(
                        context,
                        title: '예시 멘트를 어떤 말로 할까요?',
                        options: [for (final v in SpeechLevel.values) (v, v.label)],
                        selected: current.speech,
                        onPicked: (v) => current.copyWith(speech: v),
                      ),
                    ),
                    _Row(
                      title: '결과',
                      value: current.outcome?.label ?? '아직',
                      onTap: () => showOutcome(context, current),
                    ),
                    _ChatNames(crush: current),
                  ],
                ),
              ),
            ],
            const _SectionTitle('나'),
            PanelCard(
              child: Column(
                children: [
                  _CourageEditor(courage: crushes.courage),
                  const SizedBox(height: 8),
                  _Row(
                    title: '웃음 표현',
                    value: crushes.laughStyle.label,
                    onTap: () => _editLaugh(context, crushes.laughStyle),
                  ),
                ],
              ),
            ),
            const _SectionTitle('상대 관리'),
            const PanelCard(child: _CrushList()),
            const _SectionTitle('기록'),
            PanelCard(
              child: Column(
                children: [
                  _Row(
                    title: '분석 기록 모아보기',
                    value: '상대별 호감 신호 점수 변화',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _Row(
                    title: '학습한 내용',
                    value: _learningSummary(LearningScope.maybeOf(context)),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LearningScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- 지금 상대 고치기 ----------

  Future<void> _editNickname(BuildContext context, Crush crush) async {
    final name = await _askText(
      context,
      title: '별명',
      initial: crush.nickname,
      hint: '예: 지민',
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    await CrushScope.of(context).update(crush.copyWith(nickname: name));
  }

  Future<void> _editDDay(BuildContext context, Crush crush) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final picked = await showDatePicker(
      context: context,
      // 이미 지난 D-Day면 내일부터
      initialDate: crush.dDay.isBefore(tomorrow) ? tomorrow : crush.dDay,
      firstDate: tomorrow,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'D-Day 선택',
    );
    if (picked == null || !context.mounted) return;
    await CrushScope.of(context).update(crush.copyWith(dDay: picked));
  }

  /// 사유 태그 고르기, '기타'면 글자 입력
  Future<void> _editReason(BuildContext context, Crush crush) async {
    final tag = await _choose<String>(
      context,
      title: '어떤 날인가요?',
      options: [for (final tag in reasonTags) (tag, tag)],
      selected: reasonTagOf(crush.reason),
    );
    if (tag == null || !context.mounted) return;
    var reason = tag.$1;
    if (reason == otherReason) {
      final typed = await _askText(
        context,
        title: '어떤 날인가요?',
        initial: reasonTagOf(crush.reason) == otherReason ? crush.reason : '',
        hint: '예: 이사, 교환학생 출국',
      );
      if (typed == null || typed.trim().isEmpty || !context.mounted) return;
      reason = typed.trim();
    }
    await CrushScope.of(context).update(crush.copyWith(reason: reason));
  }

  /// 예시 멘트 웃음 표현 고르기 (나에 대한 값)
  Future<void> _editLaugh(BuildContext context, LaughStyle selected) async {
    final picked = await _choose<LaughStyle>(
      context,
      title: '예시 멘트에 웃음을 넣을까요?',
      options: [for (final v in LaughStyle.values) (v, v.label)],
      selected: selected,
    );
    if (picked == null || !context.mounted) return;
    await CrushScope.of(context).setLaughStyle(picked.$1);
  }

  /// 목록에서 하나 고르기 (지금 사이 · 만남 빈도 · 목표 · 말 높이), '확인'을 누르면 onPicked로 만든 상대로 저장
  Future<void> _pick<T>(
    BuildContext context, {
    required String title,
    required List<(T, String)> options,
    required T selected,
    required Crush Function(T value) onPicked,
  }) async {
    final picked = await _choose<T>(
      context,
      title: title,
      options: options,
      selected: selected,
    );
    if (picked == null || !context.mounted) return;
    await CrushScope.of(context).update(onPicked(picked.$1));
  }
}

// ---------- 상대 관리 ----------

/// 상대 목록: 라디오 버튼으로 골라 두고 '확인'을 누르면 지금 상대로 (고른 게 지금 상대와 다를 때만 '확인')
class _CrushList extends StatefulWidget {
  const _CrushList();

  @override
  State<_CrushList> createState() => _CrushListState();
}

class _CrushListState extends State<_CrushList> {
  /// 골라 둔 상대, 지금 상대 그대로면 null
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = CrushScope.of(context);
    final current = crushes.current;
    final active = crushes.active;
    // 고른 상대가 보관 · 지우기로 빠졌으면 무시
    final picked = active.any((c) => c.id == _picked) ? _picked : null;
    final checked = picked ?? current?.id;
    // 상대가 한 명뿐이면 보관 · 지우기 안 됨
    final canDrop = active.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in active)
          _CrushRow(
            crush: c,
            isCurrent: c.id == current?.id,
            checked: c.id == checked,
            canDrop: canDrop,
            onTap: () => setState(
              () => _picked = c.id == current?.id ? null : c.id,
            ),
          ),
        for (final c in crushes.archived)
          _CrushRow(crush: c, isCurrent: false, checked: false, canDrop: true),
        if (picked != null) ...[
          const SizedBox(height: 8),
          PrimaryButton(
            label: '확인',
            onPressed: () async {
              setState(() => _picked = null);
              await crushes.select(picked);
            },
          ),
          const SizedBox(height: 4),
        ],
        _Row(
          title: '+ 새 상대 추가',
          onTap: () => startNewCrush(context),
        ),
        if (!canDrop && active.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '상대가 한 명뿐이면 보관 · 지우기를 할 수 없어요.',
              style: text.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// 상대 한 줄: 라디오 버튼(누르면 골라 둠) · 이름 · D-Day 요약, 보관 · 꺼내기 · 지우기
class _CrushRow extends StatelessWidget {
  const _CrushRow({
    required this.crush,
    required this.isCurrent,
    required this.checked,
    required this.canDrop,
    this.onTap,
  });

  final Crush crush;

  /// 지금 상대 (이름 굵게)
  final bool isCurrent;

  /// 라디오 버튼 켜짐 (골라 둔 상대, 안 골랐으면 지금 상대)
  final bool checked;

  /// 누르면 골라 둠 (보관한 상대는 null)
  final VoidCallback? onTap;

  /// 보관 · 지우기 가능 (상대가 두 명 이상)
  final bool canDrop;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crushes = CrushScope.of(context);

    // 보관한 상대는 라디오 대신 보관 아이콘 ('꺼내기'로 돌려놓음)
    final selectable = !crush.archived;

    return InkWell(
      onTap: selectable ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              !selectable
                  ? Icons.inventory_2_outlined
                  : checked
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
              size: 20,
              color: AppColors.charcoal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crush.archived ? '${crush.nickname} · 보관' : crush.nickname,
                    style: isCurrent ? text.titleSmall : text.bodyMedium,
                  ),
                  Text(crushSummary(crush), style: text.bodySmall),
                ],
              ),
            ),
            if (crush.archived)
              _SmallButton('꺼내기', () => crushes.restore(crush.id)),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18, color: AppColors.warmGray),
              color: AppColors.warmWhite,
              enabled: canDrop || crush.archived,
              onSelected: (v) => v == 'archive'
                  ? _archive(context, crush)
                  : _remove(context, crush),
              itemBuilder: (_) => [
                if (!crush.archived)
                  const PopupMenuItem(value: 'archive', child: Text('보관하기')),
                const PopupMenuItem(value: 'delete', child: Text('지우기')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 보관하기 (한 번 더 묻고)
  Future<void> _archive(BuildContext context, Crush crush) async {
    final ok = await _confirm(
      context,
      '${crush.nickname}의 정보를 보관할까요?\n설정에서 언제든 꺼낼 수 있어요.',
      action: '보관하기',
      danger: false,
    );
    if (!ok || !context.mounted) return;
    await CrushScope.of(context).archive(crush.id);
  }

  /// 지우기 (그 상대에게 연결한 카톡 이름의 분석 기록까지)
  Future<void> _remove(BuildContext context, Crush crush) async {
    final ok = await _confirm(
      context,
      '${crush.nickname}의 정보와 대화 분석 기록을 모두 지울까요?\n되돌릴 수 없어요.',
      action: '지우기',
    );
    if (!ok || !context.mounted) return;
    final chat = ChatScope.of(context);
    final names = await CrushScope.of(context).remove(crush.id);
    try {
      for (final name in names) {
        await ChatHistoryDb.clear(name);
      }
    } catch (e) {
      debugPrint('분석 기록 지우기 실패: $e');
    }
    // 마지막 분석 결과가 이 상대 대화였으면 예시로
    if (names.contains(chat.stats.record?.partner)) chat.showExample();
  }
}

/// 연결한 카톡 이름 (✕로 끊기)
class _ChatNames extends StatelessWidget {
  const _ChatNames({required this.crush});

  final Crush crush;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연결한 카톡 이름', style: text.titleSmall),
          const SizedBox(height: 6),
          if (crush.chatNames.isEmpty)
            Text('아직 없어요. 대화 분석 결과에서 연결할 수 있어요.', style: text.bodySmall)
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in crush.chatNames)
                  InputChip(
                    label: Text(name, style: text.bodySmall),
                    backgroundColor: AppColors.warmWhite,
                    side: const BorderSide(color: AppColors.border),
                    onDeleted: () =>
                        CrushScope.of(context).unlinkChatName(crush.id, name),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 용기 배터리 슬라이더 (손을 떼면 저장)
class _CourageEditor extends StatefulWidget {
  const _CourageEditor({required this.courage});

  final int courage;

  @override
  State<_CourageEditor> createState() => _CourageEditorState();
}

class _CourageEditorState extends State<_CourageEditor> {
  late double _value = widget.courage.toDouble();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = CourageLevel.of(_value.round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('오늘의 용기', style: text.titleSmall),
            const Spacer(),
            Text('${_value.round()}%', style: text.titleSmall),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Slider(
            value: _value,
            max: 100,
            divisions: 10,
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: (v) => CrushScope.of(context).setCourage(v.round()),
          ),
        ),
        Text(level.label, style: text.bodySmall),
      ],
    );
  }
}

// ---------- 작은 위젯 · 도우미 ----------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// 설정 한 줄 (제목 + 지금 값, 누르면 고치기)
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.onTap,
    this.value,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final value = this.value;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleSmall),
                  if (value != null) Text(value, style: text.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.warmGray),
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.charcoal,
        textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

/// '기록 12개 · 켬', 학습이 없으면 null
String? _learningSummary(LearningStore? learning) => learning == null
    ? null
    : '기록 ${learning.events().length}개 · ${learning.enabled ? '켬' : '끔'}';

String _date(DateTime d) =>
    '${d.year}. ${d.month.toString().padLeft(2, '0')}. '
    '${d.day.toString().padLeft(2, '0')}.';

/// 글자 한 줄 묻기, 취소하면 null
Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.warmWhite,
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: nicknameMaxLength,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(dialog, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, controller.text),
          child: const Text('저장'),
        ),
      ],
    ),
  );
  // controller는 닫히는 동안에도 입력칸이 쓰고 있어서 바로 dispose하지 않음 (가비지 컬렉션에 맡김)
}

/// 보관 · 지우기 전 한 번 더 묻기 (danger면 버튼 글자를 빨갛게)
Future<bool> _confirm(
  BuildContext context,
  String message, {
  required String action,
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: AppColors.warmWhite,
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialog, true),
          style: danger
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 목록에서 하나 골라 두고 '확인'을 눌러야 정해지는 창, 취소하면 null
/// 고른 값은 (값,)으로 감싸서 돌려줌 (값이 null일 수도 있는 T와 '취소'를 구분)
Future<(T,)?> _choose<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
}) {
  var picked = selected;
  return showDialog<(T,)>(
    context: context,
    builder: (dialog) => StatefulBuilder(
      builder: (_, setDialogState) => AlertDialog(
        backgroundColor: AppColors.warmWhite,
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (value, label) in options)
                _RadioRow(
                  label: label,
                  checked: value == picked,
                  onTap: () => setDialogState(() => picked = value),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, (picked,)),
            child: const Text('확인'),
          ),
        ],
      ),
    ),
  );
}

/// 고르는 창 한 줄 (라디오 버튼 + 글자)
class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(
              checked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 20,
              color: AppColors.charcoal,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: checked
                    ? Theme.of(context).textTheme.titleSmall
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
