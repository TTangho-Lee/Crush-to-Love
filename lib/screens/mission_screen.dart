import 'package:material_ui/material_ui.dart';

import '../models/mission.dart';
import '../utils/format.dart';
import 'mission_result_screen.dart';

class MissionScreen extends StatelessWidget {
  const MissionScreen({super.key, required this.mission});

  final Mission mission;

  void _openResult(BuildContext context, bool success) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => MissionResultScreen(mission: mission, success: success),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall;

    return Scaffold(
      appBar: AppBar(title: const Text('미션')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(mission.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('마감: ${formatDate(mission.deadline)} · 난이도 ${mission.difficulty}/5'),
          const SizedBox(height: 24),
          Text('상황', style: titleStyle),
          Text(mission.situation),
          const SizedBox(height: 16),
          Text('추천 멘트', style: titleStyle),
          for (final s in mission.scripts)
            Card(child: ListTile(title: Text(s))),
          const SizedBox(height: 16),
          Text('주의할 점', style: titleStyle),
          Text(mission.caution),
          const SizedBox(height: 32),
          if (mission.status == MissionStatus.inProgress)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _openResult(context, false),
                    child: const Text('못 했어요'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _openResult(context, true),
                    child: const Text('성공했어요'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
