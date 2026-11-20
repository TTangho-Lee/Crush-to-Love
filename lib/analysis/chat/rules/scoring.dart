// 규칙 ④ 점수: 주고받기 지표 → 호감 신호 점수 0~100
//   baseScore(40점)에서 시작해서 상대 쪽 행동마다 더하고 빼는 방식 (나의 행동은 점수에 안 넣음)
//   보통 친구 사이 대화가 '보통' 구간에 오도록 맞춤, 여러 신호가 겹쳐야 '높음'
//   근거(Signal)를 같이 남겨서 화면에 '왜 이 점수인지' 보여줌
//   기준값 · 점수는 아래 표에서 고치면 됨 (실제 대화로 맞춰가며 조정할 것)
import 'features.dart';
import 'lexicon.dart';

/// 점수에 반영된 근거 하나
class Signal {
  const Signal(this.label, this.points);

  /// 화면에 보여줄 문장 (예: '내 질문에 자주 되물어요')
  final String label;

  /// 더하거나 뺀 점수
  final int points;
}

/// 점수 구간
enum InterestLevel {
  low('낮음'),
  mid('보통'),
  high('높음');

  const InterestLevel(this.label);

  final String label;
}

/// 호감 신호 점수 결과
class InterestScore {
  const InterestScore({
    required this.score,
    required this.level,
    required this.confidence,
    required this.signals,
  });

  /// 0 ~ 100
  final int score;
  final InterestLevel level;

  /// 자료 양에 따른 믿을 만한 정도 0~1 (상대 메시지 30개 이상, 대화 2번 이상이면 1)
  final double confidence;

  /// 점수에 영향이 큰 순서
  final List<Signal> signals;

  /// '충분', '보통', '적음'
  String get confidenceLabel => confidence >= 0.8
      ? '충분'
      : confidence >= 0.4
          ? '보통'
          : '적음';

  /// 점수를 올린 근거 (큰 순)
  List<Signal> get plus => [for (final s in signals) if (s.points > 0) s];

  /// 점수를 내린 근거 (큰 순)
  List<Signal> get minus => [for (final s in signals) if (s.points < 0) s];
}

/// 시작 점수
const baseScore = 40;

/// 이 점수 이상이면 '높음'
const highScore = 70;

/// 이 점수 이상이면 '보통'
const midScore = 45;

