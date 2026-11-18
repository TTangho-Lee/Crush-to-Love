// 가이드 규칙: 장소 · 날씨 · 친밀도 · 용기 → DateGuide
// 가짜: 장소 · 날씨만 바꾸고 내용은 예시 그대로
import '../../shared/models.dart';
import 'date_guide.dart';

DateGuide buildDateGuide({
  required String place,
  required String weather,
  required Profile profile,
}) {
  return DateGuide(place: place, weather: weather, items: fakeDateGuide.items);
}
