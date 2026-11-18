// 데이트 가이드 흐름의 데이터 (10번, 13번이 같이 씀)
// 화면에서는 DateScope.of(context)로 꺼내 씀
import 'package:flutter/widgets.dart';

import '../../shared/models.dart';
import 'date_guide.dart';
import 'date_guide_rules.dart';

class DateStore extends ChangeNotifier {
  DateGuide _guide = fakeDateGuide;

  /// 마지막 데이트 가이드 (피그마 13번), 지금 고른 장소 · 날씨도 여기
  DateGuide get guide => _guide;

  /// 데이트 가이드 만들기 (피그마 10번 '준비 가이드 보기')
  /// profile은 MissionScope.of(context).profile을 넘기기 (친밀도 · 용기 반영용)
  DateGuide build({
    required String place,
    required String weather,
    required Profile profile,
  }) {
    _guide = buildDateGuide(place: place, weather: weather, profile: profile);
    notifyListeners();
    return _guide;
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
