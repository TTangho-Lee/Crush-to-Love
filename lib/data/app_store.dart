import 'package:flutter/widgets.dart';

import '../models/mission.dart';
import '../models/target_profile.dart';
import '../services/mission_generator.dart';
import '../services/progress_calculator.dart';

/// 앱 상태. 지금은 메모리에만 저장(앱 종료 시 초기화).
/// TODO: drift(SQLite) 로컬 DB로 교체.
class AppStore extends ChangeNotifier {
  AppStore({
    MissionGenerator? generator,
    ProgressCalculator? progressCalculator,
  })  : _generator = generator ?? DummyMissionGenerator(),
        _progress = progressCalculator ?? ProgressCalculator();

  final MissionGenerator _generator;
  final ProgressCalculator _progress;

  TargetProfile? profile;
  Mission? currentMission;
  final List<Mission> pastMissions = [];
  final List<MissionResult> results = [];
  bool isGenerating = false;

  Future<void> saveProfile(TargetProfile newProfile) async {
    profile = newProfile.copyWith(
      progress: _progress.calculate(newProfile, results),
    );
    notifyListeners();
    if (currentMission == null) await generateNextMission();
  }

  Future<void> generateNextMission() async {
    final p = profile;
    if (p == null) return;
    isGenerating = true;
    notifyListeners();
    currentMission = await _generator.generate(p, results);
    isGenerating = false;
    notifyListeners();
  }

  /// 결과 기록 → 친밀도 재확인 반영 → 진척도 갱신 → 다음 미션.
  Future<void> submitResult(MissionResult result, int newIntimacy) async {
    final mission = currentMission;
    final p = profile;
    if (mission == null || p == null) return;

    pastMissions.add(mission.copyWith(
      status: result.success ? MissionStatus.success : MissionStatus.failed,
    ));
    results.add(result);
    currentMission = null;

    final updated = p.copyWith(intimacyLevel: newIntimacy);
    profile = updated.copyWith(progress: _progress.calculate(updated, results));
    notifyListeners();

    // TODO: 실패 시 원인별 미션 수정, 성공 시 피드백 생성
    await generateNextMission();
  }
}

/// 위젯 트리 어디서든 AppScope.of(context)로 접근.
class AppScope extends InheritedNotifier<AppStore> {
  const AppScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  }
}
