// 시연용 가상 기록 (디버그 빌드 '학습한 내용' 화면의 '시연용 기록 넣기'), tool/learning/make_demo.py로 만듦 — 직접 고치지 말 것
//   가상 사용자 '온라인파' 7주 기록 29개: 직접 만나는 미션 · 혼자 준비 미션은 잘 안 하고, 톡으로 반응 · 질문하는 미션을 잘 함
//   상대 번호 0으로 넣음 (상대를 지워도 남고, '학습 기록 지우기'로 지움), 꺼져 있으면 켜고 넣음
import 'learning_db.dart';
import 'learning_store.dart';
import 'mission_features.dart';

/// (미션 id, 종류, 보상, 문맥)
const _records = <(String, LearnKind, double, Map<String, Object?>)>[
  ('topic-2', LearnKind.done, 1.0, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.0625, 'weekday': 4, 'hour': 19, 'lv': 2, 'off': false, 'tags': ['ask']}),
  ('topic-4', LearnKind.done, 1.0, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.0625, 'weekday': 4, 'hour': 19, 'lv': 2, 'off': false, 'tags': ['ask']}),
  ('topic-8', LearnKind.missed, -0.5, {'rule': 5.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.125, 'rest': 3, 'gap': 3, 'interest': 'mid', 'lv': 2, 'off': false, 'tags': ['prep', 'push']}),
  ('topic-5', LearnKind.skip, -0.2, {'rule': 3.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.145833, 'rest': 4, 'gap': 4, 'interest': 'mid', 'weekday': 1, 'hour': 16, 'lv': 2, 'off': true, 'tags': ['greet', 'ask']}),
  ('topic-1', LearnKind.done, 1.0, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.145833, 'rest': 4, 'gap': 4, 'interest': 'mid', 'weekday': 1, 'hour': 16, 'lv': 2, 'off': false, 'tags': ['react', 'ask']}),
  ('topic-5', LearnKind.skip, -0.2, {'rule': 3.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.166667, 'rest': 1, 'gap': 5, 'interest': 'mid', 'weekday': 2, 'hour': 11, 'lv': 2, 'off': true, 'tags': ['greet', 'ask']}),
  ('topic-6', LearnKind.done, 1.0, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.166667, 'rest': 1, 'gap': 5, 'interest': 'mid', 'weekday': 2, 'hour': 11, 'lv': 2, 'off': false, 'tags': ['ask']}),
  ('topic-1', LearnKind.chat, 0.15, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.145833, 'rest': 4, 'gap': 4, 'interest': 'mid', 'weekday': 1, 'hour': 16, 'lv': 2, 'off': false, 'tags': ['react', 'ask']}),
  ('topic-6', LearnKind.chat, 0.15, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.166667, 'rest': 1, 'gap': 5, 'interest': 'mid', 'weekday': 2, 'hour': 11, 'lv': 2, 'off': false, 'tags': ['ask']}),
  ('topic-5', LearnKind.missed, -0.5, {'rule': 3.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.270833, 'rest': 5, 'gap': 5, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['greet', 'ask']}),
  ('follow-5', LearnKind.done, 1.0, {'rule': 5.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.291667, 'rest': 6, 'gap': 6, 'interest': 'mid', 'weekday': 1, 'hour': 11, 'lv': 2, 'off': false, 'tags': ['ask', 'care']}),
  ('follow-1', LearnKind.done, 1.0, {'rule': 5.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.375, 'rest': 4, 'gap': 10, 'interest': 'mid', 'weekday': 5, 'hour': 13, 'lv': 2, 'off': false, 'tags': ['share', 'push']}),
  ('follow-5', LearnKind.chat, -0.025, {'rule': 5.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.291667, 'rest': 6, 'gap': 6, 'interest': 'mid', 'weekday': 1, 'hour': 11, 'lv': 2, 'off': false, 'tags': ['ask', 'care']}),
  ('follow-1', LearnKind.chat, -0.025, {'rule': 5.0, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.375, 'rest': 4, 'gap': 10, 'interest': 'mid', 'weekday': 5, 'hour': 13, 'lv': 2, 'off': false, 'tags': ['share', 'push']}),
  ('follow-3', LearnKind.missed, -0.5, {'rule': 1.5, 'maxLv': 2, 'pace': 'onTrack', 'meet': 2, 'elapsed': 0.416667, 'rest': 2, 'gap': 2, 'interest': 'mid', 'lv': 2, 'off': false, 'tags': ['share']}),
  ('often-3', LearnKind.missed, -0.5, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.5625, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': false, 'tags': ['care']}),
  ('often-6', LearnKind.missed, -0.5, {'rule': 5.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.5625, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['greet', 'ask']}),
  ('often-7', LearnKind.missed, -0.5, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.5625, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': false, 'tags': ['care', 'push']}),
  ('plan-1', LearnKind.done, 1.0, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.625, 'rest': 12, 'gap': 12, 'interest': 'mid', 'weekday': 3, 'hour': 15, 'lv': 2, 'off': false, 'tags': ['invite']}),
  ('plan-4', LearnKind.skip, -0.2, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.645833, 'rest': 1, 'gap': 13, 'interest': 'mid', 'weekday': 4, 'hour': 15, 'lv': 2, 'off': true, 'tags': ['greet', 'invite']}),
  ('plan-6', LearnKind.done, 1.0, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.666667, 'rest': 2, 'gap': 14, 'interest': 'mid', 'weekday': 5, 'hour': 20, 'lv': 2, 'off': false, 'tags': ['care']}),
  ('plan-4', LearnKind.missed, -0.5, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.708333, 'rest': 2, 'gap': 16, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['greet', 'invite']}),
  ('plan-1', LearnKind.chat, 0.1, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.625, 'rest': 12, 'gap': 12, 'interest': 'mid', 'weekday': 3, 'hour': 15, 'lv': 2, 'off': false, 'tags': ['invite']}),
  ('plan-6', LearnKind.chat, 0.1, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.666667, 'rest': 2, 'gap': 14, 'interest': 'mid', 'weekday': 5, 'hour': 20, 'lv': 2, 'off': false, 'tags': ['care']}),
  ('alone-0', LearnKind.skip, -0.2, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.854167, 'rest': 9, 'gap': 9, 'interest': 'mid', 'weekday': 7, 'hour': 20, 'lv': 2, 'off': true, 'tags': ['invite']}),
  ('alone-0', LearnKind.missed, -0.5, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.854167, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['invite']}),
  ('alone-4', LearnKind.missed, -0.5, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.854167, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['invite']}),
  ('alone-5', LearnKind.missed, -0.5, {'rule': 3.6, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.854167, 'rest': 9, 'gap': 9, 'interest': 'mid', 'lv': 2, 'off': true, 'tags': ['care']}),
  ('show-0', LearnKind.done, 1.0, {'rule': 2.1, 'maxLv': 2, 'pace': 'behind', 'meet': 2, 'elapsed': 0.875, 'rest': 10, 'gap': 10, 'interest': 'mid', 'weekday': 1, 'hour': 19, 'lv': 2, 'off': false, 'tags': ['express']}),
];

/// 시연용 기록 수
int get demoRecordCount => _records.length;

/// 시연용 기록 넣기, 넣은 수를 돌려줌
Future<int> seedDemoRecords(LearningStore store) async {
  if (!store.enabled) await store.setEnabled(true);
  var n = 0;
  for (final (arm, kind, reward, ctx) in _records) {
    final saved = await store.record(
      domain: missionDomain,
      crushId: 0,
      arm: arm,
      ctx: ctx,
      reward: reward,
      kind: kind,
    );
    if (saved != null) n++;
  }
  store.touch();
  return n;
}
