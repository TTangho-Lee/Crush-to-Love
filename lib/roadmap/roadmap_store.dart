// 미션 흐름 데이터 (상대별 로드맵), 화면에서는 RoadmapScope.of(context)
//   지금 상대(CrushStore)마다 로드맵 하나, 상대를 바꾸면 그 상대 로드맵으로
//   로드맵이 없으면 만들고, D-Day · 사이 · 목표 · 만남 빈도 · 용기 단계가 바뀌면 다시 짬 (완료한 미션은 남김)
//   진도 · 대화 분석(ChatStore · 분석 기록)에 맞춰 다음 주차를 자동 조정 (roadmap_rules.dart)
//   오늘의 미션: 규칙 점수가 높은 순, '↻ 다른 미션'으로 다음 순서 (오늘 · 상대마다 따로, 저장 안 함)
//   맞춤 추천(LearningStore, 켰을 때만 · 예시는 안 함, roadmap_learning.dart)
//     오늘의 미션: 학습 순서를 하루 · 후보가 같은 동안 고정 ('↻'로 배워도 순서가 안 흔들리게), 근거가 쌓이면 이유 줄도
//     주차 구성: 완료 기록이 쌓인 뒤(learnedWeekMinDone)에만 새 로드맵 · 다시 짜기 · 자동 조정 때 학습 순서로,
//       주차가 시작되고 아직 한 미션이 없으면 그 주차를 다시 고름 (그 전엔 지금 순서 그대로)
//     기록: 완료 · 완료 취소 · '↻' · 끝난 주차의 안 한 미션 (날이 바뀌면 checkDay)
//   지운 상대 로드맵은 DB에서도 지움, 보관한 상대 로드맵은 남김
//   지금 상대가 없으면(예시 화면) 피그마 예시처럼 D-20 · 첫 미션 완료 로드맵을 저장하지 않고 씀
//   바뀔 때마다 그 상대 로드맵만 저장 (RoadmapStorage, 앱은 RoadmapDb), 저장이 안 돼도 앱은 그대로 (Run 창에 출력)
// 순서: load()로 DB에서 불러온 뒤 attachLearning(학습) · attach(상대 목록) · attachChat(대화 분석) (main.dart)
import 'dart:async';

import 'package:flutter/widgets.dart';

import '../analysis/chat/chat_store.dart';
import '../analysis/chat/history/chat_history_db.dart';
import '../analysis/chat/history/chat_record.dart';
import '../learning/learning_store.dart';
import '../onboarding/data/crush_store.dart';
import '../shared/models.dart';
import 'roadmap_db.dart';
import 'roadmap_learning.dart';
import 'roadmap_models.dart';
import 'roadmap_rules.dart';
import 'roadmap_generator.dart';

/// 예시 로드맵의 상대 번호 (저장 안 함)
const _exampleId = 0;

/// 이보다 오래된 분석 기록은 신호로 안 씀
const _signalMaxAge = Duration(days: 30);

class RoadmapStore extends ChangeNotifier {
  RoadmapStore({
    RoadmapStorage? storage,
    DateTime Function()? clock,
    Future<List<ChatRecord>> Function()? loadHistory,
  })  : _storage = storage ?? const RoadmapDb(),
        _clock = clock ?? DateTime.now,
        _loadHistory = loadHistory ?? ChatHistoryDb.loadAll;

  final RoadmapStorage _storage;

  /// 오늘 (테스트는 고정한 날)
  final DateTime Function() _clock;
  final Future<List<ChatRecord>> Function() _loadHistory;

  CrushStore? _crushes;
  ChatStore? _chat;
  List<ChatRecord> _history = const [];

  /// 분석 기록을 읽었으면 true (대화 분석이 바뀌면 다시 읽음)
  bool _historyLoaded = false;
  final Map<int, Roadmap> _roadmaps = {};
  Profile? _exampleProfile;
  Roadmap? _example;

  /// '↻ 다른 미션'을 누른 횟수 (상대 번호 → (날짜, 횟수))
  final Map<int, (DateTime, int)> _rotation = {};

  LearningStore? _learning;

  /// 오늘 고정한 학습 순서 (상대 번호 → (날짜, 후보 · 학습 판, 미션 id 순서))
  final Map<int, (DateTime, String, List<String>)> _frozen = {};

  /// 마지막으로 날짜 확인(주차 판정 · 다시 고르기)을 한 날
  DateTime? _checkedDay;

  // ---------- 읽기 ----------

  /// 지금 상대가 없어서 예시 로드맵을 보여 주는 중이면 true
  bool get isExample => _crushes?.current == null;

