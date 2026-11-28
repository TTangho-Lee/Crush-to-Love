// 피그마 11번 화면 (우리 사이 업데이트)
//   지금 사이 · 이번 목표 · 오늘의 용기를 한 화면에서 고침 (각각 따로 상자)
//   '변경 저장하고 미션 다시 짜기': 지금 상대 정보 · 내 용기(CrushStore)를 바꾸면 로드맵을 다시 짬
//     (이번 주부터 안 한 미션만 새로, 완료한 미션은 남음) → 로드맵 탭
//     예시 화면이면 예시 로드맵만 다시 짬 (저장 안 함)
//   '취소하고 홈으로': 바꾸지 않고 닫기
import 'package:material_ui/material_ui.dart';

import '../app/main_shell.dart';
import '../onboarding/data/crush_store.dart';
import '../shared/app_colors.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/option_card.dart';
import '../shared/widgets/panel_card.dart';
import '../shared/widgets/primary_button.dart';
import '../shared/widgets/secondary_button.dart';
import 'roadmap_store.dart';

class RoadmapRelationScreen extends StatefulWidget {
  const RoadmapRelationScreen({super.key});

  @override
  State<RoadmapRelationScreen> createState() =>
      _RoadmapRelationScreenState();
}

class _RoadmapRelationScreenState extends State<RoadmapRelationScreen> {
  /// 고른 값 (처음엔 지금 값)
  late Intimacy _intimacy = RoadmapScope.of(context).profile.intimacy;
  late Goal _goal = RoadmapScope.of(context).profile.goal;
  late double _courage = RoadmapScope.of(context).profile.courage.toDouble();

  Future<void> _save() async {
    final store = RoadmapScope.of(context);
    final crushes = CrushScope.maybeOf(context);
    final crush = crushes?.current;
    final navigator = Navigator.of(context);
    final courage = _courage.round();
    if (crushes == null || crush == null) {
      store.updateExample(intimacy: _intimacy, goal: _goal, courage: courage);
    } else {
      if (courage != crushes.courage) await crushes.setCourage(courage);
      await crushes.update(crush.copyWith(intimacy: _intimacy, goal: _goal));
    }
    // 다시 짠 로드맵 보기 (피그마 8번)
    MainShell.tabIndex.value = 1;
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final level = CourageLevel.of(_courage.round());

    Widget section(String title, Widget child) => PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 12),
              child,
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(showCrush: false),
            const SizedBox(height: 24),
            Text('우리 사이 업데이트', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '바꾼 대로 남은 미션을 다시 짜요. 완료한 미션은 그대로 남아요.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 20),
            section(
              '지금은 어떤 사이인가요?',
              Column(
                spacing: 8,
                children: [
                  for (final v in Intimacy.values)
                    OptionCard(
                      title: v.label,
                      selected: v == _intimacy,
                      onTap: () => setState(() => _intimacy = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            section(
              '이번 목표',
              Column(
                spacing: 8,
                children: [
                  for (final v in Goal.values)
                    OptionCard(
                      title: v.label,
                      selected: v == _goal,
                      onTap: () => setState(() => _goal = v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            section(
              '오늘의 용기',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_courage.round()}%',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(level.label, style: text.bodySmall)),
                    ],
                  ),
                  Slider(
                    value: _courage,
                    max: 100,
                    divisions: 20,
                    onChanged: (v) => setState(() => _courage = v),
                  ),
                  Text(level.description, style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: '변경 저장하고 미션 다시 짜기', onPressed: _save),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '취소하고 홈으로',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
