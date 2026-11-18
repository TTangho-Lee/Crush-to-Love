// 미션 흐름의 데이터 (온보딩 · 홈 · 로드맵이 같이 씀)
// 화면에서는 MissionScope.of(context)로 꺼내 씀
//   final store = MissionScope.of(context);
//   Text(store.profile.goal.label)
// 지금은 가짜 데이터. 메서드 이름과 주고받는 모양만 약속
import 'package:flutter/widgets.dart';

import '../../shared/models.dart';
import 'local_storage.dart';
import 'mission_fake_data.dart';
import 'mission_models.dart';
import 'roadmap_generator.dart';

class MissionStore extends ChangeNotifier {
  final _storage = LocalStorage();
  Profile _profile = fakeProfile();
  List<WeekPlan> _weeks = fakeWeeks;

  // ---------- 읽기 ----------

  /// 온보딩 입력값
  Profile get profile => _profile;

  /// D-Day까지 남은 날 (20이면 'D-20')
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = _profile.dDay;
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  /// 주차별 로드맵 (피그마 8번, 14~16번)
  List<WeekPlan> get weeks => _weeks;

  /// 지금 주차 (피그마 8번 분홍 카드)
  WeekPlan get currentWeek {
    final left = daysLeft;
    return _weeks.firstWhere(
      (w) => left <= w.fromDDay && left >= w.toDDay,
      orElse: () => _weeks.first,
    );
  }

  /// 오늘의 미션 = 지금 주차 미션 (피그마 7번)
  List<Mission> get todayMissions => currentWeek.missions;

  /// 완료한 미션 수 (전체 주차)
  int get doneCount => _weeks.fold(0, (sum, w) => sum + w.doneCount);

  /// 전체 미션 수
  int get totalCount => _weeks.fold(0, (sum, w) => sum + w.missions.length);

  /// 미션 진행률 0 ~ 1 (피그마 7번 '미션 진행률 · 11%')
  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  // ---------- 바꾸기 ----------

  /// 온보딩 완료 (피그마 6번 '내 로드맵 만들기')
  void saveOnboarding(Profile profile) {
    _profile = profile;
    _weeks = generateRoadmap(profile);
    _save();
  }

  /// 미션 완료 / 미완료 전환 (피그마 7번 체크 칸)
  void toggleMission(String missionId) {
    _weeks = [
      for (final w in _weeks)
        w.copyWith(
          missions: [
            for (final m in w.missions)
              m.id == missionId ? m.copyWith(done: !m.done) : m,
          ],
        ),
    ];
    _save();
  }

  /// 친밀도 · 목표 바꾸기 (피그마 11번 '변경 저장하고 미션 다시 짜기')
  /// 가짜: 입력값만 바꾸고 미션은 그대로
  void updateRelation({required Intimacy intimacy, required Goal goal}) {
    _profile = _profile.copyWith(intimacy: intimacy, goal: goal);
    _save();
  }

  void _save() {
    _storage.save(profile: _profile, weeks: _weeks);
    notifyListeners();
  }
}

/// 위젯 트리 어디서든 MissionScope.of(context)로 MissionStore를 꺼내기 위한 통로
class MissionScope extends InheritedNotifier<MissionStore> {
  const MissionScope({
    super.key,
    required MissionStore store,
    required super.child,
  }) : super(notifier: store);

  static MissionStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MissionScope>()!.notifier!;
  }
}
