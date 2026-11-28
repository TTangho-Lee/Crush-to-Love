// 기기 안에서 배우는 추천의 데이터 (미션 · 멘트가 같이 씀), 화면에서는 LearningScope.of(context)
//   분야(LearnDomain)마다 선형 보상 모델 하나 (linear_ts.dart), 모델 = 사전 + 보상 기록의 합
//   기록(record) → 모델에 바로 반영 · 저장, 취소(cancel)는 같은 기록을 빼서 정확히 되돌림
//   상대를 지우면(forgetCrush · keepCrushes) 그 상대 기록 · meta를 지우고 처음부터 다시 계산 (그 상대에게서 배운 것도 사라짐)
//     상대 번호 0은 상대 없는 기록 (시연용 기록), '학습 기록 지우기'로만 지움
//   revision: 켜기/끄기 · 지우기 · 시연 기록처럼 크게 바뀔 때만 올라감 (쓰는 쪽이 고정해 둔 순서를 새로 계산)
//   끄면(enabled false) 기록하지 않고, 쓰는 쪽은 규칙 순서 그대로 (dummy_mission_learning.dart 등)
//   특징 버전이 바뀌면 저장해 둔 문맥으로 다시 계산 (문맥에 고른 것의 특징까지 저장해 둠)
//   저장이 안 돼도 앱은 그대로 (Run 창에 출력), 서버로 보내지 않음
// 순서: load() 뒤에 쓰기 (main.dart)
import 'package:flutter/widgets.dart';

import 'learning_db.dart';
import 'linear_ts.dart';

/// 학습 분야 하나 (특징 수 · 버전 · 사전 · 탐색 세기 · 특징 만들기)
abstract interface class LearnDomain {
  /// 'mission' · 'line'
  String get name;

  /// 특징 정의 버전 (바꾸면 저장한 기록으로 다시 계산)
  int get version;
  int get dim;

  /// 사전 평균 μ₀
  List<double> get priorMean;

  /// 사전 정밀도 λ (특징마다)
  List<double> get priorPrecision;

  /// 탐색 세기 v
  double get scale;

  /// 저장한 문맥 + 고른 것 → φ, 못 읽으면 null (그 기록은 안 씀)
  List<double>? featuresOf(Map<String, Object?> ctx, String arm);
}

/// 켜기/끄기 meta 이름
const _enabledKey = 'enabled';

/// 배운 특징 (이름, 가중치 μ − μ₀): (+ 큰 순, − 작은 순), 각각 최대 count개 ('학습한 내용' 화면)
///   labels에 있는 특징만, 근거(그 특징이 켜진 기록)가 없거나 |가중치| < minWeight면 빼고
///   거의 같은 가중치는 특징 순서로 (계산 오차로 순서가 흔들리지 않게)
(List<(String, double)>, List<(String, double)>) learnedTraits(
  LearningStore store,
  String domain, {
  required List<String> names,
  required Map<String, String> labels,
  double minWeight = 0.05,
  int count = 3,
}) {
  final d = store.domainOf(domain);
  final mu = store.meanOf(domain);
  final seen = <int>{};
  for (final e in store.events(domain: domain)) {
    final phi = d.featuresOf(e.ctx, e.arm);
    if (phi == null) continue;
    for (var i = 0; i < phi.length; i++) {
      if (phi[i] != 0) seen.add(i);
    }
  }
  final all = [
    for (var i = 0; i < names.length; i++)
      if (labels[names[i]] case final label?)
        if (seen.contains(i) && (mu[i] - d.priorMean[i]).abs() >= minWeight)
          (label, mu[i] - d.priorMean[i], i),
  ];
  int byWeight((String, double, int) a, (String, double, int) b, int sign) {
    final c = sign * ((a.$2 * 1e9).round() - (b.$2 * 1e9).round());
    return c != 0 ? c : a.$3 - b.$3;
  }

  final good = [for (final t in all) if (t.$2 > 0) t]
    ..sort((a, b) => byWeight(a, b, -1));
  final bad = [for (final t in all) if (t.$2 < 0) t]
    ..sort((a, b) => byWeight(a, b, 1));
  List<(String, double)> top(List<(String, double, int)> list) =>
      [for (final (label, w, _) in list.take(count)) (label, w)];
  return (top(good), top(bad));
}

class LearningStore extends ChangeNotifier {
  LearningStore({
    LearningStorage? storage,
    required List<LearnDomain> domains,
    DateTime Function()? clock,
  })  : _storage = storage ?? const LearningDb(),
        _clock = clock ?? DateTime.now,
        _domains = {for (final d in domains) d.name: d};

  final LearningStorage _storage;
  final DateTime Function() _clock;
  final Map<String, LearnDomain> _domains;

  final List<LearnEvent> _events = [];
  final Map<String, LinearModel> _models = {};
  final Map<String, String> _meta = {};
  bool _enabled = true;
  int _revision = 0;

