// 데이트 가이드 흐름의 데이터 (10번, 13번이 같이 씀)
// 화면에서는 DateScope.of(context)로 꺼내 씀
// 고른 조건은 앱을 켜 둔 동안만 기억 (저장 안 함)
import 'package:flutter/widgets.dart';

import 'date_guide.dart';
import 'date_guide_rules.dart';

class DateStore extends ChangeNotifier {
  DateChoice _choice = const DateChoice();
  DateGuide? _guide;
  GuideBasis? _basis;

  /// 날마다 다른 가이드가 나오게 오늘 날짜로 시작, '다른 추천 보기'마다 +1
  int _seed = DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  /// 10번에서 고른 조건
  DateChoice get choice => _choice;

  /// 마지막으로 만든 가이드 (피그마 13번), 아직 안 만들었으면 null
  DateGuide? get guide => _guide;

  /// 조건 바꾸기 (10번 칩)
  void choose(DateChoice choice) {
    _choice = choice;
    notifyListeners();
  }

  /// 지금 조건으로 가이드 만들기 (10번 '준비 가이드 보기')
  /// basis는 guideBasisOf(MissionScope.of(context).profile, ChatScope.of(context).stats)
  DateGuide build(GuideBasis basis) {
    _basis = basis;
    return _rebuild(basis);
  }

  /// 같은 조건으로 다른 문장 고르기 (13번 '다른 추천 보기')
  void shuffle() {
    final basis = _basis;
    if (basis == null) return;
    _seed++;
    _rebuild(basis);
  }

  DateGuide _rebuild(GuideBasis basis) {
    final guide = buildDateGuide(choice: _choice, basis: basis, seed: _seed);
    _guide = guide;
    notifyListeners();
    return guide;
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
