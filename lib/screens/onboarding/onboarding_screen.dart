// 피그마 2~6번 화면 (온보딩)
// 머리글 · 진행 바 · 버튼은 2~6번이 같고, 가운데 내용만 steps 폴더에서 가져옴
// '다음 →' / '이전'은 화면 이동 없이 가운데 내용만 바꿈
// 6번 '내 로드맵 만들기'에서 쓸 데이터 메서드: AppStore.saveOnboarding(Profile)
import 'package:material_ui/material_ui.dart';

import '../../app/main_shell.dart';
import '../../widgets/app_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/secondary_button.dart';
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
  /// 지금 단계 1 ~ 5 (피그마 2 ~ 6번)
  int _step = 1;

  static const List<Widget> _steps = [
    DdayStep(), // 피그마 2번
    IntimacyStep(), // 피그마 3번
    MeetingStep(), // 피그마 4번
    CourageStep(), // 피그마 5번
    GoalStep(), // 피그마 6번
  ];

  bool get _isLastStep => _step == _steps.length;

  void _next() {
    if (!_isLastStep) {
      setState(() => _step++);
      return;
    }
    // 마지막 단계: 홈(피그마 7번)으로, 뒤로가기로 온보딩에 못 돌아오게
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
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(label: '$_step / ${_steps.length}'),
            const SizedBox(height: 16),
            ProgressBar(value: _step / _steps.length),
            const SizedBox(height: 24),
            _steps[_step - 1],
            const SizedBox(height: 24),
            PrimaryButton(
              label: _isLastStep ? '내 로드맵 만들기 →' : '다음 →',
              onPressed: _next,
            ),
            const SizedBox(height: 12),
            SecondaryButton(label: '이전', onPressed: _prev),
          ],
        ),
      ),
    );
  }
}
