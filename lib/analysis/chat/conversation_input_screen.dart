// 피그마 9번 화면 (우리 대화 돌아보기)
// 세 단계로 나눠서 위에서부터 채우면 되게
//   ① 대화 넣기: 'txt 파일 불러오기' 또는 직접 붙여넣기 (안드로이드는 카톡 공유로도 들어옴)
//   ② 분석 기간: 하루 · 3일 · 1주 · 2주 · 한 달 중 하나 (_ranges), 바꾸면 불러온 대화도 다시 잘라 넣음
//   ③ 대화 속 사람: 내 이름 · 짝사랑 상대 고르기 (대화에 나온 이름 중에서)
//      기본값: 내 이름은 추측 (1:1 파일 첫 줄 → '나' → 둘이면 먼저 말한 사람)
//              상대는 앱의 상대에 연결해 둔 카톡 이름(지금 상대 먼저) → 둘이면 나머지 한 명
//      단톡방은 상대를 꼭 골라야 함, 고른 사람과 나의 메시지만 분석
// 입력칸 아래 한 줄로 지금 넣은 대화 상태 (메시지 수 · 사람 수, 형식 오류)
// 카톡에서 가져오는 법 (import_guide.dart): ① 제목 오른쪽 '? 가져오는 법'을 누르면 아래에서 올라옴
// 기호로 알 수 있는 건 글자로 따로 안 씀 (▾ 고르기, ✓ 읽음, ~ 기간)
// '대화 분석하기'를 눌러야 분석, 성공하면 12번, 실패하면 이유를 버튼 위에 표시
//   다른 상대에 연결된 카톡 이름이면 지금 상대도 그 상대로 바꿈 (CrushStore.followChat)
// 몇 년치 파일도 멈추지 않게
//   파일 · 공유는 최근 keepDays(31)일만 남기고 읽음 (chat_parser.dart)
//   대화 읽기는 백그라운드(compute)에서 한 번만 하고 읽은 결과를 다시 씀
//   직접 붙여넣은 대화도 입력이 멈추면 잠시 뒤 읽어서 상태 · 이름 목록을 채움
import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../onboarding/data/crush_store.dart';
import '../../shared/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/panel_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'chat_analyzer.dart';
import 'chat_store.dart';
import 'conversation_result_screen.dart';
import 'import_guide.dart';

/// 분석 기간 칩 (한 달은 keepDays 안이 되게 30일)
const List<(Duration, String)> _ranges = [
  (Duration(days: 1), '하루'),
  (Duration(days: 3), '3일'),
  (Duration(days: 7), '1주'),
  (Duration(days: 14), '2주'),
  (Duration(days: 30), '한 달'),
];

/// 직접 붙여넣은 대화를 읽기 전 기다리는 시간 (입력 중엔 안 읽음)
const _typingPause = Duration(milliseconds: 600);

/// 입력칸 아래 상태 한 줄
typedef _Status = ({IconData icon, String text, bool warn});

/// txt 파일 → 최근 keepDays일만 읽은 대화 (compute로 백그라운드에서)
ParsedChat _readFile(List<int> bytes) =>
    ParsedChat.parse(dropOldLines(utf8.decode(bytes, allowMalformed: true)));

/// 공유받은 글자 → 최근 keepDays일만 읽은 대화 (compute로 백그라운드에서)
ParsedChat _readShared(String text) => ParsedChat.parse(dropOldLines(text));

class ConversationInputScreen extends StatefulWidget {
  const ConversationInputScreen({super.key});

  @override
  State<ConversationInputScreen> createState() =>
      _ConversationInputScreenState();
}

class _ConversationInputScreenState extends State<ConversationInputScreen> {
  final _chatController = TextEditingController();

  /// 분석 기간: 지금부터 이만큼 전까지 (_ranges 중 하나)
  Duration _range = defaultRange;

  /// 파일 · 공유로 받아 읽어 둔 전체 대화 (기간을 바꾸면 여기서 다시 자름), 직접 고치면 null
  ParsedChat? _source;

  /// 마지막으로 입력칸에 넣은 글자 (직접 고쳤는지 확인용)
  String? _filledText;

  /// 직접 붙여넣거나 고친 대화를 읽은 결과, _typedText가 그 글자
  ParsedChat? _typed;
  String? _typedText;

  /// 입력칸의 마지막 글자 (커서만 움직였을 때 무시하려고)
  String _lastText = '';

  /// 입력이 멈추면 _typingPause 뒤에 읽기
  Timer? _typingTimer;

  /// 입력칸 아래 상태, 대화가 없으면 null
  _Status? _status;

  /// 분석 기간 안 대화에 나온 이름 (메시지 많은 순), '내 이름' · '짝사랑 상대' 목록
  List<String> _senders = const [];

