// 피그마 12번 화면 (대화 분석 결과)
// 데이터: AppStore의 chatStats
import 'package:material_ui/material_ui.dart';

import '../../app/app_colors.dart';
import '../../data/app_store.dart';
import '../../widgets/app_header.dart';
import '../../widgets/info_card.dart';
import '../../widgets/secondary_button.dart';

class ConversationResultScreen extends StatelessWidget {
  const ConversationResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final stats = AppScope.of(context).chatStats;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const AppHeader(label: '예시'),
            const SizedBox(height: 24),
            Text(stats.summary, style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('대화에서 관찰된 변화와 다음 대화 힌트를 확인해요.', style: text.bodySmall),
            const SizedBox(height: 24),
            Column(
              spacing: 12,
              children: [
                InfoCard(
                  title: '평균 답장 텀 · ${stats.avgReplyMinutes}분',
                  description: '내 메시지 다음에 온 상대 답장 기준',
                ),
                InfoCard(
                  title: '평균 답장 길이 · ${stats.avgLength}자',
                  description: '상대 메시지 기준',
                ),
                InfoCard(
                  title: '하루 메시지 · ${stats.messagesPerDay}개',
                  description: '첫 메시지와 마지막 메시지 사이 날짜 기준',
                ),
                InfoCard(
                  title: '긍정 표현 · ${stats.positivePercent}%',
                  description: '고마움·웃음 표현이 포함된 상대 메시지',
                  color: AppColors.roseSoft,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              label: '대화 다시 입력하기',
              // 피그마 9번으로 돌아가기
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
