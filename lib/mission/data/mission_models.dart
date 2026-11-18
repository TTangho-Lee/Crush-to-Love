// 미션 흐름의 데이터 모양 (홈 · 로드맵)

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
