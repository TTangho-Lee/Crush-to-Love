// 피그마 17번 (짝사랑에 성공하셨나요?)
//   D-Day가 지났는데 결과를 안 고른 지금 상대가 있으면 앱을 켤 때 한 번 띄움 (OutcomeAsker, app/main_shell.dart)
//   설정 '지금 상대 · 결과'에서도 열 수 있음
//   네 / 아니요를 골라 두고 '결과 입력하기' → 네: 18번, 아니요: 19번 (이 화면을 바꿔 끼움)
import 'package:material_ui/material_ui.dart';

import '../onboarding/data/crush_store.dart';
import '../shared/models.dart';
import '../shared/widgets/app_header.dart';
import '../shared/widgets/option_card.dart';
import '../shared/widgets/primary_button.dart';
import 'reflect_screen.dart';
import 'success_screen.dart';

/// 17번 띄우기 (하단 탭 위로 덮음)
Future<void> showOutcome(BuildContext context, Crush crush) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(builder: (_) => OutcomeScreen(crushId: crush.id)),
  );
}

class OutcomeScreen extends StatefulWidget {
  const OutcomeScreen({super.key, required this.crushId});

  /// 결과를 정할 상대
  final int crushId;

  @override
  State<OutcomeScreen> createState() => _OutcomeScreenState();
}

class _OutcomeScreenState extends State<OutcomeScreen> {
  /// 골라 둔 결과 (이미 정한 결과가 있으면 그것부터)
  late CrushOutcome? _picked =
      CrushScope.read(context)?.byId(widget.crushId)?.outcome;

  Future<void> _submit() async {
    final picked = _picked;
    if (picked == null) return;
    final navigator = Navigator.of(context);
    await CrushScope.of(context).setOutcome(widget.crushId, picked);
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => picked == CrushOutcome.success
            ? const SuccessScreen()
            : ReflectScreen(crushId: widget.crushId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final crush = CrushScope.of(context).byId(widget.crushId);
    final picked = _picked;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            AppHeader(showCrush: false, onBack: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Text('짝사랑에 성공하셨나요?', style: text.headlineSmall),
            // 상대가 여러 명일 수 있어서 누구 결과인지
            if (crush != null) ...[
              const SizedBox(height: 8),
              Text('${crush.nickname} · ${crush.reason}', style: text.bodySmall),
            ],
            const SizedBox(height: 24),
            Column(
              spacing: 12,
              children: [
                for (final (value, label) in const [
                  (CrushOutcome.success, '네, 성공했어요'),
                  (CrushOutcome.fail, '아니요'),
                ])
                  OptionCard(
                    title: label,
                    selected: picked == value,
                    onTap: () => setState(() => _picked = value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '결과 입력하기',
              onPressed: picked == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// D-Day가 지났는데 결과를 안 고른 지금 상대가 있으면 17번을 한 번 띄움
/// 앱을 켤 때마다 상대마다 한 번 (되돌아가기로 닫으면 다음에 켤 때 다시 물음)
class OutcomeAsker extends StatefulWidget {
  const OutcomeAsker({super.key, required this.child});

  final Widget child;

  @override
  State<OutcomeAsker> createState() => _OutcomeAskerState();
}

class _OutcomeAskerState extends State<OutcomeAsker> {
  /// 이번에 켠 동안 이미 물어본 상대
  static final _asked = <int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 지금 상대가 바뀌거나 정보가 바뀔 때마다 다시 봄
    final crush = CrushScope.maybeOf(context)?.awaitingOutcome;
    if (crush == null || !_asked.add(crush.id)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showOutcome(context, crush);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