  /// 지금 상대 입력값 + 내 용기 (예시면 예시 입력값)
  Profile get profile => _crushes?.profile ?? _exampleProfileOrNew;

  /// 지금 상대 로드맵 (예시면 예시 로드맵)
  Roadmap get roadmap {
    final crush = _crushes?.current;
    final saved = crush == null ? null : _roadmaps[crush.id];
    return saved ?? (_example ??= _newExample());
  }

  /// 이 상대의 로드맵이 있으면 (테스트 · 확인용)
  Roadmap? roadmapOf(int crushId) => _roadmaps[crushId];

  /// 지금 상대와의 대화 분석 신호, 없으면 null
  /// 이번에 켠 동안 분석한 대화면 추천 방향 · 사이까지, 아니면 지난 분석 기록(30일 안)의 점수만
  ChatSignal? get chatSignal {
    final crushes = _crushes;
    final crush = crushes?.current;
    if (crushes == null || crush == null) return null;

    final stats = _chat?.stats;
    final record = stats?.record;
    final insight = stats?.insight;
    if (stats != null &&
        !stats.isExample &&
        record != null &&
        insight != null &&
        crushes.chatBelongsToCurrent(record.partner)) {
      return ChatSignal(
        interest: insight.interest.level,
        approach: insight.approach,
        intimacy: insight.intimacy,
        lastTalkAt: record.lastMessageAt,
      );
    }

    final today = _clock();
    ChatRecord? latest;
    for (final r in _history) {
      if (!crush.chatNames.contains(r.partner)) continue;
      if (today.difference(r.analyzedAt) > _signalMaxAge) continue;
      if (latest == null || r.analyzedAt.isAfter(latest.analyzedAt)) latest = r;
    }
    if (latest == null) return null;
    return ChatSignal(
      interest: ChatSignal.levelOf(latest.score),
      lastTalkAt: latest.lastMessageAt,
    );
  }

  /// 지금 상황 (진척도 · 진도 · 대화 신호)
  MissionSituation get situation => readSituation(
        profile: profile,
        roadmap: roadmap,
        today: _clock(),
        chat: isExample ? null : chatSignal,
      );

  /// 홈 맨 위 한 줄 진단
  String get summary => summaryOf(situation, today: _clock());

  /// 맞춤 추천을 쓰는 중이면 true (학습을 붙였고 켰고 예시가 아님)
  bool get learns => _learning?.enabled == true && !isExample;

  /// 오늘의 미션 (규칙 · 학습 순서에서 '↻ 다른 미션' 횟수만큼 넘긴 것), 다 했으면 null
  TodayPick? get todayPick {
    final ranked = _ranked();
    if (ranked.isEmpty) return null;
    final pick = ranked[_rotationCount % ranked.length];
    final learning = _learning;
    return learns && learning != null
        ? explainPick(learning, pick, situation, now: _clock())
        : pick;
  }

  /// 오늘 할 만한 미션 전체 (규칙 · 학습 순서, 다 한 건 빠짐), 홈 목록 순서 · 고른 이유
  List<TodayPick> get ranked => _ranked();

  /// '↻ 다른 미션'으로 바꿀 후보가 있으면 true
  bool get canRotate => rankToday(situation, today: _clock()).length > 1;

  /// D-Day까지 남은 날 (20이면 'D-20', 지나면 음수)
  int get daysLeft => daysUntil(profile.dDay, now: _clock());

  /// 주차별 로드맵 (피그마 8번, 14~16번)
  List<RoadmapWeek> get weeks => roadmap.weeks;

  /// 지금 주차 (피그마 8번 분홍 카드), D-Day가 지났으면 마지막 주차
  RoadmapWeek get currentWeek => situation.week;

  /// 날짜 (D-n → 그날)
  DateTime dateOf(int dDayNumber) {
    final d = profile.dDay;
    return DateTime(d.year, d.month, d.day - dDayNumber);
  }

  // ---------- 바꾸기 ----------

  /// DB에서 전체 로드맵 불러오기 (앱을 켤 때 한 번, attach 전에)
  Future<void> load() async {
    for (final r in await _storage.loadAll()) {
      _roadmaps[r.crushId] = r;
    }
    notifyListeners();
  }

  /// 상대 목록에 붙이기: 지금 상대가 바뀌거나 정보가 바뀔 때마다 로드맵을 맞춤
  void attach(CrushStore crushes) {
    _crushes?.removeListener(_sync);
    _crushes = crushes;
    crushes.addListener(_sync);
    _sync();
  }

