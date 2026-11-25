// 피그마 2~6번 화면 (온보딩)
// 머리글 · 진행 바 · 버튼은 단계마다 같고, 가운데 내용만 steps 폴더에서 가져옴
// '다음 →' / '이전'은 화면 이동 없이 가운데 내용만 바꿈
// 입력값은 이 화면이 들고 있다가 마지막 단계에서 CrushStore에 저장 (미션 흐름 · 알림은 main.dart가 이어서)
// 두 가지로 씀
//   처음: 시작 화면에서, 첫 상대 + 내 용기 (5단계)
//   새 상대: 설정 · 대화 분석 결과에서 (용기는 나에 대한 값이라 빼고 4단계, 지금 상대는 그대로 둠)
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/progress_bar.dart';
import '../shared/widgets/secondary_button.dart';
import 'data/crush_store.dart';
import 'steps/courage_step.dart';
import 'steps/dday_step.dart';
import 'steps/goal_step.dart';
import 'steps/intimacy_step.dart';
import 'steps/meeting_step.dart';

/// 온보딩 단계 (피그마 2 ~ 6번)
enum _Step { dDay, intimacy, meeting, courage, goal }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.chatName});

  /// 새 상대에 바로 연결할 카톡 이름 (대화 분석 결과 '새 상대'), 별명 칸에도 미리 채움
  final String? chatName;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// 이번에 거칠 단계 (새 상대면 용기 단계 빼고)
  List<_Step> _steps = _Step.values;

  /// 지금 단계 번호 0부터
  int _index = 0;

  // 입력값, 기본값은 피그마 예시 (별명 · 날짜는 직접)
  final _nickname = TextEditingController();
  final _customReason = TextEditingController();
  DateTime? _dDay;
  String _reasonTag = reasonTags.first;
  Intimacy _intimacy = Intimacy.smallTalk;
  int _meetingsPerWeek = 2;
  int _courage = defaultCourage;
  Goal _goal = Goal.friends;

  /// 저장 중 버튼 두 번 눌림 방지
  bool _saving = false;

  /// 처음 화면을 그릴 때 한 번만 단계 · 용기를 정함
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    // 글자를 바꾸면 '다음' 버튼을 다시 그림
    _nickname.addListener(_refresh);
    _customReason.addListener(_refresh);
    _nickname.text = widget.chatName ?? '';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    // 이미 상대가 있으면 새 상대 추가: 용기는 지금 값 그대로, 용기 단계는 건너뜀
    final crushes = CrushScope.read(context);
    if (crushes != null && crushes.all.isNotEmpty) {
      _courage = crushes.courage;
      _steps = [
        for (final step in _Step.values)
          if (step != _Step.courage) step,
      ];
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _customReason.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  _Step get _step => _steps[_index];

  bool get _isLastStep => _index == _steps.length - 1;

  /// 저장할 사유 ('기타'면 직접 입력한 글자)
  String get _reason =>
      _reasonTag == otherReason ? _customReason.text.trim() : _reasonTag;

  /// 첫 단계는 별명 · 날짜 · ('기타'면) 어떤 날인지가 있어야 '다음' 가능
  bool get _canNext =>
      !_saving &&
      (_step != _Step.dDay ||
          (_nickname.text.trim().isNotEmpty &&
              _dDay != null &&
              _reason.isNotEmpty));

  Widget _buildStep() {
    return switch (_step) {
      _Step.dDay => DdayStep(
          nicknameController: _nickname,
          customReasonController: _customReason,
          dDay: _dDay,
          reasonTag: _reasonTag,
          onDDayChanged: (v) => setState(() => _dDay = v),
          onReasonChanged: (v) => setState(() => _reasonTag = v),
        ),
      _Step.intimacy => IntimacyStep(
          selected: _intimacy,
          onChanged: (v) => setState(() => _intimacy = v),
        ),
      _Step.meeting => MeetingStep(
          value: _meetingsPerWeek,
          onChanged: (v) => setState(() => _meetingsPerWeek = v),
        ),
      _Step.courage => CourageStep(
          value: _courage,
          onChanged: (v) => setState(() => _courage = v),
        ),
      _Step.goal => GoalStep(
          selected: _goal,
          onChanged: (v) => setState(() => _goal = v),
        ),
    };
  }

  Future<void> _next() async {
    if (!_isLastStep) {
      setState(() => _index++);
      return;
    }

    setState(() => _saving = true);
    final chatName = widget.chatName;
    await CrushScope.of(context).add(
      nickname: _nickname.text,
      dDay: _dDay!,
      reason: _reason,
      intimacy: _intimacy,
      meetingsPerWeek: _meetingsPerWeek,
      goal: _goal,
      courage: _courage,
      chatNames: [?chatName],
    );

    if (!mounted) return;
    // 홈(피그마 7번)으로, 뒤로가기로 온보딩에 못 돌아오게
    MainShell.tabIndex.value = 0;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _prev() {
    if (_index > 0) {
      setState(() => _index--);
      return;
    }
    // 첫 단계: 들어온 화면(시작 화면 · 홈 등)으로
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final count = _steps.length;

    // 기기 뒤로가기도 '이전'과 같게 (2단계 이상이면 화면 안 닫고 한 단계 뒤로)
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              // 입력하는 동안엔 지금 상대를 안 보여줌
              AppHeader(label: '${_index + 1} / $count', showCrush: false),
              const SizedBox(height: 16),
              ProgressBar(value: (_index + 1) / count),
              const SizedBox(height: 24),
              _buildStep(),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isLastStep ? '내 로드맵 만들기 →' : '다음 →',
                onPressed: _canNext ? _next : null,
              ),
              const SizedBox(height: 12),
              SecondaryButton(label: '이전', onPressed: _prev),
            ],
          ),
        ),
      ),
    );
  }
}