  // ---------- 읽기 ----------

  /// 맞춤 추천을 켰으면 true (끄면 규칙 그대로)
  bool get enabled => _enabled;

  /// 크게 바뀐 횟수 (켜기/끄기 · 지우기 · 시연 기록 · 불러오기)
  int get revision => _revision;

  /// 취소 안 된 보상 기록 (취소 기록 · 취소된 기록 빼고)
  List<LearnEvent> events({String? domain, int? crushId}) {
    final cancelled = {
      for (final e in _events)
        if (e.kind == LearnKind.cancel) e.ref,
    };
    return [
      for (final e in _events)
        if (e.kind != LearnKind.cancel &&
            !cancelled.contains(e.id) &&
            (domain == null || e.domain == domain) &&
            (crushId == null || e.crushId == crushId))
          e,
    ];
  }

  /// 분야 설정
  LearnDomain domainOf(String domain) => _domains[domain]!;

  /// 지금 모델 (사전 + 기록)
  LinearModel modelOf(String domain) =>
      _models[domain] ??= _rebuild(_domains[domain]!);

  /// 사후 평균 μ
  List<double> meanOf(String domain) => modelOf(domain).mean();

  /// 사후에서 하나 뽑기, 같은 seed 글자 · 같은 기록이면 같은 값
  List<double> sampleOf(String domain, String seedKey) =>
      modelOf(domain).sample(
        LearnRng(fnv1a('$domain|$seedKey')),
        _domains[domain]!.scale,
      );

  /// 배워서 달라진 몫 (μ − μ₀)·φ, 특징마다
  List<double> learnedPart(String domain, List<double> phi) {
    final d = _domains[domain]!;
    final mu = meanOf(domain);
    return [
      for (var i = 0; i < d.dim; i++) (mu[i] - d.priorMean[i]) * phi[i],
    ];
  }

  /// 이 특징이 켜진 채 보상이 +였던 기록 수 (설명 근거)
  int evidence(String domain, int feature, {Set<LearnKind>? kinds}) {
    final d = _domains[domain]!;
    var n = 0;
    for (final e in events(domain: domain)) {
      if (e.reward <= 0 || (kinds != null && !kinds.contains(e.kind))) continue;
      final phi = d.featuresOf(e.ctx, e.arm);
      if (phi != null && phi[feature] != 0) n++;
    }
    return n;
  }

  String? meta(String key) => _meta[key];

  // ---------- 바꾸기 ----------

  /// DB에서 기록 · 모델 캐시 · 설정 불러오기 (앱을 켤 때 한 번)
  Future<void> load() async {
    _events
      ..clear()
      ..addAll(await _storage.loadEvents());
    _meta
      ..clear()
      ..addAll(await _storage.loadMeta());
    _enabled = _meta[_enabledKey] != '0';
    _models.clear();
    for (final d in _domains.values) {
      final saved = await _storage.loadModel(d.name);
      final last = _lastId(d.name);
      if (saved != null &&
          saved.version == d.version &&
          saved.lastEvent == last &&
          saved.model.dim == d.dim) {
        _models[d.name] = saved.model;
      } else {
        _models[d.name] = _rebuild(d);
        await _quietly('모델 저장', () => _saveModel(d));
      }
    }
    _revision++;
    notifyListeners();
  }

  /// 맞춤 추천 켜기/끄기 (기록은 그대로)
  Future<void> setEnabled(bool on) async {
    if (_enabled == on) return;
    _enabled = on;
    _revision++;
    notifyListeners();
    await _quietly('설정 저장', () => _storage.setMeta(_enabledKey, on ? '1' : '0'));
  }

  /// 보상 기록 하나, 꺼져 있거나 특징을 못 만들면 null
  Future<LearnEvent?> record({
    required String domain,
    required int crushId,
    required String arm,
    required Map<String, Object?> ctx,
    required double reward,
    required LearnKind kind,
  }) async {
    if (!_enabled) return null;
    final d = _domains[domain]!;
    final phi = d.featuresOf(ctx, arm);
    if (phi == null) return null;
    final event = LearnEvent(
      domain: domain,
      crushId: crushId,
      arm: arm,
      ctx: ctx,
      reward: reward,
      kind: kind,
      at: _clock(),
    );
    return _add(event, phi);
  }

  /// 앞 기록 취소 (완료 취소 · 정정), 이미 취소했으면 그대로
  /// 꺼져 있어도 취소는 함 (켜 둔 동안 남긴 기록을 바로잡기)
  Future<void> cancel(LearnEvent event) async {
    final id = event.id;
    if (id == null || event.kind == LearnKind.cancel) return;
    if (_events.any((e) => e.kind == LearnKind.cancel && e.ref == id)) return;
    final phi = _domains[event.domain]?.featuresOf(event.ctx, event.arm);
    if (phi == null) return;
    await _add(
      LearnEvent(
        domain: event.domain,
        crushId: event.crushId,
        arm: event.arm,
        ctx: event.ctx,
        reward: event.reward,
        weight: -1,
        kind: LearnKind.cancel,
        at: _clock(),
        ref: id,
      ),
      phi,
    );
  }

