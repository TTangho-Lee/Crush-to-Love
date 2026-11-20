// 피그마 2~6번 화면 (온보딩)
// 머리글 · 진행 바 · 버튼은 2~6번이 같고, 가운데 내용만 steps 폴더에서 가져옴
// '다음 →' / '이전'은 화면 이동 없이 가운데 내용만 바꿈
// 입력값은 이 화면이 들고 있다가 6번 '내 로드맵 만들기'에서 ProfileDb에 저장
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/progress_bar.dart';
import '../shared/widgets/secondary_button.dart';
import 'data/profile_db.dart';
import 'steps/courage_step.dart';
import 'steps/dday_step.dart';
import 'steps/goal_step.dart';
import 'steps/intimacy_step.dart';
import 'steps/meeting_step.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _stepCount = 5;

  /// 지금 단계 1 ~ 5 (피그마 2 ~ 6번)
  int _step = 1;

  // 입력값, 기본값은 피그마 예시 (날짜만 직접 골라야 함)
  DateTime? _dDay;
  String _reason = reasonTags.first;
  Intimacy _intimacy = Intimacy.smallTalk;
  int _meetingsPerWeek = 2;
  int _courage = 50;
  Goal _goal = Goal.friends;

  /// 저장 중 버튼 두 번 눌림 방지
  bool _saving = false;

  bool get _isLastStep => _step == _stepCount;

  /// 1단계는 날짜를 골라야 '다음' 가능
  bool get _canNext => !_saving && (_step != 1 || _dDay != null);

  Widget _buildStep() {
    return switch (_step) {
      1 => DdayStep(
          dDay: _dDay,
          reason: _reason,
          onDDayChanged: (v) => setState(() => _dDay = v),
          onReasonChanged: (v) => setState(() => _reason = v),
        ),
      2 => IntimacyStep(
          selected: _intimacy,
          onChanged: (v) => setState(() => _intimacy = v),
        ),
      3 => MeetingStep(
          value: _meetingsPerWeek,
          onChanged: (v) => setState(() => _meetingsPerWeek = v),
        ),
      4 => CourageStep(
          value: _courage,
          onChanged: (v) => setState(() => _courage = v),
        ),
      _ => GoalStep(
          selected: _goal,
          onChanged: (v) => setState(() => _goal = v),
        ),
    };
  }

  Future<void> _next() async {
    if (!_isLastStep) {
      setState(() => _step++);
      return;
    }

    setState(() => _saving = true);
    final profile = Profile(
      dDay: _dDay!,
      reason: _reason,
      intimacy: _intimacy,
      meetingsPerWeek: _meetingsPerWeek,
      courage: _courage,
      goal: _goal,
    );

    try {
      await ProfileDb.save(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장하지 못했어요. 다시 눌러 주세요.')),
      );
      return;
    }
    // TODO(합치기): 팀원 MissionStore.saveOnboarding(profile)도 호출 (로드맵 생성)

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
    if (_step > 1) {
      setState(() => _step--);
      return;
    }
    // 첫 단계: 시작 화면(피그마 1번)으로
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // 기기 뒤로가기도 '이전'과 같게 (2단계 이상이면 화면 안 닫고 한 단계 뒤로)
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _prev();
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              AppHeader(label: '$_step / $_stepCount'),
              const SizedBox(height: 16),
              ProgressBar(value: _step / _stepCount),
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
