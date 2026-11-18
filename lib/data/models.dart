// 데이터 모양 (화면과 데이터가 주고받는 형태)

/// 'D-20' 같은 글자, 0 이하면 'D-Day'
String dDayLabel(int days) => days <= 0 ? 'D-Day' : 'D-$days';

/// D-Day 사유 태그 (피그마 2번)
const reasonTags = ['종강', '군 입대', '졸업', '방학', '기타'];

/// 데이트 장소 유형 (피그마 10번)
const datePlaces = ['캠퍼스', '감성 카페', '전시회'];

/// 데이트 날씨 (피그마 10번)
const dateWeathers = ['맑음', '비', '추움'];

/// 친밀도 (피그마 3번, 11번)
enum Intimacy {
  faceOnly('얼굴만 아는 사이', '아직 서로에게 먼저 말을 건 적은 거의 없어요.'),
  smallTalk('인사·스몰토크 가능', '마주치면 인사하고 짧게 이야기할 수 있어요.'),
  close('사적 연락·만남 가능', '따로 연락하거나 약속을 잡을 수 있어요.');

  const Intimacy(this.label, this.description);

  final String label;
  final String description;
}

/// 목표 (피그마 6번, 11번)
enum Goal {
  friends('친해지기', '편하게 인사하고 가끔 이야기를 나눠요.'),
  some('썸 타기', '서로에게 관심을 표현할 기회를 만들어요.'),
  dating('사귀기', '분위기와 서로의 의사를 살피며 마음을 전해요.');

  const Goal(this.label, this.description);

  final String label;
  final String description;
}

/// 온보딩 입력값 (피그마 2~6번)
class Profile {
  const Profile({
    required this.dDay,
    required this.reason,
    required this.intimacy,
    required this.meetingsPerWeek,
    required this.courage,
    required this.goal,
  });

  final DateTime dDay;

  /// reasonTags 중 하나
  final String reason;
  final Intimacy intimacy;

  /// 주 0 ~ 7회
  final int meetingsPerWeek;

  /// 용기 배터리 0 ~ 100
  final int courage;
  final Goal goal;

  Profile copyWith({Intimacy? intimacy, Goal? goal}) {
    return Profile(
      dDay: dDay,
      reason: reason,
      intimacy: intimacy ?? this.intimacy,
      meetingsPerWeek: meetingsPerWeek,
      courage: courage,
      goal: goal ?? this.goal,
    );
  }
}

/// 미션 하나 (피그마 7번, 14~16번)
class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.tip,
    this.done = false,
  });

  final String id;
  final String title;

  /// 실행 팁
  final String tip;
  final bool done;

  Mission copyWith({bool? done}) {
    return Mission(id: id, title: title, tip: tip, done: done ?? this.done);
  }
}

/// 주차 하나 (피그마 8번, 14~16번)
class WeekPlan {
  const WeekPlan({
    required this.weekNo,
    required this.title,
    required this.fromDDay,
    required this.toDDay,
    required this.missions,
  });

  /// 1, 2, 3
  final int weekNo;

  /// 주차 목표 (예: 인사할 틈 만들기)
  final String title;

  /// 시작 날 (20이면 D-20)
  final int fromDDay;

  /// 끝 날 (0이면 D-Day)
  final int toDDay;
  final List<Mission> missions;

  /// 완료한 미션 수
  int get doneCount => missions.where((m) => m.done).length;

  /// 'D-20 ~ D-14'
  String get periodLabel => '${dDayLabel(fromDDay)} ~ ${dDayLabel(toDDay)}';

  WeekPlan copyWith({List<Mission>? missions}) {
    return WeekPlan(
      weekNo: weekNo,
      title: title,
      fromDDay: fromDDay,
      toDDay: toDDay,
      missions: missions ?? this.missions,
    );
  }
}

/// 대화 분석 결과 (피그마 12번)
class ChatStats {
  const ChatStats({
    required this.summary,
    required this.avgReplyMinutes,
    required this.avgLength,
    required this.messagesPerDay,
    required this.positivePercent,
  });

  /// 결과 한 줄 (피그마 12번 제목)
  final String summary;

  /// 평균 답장 텀 (분)
  final int avgReplyMinutes;

  /// 평균 답장 길이 (글자 수)
  final int avgLength;

  /// 하루 메시지 수
  final int messagesPerDay;

  /// 긍정 표현 비율 (%)
  final int positivePercent;
}

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
