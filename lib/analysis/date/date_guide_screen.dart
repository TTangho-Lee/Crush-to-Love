// 피그마 13번 화면 (데이트 가이드)
// 데이터: DateStore의 guide (10번 '준비 가이드 보기'로 만든 것)
//   위: 고른 조건 (아이콘 칩), 가운데: 항목 6개 (마지막 한마디 팁만 연분홍), 아래: 만난 뒤 보낼 톡 (누르면 복사)
//   '다른 추천 보기': 같은 조건으로 다른 문장
import 'package:material_ui/material_ui.dart';

import '../../shared/app_colors.dart';
import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/copy_bubble.dart';
import '../../shared/widgets/info_card.dart';
import '../../shared/widgets/secondary_button.dart';
import 'date_guide.dart';
import 'date_store.dart';

class DateGuideScreen extends StatelessWidget {
  const DateGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final store = DateScope.of(context);
    final guide = store.guide;
    if (guide == null) return const Scaffold();
    final choice = guide.choice;
    final items = guide.items;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(label: '가이드'),
            const SizedBox(height: 24),
            Text('만나기 전에 챙길 것', style: text.headlineSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(choice.place.icon, choice.place.label),
                _Pill(choice.weather.icon, choice.weather.label),
                _Pill(choice.time.icon, choice.time.label),
                _Pill(choice.company.icon, choice.company.label),
              ],
            ),
            const SizedBox(height: 20),
            Column(
              spacing: 12,
              children: [
                for (var i = 0; i < items.length; i++)
                  InfoCard(
                    // 01, 02 ... 번호
                    title:
                        '${(i + 1).toString().padLeft(2, '0')}  ${items[i].kind.label}',
                    description: items[i].lines.join('\n'),
                    color: items[i].kind == GuideKind.tip
                        ? AppColors.roseSoft
                        : AppColors.warmWhite,
                  ),
              ],
            ),
            if (guide.afterLines.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('만난 뒤 보낼 톡', style: text.titleSmall),
              const SizedBox(height: 8),
              Column(
                spacing: 8,
                children: [for (final line in guide.afterLines) CopyBubble(line)],
              ),
            ],
            const SizedBox(height: 24),
            SecondaryButton(label: '↻ 다른 추천 보기', onPressed: store.shuffle),
            const SizedBox(height: 8),
            SecondaryButton(
              label: '조건 다시 고르기',
              // 피그마 10번으로 돌아가기
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 고른 조건 작은 칩 (아이콘 + 이름)
class _Pill extends StatelessWidget {
  const _Pill(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.rose,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Icon(icon, size: 14, color: AppColors.charcoal),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
