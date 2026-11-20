// 피그마 1번 화면 (시작)
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/secondary_button.dart';
import 'onboarding_screen.dart';
import 'widgets/example_dday_card.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('종강까지 20일.\n첫마디는 오늘.', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '남은 날과 지금의 용기에 맞춰 오늘 건넬 한마디를 골라요.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 24),
            const ExampleDdayCard(
              dDayText: 'D-20',
              firstMission: '첫 미션 · 마주치면 먼저 인사하기',
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '첫 미션 받기 →',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              ),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: 'D-20 예시 보기',
              // 예시 데이터 홈(피그마 7번)으로, 맨 위 '나가기'로 이 화면 복귀
              onPressed: () {
                MainShell.tabIndex.value = 0;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MainShell(example: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
