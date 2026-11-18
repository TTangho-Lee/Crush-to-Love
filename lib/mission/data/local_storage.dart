// 로컬 저장소 (DB)
// 가짜: 아직 아무것도 저장하지 않음
import '../../shared/models.dart';
import 'mission_models.dart';

class LocalStorage {
  /// 프로필과 로드맵(미션 완료 기록 포함) 저장
  Future<void> save({
    required Profile profile,
    required List<WeekPlan> weeks,
  }) async {}

  /// 저장된 프로필 불러오기, 없으면 null
  Future<Profile?> loadProfile() async => null;

  /// 저장된 로드맵 불러오기, 없으면 null
  Future<List<WeekPlan>?> loadWeeks() async => null;
}
