// 로드맵 데이터 모양 (미션 · 주차 · 로드맵), 팀원 Mission · WeekPlan과 이름 겹치지 않게 Roadmap*
//   상대마다 로드맵 하나 (Roadmap), DB에는 주차 목록을 JSON 글자로 저장 (roadmap_db.dart)
import 'mission_lines.dart';

/// 미션 하나 (피그마 7번, 14~16번)
class RoadmapMission {
  const RoadmapMission({
    required this.id,
    required this.title,
    required this.tip,
    this.done = false,
    this.doneAt,
    this.brave = false,
  });

  /// 사전 위치 ('topic-2' = 이야기할 거리 찾기 3번째 미션)
  final String id;
  final String title;

  /// 실행 팁
  final String tip;
  final bool done;

  /// 완료한 때 (쉰 날 세기)
  final DateTime? doneAt;

  /// 그때 용기 단계보다 어려운 미션을 해냈으면 true (진척도 1.5배)
  final bool brave;

  /// 사전 속 미션 (사전이 바뀌어 없어졌으면 null)
  MissionLine? get line {
    final parts = id.split('-');
    if (parts.length != 2) return null;
    final lines = missionLines[RoadmapStage.values.asNameMap()[parts[0]]];
    final i = int.tryParse(parts[1]);
    return lines == null || i == null || i < 0 || i >= lines.length
        ? null
        : lines[i];
  }

  /// 필요한 용기 1 ~ 3
  int get level => line?.level ?? 1;

  /// 직접 만나야 하면 true
  bool get offline => line?.offline ?? false;

  /// 완료 · 취소 (at: 완료한 때, brave: 용기 단계보다 어려운 미션이었는지)
  RoadmapMission mark(bool done, {DateTime? at, bool brave = false}) =>
      RoadmapMission(
        id: id,
        title: title,
        tip: tip,
        done: done,
        doneAt: done ? at : null,
        brave: done && brave,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'tip': tip,
        'done': done,
        if (doneAt != null) 'doneAt': doneAt!.toIso8601String(),
        if (brave) 'brave': true,
      };

  factory RoadmapMission.fromJson(Map<String, Object?> json) => RoadmapMission(
        id: json['id'] as String,
        title: json['title'] as String,
        tip: json['tip'] as String,
        done: json['done'] == true,
        doneAt: DateTime.tryParse(json['doneAt'] as String? ?? ''),
        brave: json['brave'] == true,
      );
}

/// 주차 하나 (피그마 8번, 14~16번)
class RoadmapWeek {
  const RoadmapWeek({
    required this.weekNo,
    required this.stage,
    required this.fromDDay,
    required this.toDDay,
    required this.missions,
  });

  /// 1부터
  final int weekNo;

  /// 이번 주 단계 (제목 · 할 일)
  final RoadmapStage stage;

  /// 시작 날 (20이면 D-20)
  final int fromDDay;

  /// 끝 날 (0이면 D-Day)
  final int toDDay;
  final List<RoadmapMission> missions;

  /// 주차 목표 (예: 인사할 틈 만들기)
  String get title => stage.title;

  /// 완료한 미션 수
  int get doneCount => missions.where((m) => m.done).length;

  /// 이번 주 미션을 다 했으면 true
  bool get allDone => missions.every((m) => m.done);

  /// '1주차', 한 주차가 7일보다 길면 '1단계' (D-Day가 아주 멀 때)
  String get label => fromDDay - toDDay + 1 > 7 ? '$weekNo단계' : '$weekNo주차';

  RoadmapWeek copyWith({
    int? fromDDay,
    int? toDDay,
    List<RoadmapMission>? missions,
  }) =>
      RoadmapWeek(
        weekNo: weekNo,
        stage: stage,
        fromDDay: fromDDay ?? this.fromDDay,
        toDDay: toDDay ?? this.toDDay,
        missions: missions ?? this.missions,
      );

  Map<String, Object?> toJson() => {
        'weekNo': weekNo,
        'stage': stage.name,
        'fromDDay': fromDDay,
        'toDDay': toDDay,
        'missions': [for (final m in missions) m.toJson()],
      };

  factory RoadmapWeek.fromJson(Map<String, Object?> json) => RoadmapWeek(
        weekNo: json['weekNo'] as int,
        // 처음 버전(제목만 저장)도 읽게
        stage: RoadmapStage.values.asNameMap()[json['stage']] ??
            RoadmapStage.values.firstWhere(
              (s) => s.title == json['title'],
              orElse: () => RoadmapStage.greet,
            ),
        fromDDay: json['fromDDay'] as int,
        toDDay: json['toDDay'] as int,
        missions: [
          for (final m in json['missions'] as List)
            RoadmapMission.fromJson((m as Map).cast<String, Object?>()),
        ],
      );
}

/// 상대 한 명의 로드맵
class Roadmap {
  const Roadmap({
    required this.crushId,
    required this.startedAt,
    required this.planKey,
    required this.weeks,
    this.shift = 0,
    this.note,
    this.noteAt,
  });

  /// 상대 번호 (CrushStore), 예시 로드맵은 0
  final int crushId;

  /// 로드맵을 처음 만든 날 (주차는 이날부터 D-Day까지 나눔)
  final DateTime startedAt;

  /// 만들 때 쓴 입력값 (D-Day · 사이 · 목표 · 만남 빈도 · 용기 단계), 바뀌면 남은 미션을 다시 짬
  final String planKey;
  final List<RoadmapWeek> weeks;

  /// 다음 주차부터 당긴(+1) · 늦춘(-1) 단계 수 (진도 · 대화 분석에 맞춰 자동으로)
  final int shift;

  /// 마지막으로 자동 조정한 이유 (로드맵 화면 위 한 줄), 없으면 null
  final String? note;
  final DateTime? noteAt;

  Roadmap copyWith({
    String? planKey,
    List<RoadmapWeek>? weeks,
    int? shift,
    String? note,
    DateTime? noteAt,
    bool clearNote = false,
  }) =>
      Roadmap(
        crushId: crushId,
        startedAt: startedAt,
        planKey: planKey ?? this.planKey,
        weeks: weeks ?? this.weeks,
        shift: shift ?? this.shift,
        note: clearNote ? null : note ?? this.note,
        noteAt: clearNote ? null : noteAt ?? this.noteAt,
      );
}