  /// 고른 내 이름, 아직 없으면 null
  String? _myName;

  /// 고른 짝사랑 상대, 아직 없으면 null
  String? _partner;

  /// 짝사랑 상대 목록 (내 이름으로 고른 사람 빼고)
  List<String> get _others => [
        for (final name in _senders)
          if (name != _myName) name,
      ];

  /// 세 명 이상 = 단톡방
  bool get _isGroup => _senders.length > 2;

  /// 분석 실패 이유, 없으면 null
  String? _error;

  /// 공유받은 대화 처리를 이미 예약했으면 true (중복 방지)
  bool _sharedScheduled = false;

  /// 대화를 읽거나 분석하는 중이면 true (버튼 잠금)
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onChatChanged);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  // ---------- 대화 읽기 ----------

  /// 입력칸이 바뀌면 불러온 원본과 연결을 끊고 (기간을 바꿔도 덮어쓰지 않게), 잠시 뒤 다시 읽기
  void _onChatChanged() {
    final text = _chatController.text;
    if (text == _lastText) return; // 커서만 움직임
    _lastText = text;
    if (text == _filledText) return; // 불러온 대화를 넣은 것
    _source = null;
    _typed = null;
    _typedText = null;
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingPause, () => _readTyped(text));
  }

  /// 직접 넣은 대화 읽기 → 상태 · 이름 목록 갱신
  Future<void> _readTyped(String text) async {
    final parsed = text.trim().isEmpty
        ? null
        : await compute<String, ParsedChat>(ParsedChat.parse, text);
    if (!mounted || _chatController.text != text) return; // 그새 또 바뀜
    _typed = parsed;
    _typedText = text;
    _show(parsed);
  }

  /// 파일 · 공유로 받은 대화를 백그라운드에서 읽어 두고(reading) 기간만큼 입력칸에 넣기
  Future<void> _fillChat(Future<ParsedChat> reading) async {
    _typingTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
      _status = (icon: Icons.hourglass_empty, text: '읽는 중…', warn: false);
    });
    final ParsedChat parsed;
    try {
      parsed = await reading;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = null;
        _error = '대화를 읽지 못했어요. 다시 시도해 주세요.';
      });
      return;
    }
    if (!mounted) return;
    _source = parsed;
    // 새 대화라 이름은 다시 추측
    _myName = null;
    _partner = null;
    _busy = false;
    _applyRange();
  }

  /// 읽어 둔 대화를 지금 기간으로 잘라 입력칸에 (없으면 아무것도 안 함)
  void _applyRange() {
    final source = _source;
    if (source == null) return;
    final trimmed = source.keepRecent(range: _range);
    _filledText = trimmed;
    _chatController.text = trimmed;
    _show(source);
  }

  /// 읽은 대화로 상태 한 줄 · 이름 목록 갱신 (분석 기간 안 메시지 기준)
  void _show(ParsedChat? chat) {
    final from = DateTime.now().subtract(_range);
    final senders = chat?.senders(from: from) ?? const <String>[];
    final count = chat == null
        ? 0
        : chat.messages.where((m) => !m.time.isBefore(from)).length;
    final period = rangeLabel(_range);

    final _Status? status = chat == null
        ? null
        : chat.messages.isEmpty
            ? (
                icon: Icons.error_outline,
                text: "카톡 내보내기 형식이 아니에요. '[이름] [오후 1:00] 내용' 형식인지 확인해 주세요.",
                warn: true,
              )
            : count == 0
                ? (
                    icon: Icons.info_outline,
                    text: '최근 $period 안에는 대화가 없어요. 분석 기간을 늘려 보세요.',
                    warn: true,
                  )
                : (
                    icon: Icons.check_circle_outline,
                    text: '최근 $period · 메시지 $count개 · ${senders.length}명',
                    warn: false,
                  );

    setState(() {
      _status = status;
      _senders = senders;
      _error = null;
      // 고른 이름이 목록에 없으면 기본값으로
      if (!senders.contains(_myName)) {
        final guessed = chat?.guessMe();
        _myName = senders.contains(guessed) ? guessed : null;
      }
      _fixPartner();
    });
  }

  /// 상대가 비었거나 나와 같으면: 연결해 둔 카톡 이름 → 둘이면 나머지 한 명 → 단톡방이면 비움
  void _fixPartner() {
    final others = _others;
    if (others.contains(_partner)) return;
    _partner = _linkedPartner(others) ??
        (others.length == 1 ? others.first : null);
  }

  /// 앱의 상대에 연결해 둔 카톡 이름 중 대화에 있는 사람 (지금 상대 먼저), 없으면 null
  String? _linkedPartner(List<String> others) {
    final crushes = CrushScope.read(context);
    if (crushes == null) return null;
    final current = crushes.current;
    for (final c in [?current, ...crushes.active]) {
      for (final name in c.chatNames) {
        if (others.contains(name)) return name;
      }
    }
    return null;
  }

  // ---------- 버튼 ----------

  /// 'txt 파일 불러오기': 고른 파일 내용을 입력칸에
  Future<void> _pickFile() async {
    final List<int> bytes;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt'],
      );
      if (files.isEmpty) return; // 취소
      bytes = await files.first.readAsBytes();
    } catch (e) {
      if (mounted) setState(() => _error = '파일을 열지 못했어요. 다시 골라 주세요.');
      return;
    }
    if (!mounted) return;
    await _fillChat(compute(_readFile, bytes));
  }

  /// 안드로이드 공유로 받은 대화: 열려 있던 결과 화면을 닫고 입력칸에
  void _fillShared() {
    _sharedScheduled = false;
    if (!mounted) return;
    final chat = ChatScope.of(context).takePendingText();
    if (chat == null) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    _fillChat(compute(_readShared, chat));
  }

  void _setRange(Duration range) {
    setState(() => _range = range);
    if (_source != null) {
      _applyRange();
    } else if (_typed != null) {
      _show(_typed);
    }
  }

  void _pickMyName(String? name) {
    setState(() {
      _myName = name;
      _fixPartner();
    });
  }

  /// '대화 분석하기'
  Future<void> _analyze() async {
    final chat = _chatController.text;
    if (chat.trim().isEmpty) {
      setState(() => _error = '대화를 붙여넣거나 txt 파일을 불러와 주세요.');
      return;
    }
    // 이름 목록이 있으면 둘 다 골라야 함 (없으면 분석기가 추측)
    if (_senders.isNotEmpty && (_myName == null || _partner == null)) {
      setState(() {
        _error = _myName == null
            ? '내 이름을 골라 주세요.'
            : _others.isEmpty
                ? '분석 기간 안에 상대 메시지가 없어요. 기간을 늘려 보세요.'
                : '짝사랑 상대를 골라 주세요.';
      });
      return;
    }
    final store = ChatScope.of(context);
    _typingTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });

    ParsedChat? parsed;
    String? error;
    try {
      // 이미 읽어 둔 결과가 있으면 그대로, 없으면 백그라운드에서 읽기
      final typed = _typedText == chat ? _typed : null;
      final read = _source ??
          typed ??
          await compute<String, ParsedChat>(ParsedChat.parse, chat);
      parsed = read;
      if (_source == null) {
        _typed = read;
        _typedText = chat;
      }
      store.analyze(
        read,
        myName: _myName,
        partnerName: _partner,
        range: _range,
      );
    } on ChatAnalysisError catch (e) {
      error = e.message;
    } catch (_) {
      error = '분석하다 문제가 생겼어요. 다시 시도해 주세요.';
    }
    if (!mounted) return;

    if (error != null) {
      // 이름 문제일 수 있으니 분석 기간 안 대화에 나온 이름으로 목록 갱신
      if (parsed != null) _show(parsed);
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    setState(() => _busy = false);
    // 다른 상대에 연결된 대화면 지금 상대를 그 상대로 (머리글 '서연 ▾'로 바뀜)
    final partner = store.stats.record?.partner;
    final crushes = CrushScope.read(context);
    if (partner != null && crushes != null) {
      await crushes.followChat(partner);
      if (!mounted) return;
    }
    // 피그마 12번으로 (대화 탭 안에서 이동, 하단 탭 유지)
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationResultScreen()),
    );
  }

  // ---------- 화면 ----------

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final error = _error;
    final status = _status;

    // 공유받은 대화가 들어오면 화면을 다 그린 뒤 입력칸에
    if (ChatScope.of(context).hasPendingText && !_sharedScheduled) {
      _sharedScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fillShared());
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('우리 대화 돌아보기', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('카톡 대화로 답장 패턴과 호감 신호를 확인해요.', style: text.bodySmall),
            const SizedBox(height: 20),
            _Step(
              number: 1,
              title: '대화 넣기',
              trailing: TextButton.icon(
                onPressed: () => showImportGuide(context),
                icon: const Icon(Icons.help_outline, size: 15),
                label: const Text('가져오는 법'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.warmGray,
                  textStyle: text.labelSmall,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FileButton(onPressed: _busy ? null : _pickFile),
                  const SizedBox(height: 10),
                  Text('또는 붙여넣기', style: text.bodySmall),
                  const SizedBox(height: 6),
                  // 긴 대화도 한눈에 보이게 작은 글자로 여러 줄
                  AppTextField(
                    hint: '[지민] [오후 1:00] 오늘 수업 어땠어?',
                    maxLines: 10,
                    fontSize: 11,
                    controller: _chatController,
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    _StatusLine(status),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Step(
              number: 2,
              title: '분석 기간',
              // 지금부터 고른 기간 전까지
              child: Row(
                spacing: 6,
                children: [
                  for (final (range, label) in _ranges)
                    Expanded(
                      child: _RangeChip(
                        label: label,
                        selected: range == _range,
                        onTap: () => _setRange(range),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _Step(
              number: 3,
              title: '대화 속 사람',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Labeled(
                          label: '내 이름',
                          child: _Dropdown<String?>(
                            value: _myName,
                            expanded: true,
                            hint: _senders.isEmpty ? '-' : '선택',
                            items: [for (final name in _senders) (name, name)],
                            onChanged: _senders.isEmpty ? null : _pickMyName,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Labeled(
                          label: '짝사랑 상대',
                          child: _Dropdown<String?>(
                            value: _partner,
                            expanded: true,
                            hint: _senders.isEmpty ? '-' : '선택',
                            items: [for (final name in _others) (name, name)],
                            onChanged: _others.isEmpty
                                ? null
                                : (name) => setState(() => _partner = name),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isGroup) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.groups_outlined,
                          size: 15,
                          color: AppColors.warmGray,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '단톡방 · 고른 상대와 내 메시지만 분석해요',
                            style: text.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              _ErrorBox(error),
            ],
            const SizedBox(height: 16),
            PrimaryButton(
              label: _busy ? '분석하는 중…' : '대화 분석하기',
              onPressed: _busy ? null : _analyze,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: AppColors.warmGray),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '대화는 이 기기에서만 분석하고, 내용은 저장하지 않아요.',
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- 작은 위젯 ----------

/// 번호가 붙은 단계 상자 ('① 대화 넣기')
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.child,
    this.trailing,
  });

  final int number;
  final String title;
  final Widget child;

  /// 제목 줄 오른쪽 끝 (예: '가져오는 법'), 없으면 null
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.peach,
                  shape: BoxShape.circle,
                ),
                child: Text('$number', style: text.titleSmall?.copyWith(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              Text(title, style: text.titleSmall),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// 작은 이름 + 아래 입력 칸 ('내 이름' + 스피너)
class _Labeled extends StatelessWidget {
  const _Labeled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

/// 'txt 파일 불러오기' 버튼 (흰 바탕 테두리, 아이콘)
class _FileButton extends StatelessWidget {
  const _FileButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.upload_file, size: 18),
        label: const Text('txt 파일 불러오기'),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.warmWhite,
          foregroundColor: AppColors.charcoal,
          disabledForegroundColor: AppColors.warmGray,
          side: const BorderSide(color: AppColors.border),
          textStyle: Theme.of(context).textTheme.titleSmall,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// 입력칸 아래 상태 한 줄 (아이콘 + 글자), 문제가 있으면 빨간 글자
class _StatusLine extends StatelessWidget {
  const _StatusLine(this.status);

  final _Status status;

  @override
  Widget build(BuildContext context) {
    final color = status.warn
        ? Theme.of(context).colorScheme.error
        : AppColors.warmGray;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(status.icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            status.text,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

/// 분석 실패 이유 상자
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.roseSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// 분석 기간 칩, 고르면 분홍 바탕 (칸이 좁으면 줄을 바꾸지 않고 글자를 조금 작게)
class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.rose : AppColors.warmWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.peach : AppColors.border,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.charcoal,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}

/// 작은 고르기 칸 ('내 이름 ▾')
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.expanded = false,
  });

  final T value;

  /// (값, 보여줄 글자)
  final List<(T, String)> items;

  /// null이면 흐려지고 못 고름
  final ValueChanged<T>? onChanged;

  /// 고른 값이 없을 때 보여줄 글자
  final String? hint;

  /// 가로로 꽉 채우기 (기본은 글자 길이만큼)
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodySmall
        ?.copyWith(color: AppColors.charcoal);
    final hint = this.hint;
    final onChanged = this.onChanged;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.warmWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: expanded,
          iconSize: 18,
          borderRadius: BorderRadius.circular(10),
          dropdownColor: AppColors.warmWhite,
          menuMaxHeight: 300,
          style: style,
          hint: hint == null
              ? null
              : Text(
                  hint,
                  style: style?.copyWith(color: AppColors.warmGray),
                  overflow: TextOverflow.ellipsis,
                ),
          items: [
            for (final (v, label) in items)
              DropdownMenuItem<T>(
                value: v,
                child: Text(label, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged == null ? null : (v) => onChanged(v as T),
        ),
      ),
    );
  }
}
