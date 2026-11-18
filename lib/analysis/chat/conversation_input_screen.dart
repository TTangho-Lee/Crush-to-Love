// 피그마 9번 화면 (우리 대화 돌아보기)
// '대화 분석하기'에서 쓸 데이터 메서드: ChatStore.analyze(대화 텍스트, myName: 내 이름)
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/app_header.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/panel_card.dart';
import '../../shared/widgets/primary_button.dart';
import '../../shared/widgets/secondary_button.dart';
import 'conversation_result_screen.dart';

class ConversationInputScreen extends StatelessWidget {
  const ConversationInputScreen({super.key});

  // 피그마 12번으로 (대화 탭 안에서 이동, 하단 탭 유지)
  void _openResult(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConversationResultScreen()),
    );
  }

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
            Text('우리 대화 돌아보기', style: text.headlineSmall),
            const SizedBox(height: 8),
            Text('카톡 대화를 붙여넣고 답장 패턴을 확인해요.', style: text.bodySmall),
            const SizedBox(height: 24),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('대화 붙여넣기', style: text.titleSmall),
                  const SizedBox(height: 4),
                  Text('시간과 발신자가 포함된 카카오톡 내보내기 텍스트', style: text.bodySmall),
                  const SizedBox(height: 12),
                  const AppTextField(
                    hint: '[나] [오후 1:00] 오늘 수업 어땠어?',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 16),
                  Text('내 이름 · 선택', style: text.titleSmall),
                  const SizedBox(height: 8),
                  const AppTextField(hint: "미입력 시 '나' 또는 첫 발신자"),
                  const SizedBox(height: 8),
                  Text('대화는 브라우저에서 분석하며 저장하지 않아요.', style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '대화 분석하기',
              onPressed: () => _openResult(context),
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: '예시 결과 보기',
              onPressed: () => _openResult(context),
            ),
          ],
        ),
      ),
    );
  }
}
