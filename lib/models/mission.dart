enum MissionStatus {
  inProgress('진행 중'),
  success('성공'),
  failed('실패'),
  expired('만료');

  const MissionStatus(this.label);
  final String label;
}

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.situation,
    required this.scripts,
    required this.caution,
    required this.deadline,
    required this.difficulty,
    this.status = MissionStatus.inProgress,
  });

  final String id;
  final String title;

  /// 상황·타이밍 설명
  final String situation;

  /// 추천 멘트 (여러 버전)
  final List<String> scripts;
  final String caution;
  final DateTime deadline;

  /// 1~5
  final int difficulty;
  final MissionStatus status;

  Mission copyWith({MissionStatus? status}) {
    return Mission(
      id: id,
      title: title,
      situation: situation,
      scripts: scripts,
      caution: caution,
      deadline: deadline,
      difficulty: difficulty,
      status: status ?? this.status,
    );
  }
}

/// 선택지 문구는 임시(n번 답안). TODO: 기획팀 확정 후 수정.
enum FailReason {
  noChance('1번 답안'), // 기회가 없었음
  noCourage('2번 답안'), // 용기가 부족했음
  situationChanged('3번 답안'), // 상황이 바뀜
  other('4번 답안'); // 기타

  const FailReason(this.label);
  final String label;
}

/// 상대 답장 지표. 지금은 직접 입력, 나중에 카톡 txt 파싱으로 자동 계산.
class ReplyMetrics {
  const ReplyMetrics({
    this.replyDelayMinutes,
    this.avgLength,
    this.messageCount,
    this.positivity,
  });

  /// 텀(분)
  final int? replyDelayMinutes;

  /// 평균 글자 수
  final int? avgLength;

  /// 상대가 보낸 메시지 수
  final int? messageCount;

  /// 긍정도 0.0~1.0
  final double? positivity;
}

class MissionResult {
  const MissionResult({
    required this.missionId,
    required this.success,
    this.failReason,
    this.memo = '',
    this.metrics,
    required this.recordedAt,
  });

  final String missionId;
  final bool success;
  final FailReason? failReason;
  final String memo;
  final ReplyMetrics? metrics;
  final DateTime recordedAt;
}
