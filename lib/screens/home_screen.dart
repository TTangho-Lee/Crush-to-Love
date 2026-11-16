import 'package:material_ui/material_ui.dart';

import '../data/app_store.dart';
import '../models/mission.dart';
import '../models/target_profile.dart';
import '../utils/format.dart';
import 'mission_screen.dart';
import 'profile_form_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final profile = store.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('짝사랑 성공 프로젝트')),
      body: profile == null
          ? const _EmptyView()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ProfileCard(profile: profile),
                const SizedBox(height: 12),
                _ProgressCard(progress: profile.progress),
                const SizedBox(height: 12),
                _MissionCard(
                  mission: store.currentMission,
                  isGenerating: store.isGenerating,
                ),
                const SizedBox(height: 12),
                Text('완료한 미션: ${store.pastMissions.length}개'),
              ],
            ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('아직 등록된 상대가 없어요'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const ProfileFormScreen(),
            )),
            child: const Text('상대 프로필 등록하기'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final TargetProfile profile;

  @override
  Widget build(BuildContext context) {
    final end = profile.periodEnd;
    return Card(
      child: ListTile(
        title: Text(profile.nickname),
        subtitle: Text(
          '목표: ${profile.goal.label} · 주 ${profile.meetingsPerWeek}회 만남\n'
          '기간: ${profile.periodType.label}'
          '${end != null ? ' (~${formatDate(end)})' : ''}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ProfileFormScreen(initial: profile),
          )),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.progress});

  final int progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('관계 진척도 $progress%'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress / 100),
          ],
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.isGenerating});

  final Mission? mission;
  final bool isGenerating;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    if (isGenerating || m == null) {
      return const Card(
        child: ListTile(title: Text('미션 생성 중...')),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.flag),
        title: Text(m.title),
        subtitle: Text('마감: ${formatDate(m.deadline)} · ${m.status.label}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MissionScreen(mission: m),
        )),
      ),
    );
  }
}
