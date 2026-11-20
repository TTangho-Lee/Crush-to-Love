// 여러 흐름이 같이 쓰는 데이터 모양 (온보딩 · 미션 · 데이트)

/// 'D-20' 같은 글자, 0 이하면 'D-Day'
String dDayLabel(int days) => days <= 0 ? 'D-Day' : 'D-$days';

/// D-Day 사유 태그 (피그마 2번)
const reasonTags = ['종강', '군 입대', '졸업', '방학', '기타'];

/// 친밀도 (피그마 3번, 11번)
enum Intimacy {
  faceOnly('얼굴만 아는 사이', '아직 서로에게 먼저 말을 건 적은 거의 없어요.'),
  smallTalk('인사·스몰토크 가능', '마주치면 인사하고 짧게 이야기할 수 있어요.'),
  close('사적 연락·만남 가능', '따로 연락하거나 약속을 잡을 수 있어요.');

  const Intimacy(this.label, this.description);

  final String label;
  final String description;
}

/// 용기 배터리 단계 (피그마 5번), 기획서의 20 · 50 · 80 · 100% 기준
enum CourageLevel {
  low('저전력 · 가벼운 신호', '눈이 마주치면 인사하거나 스토리에 좋아요를 눌러봐요.'),
  standard('표준 · 가벼운 대화', '먼저 톡을 보내거나 공통 관심사를 가볍게 물어봐요.'),
  boost('고속충전 · 단둘이 약속', '단둘이 식사나 카페에 가자고 가볍게 제안해봐요.'),
  full('풀충전 · 마음 표현', '호감을 표현하거나 용기 내어 고백해봐요.');

  const CourageLevel(this.label, this.description);

  final String label;
  final String description;

  /// 0~34% 저전력, 35~64% 표준, 65~89% 고속충전, 90~100% 풀충전
  static CourageLevel of(int percent) => switch (percent) {
        < 35 => low,
        < 65 => standard,
        < 90 => boost,
        _ => full,
      };
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
