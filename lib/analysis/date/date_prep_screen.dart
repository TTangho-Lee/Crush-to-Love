// 피그마 10번 화면 (데이트 준비하기)
// 데이터: DateStore의 guide (지금 고른 장소 · 날씨), 선택지는 date_guide.dart의 datePlaces, dateWeathers
// '준비 가이드 보기'에서 쓸 데이터 메서드: DateStore.build(place:, weather:, profile:)
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/primary_button.dart';
import 'date_guide.dart';
import 'date_guide_screen.dart';
import 'date_store.dart';

class DatePrepScreen extends StatelessWidget {
  const DatePrepScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final guide = DateScope.of(context).guide;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Text('데이트 준비하기', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('약속이 정해졌다면 장소와 상황에 맞는 준비를 시작해요.', style: text.bodySmall),
            const SizedBox(height: 24),
            InfoCard(
              title: '장소 유형 · ${guide.place}',
              description: datePlaces.join(' / '),
              color: AppColors.ivory,
            ),
            const SizedBox(height: 12),
            InfoCard(
              title: '날씨 · ${guide.weather}',
              description: dateWeathers.join(' / '),
              color: AppColors.ivory,
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '준비 가이드 보기 →',
              // 피그마 13번으로 (데이트 탭 안에서 이동, 하단 탭 유지)
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DateGuideScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
