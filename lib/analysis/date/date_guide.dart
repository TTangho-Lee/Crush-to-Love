// 데이트 가이드 흐름의 데이터 모양

/// 데이트 장소 유형 (피그마 10번)
const datePlaces = ['캠퍼스', '감성 카페', '전시회'];

/// 데이트 날씨 (피그마 10번)
const dateWeathers = ['맑음', '비', '추움'];

/// 데이트 가이드 항목 하나 (예: OOTD)
class GuideItem {
  const GuideItem({required this.title, required this.content});

  final String title;
  final String content;
}

/// 데이트 가이드 (피그마 13번)
class DateGuide {
  const DateGuide({
    required this.place,
    required this.weather,
    required this.items,
  });

  /// datePlaces 중 하나
  final String place;

  /// dateWeathers 중 하나
  final String weather;

  /// 5개: OOTD, 데이트 코스, 추천 메뉴, 분위기 가이드, 한마디 팁
  final List<GuideItem> items;
}

/// 가짜 데이터 (피그마 예시 그대로)
const fakeDateGuide = DateGuide(
  place: '감성 카페',
  weather: '맑음',
  items: [
    GuideItem(title: 'OOTD', content: '깔끔한 셔츠나 가벼운 니트에 편한 신발'),
    GuideItem(title: '데이트 코스', content: '카페에서 대화 → 근처에서 가볍게 산책'),
    GuideItem(title: '추천 메뉴', content: '나눠 먹기 쉬운 디저트와 각자 좋아하는 음료'),
    GuideItem(title: '분위기 가이드', content: '가벼운 질문으로 시작하고 상대의 반응을 살펴요.'),
    GuideItem(title: '한마디 팁', content: '"오늘 이야기 즐거웠어, 다음에도 여기 올래?"'),
  ],
);