  /// 대화 분석에 붙이기: 분석이 바뀌면 분석 기록을 다시 읽고 다음 주차를 조정
  void attachChat(ChatStore chat) {
    _chat?.removeListener(_onChat);
    _chat = chat;
    chat.addListener(_onChat);
    _onChat();
  }

  /// 미션 완료 / 미완료 전환 (홈 '했어요' · 체크 칸, 14~16번 카드)
  Future<void> toggleMission(String missionId) async {
    final r = roadmap;
    final now = _clock();
    final maxLevel = courageMax(profile.courage);
    // 학습 기록은 바꾸기 전 상황으로
    final before = situation;
    final learning = isExample ? null : _learning;
    // ✕ 미션의 체크 칸: 다시 열기만 (완료 · 학습 기록 없음)
    if (r.weeks.any((w) => w.missions.any((m) => m.id == missionId && m.failed))) {
      await _put(r.copyWith(weeks: [
        for (final w in r.weeks)
          w.copyWith(missions: [
            for (final m in w.missions)
              m.id == missionId ? m.markFailed(false) : m,
          ]),
      ]));
      return;
    }
    final found = [
      for (final w in r.weeks)
        for (final m in w.missions)
          if (m.id == missionId) (m, w.stage),
    ];
    await _put(r.copyWith(weeks: [
      for (final w in r.weeks)
        w.copyWith(missions: [
          for (final m in w.missions)
            m.id == missionId
                ? m.mark(!m.done, at: now, brave: m.level > maxLevel)
                : m,
        ]),
    ]));
    if (learning != null && found.isNotEmpty) {
      final (m, stage) = found.first;
      if (m.done) {
        await recordUndo(learning, missionId, crushId: r.crushId);
      } else {
        await recordDone(
          learning,
          before,
          m,
          stage,
          crushId: r.crushId,
          now: now,
        );
      }
    }
    _adapt();
  }

  /// 맞춤 추천 붙이기 (attach 전에): 켜기/끄기 · 기록 지우기 · 시연 기록이 바뀌면 순서를 다시 계산
  void attachLearning(LearningStore learning) {
    _learning?.removeListener(_onLearning);
    _learning = learning;
    learning.addListener(_onLearning);
  }

  /// 날이 바뀌었으면 끝난 주차 판정 · 이번 주 다시 고르기 (앱을 켤 때 · 오늘의 미션을 볼 때)
  Future<void> checkDay() async {
    if (_checkedDay == _today) return;
    _checkedDay = _today;
    _recompose();
    await _judge();
  }

  /// 학습이 크게 바뀐 뒤(시연 기록 넣기) 이번 주를 학습 순서로 다시 고르고 순서를 새로 (아직 한 미션이 없을 때만)
  void refreshLearning() {
    _frozen.clear();
    _recompose(force: true);
    notifyListeners();
  }

  /// '못 했어요'를 누를 수 있으면 true (아직 안 한 미션)
  bool canReplace(String missionId) =>
      replaceMission(roadmap, profile: profile, missionId: missionId) != null;

  /// '못 했어요': 같은 단계의 더 어렵지 않은 미션으로 바꾸고, 2번 바꾼 자리 · 바꿀 게 없으면 ✕ (감점 없음, 학습엔 '↻'처럼 약한 −)
  Future<void> failMission(String missionId) async {
    final r = roadmap;
    final next = replaceMission(r, profile: profile, missionId: missionId);
    if (next == null) return;
    final learning = _learning;
    if (learns && learning != null) {
      final picks = _ranked().where((p) => p.mission.id == missionId);
      if (picks.isNotEmpty) {
        unawaited(recordSkip(
          learning,
          picks.first,
          situation,
          crushId: r.crushId,
          now: _clock(),
        ));
      }
    }
    await _put(next);
    _adapt();
  }

  /// '↻ 다른 미션' (보던 미션은 약한 −로 배움)
  void rotateToday() {
    final learning = _learning;
    final pick = todayPick;
    if (learns && learning != null && pick != null) {
      unawaited(recordSkip(
        learning,
        pick,
        situation,
        crushId: roadmap.crushId,
        now: _clock(),
      ));
    }
    _rotation[roadmap.crushId] = (_today, _rotationCount + 1);
    notifyListeners();
  }