InterestScore scoreInterest(ConversationFeatures f) {
  final signals = <Signal>[];
  void add(int points, String label) => signals.add(Signal(label, points));

  final them = f.them;

  // 답장 속도 (상대 답장 시간 중앙값)
  final reply = them.replyMedianMinutes;
  if (reply != null) {
    final r = reply.round();
    if (reply <= 5) {
      add(10, '답장이 아주 빨라요 (보통 $r분)');
    } else if (reply <= 30) {
      add(5, '답장이 빠른 편이에요 (보통 $r분)');
    } else if (reply > 360) {
      add(-10, '답장이 많이 늦어요 (보통 ${_hours(reply)})');
    } else if (reply > 120) {
      add(-5, '답장이 늦는 편이에요 (보통 ${_hours(reply)})');
    }
  }

  // 먼저 말 걸기 (대화가 2번 이상일 때만)
  if (f.sessionCount >= 2) {
    if (f.theirStartRate >= 0.5) {
      add(10, '상대가 먼저 말을 거는 일이 많아요');
    } else if (f.theirStartRate >= 0.3) {
      add(4, '상대가 먼저 말을 걸기도 해요');
    } else if (f.theirStartRate == 0 && f.sessionCount >= 3) {
      add(-8, '대화는 늘 내가 먼저 시작해요');
    }
  }

  // 내 질문에 대한 반응
  final askBack = f.askBackRate;
  if (askBack != null) {
    if (askBack >= 0.4) {
      add(10, '내 질문에 자주 되물어요');
    } else if (askBack >= 0.2) {
      add(5, '내 질문에 되묻기도 해요');
    }
  }
  final answer = f.answerRate;
  if (answer != null && answer < 0.5) {
    add(-8, '내 질문에 답이 없을 때가 많아요');
  }

  // 대화 양 · 길이
  if (f.theirShare >= 0.45) {
    add(5, '상대도 비슷하게 많이 보내요');
  } else if (f.theirShare < 0.25) {
    add(-8, '대부분 내가 보내고 있어요');
  }
  if (them.textCount > 0) {
    if (f.lengthBalance >= 0.8) {
      add(4, '상대 답장 길이가 나와 비슷하거나 길어요');
    } else if (f.lengthBalance < 0.4) {
      add(-6, '상대 답장이 내 메시지보다 많이 짧아요');
    }
  }

  // 표현
  if (them.warmRate >= 0.4) {
    add(8, '웃음 · 긍정 표현이 많아요');
  } else if (them.warmRate >= 0.2) {
    add(4, '웃음 · 긍정 표현이 종종 있어요');
  } else if (them.textCount >= 10 && them.warmRate < 0.05) {
    add(-3, '웃음 · 긍정 표현이 거의 없어요');
  }
  if (them.rate(MessageTag.personal) > 0) {
    add(6, '나에 대해 사적인 질문을 해요');
  }
  if (them.rate(MessageTag.care) > 0) {
    add(5, '나를 챙기는 말을 해요');
  }
  if (them.rate(MessageTag.compliment) > 0) {
    add(4, '칭찬하는 말을 해요');
  }
  if (them.rate(MessageTag.shortReply) >= 0.4) {
    add(-8, '짧은 대답이 많아요');
  } else if (them.rate(MessageTag.shortReply) >= 0.25) {
    add(-4, '짧은 대답이 종종 있어요');
  }
  if (them.rate(MessageTag.negative) >= 0.2) {
    add(-5, '부정적인 표현이 자주 보여요');
  }
  if (them.rate(MessageTag.busy) >= 0.15) {
    add(-4, '바쁘다는 말이 자주 보여요');
  }

  // 약속
  if (them.rate(MessageTag.invite) > 0) {
    add(8, '상대가 먼저 무언가를 제안해요');
  }
  final accept = f.inviteAcceptRate;
  if (accept != null) {
    if (accept >= 0.5) {
      add(10, '내 제안을 받아들여요');
    } else if (accept == 0) {
      add(-6, '내 제안을 아직 받아주지 않았어요');
    }
  }
  if (them.rate(MessageTag.future) > 0) {
    add(5, '다음을 기약하는 말을 해요');
  }

  // 시간대
  if (f.lateNightRate >= 0.2 && f.them.count >= 5) {
    add(4, '밤늦게도 대화를 이어가요');
  }

  // 변화 (앞 절반 → 뒤 절반)
  final trend = f.trend;
  if (trend != null) {
    final replyChange = trend.theirReplyChange;
    if (replyChange != null && replyChange <= -5) {
      add(4, '최근 답장이 빨라졌어요');
    } else if (replyChange != null && replyChange >= 30) {
      add(-4, '최근 답장이 느려졌어요');
    }
    if (trend.theirWarmthChange >= 0.1) {
      add(3, '최근 웃음 · 긍정 표현이 늘었어요');
    } else if (trend.theirWarmthChange <= -0.1) {
      add(-3, '최근 웃음 · 긍정 표현이 줄었어요');
    }
    if (trend.theirShareChange >= 0.1) {
      add(3, '최근 상대 메시지가 늘었어요');
    } else if (trend.theirShareChange <= -0.1) {
      add(-3, '최근 상대 메시지가 줄었어요');
    }
  }

  signals.sort((a, b) => b.points.abs().compareTo(a.points.abs()));
  final total = baseScore + signals.fold(0, (sum, s) => sum + s.points);
  final score = total.clamp(0, 100).toInt();

  final dataAmount = (them.textCount / 30).clamp(0.0, 1.0).toDouble();
  final confidence = f.sessionCount >= 2 ? dataAmount : dataAmount * 0.7;

  return InterestScore(
    score: score,
    level: score >= highScore
        ? InterestLevel.high
        : score >= midScore
            ? InterestLevel.mid
            : InterestLevel.low,
    confidence: confidence,
    signals: signals,
  );
}

/// 분 → '3시간', '1시간 30분'
String _hours(double minutes) {
  final m = minutes.round();
  final h = m ~/ 60;
  final rest = m % 60;
  return rest == 0 ? '$h시간' : '$h시간 $rest분';
}
