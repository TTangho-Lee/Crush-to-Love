// 피그마 19번 (괜찮아요!)
//   부족했던 점을 직접 써 보고 '분석 결과 보기' → 20번 (이 화면을 바꿔 끼움)
//   글은 기기 안에서 단어로만 보고 저장 · 전송하지 않음 (reflect_rules.dart)
//   글에서 못 찾으면 용기 배터리 · 이 상대와의 마지막 대화 분석으로
import 'package:material_ui/material_ui.dart';

import '../analysis/chat/chat_store.dart';
import '../onboarding/data/crush_store.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/app_text_field.dart';
import '../shared/widgets/panel_card.dart';
import '../shared/widgets/primary_button.dart';
import 'reflect_result_screen.dart';
import 'reflect_rules.dart';

class ReflectScreen extends StatefulWidget {
  const ReflectScreen({super.key, required this.crushId});

  /// 돌아볼 상대
  final int crushId;

  @override
  State<ReflectScreen> createState() => _ReflectScreenState();
}

class _ReflectScreenState extends State<ReflectScreen> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 글이 생기면 '분석 결과 보기'를 켬
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final crushes = CrushScope.of(context);
    final chat = ChatScope.of(context).stats;
    final partner = chat.record?.partner;
    // 마지막 대화 분석이 이 상대 대화일 때만 (연결 전이면 상대가 한 명뿐일 때만)
    final linked = partner == null ? null : crushes.crushForChatName(partner);
    final isThisCrush = !chat.isExample &&
        partner != null &&
        (linked != null
            ? linked.id == widget.crushId
            : crushes.active.length == 1 &&
                crushes.active.single.id == widget.crushId);
    final reasons = reflectOn(
      _controller.text,
      courage: crushes.courage,
      chat: isThisCrush ? chat.features : null,
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ReflectResultScreen(reasons: reasons),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasText = _controller.text.trim().isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(showCrush: false, onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('괜찮아요!', style: text.headlineSmall),
            const SizedBox(height: 20),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('내가 부족했던 부분이 뭔지 스스로 써 보세요', style: text.titleSmall),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _controller,
                    hint: '예: 먼저 말 거는 게 너무 어려웠어요',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 8),
                  Text('쓴 글은 저장하지 않아요.', style: text.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '분석 결과 보기',
              onPressed: hasText ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
