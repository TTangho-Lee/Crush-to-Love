// 피그마 13번 화면 (데이트 가이드)
// 데이터: DateStore의 guide
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/secondary_button.dart';
import 'date_store.dart';

class DateGuideScreen extends StatelessWidget {
  const DateGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final guide = DateScope.of(context).guide;
    final items = guide.items;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(label: '가이드'),
            const SizedBox(height: 24),
            Text('만나기 전, 챙길 다섯 가지', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('${guide.place} · ${guide.weather}', style: text.bodySmall),
            const SizedBox(height: 24),
            Column(
              spacing: 12,
              children: [
                for (var i = 0; i < items.length; i++)
                  InfoCard(
                    // 01, 02 ... 번호
                    title: '${(i + 1).toString().padLeft(2, '0')}  ${items[i].title}',
                    description: items[i].content,
                    // 마지막 '한마디 팁'만 연분홍
                    color: i == items.length - 1
                        ? AppColors.roseSoft
                        : AppColors.warmWhite,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: '준비 조건 다시 선택하기',
              // 피그마 10번으로 돌아가기
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
