// 늦게 오는 보상: 같은 상대를 다시 분석했을 때 호감 신호 점수가 오르거나 내리면
//   그 사이 완료한 연락 미션(혼자 준비만 하는 미션 빼고)에 clip(Δ/20, ±0.5) ÷ 미션 수 (원래 완료 기록의 문맥 · 미션 그대로)
//   그 사이 복사한 멘트에도 같은 몫을 따로 ÷ 멘트 수 (분야마다 모델이 따로라 나누지 않음)
//   새 대화(마지막 메시지 시각이 더 뒤)일 때만, 예시 결과 · 어느 상대인지 모르는 대화는 안 봄
//   상대별 마지막 분석은 meta 'chat:<상대 번호>' = 점수|마지막 메시지 시각|분석 시각 (숫자만, 대화 글자 없음)
//   대화 분석(ChatStore) · 상대 연결(CrushStore)이 바뀔 때마다 확인 (main.dart)
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../analysis/chat/chat_store.dart';
import '../onboarding/data/crush_store.dart';
import 'learning_db.dart';
import 'learning_store.dart';
import 'line_features.dart';
import 'mission_features.dart';

/// 점수 변화 Δ를 보상으로 바꾸는 나눗수 · 최대 (tool/learning/simulate.py chat_div · chat_cap)
const chatRewardScale = 20.0;
const chatRewardCap = 0.5;

/// 상대별 마지막 분석 meta 이름
String chatKey(int crushId) => 'chat:$crushId';

/// 기록 문맥 속 미션이 연락 미션이면 true (태그 중 혼자 준비 말고 다른 게 있음)
bool _contact(Map<String, Object?> ctx) {
  final tags = ctx['tags'];
  return tags is List && tags.any((t) => t != 'prep');
}

/// 분석 결과 하나 반영, 보상을 나눠 준 기록 수 (미션 + 멘트)
Future<int> rewardChatDelta(
  LearningStore learning, {
  required int crushId,
  required int score,
  required DateTime lastMessageAt,
  required DateTime analyzedAt,
}) async {
  final key = chatKey(crushId);
  final saved = learning.meta(key)?.split('|');
  final prevScore = saved == null ? null : int.tryParse(saved.first);
  final prevLast = saved == null || saved.length < 3
      ? null
      : DateTime.tryParse(saved[1]);
  final prevAt = saved == null || saved.length < 3
      ? null
      : DateTime.tryParse(saved[2]);
  // 같은 대화 · 더 옛 대화를 다시 분석했으면 그대로
  if (prevLast != null && !lastMessageAt.isAfter(prevLast)) return 0;
  // 먼저 기록해 둠 (알림이 겹쳐 와도 한 번만)
  final pending = learning.setMeta(
    key,
    '$score|${lastMessageAt.toIso8601String()}|${analyzedAt.toIso8601String()}',
  );
  if (prevScore == null || prevAt == null || score == prevScore) {
    await pending;
    return 0;
  }
  final total = ((score - prevScore) / chatRewardScale)
      .clamp(-chatRewardCap, chatRewardCap)
      .toDouble();
  final missions = [
    for (final e in learning.events(domain: missionDomain, crushId: crushId))
      if (e.kind == LearnKind.done && e.at.isAfter(prevAt) && _contact(e.ctx)) e,
  ];
  final lines = [
    for (final e in learning.events(domain: lineDomain, crushId: crushId))
      if (e.kind == LearnKind.copy && e.at.isAfter(prevAt)) e,
  ];
  for (final group in [missions, lines]) {
    for (final e in group) {
      await learning.record(
        domain: e.domain,
        crushId: crushId,
        arm: e.arm,
        ctx: e.ctx,
        reward: total / group.length,
        kind: LearnKind.chat,
      );
    }
  }
  await pending;
  return missions.length + lines.length;
}

/// 대화 분석 · 상대 연결을 지켜보다가 rewardChatDelta
class ChatReward {
  ChatReward({
    required this.learning,
    required this.crushes,
    required this.chat,
  });

  final LearningStore learning;
  final CrushStore crushes;
  final ChatStore chat;

  void attach() {
    chat.addListener(_check);
    crushes.addListener(_check);
    _check();
  }

  void dispose() {
    chat.removeListener(_check);
    crushes.removeListener(_check);
  }

  void _check() {
    final stats = chat.stats;
    final record = stats.record;
    if (stats.isExample || record == null) return;
    final crush = crushes.crushForChatName(record.partner) ??
        (crushes.chatBelongsToCurrent(record.partner) ? crushes.current : null);
    if (crush == null) return;
    unawaited(
      rewardChatDelta(
        learning,
        crushId: crush.id,
        score: record.score,
        lastMessageAt: record.lastMessageAt,
        analyzedAt: record.analyzedAt,
      ).catchError((Object e) {
        debugPrint('대화 보상 실패: $e');
        return 0;
      }),
    );
  }
}
