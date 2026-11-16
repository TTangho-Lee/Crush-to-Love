/// 짝사랑 상대 프로필.
enum RelationshipGoal {
  friends('친해지기'),
  some('썸'),
  dating('사귀기');

  const RelationshipGoal(this.label);
  final String label;
}

enum PeriodType {
  semester('학기 중'),
  custom('기간 지정'),
  unlimited('기한 없음'); // 선택 시 날짜 입력 숨김

  const PeriodType(this.label);
  final String label;
}

/// TODO: 기획팀 확정 후 선택지 추가/수정
enum MeetReason {
  club('동아리'),
  lecture('수업'),
  work('알바/직장'),
  introduction('지인 소개'),
  other('기타');

  const MeetReason(this.label);
  final String label;
}

class TargetProfile {
  const TargetProfile({
    required this.nickname,
    required this.myAge,
    required this.targetAge,
    required this.meetReason,
    this.meetReasonDetail = '',
    required this.periodType,
    this.periodEnd,
    required this.meetingsPerWeek,
    required this.intimacyLevel,
    required this.courageLevel,
    required this.goal,
    this.progress = 0,
  });

  final String nickname;
  final int myAge;
  final int targetAge;
  final MeetReason meetReason;
  final String meetReasonDetail;
  final PeriodType periodType;

  /// 만날 수 있는 마지막 날. 모든 미션 마감일의 상한.
  final DateTime? periodEnd;
  final int meetingsPerWeek;

  /// 1부터 시작. 단계 수는 config/level_texts.dart 기준.
  final int intimacyLevel;
  final int courageLevel;
  final RelationshipGoal goal;

  /// 관계 진척도 0~100
  final int progress;

  TargetProfile copyWith({int? intimacyLevel, int? progress}) {
    return TargetProfile(
      nickname: nickname,
      myAge: myAge,
      targetAge: targetAge,
      meetReason: meetReason,
      meetReasonDetail: meetReasonDetail,
      periodType: periodType,
      periodEnd: periodEnd,
      meetingsPerWeek: meetingsPerWeek,
      intimacyLevel: intimacyLevel ?? this.intimacyLevel,
      courageLevel: courageLevel,
      goal: goal,
      progress: progress ?? this.progress,
    );
  }
}
