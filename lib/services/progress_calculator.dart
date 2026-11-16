import 'dart:math' as math;

import '../config/level_texts.dart';
import '../models/mission.dart';
import '../models/target_profile.dart';

/// 관계 진척도(0~100) 계산.
/// TODO: 친밀도, 미션 성공률, 반응 지표 추세, 목표와의 거리 가중합으로 교체.
class ProgressCalculator {
  int calculate(TargetProfile profile, List<MissionResult> results) {
    final maxLevel = intimacyLevelTexts.length;
    final base = ((profile.intimacyLevel - 1) / (maxLevel - 1) * 60).round();
    final successCount = results.where((r) => r.success).length;
    return math.min(100, math.max(0, base + successCount * 5));
  }
}
