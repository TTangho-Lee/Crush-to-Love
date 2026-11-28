// 마지막 보상: 짝사랑 결과(피그마 17번, 설정 '결과')를 고르면 그 상대와 완료한 미션 기록마다
//   성공 +0.3 · 실패 −0.1 (원래 완료 기록의 문맥 · 미션 그대로, 실패는 미션 탓이 아닐 수 있어서 작게)
//   결과를 바꾸면 앞 결과 보상을 빼고 새로, 상대별 반영한 결과는 meta 'outcome:<상대 번호>'
//   한 상대에 한 번뿐인 보상이라 크기는 시뮬레이션으로 정하지 않고 작게 둠
//   상대 목록(CrushStore)이 바뀔 때마다 확인 (main.dart)
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../onboarding/data/crush_store.dart';
import '../shared/models.dart';
import 'learning_db.dart';
import 'learning_store.dart';
import 'mission_features.dart';

/// 결과 보상
const outcomeRewardSuccess = 0.3;
const outcomeRewardFail = -0.1;

/// 상대별 반영한 결과 meta 이름
String outcomeKey(int crushId) => 'outcome:$crushId';

/// 결과 하나 반영, 보상을 준 기록 수 (이미 반영한 결과면 0)
Future<int> rewardOutcome(
  LearningStore learning, {
  required int crushId,
  required CrushOutcome? outcome,
}) async {
  final key = outcomeKey(crushId);
  final name = outcome?.name;
  if (learning.meta(key) == name) return 0;
  // 먼저 기록해 둠 (알림이 겹쳐 와도 한 번만)
  final pending = learning.setMeta(key, name);
  final mine = learning.events(domain: missionDomain, crushId: crushId);
  for (final e in mine) {
    if (e.kind == LearnKind.outcome) await learning.cancel(e);
  }
  if (outcome == null) {
    await pending;
    return 0;
  }
  final reward = outcome == CrushOutcome.success
      ? outcomeRewardSuccess
      : outcomeRewardFail;
  final done = [
    for (final e in mine)
      if (e.kind == LearnKind.done) e,
  ];
  for (final e in done) {
    await learning.record(
      domain: e.domain,
      crushId: crushId,
      arm: e.arm,
      ctx: e.ctx,
      reward: reward,
      kind: LearnKind.outcome,
    );
  }
  await pending;
  return done.length;
}

/// 상대 목록을 지켜보다가 결과가 정해지거나 바뀌면 rewardOutcome
class OutcomeReward {
  OutcomeReward({required this.learning, required this.crushes});

  final LearningStore learning;
  final CrushStore crushes;

  void attach() {
    crushes.addListener(_check);
    _check();
  }

  void dispose() => crushes.removeListener(_check);

  void _check() {
    for (final c in crushes.all) {
      final outcome = c.outcome;
      if (learning.meta(outcomeKey(c.id)) == outcome?.name) continue;
      unawaited(
        rewardOutcome(learning, crushId: c.id, outcome: outcome)
            .catchError((Object e) {
          debugPrint('결과 보상 실패: $e');
          return 0;
        }),
      );
    }
  }
}
