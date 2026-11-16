import '../models/mission.dart';
import '../models/target_profile.dart';

/// 미션 생성기 인터페이스.
/// 구현 예정: 규칙 엔진(템플릿 필터링·점수화) + LLM(서버 경유, 요약값만 전송) 하이브리드.
abstract class MissionGenerator {
  Future<Mission> generate(TargetProfile profile, List<MissionResult> history);
}

/// 골격용: 미션 1, 미션 2 ... 순서대로 반환.
class DummyMissionGenerator implements MissionGenerator {
  static const _defaultDays = 5;

  @override
  Future<Mission> generate(
    TargetProfile profile,
    List<MissionResult> history,
  ) async {
    final now = DateTime.now();
    var deadline = now.add(const Duration(days: _defaultDays));
    // 마감일 = min(오늘 + 기본일수, 만날 수 있는 기간 종료일)
    final end = profile.periodEnd;
    if (end != null && end.isBefore(deadline)) deadline = end;

    final n = history.length + 1;
    return Mission(
      id: now.microsecondsSinceEpoch.toString(),
      title: '미션 $n',
      situation: '미션 $n 상황 예시',
      scripts: [for (var i = 1; i <= 3; i++) '미션 $n 멘트 예시 $i'],
      caution: '미션 $n 주의사항 예시',
      deadline: deadline,
      difficulty: 2,
    );
  }
}
