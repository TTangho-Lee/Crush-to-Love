// 데이트 가이드 흐름의 데이터 (10번, 13번이 같이 씀)
// 화면에서는 DateScope.of(context)로 꺼내 씀
// 고른 조건은 앱을 켜 둔 동안만 기억 (저장 안 함)
// 맞춤 추천(attachLearning, 켰을 때만): 말해볼 문장(한마디 팁 · 대화 소재 질문 · 만난 뒤 톡)을 멘트 학습 순서로
//   가이드를 만들 때마다 순서를 정해 두고 '다른 추천 보기'로 다음 것, 복사하면 기록 (멘트 학습과 같은 분야 'line')
//   나머지 항목(OOTD · 코스 · 메뉴 · 분위기)은 고른 걸 알 수 있는 신호가 없어서 지금처럼 돌려 고름
import 'package:flutter/widgets.dart';

import '../../learning/learning_db.dart';
import '../../learning/learning_store.dart';
import '../../learning/line_features.dart';
import '../../learning/linear_ts.dart';
import '../chat/line_learning.dart';
import '../chat/rules/lines.dart';
import 'date_guide.dart';
import 'date_guide_rules.dart';

class DateStore extends ChangeNotifier {
  DateStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seed = _clock().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  final DateTime Function() _clock;
  DateChoice _choice = const DateChoice();
  DateGuide? _guide;
  GuideBasis? _basis;
  LearningStore? _learning;

  /// 날마다 다른 가이드가 나오게 오늘 날짜로 시작, '다른 추천 보기'마다 +1
  late int _seed;

  /// 가이드를 만든 뒤 '다른 추천 보기'를 누른 횟수 (말해볼 문장 학습 순서에서 몇 번째)
  int _round = 0;

  /// 이번 가이드의 말해볼 문장 학습 순서 (slot → 순서), 가이드를 새로 만들면 비움
  final Map<String, List<Line>> _orders = {};
  int _deckSeed = 0;

  /// 이번 가이드에서 복사해서 기록한 사전 문장 (한 번씩)
  final Set<String> _copied = {};

  /// 10번에서 고른 조건
  DateChoice get choice => _choice;

  /// 마지막으로 만든 가이드 (피그마 13번), 아직 안 만들었으면 null
  DateGuide? get guide => _guide;

  /// 맞춤 추천 붙이기 (main.dart)
  void attachLearning(LearningStore learning) => _learning = learning;

  /// 조건 바꾸기 (10번 칩)
  void choose(DateChoice choice) {
    _choice = choice;
    notifyListeners();
  }

  /// 지금 조건으로 가이드 만들기 (10번 '준비 가이드 보기')
  /// basis는 guideBasisOf(MissionScope.of(context).profile, ChatScope.of(context).stats)
  DateGuide build(GuideBasis basis) {
    _basis = basis;
    _round = 0;
    _orders.clear();
    _copied.clear();
    _deckSeed = _seed;
    return _rebuild(basis);
  }

  /// 같은 조건으로 다른 문장 고르기 (13번 '다른 추천 보기')
  void shuffle() {
    final basis = _basis;
    if (basis == null) return;
    _seed++;
    _round++;
    _rebuild(basis);
  }

  /// 말해볼 문장을 복사했을 때 (shown: 화면 글자), 가이드마다 한 문장에 한 번
  Future<void> recordSaying(String shown, {required int crushId}) async {
    final learning = _learning;
    final raw = _guide?.sayings[shown];
    if (learning == null || raw == null || !_copied.add(raw)) return;
    final arm = lineArmOf(Line(raw));
    await learning.record(
      domain: lineDomain,
      crushId: crushId,
      arm: arm.key,
      ctx: _context.toJson(arm),
      reward: rewardCopy,
      kind: LearnKind.copy,
    );
  }

  /// 기록 문맥: 만나는 시간 (낮 15시 · 저녁 21시, 만난 뒤 톡과 같게)
  LineContext get _context =>
      LineContext(hour: _choice.time == MeetTime.day ? 15 : 21);

  DateGuide _rebuild(GuideBasis basis) {
    final learning = _learning;
    final learns = learning != null && learning.enabled;
    final guide = buildDateGuide(
      choice: _choice,
      basis: basis,
      seed: _seed,
      now: _clock(),
      sayOrder: learns ? (slot, pool) => _order(learning, slot, pool, basis) : null,
      round: _round,
    );
    _guide = guide;
    notifyListeners();
    return guide;
  }

  /// 학습 점수 순 (같으면 지금처럼 돌려 고른 순서), 가이드마다 한 번 정해 둠
  List<Line> _order(
    LearningStore learning,
    String slot,
    List<Line> pool,
    GuideBasis basis,
  ) {
    final key = '$slot|${pool.length}|${pool.isEmpty ? '' : pool.first.text}';
    final saved = _orders[key];
    if (saved != null) return saved;
    final theta = learning.sampleOf(
      lineDomain,
      'guide|$_deckSeed|$slot|${basis.formal ? 1 : 0}',
    );
    final ctx = _context;
    final rows = <(double, int, Line)>[
      for (var i = 0; i < pool.length; i++)
        (
          dot(theta, lineFeatures(ctx, lineArmOf(pool[i]))),
          (i - _deckSeed) % pool.length,
          pool[i],
        ),
    ];
    rows.sort((a, b) {
      final byScore = b.$1.compareTo(a.$1);
      return byScore != 0 ? byScore : a.$2.compareTo(b.$2);
    });
    return _orders[key] = [for (final r in rows) r.$3];
  }
}

/// 위젯 트리 어디서든 DateScope.of(context)로 DateStore를 꺼내기 위한 통로
class DateScope extends InheritedNotifier<DateStore> {
  const DateScope({super.key, required DateStore store, required super.child})
      : super(notifier: store);

  static DateStore of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DateScope>()!.notifier!;
  }
}
