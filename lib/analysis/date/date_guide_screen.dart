// 피그마 13번 화면 (데이트 가이드)
// 데이터: DateStore의 guide (10번 '준비 가이드 보기'로 만든 것)
//   위: 고른 조건 (아이콘 칩), 가운데: 항목 6개 (마지막 한마디 팁만 연분홍), 아래: 만난 뒤 보낼 톡 (누르면 복사)
//   '다른 추천 보기': 같은 조건으로 다른 문장
//   말해볼 문장(한마디 팁 · 대화 소재 질문 · 만난 뒤 톡)은 누르면 복사 (복사 아이콘으로만 표시), 맞춤 추천을 켰으면 기록
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../onboarding/data/crush_store.dart';
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
    final crushId = CrushScope.maybeOf(context)?.current?.id ?? 0;
    // 말해볼 문장 복사 (한마디 팁 · 대화 소재 질문)
    VoidCallback? copyOf(String? saying) => saying == null
        ? null
        : () {
            Clipboard.setData(ClipboardData(text: saying));
            store.recordSaying(saying, crushId: crushId);
          };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            // 오른쪽 위 되돌아가기 → 10번 (고른 조건은 그대로)
            AppHeader(onBack: () => Navigator.pop(context)),
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
                  _GuideCard(
                    index: i,
                    item: items[i],
                    onCopy: copyOf(switch (items[i].kind) {
                      GuideKind.tip => guide.tip,
                      GuideKind.talk => guide.question,
                      _ => null,
                    }),
                  ),
              ],
            ),
            if (guide.afterLines.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('만난 뒤 보낼 톡', style: text.titleSmall),
              const SizedBox(height: 8),
              Column(
                spacing: 8,
                children: [
                  for (final line in guide.afterLines)
                    CopyBubble(
                      line,
                      onCopied: () => store.recordSaying(line, crushId: crushId),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            SecondaryButton(label: '↻ 다른 추천 보기', onPressed: store.shuffle),
          ],
        ),
      ),
    );
  }
}

/// 가이드 항목 카드 (01 OOTD …), 말해볼 문장이 있으면 누르면 복사 (오른쪽 위 복사 아이콘)
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.index, required this.item, this.onCopy});

  final int index;
  final GuideItem item;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final card = InfoCard(
      // 01, 02 ... 번호
      title: '${(index + 1).toString().padLeft(2, '0')}  ${item.kind.label}',
      description: item.lines.join('\n'),
      color: item.kind == GuideKind.tip ? AppColors.roseSoft : AppColors.warmWhite,
    );
    if (onCopy == null) return card;
    // 카드 어디를 눌러도(복사 아이콘 포함) 바로 복사
    return GestureDetector(
      onTap: onCopy,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          card,
          const Positioned(
            top: 18,
            right: 18,
            child: Icon(Icons.copy_rounded, size: 16, color: AppColors.warmGray),
          ),
        ],
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
