// 피그마 20번 (무엇이 좀 부족했을까요?)
//   19번 글 · 데이터로 찾은 부족했던 점 카드 (01 용기 내기 …, reflect_rules.dart), 못 찾으면 한 장
//   맨 아래 응원 한 줄 (연분홍), '확인'으로 닫음
import 'package:material_ui/material_ui.dart';

import '../shared/app_colors.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/info_card.dart';
import '../shared/widgets/primary_button.dart';
import 'reflect_rules.dart';

class ReflectResultScreen extends StatelessWidget {
  const ReflectResultScreen({super.key, required this.reasons});

  /// 부족했던 점 (많이 나온 순)
  final List<FailReason> reasons;

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
            Text('무엇이 좀 부족했을까요?', style: text.headlineSmall),
            const SizedBox(height: 20),
            Column(
              spacing: 12,
              children: [
                if (reasons.isEmpty)
                  const InfoCard(
                    title: '딱 하나로 꼽기 어려워요',
                    description: '마음이 닿는 데엔 타이밍도 있어요. 돌아본 것만으로도 다음엔 더 잘할 수 있어요',
                  )
                else
                  for (var i = 0; i < reasons.length; i++)
                    InfoCard(
                      // 01, 02 ... 번호
                      title: '${(i + 1).toString().padLeft(2, '0')}  '
                          '${reasons[i].label}',
                      description: reasons[i].description,
                    ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.roseSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '이번 경험을 바탕으로 다음엔 꼭 성공할 수 있기를 바랄게요!',
                    style: text.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: '확인',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
