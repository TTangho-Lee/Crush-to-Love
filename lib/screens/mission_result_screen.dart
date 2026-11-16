import 'package:material_ui/material_ui.dart';

import '../config/level_texts.dart';
import '../data/app_store.dart';
import '../models/mission.dart';
import '../widgets/level_slider.dart';

class MissionResultScreen extends StatefulWidget {
  const MissionResultScreen({
    super.key,
    required this.mission,
    required this.success,
  });

  final Mission mission;
  final bool success;

  @override
  State<MissionResultScreen> createState() => _MissionResultScreenState();
}

class _MissionResultScreenState extends State<MissionResultScreen> {
  final _memo = TextEditingController();
  final _replyDelay = TextEditingController();
  final _avgLength = TextEditingController();
  final _messageCount = TextEditingController();
  double _positivity = 0.5;
  FailReason? _failReason;
  int? _intimacy;

  @override
  void dispose() {
    _memo.dispose();
    _replyDelay.dispose();
    _avgLength.dispose();
    _messageCount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!widget.success && _failReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('못 한 이유를 선택해 주세요')),
      );
      return;
    }

    final store = AppScope.of(context);
    final navigator = Navigator.of(context);
    final result = MissionResult(
      missionId: widget.mission.id,
      success: widget.success,
      failReason: widget.success ? null : _failReason,
      memo: _memo.text.trim(),
      metrics: widget.success
          ? ReplyMetrics(
              replyDelayMinutes: int.tryParse(_replyDelay.text),
              avgLength: int.tryParse(_avgLength.text),
              messageCount: int.tryParse(_messageCount.text),
              positivity: _positivity,
            )
          : null,
      recordedAt: DateTime.now(),
    );

    final intimacy = _intimacy ?? store.profile?.intimacyLevel ?? 1;
    await store.submitResult(result, intimacy);
    navigator.popUntil((route) => route.isFirst);
  }

  Widget _numberField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final intimacy = _intimacy ?? store.profile?.intimacyLevel ?? 1;
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    return Scaffold(
      appBar: AppBar(title: Text(widget.success ? '성공 기록' : '실패 기록')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.mission.title,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (widget.success) ...[
            Text('상대 반응', style: titleStyle),
            // TODO: 카톡 대화 내보내기(txt) 파싱으로 자동 계산
            const OutlinedButton(
              onPressed: null,
              child: Text('카톡 대화 파일 불러오기 (준비 중)'),
            ),
            _numberField(_replyDelay, '답장까지 걸린 시간(분)'),
            _numberField(_avgLength, '상대 메시지 평균 길이(글자)'),
            _numberField(_messageCount, '상대가 보낸 메시지 수'),
            const SizedBox(height: 16),
            Text('긍정도: ${(_positivity * 100).round()}%'),
            Slider(
              value: _positivity,
              divisions: 4,
              onChanged: (v) => setState(() => _positivity = v),
            ),
          ] else ...[
            Text('못 한 이유', style: titleStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final r in FailReason.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: _failReason == r,
                    onSelected: (_) => setState(() => _failReason = r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _memo,
            decoration: const InputDecoration(labelText: '메모 (선택)'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          LevelSlider(
            label: '지금 친한 정도',
            descriptions: intimacyLevelTexts,
            value: intimacy,
            onChanged: (v) => setState(() => _intimacy = v),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submit,
            child: const Text('기록하고 다음 미션 받기'),
          ),
        ],
      ),
    );
  }
}