  /// 작은 값 저장 (주차 판정 위치 등), null이면 지움
  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      _meta.remove(key);
    } else {
      _meta[key] = value;
    }
    await _quietly('설정 저장', () => _storage.setMeta(key, value));
  }

  /// 상대를 지울 때: 그 상대 기록 · meta('…:상대 번호')를 지우고 모든 분야를 다시 계산
  Future<void> forgetCrush(int crushId) async {
    final keys = [for (final k in _meta.keys) if (k.endsWith(':$crushId')) k];
    for (final k in keys) {
      _meta.remove(k);
    }
    final had = _events.any((e) => e.crushId == crushId);
    if (had) {
      _events.removeWhere((e) => e.crushId == crushId);
      _models.clear();
    }
    _revision++;
    notifyListeners();
    await _quietly('상대 학습 지우기', () async {
      for (final k in keys) {
        await _storage.setMeta(k, null);
      }
      if (!had) return;
      await _storage.deleteCrush(crushId);
      for (final d in _domains.values) {
        await _saveModel(d);
      }
    });
  }

  /// 이 상대들만 남기기 (상대 목록이 바뀔 때, 0은 남김)
  Future<void> keepCrushes(Set<int> crushIds) async {
    final gone = {
      for (final e in _events)
        if (e.crushId != 0 && !crushIds.contains(e.crushId)) e.crushId,
      for (final k in _meta.keys)
        if (_crushOfKey(k) case final id?)
          if (id != 0 && !crushIds.contains(id)) id,
    };
    for (final id in gone) {
      await forgetCrush(id);
    }
  }

  /// 여러 기록을 넣은 뒤 (시연 기록) 쓰는 쪽에 크게 바뀌었다고 알림
  void touch() {
    _revision++;
    notifyListeners();
  }

  /// 학습 기록 지우기 (설정): 기록 · 모델 · 판정 위치를 지우고 켜기/끄기만 남김
  Future<void> clear() async {
    _events.clear();
    _models.clear();
    final keys = [for (final k in _meta.keys) if (k != _enabledKey) k];
    for (final k in keys) {
      _meta.remove(k);
    }
    _revision++;
    notifyListeners();
    await _quietly('학습 기록 지우기', () async {
      await _storage.clear();
      for (final k in keys) {
        await _storage.setMeta(k, null);
      }
    });
  }

  // ---------- 안쪽 ----------

  /// 'judged:3' → 3, 상대 meta가 아니면 null
  static int? _crushOfKey(String key) {
    final i = key.lastIndexOf(':');
    return i < 0 ? null : int.tryParse(key.substring(i + 1));
  }

  Future<LearnEvent> _add(LearnEvent event, List<double> phi) async {
    var saved = event;
    try {
      saved = await _storage.addEvent(event);
    } catch (e) {
      // 저장이 안 돼도 이번에 켠 동안은 배움 (번호는 메모리에서)
      debugPrint('학습 기록 저장 실패: $e');
      saved = event.withId(-(_events.length + 1));
    }
    _events.add(saved);
    modelOf(saved.domain).update(phi, saved.reward, weight: saved.weight);
    notifyListeners();
    await _quietly('모델 저장', () => _saveModel(_domains[saved.domain]!));
    return saved;
  }

  LinearModel _rebuild(LearnDomain d) {
    final model = LinearModel.prior(d.priorMean, d.priorPrecision);
    for (final e in _events) {
      if (e.domain != d.name) continue;
      final phi = d.featuresOf(e.ctx, e.arm);
      if (phi == null) continue;
      model.update(phi, e.reward, weight: e.weight);
    }
    return model;
  }

  int _lastId(String domain) => _events.fold(
        0,
        (m, e) => e.domain == domain && (e.id ?? 0) > m ? e.id! : m,
      );

  Future<void> _saveModel(LearnDomain d) => _storage.saveModel(
        d.name,
        SavedModel(
          version: d.version,
          lastEvent: _lastId(d.name),
          model: modelOf(d.name),
        ),
      );

  Future<void> _quietly(String what, Future<void> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('$what 실패: $e');
    }
  }
}

/// 위젯 트리 어디서든 LearningScope.of(context)로 LearningStore를 꺼내기 위한 통로
class LearningScope extends InheritedNotifier<LearningStore> {
  const LearningScope({
    super.key,
    required LearningStore store,
    required super.child,
  }) : super(notifier: store);

  static LearningStore of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LearningScope>()!
        .notifier!;
  }

  static LearningStore? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<LearningScope>()
        ?.notifier;
  }
}