  /// 예시 화면에서 '변경 저장하고 미션 다시 짜기' (저장 안 함)
  /// 실제 상대는 CrushStore.update · setCourage로 바꾸면 알아서 다시 짬
  void updateExample({
    required Intimacy intimacy,
    required Goal goal,
    required int courage,
  }) {
    final p = profile;
    final next = Profile(
      dDay: p.dDay,
      reason: p.reason,
      intimacy: intimacy,
      meetingsPerWeek: p.meetingsPerWeek,
      courage: courage,
      goal: goal,
    );
    _exampleProfile = next;
    _example = replanRoadmap(
      _example ?? _newExample(),
      profile: next,
      today: _clock(),
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _crushes?.removeListener(_sync);
    _chat?.removeListener(_onChat);
    _learning?.removeListener(_onLearning);
    super.dispose();
  }

  // ---------- 안쪽 ----------

  DateTime get _today {
    final t = _clock();
    return DateTime(t.year, t.month, t.day);
  }

  /// 오늘 이 상대에서 '↻ 다른 미션'을 누른 횟수 (날이 바뀌면 0)
  int get _rotationCount {
    final saved = _rotation[roadmap.crushId];
    return saved == null || saved.$1 != _today ? 0 : saved.$2;
  }

  /// 상대 목록이 바뀌면: 지운 상대 로드맵 지우기, 지금 상대 로드맵 만들기 · 다시 짜기 · 자동 조정
  void _sync() {
    final crushes = _crushes;
    if (crushes == null) return;
    final ids = {for (final c in crushes.all) c.id};
    for (final id in [..._roadmaps.keys]) {
      if (ids.contains(id)) continue;
      _roadmaps.remove(id);
      _quietly('로드맵 지우기', () => _storage.delete(id));
    }

    final crush = crushes.current;
    final profile = crushes.profile;
    if (crush != null && profile != null) {
      final old = _roadmaps[crush.id];
      if (old == null || old.planKey != roadmapPlanKey(profile)) {
        final plain = old == null
            ? buildRoadmap(
                crushId: crush.id,
                profile: profile,
                today: _clock(),
              )
            : replanRoadmap(old, profile: profile, today: _clock());
        final orderFor = _orderFor(crush.id, profile, plain);
        final next = orderFor == null
            ? plain
            : old == null
                ? buildRoadmap(
                    crushId: crush.id,
                    profile: profile,
                    today: _clock(),
                    orderFor: orderFor,
                  )
                : replanRoadmap(
                    old,
                    profile: profile,
                    today: _clock(),
                    orderFor: orderFor,
                  );
        _roadmaps[crush.id] = next;
        _quietly('로드맵 저장', () => _storage.save(next));
      }
      // 지금 상대가 있을 때만 분석 기록을 읽음 (예시 화면 · 테스트에선 DB를 안 엶)
      if (!_historyLoaded) _refreshHistory();
      // 상대가 바뀌면 그 상대로 날짜 확인을 다시
      _checkedDay = null;
      unawaited(checkDay());
    }
    _adapt(notify: false);
    notifyListeners();
  }

  void _onLearning() {
    notifyListeners();
  }

  /// 규칙 순서 (학습을 쓰면 오늘 고정한 학습 순서)
  List<TodayPick> _ranked() {
    final s = situation;
    final now = _clock();
    final rules = rankToday(s, today: now);
    final learning = _learning;
    if (!learns || learning == null || rules.length < 2) return rules;
    // 날이 바뀌었으면 화면을 그린 뒤 판정 · 다시 고르기
    if (_checkedDay != _today) scheduleMicrotask(checkDay);

    final crushId = roadmap.crushId;
    final ids = [for (final p in rules) p.mission.id]..sort();
    final key = '${ids.join(',')}|${learning.revision}';
    final saved = _frozen[crushId];
    final List<String> order;
    if (saved != null && saved.$1 == _today && saved.$2 == key) {
      order = saved.$3;
    } else {
      order = learnedTodayOrder(learning, rules, s, now: now, crushId: crushId);
      _frozen[crushId] = (_today, key, order);
    }
    final byId = {for (final p in rules) p.mission.id: p};
    return [
      for (final id in order) ?byId[id],
    ];
  }

  /// 주차 구성 학습 순서 (학습을 안 쓰거나 완료 기록이 적으면 null → 지금 순서)
  RoadmapOrder? _orderFor(int crushId, Profile profile, Roadmap plain) {
    final learning = _learning;
    if (learning == null || !learning.enabled || !canLearnWeeks(learning)) {
      return null;
    }
    final s = readSituation(
      profile: profile,
      roadmap: plain,
      today: _clock(),
      chat: chatSignal,
    );
    return (stage, weekNo) => learnedWeekOrder(
          learning,
          s,
          stage,
          crushId: crushId,
          weekNo: weekNo,
          today: _clock(),
        );
  }

  /// 주차가 시작되고 아직 한 미션이 없으면 그 주차를 학습 순서로 다시 고름 (주차마다 한 번)
  /// 처음 붙일 땐 지금 주차는 그대로 (이미 본 미션), force면 위치와 상관없이 (시연)
  void _recompose({bool force = false}) {
    final learning = _learning;
    final crush = _crushes?.current;
    final profile = _crushes?.profile;
    final old = crush == null ? null : _roadmaps[crush.id];
    if (learning == null || crush == null || profile == null || old == null) {
      return;
    }
    final s = situation;
    final week = s.week;
    final saved = int.tryParse(learning.meta(composedKey(crush.id)) ?? '');
    if (!force && saved != null && saved >= week.weekNo) return;
    unawaited(learning.setMeta(composedKey(crush.id), '${week.weekNo}'));
    if (!force && saved == null) return;
    if (!learning.enabled || !canLearnWeeks(learning)) return;
    if (s.passed || week.missions.any((m) => m.done)) return;
    final order = learnedWeekOrder(
      learning,
      s,
      week.stage,
      crushId: crush.id,
      weekNo: week.weekNo,
      today: _clock(),
    );
    final next = recomposeWeek(
      old,
      profile: profile,
      weekIndex: s.weekIndex,
      order: order,
    );
    _roadmaps[crush.id] = next;
    _quietly('로드맵 저장', () => _storage.save(next));
    notifyListeners();
  }

  /// 지금 상대의 끝난 주차 판정 (안 한 미션 → '안 함' 기록)
  Future<void> _judge() async {
    final learning = _learning;
    final crush = _crushes?.current;
    final profile = _crushes?.profile;
    final r = crush == null ? null : _roadmaps[crush.id];
    if (learning == null || crush == null || profile == null || r == null) {
      return;
    }
    await judgeEndedWeeks(
      learning,
      crushId: crush.id,
      profile: profile,
      roadmap: r,
      today: _clock(),
      chat: chatSignal,
    );
  }

  void _onChat() {
    _historyLoaded = false;
    _sync();
  }

  /// 분석 기록 다시 읽기 (분석 결과를 저장한 뒤라 조금 늦게 들어올 수 있음)
  Future<void> _refreshHistory() async {
    _historyLoaded = true;
    try {
      _history = await _loadHistory();
    } catch (e) {
      debugPrint('분석 기록 불러오기 실패: $e');
      return;
    }
    _adapt();
  }

  /// 진도 · 대화 신호로 다음 주차 조정 (지금 상대만, 예시는 안 함)
  void _adapt({bool notify = true}) {
    final crush = _crushes?.current;
    final old = crush == null ? null : _roadmaps[crush.id];
    if (old == null) return;
    final change = adaptShift(situation);
    if (change == null) return;
    final (shift, note) = change;
    final next = adaptRoadmap(
      old,
      profile: profile,
      today: _clock(),
      shift: shift,
      note: note,
      orderFor: _orderFor(old.crushId, profile, old),
    );
    _roadmaps[old.crushId] = next;
    _quietly('로드맵 저장', () => _storage.save(next));
    if (notify) notifyListeners();
  }

  /// 화면 먼저 바꾸고 저장 (예시는 저장 안 함)
  Future<void> _put(Roadmap r) async {
    if (r.crushId == _exampleId) {
      _example = r;
      notifyListeners();
      return;
    }
    _roadmaps[r.crushId] = r;
    notifyListeners();
    await _quietly('로드맵 저장', () => _storage.save(r));
  }

  Future<void> _quietly(String what, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('$what 실패: $e');
    }
  }

