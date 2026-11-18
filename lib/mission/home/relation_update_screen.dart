// 피그마 11번 화면 (우리 사이 업데이트)
// 데이터: MissionStore의 profile (지금 친밀도 · 목표)
// '변경 저장하고 미션 다시 짜기'에서 쓸 데이터 메서드: MissionStore.updateRelation(intimacy:, goal:)
import 'package:material_ui/material_ui.dart';

import '../../app/main_shell.dart';
import '../../shared/models.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/option_card.dart';
import '../../shared/widgets/panel_card.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';
import '../../shared/widgets/select_box.dart';
import '../data/mission_store.dart';

class RelationUpdateScreen extends StatelessWidget {
  const RelationUpdateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final profile = MissionScope.of(context).profile;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('우리 사이 업데이트', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('지금 사이를 기록하면 남은 미션을 새로 짜요.', style: text.bodySmall),
            const SizedBox(height: 24),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('지금은 어떤 사이인가요?', style: text.titleSmall),
                  const SizedBox(height: 12),
                  Column(
                    spacing: 8,
                    children: [
                      for (final level in Intimacy.values)
                        OptionCard(
                          title: level.label,
                          selected: level == profile.intimacy,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('이번 목표', style: text.titleSmall),
                  const SizedBox(height: 8),
                  SelectBox(value: profile.goal.label),
                  const SizedBox(height: 8),
                  Text('완료한 미션은 기록에 남아요.', style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '변경 저장하고 미션 다시 짜기',
              // 이 화면을 닫고 로드맵 탭(피그마 8번)으로
              onPressed: () {
                MainShell.tabIndex.value = 1;
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '취소하고 홈으로',
              // 홈(피그마 7번)으로 돌아가기
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
