// 여러 흐름이 같이 쓰는 데이터 모양 (온보딩 · 미션 · 데이트)
// 짝사랑 상대는 여러 명일 수 있음 (Crush), 미션 흐름에는 지금 상대 + 내 용기를 합친 Profile을 넘김

/// 'D-20' 같은 글자, 0 이하면 'D-Day'
String dDayLabel(int days) => days <= 0 ? 'D-Day' : 'D-$days';

/// D-Day 사유 태그 (피그마 2번)
const reasonTags = ['종강', '군 입대', '졸업', '방학', otherReason];

/// 직접 입력하는 사유 태그, 고르면 글자를 따로 받아 그 글자를 사유로 저장 (예: '이사')
const otherReason = '기타';

/// 태그에 있는 사유면 그 태그, 직접 입력한 사유면 '기타' (화면에서 고른 태그 표시용)
String reasonTagOf(String reason) =>
    reasonTags.contains(reason) ? reason : otherReason;

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

/// 짝사랑 결과 (피그마 17번에서 D-Day 뒤에 고름)
enum CrushOutcome {
  success('성공'),
  fail('실패');

  const CrushOutcome(this.label);

  final String label;
}

/// 예시 멘트 웃음 표현 (설정 '나'), 기본은 대화 속 내 말투에 맞춤 (analysis/chat/rules/tone.dart)
enum LaughStyle {
  auto('대화에 맞춤'),
  kk('ㅋㅋ'),
  hh('ㅎㅎ'),
  none('안 씀');

  const LaughStyle(this.label);

  final String label;
}

/// 예시 멘트 말 높이 (설정 '지금 상대'), 기본은 대화 속 내 말투에 맞춤
enum SpeechLevel {
  auto('대화에 맞춤'),
  casual('반말'),
  formal('존댓말');

  const SpeechLevel(this.label);

  final String label;

  /// 존댓말 멘트를 쓸지 (대화에 맞춤이면 대화에서 본 값 detected)
  bool formalOr(bool detected) => switch (this) {
        auto => detected,
        casual => false,
        formal => true,
      };
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

/// 짝사랑 상대 한 명 (상대마다 따로 저장)
/// 용기 배터리는 나에 대한 값이라 여기 없음 (CrushStore.courage)
class Crush {
  const Crush({
    required this.id,
    required this.nickname,
    required this.dDay,
    required this.reason,
    required this.intimacy,
    required this.meetingsPerWeek,
    required this.goal,
    this.chatNames = const [],
    this.archived = false,
    this.speech = SpeechLevel.auto,
    this.outcome,
  });

  /// 저장용 번호 (CrushStore가 붙임, 1부터)
  final int id;

  /// 앱에서 부르는 이름 (예: 지민)
  final String nickname;

  final DateTime dDay;

  /// reasonTags 중 하나, 직접 입력했으면 그 글자 (예: '이사')
  final String reason;
  final Intimacy intimacy;

  /// 주 0 ~ 7회
  final int meetingsPerWeek;
  final Goal goal;

  /// 이 상대로 연결한 카톡 이름 (대화 분석에서 상대를 자동으로 고름)
  final List<String> chatNames;

  /// 보관했으면 true (지금 상대 목록 · 알림에서 빠지고 기록은 남음)
  final bool archived;

  /// 이 상대에게 보낼 예시 멘트 말 높이
  final SpeechLevel speech;

  /// 짝사랑 결과, 아직 안 골랐으면 null
  final CrushOutcome? outcome;

  /// 미션 흐름 · 데이트 가이드가 쓰는 입력값 (courage: 내 용기 배터리)
  Profile toProfile(int courage) {
    return Profile(
      dDay: dDay,
      reason: reason,
      intimacy: intimacy,
      meetingsPerWeek: meetingsPerWeek,
      courage: courage,
      goal: goal,
    );
  }

  Crush copyWith({
    String? nickname,
    DateTime? dDay,
    String? reason,
    Intimacy? intimacy,
    int? meetingsPerWeek,
    Goal? goal,
    List<String>? chatNames,
    bool? archived,
    SpeechLevel? speech,
    CrushOutcome? outcome,
  }) {
    return Crush(
      id: id,
      nickname: nickname ?? this.nickname,
      dDay: dDay ?? this.dDay,
      reason: reason ?? this.reason,
      intimacy: intimacy ?? this.intimacy,
      meetingsPerWeek: meetingsPerWeek ?? this.meetingsPerWeek,
      goal: goal ?? this.goal,
      chatNames: chatNames ?? this.chatNames,
      archived: archived ?? this.archived,
      speech: speech ?? this.speech,
      outcome: outcome ?? this.outcome,
    );
  }
}

/// 오늘부터 날짜까지 남은 날 (시간 무시, 날짜만 비교)
int daysUntil(DateTime day, {DateTime? now}) {
  final t = now ?? DateTime.now();
  return DateTime.utc(day.year, day.month, day.day)
      .difference(DateTime.utc(t.year, t.month, t.day))
      .inDays;
}
