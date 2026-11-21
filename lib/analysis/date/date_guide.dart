// 데이트 가이드 흐름의 데이터 모양 (피그마 10번 고르기, 13번 가이드)
//   고르는 것(DateChoice): 장소 · 날씨 · 시간 · 인원
//   가이드에 반영하는 것(GuideBasis): 지금 사이 · 용기 단계 · 목표 · 대화에 자주 나온 주제 · 존댓말 사이
//   가이드(DateGuide): 항목 6개 + 만난 뒤 보낼 톡
import 'package:material_ui/material_ui.dart';

import '../../shared/models.dart';
import '../chat/rules/topics.dart';

/// 데이트 장소 (피그마 10번)
enum DatePlace {
  campus('캠퍼스', Icons.school_outlined),
  cafe('감성 카페', Icons.local_cafe_outlined),
  restaurant('맛집', Icons.restaurant_outlined),
  movie('영화관', Icons.movie_outlined),
  exhibition('전시회', Icons.museum_outlined),
  walk('산책·공원', Icons.park_outlined),
  themePark('놀이공원', Icons.attractions_outlined),
  bar('술집', Icons.local_bar_outlined);

  const DatePlace(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 데이트 날씨 (피그마 10번)
enum DateWeather {
  sunny('맑음', Icons.wb_sunny_outlined),
  rain('비', Icons.umbrella_outlined),
  cold('추움', Icons.ac_unit),
  hot('더움', Icons.local_fire_department_outlined);

  const DateWeather(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 만나는 시간
enum MeetTime {
  day('낮', Icons.light_mode_outlined),
  evening('저녁', Icons.dark_mode_outlined);

  const MeetTime(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 둘이 만나는지, 여럿이 만나는지
enum Company {
  two('둘이', Icons.favorite_border),
  group('여럿이', Icons.groups_outlined);

  const Company(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 10번 화면에서 고른 조건
class DateChoice {
  const DateChoice({
    this.place = DatePlace.cafe,
    this.weather = DateWeather.sunny,
    this.time = MeetTime.day,
    this.company = Company.two,
  });

  final DatePlace place;
  final DateWeather weather;
  final MeetTime time;
  final Company company;

  DateChoice copyWith({
    DatePlace? place,
    DateWeather? weather,
    MeetTime? time,
    Company? company,
  }) {
    return DateChoice(
      place: place ?? this.place,
      weather: weather ?? this.weather,
      time: time ?? this.time,
      company: company ?? this.company,
    );
  }
}

/// 가이드에 반영하는 나와 상대 상황 (온보딩 입력값 + 대화 분석 결과)
class GuideBasis {
  const GuideBasis({
    required this.intimacy,
    required this.courage,
    required this.goal,
    this.topics = const [],
    this.formal = false,
    this.fromChat = false,
  });

  /// 지금 사이 (대화 분석이 있으면 그 결과, 없으면 온보딩 · 11번 입력값)
  final Intimacy intimacy;

  /// 용기 배터리 단계
  final CourageLevel courage;

  /// 이번 목표
  final Goal goal;

  /// 대화에 자주 나온 주제 (많은 순), 대화 분석이 없으면 비어 있음
  final List<Topic> topics;

  /// 내가 존댓말을 쓰는 사이면 true (한마디 팁 · 만난 뒤 톡을 존댓말로)
  final bool formal;

  /// 대화 분석 결과를 반영했으면 true
  final bool fromChat;
}

/// 가이드 문장 한 줄 (date_lines.dart)
class GuideLine {
  const GuideLine(this.text, {this.time, this.weather, this.company});

  final String text;

  /// 이 시간에만, 비우면 언제나
  final List<MeetTime>? time;

  /// 이 날씨에만, 비우면 언제나
  final List<DateWeather>? weather;

  /// 이 인원일 때만, 비우면 언제나
  final List<Company>? company;

  bool fits(DateChoice c) =>
      (time?.contains(c.time) ?? true) &&
      (weather?.contains(c.weather) ?? true) &&
      (company?.contains(c.company) ?? true);
}

/// 가이드 항목 종류 (피그마 13번 순서)
enum GuideKind {
  outfit('OOTD'),
  course('데이트 코스'),
  menu('추천 메뉴'),
  talk('대화 소재'),
  mood('분위기 가이드'),
  tip('한마디 팁');

  const GuideKind(this.label);

  final String label;
}

/// 가이드 항목 하나
class GuideItem {
  const GuideItem(this.kind, this.lines);

  final GuideKind kind;

  /// 한 줄씩 보여줄 내용 (따옴표가 붙은 줄은 그대로 말해볼 문장)
  final List<String> lines;
}

/// 데이트 가이드 (피그마 13번)
class DateGuide {
  const DateGuide({
    required this.choice,
    required this.basis,
    required this.items,
    required this.afterLines,
  });

  final DateChoice choice;
  final GuideBasis basis;

  /// GuideKind 순서대로 6개
  final List<GuideItem> items;

  /// 데이트 끝나고 보낼 톡 (채팅의 '만난 뒤 이어가기' 멘트)
  final List<String> afterLines;
}
