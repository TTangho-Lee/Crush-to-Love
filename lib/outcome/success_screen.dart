// 피그마 18번 (축하합니다!)
//   '데이트 준비하기 →': 데이트 탭으로 (연애 중에도 데이트 가이드는 그대로 씀)
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../shared/app_colors.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/primary_button.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(showCrush: false, onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('축하합니다!', style: text.headlineSmall),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: AppColors.roseSoft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    '짝사랑 성공',
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '연애 중에도 데이트 기능은 계속 쓸 수 있어요!',
                    style: text.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '데이트 준비하기 →',
              onPressed: () {
                MainShell.tabIndex.value = 3;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