  Profile get _exampleProfileOrNew => _exampleProfile ??= Profile(
        dDay: _today.add(const Duration(days: 20)),
        reason: '종강',
        intimacy: Intimacy.smallTalk,
        meetingsPerWeek: 2,
        courage: 50,
        goal: Goal.friends,
      );

  /// 피그마 예시처럼 첫 미션만 완료한 로드맵
  Roadmap _newExample() {
    final r = buildRoadmap(
      crushId: _exampleId,
      profile: _exampleProfileOrNew,
      today: _clock(),
    );
    final first = r.weeks.first;
    return r.copyWith(weeks: [
      first.copyWith(missions: [
        for (var i = 0; i < first.missions.length; i++)
          i == 0
              ? first.missions[i].mark(true, at: _clock())
              : first.missions[i],
      ]),
      ...r.weeks.skip(1),
    ]);
  }
}

/// 위젯 트리 어디서든 RoadmapScope.of(context)로 RoadmapStore를 꺼내기 위한 통로
class RoadmapScope extends InheritedNotifier<RoadmapStore> {
  const RoadmapScope({
    super.key,
    required RoadmapStore store,
    required super.child,
  }) : super(notifier: store);

  static RoadmapStore of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<RoadmapScope>()!
        .notifier!;
  }
}
