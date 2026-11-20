// 대화 분석 규칙 테스트 (flutter test test/chat_rules_test.dart)
// 단어 사전 · 규칙을 고친 뒤 돌려서 다른 결과가 망가지지 않았는지 확인
// 예시 대화는 지어낸 것 (실제 대화 아님)
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/chat_analyzer.dart';
import 'package:one_way_love/analysis/chat/history/chat_record.dart';
import 'package:one_way_love/analysis/chat/rules/features.dart';
import 'package:one_way_love/analysis/chat/rules/inference.dart';
import 'package:one_way_love/analysis/chat/rules/lexicon.dart';
import 'package:one_way_love/analysis/chat/rules/normalizer.dart';
import 'package:one_way_love/analysis/chat/rules/scoring.dart';
import 'package:one_way_love/analysis/chat/rules/tagger.dart';
import 'package:one_way_love/shared/models.dart';

void main() {
  group('① 정리', () {
    test('반복 글자 줄이기 · 공백 정리 · 띄어쓰기 뺀 글자', () {
      final n = normalize('ㅋㅋㅋㅋㅋ 뭐   해 ?!!!!');
      expect(n.text, 'ㅋㅋ 뭐 해 ?!!');
      expect(n.compact, 'ㅋㅋ뭐해?!!');
    });

    test('카톡 자리표시', () {
      expect(isPlaceholder('사진'), isTrue);
      expect(isPlaceholder('사진 3장'), isTrue);
      expect(isPlaceholder('이모티콘'), isTrue);
      expect(isPlaceholder('사진 찍자'), isFalse);
    });
  });

  group('② 단어 사전', () {
    const cases = <String, Set<MessageTag>>{
      '재밌었어 ㅎㅎ 너는?': {
        MessageTag.laugh,
        MessageTag.positive,
        MessageTag.question,
        MessageTag.askBack,
      },
      '고마워!!!!': {MessageTag.thanks},
      '안 좋아': {MessageTag.negative},
      '별로 재밌진 않았어': {MessageTag.negative},
      '주말에 뭐해?': {MessageTag.question, MessageTag.personal},
      '내일 같이 밥 먹을래?': {MessageTag.question, MessageTag.invite},
      'ㅇㅋ': {MessageTag.agree, MessageTag.shortReply},
      '좋아요!': {MessageTag.agree, MessageTag.positive},
      '그래서 그랬구나': {},
      '사진': {MessageTag.media},
      '이모티콘': {MessageTag.sticker},
      '바빠서 나중에 연락할게': {MessageTag.busy},
      '잘 자': {MessageTag.care},
      '미안 오늘은 어려울 것 같아': {MessageTag.apology, MessageTag.decline},
      '다음에 또 보자': {MessageTag.future}, // 지금 하는 제안은 아님
    };

    for (final entry in cases.entries) {
      test(entry.key, () => expect(tagMessage(entry.key), entry.value));
    }
  });

  group('③ 주고받기 지표', () {
    DateTime t(int day, int hour, int minute) =>
        DateTime(2026, 11, day, hour, minute);
    ChatMessage m(String sender, DateTime time, String text) =>
        ChatMessage(sender: sender, time: time, text: text);

    // 나 = 민수, 상대 = 지민, 둘째 날은 새 대화 묶음
    final convo = [
      m('민수', t(18, 20, 0), '오늘 수업 어땠어?'),
      m('지민', t(18, 20, 5), '재밌었어 ㅎㅎ 너는?'),
      m('민수', t(18, 20, 6), '나도 좋았어'),
      m('지민', t(18, 20, 30), '주말에 뭐해?'),
      m('민수', t(18, 20, 31), '아직 없어'),
      m('민수', t(18, 20, 32), '같이 밥 먹을래?'),
      m('지민', t(18, 20, 40), '좋아!'),
      m('지민', t(19, 12, 0), '잘 잤어?'),
      m('민수', t(19, 12, 10), '응'),
      m('민수', t(19, 12, 11), '오늘 시간 돼?'),
      m('지민', t(19, 12, 50), '미안 오늘은 어려울 것 같아'),
      m('지민', t(19, 12, 51), '다음에 또 보자'),
      m('지민', t(19, 12, 52), 'ㅠㅠ'),
    ];

    test('대화 흐름 숫자', () {
      final f = computeFeatures(convo, '민수');
      expect(f.me.count, 6);
      expect(f.them.count, 7);
      expect(f.theirShare, closeTo(7 / 13, 0.001));
      expect(f.sessionCount, 2);
      expect(f.theirStartRate, 0.5); // 둘째 날은 지민이 먼저
      expect(f.theirEndRate, 1.0);
      expect(f.them.replyMedianMinutes, 16); // 5, 24, 8, 39분의 중앙값
      expect(f.me.replyMedianMinutes, 1);
      expect(f.askBackRate!, closeTo(1 / 3, 0.001)); // 첫 질문만 되물음
      expect(f.answerRate, 1.0);
      expect(f.inviteAcceptRate, 0.5); // 밥은 수락, 오늘은 거절
      expect(f.theirBurstRate, closeTo(0.2, 0.001)); // 마지막에 3개 연달아
      expect(f.lateNightRate, 0);
      expect(f.trend, isNotNull);
    });

    test('화면 숫자 · 관찰된 변화는 지표와 같은 값', () {
      // 같은 대화를 안드로이드 내보내기 글자로 (24시간제)
      final export = [
        for (final x in convo)
          '${x.time.year}년 ${x.time.month}월 ${x.time.day}일 '
              '${x.time.hour}:${x.time.minute.toString().padLeft(2, '0')}, '
              '${x.sender} : ${x.text}',
      ].join('\n');
      final stats = analyzeChat(export, now: t(19, 13, 0));
      final f = stats.features!;

      expect(stats.replyMinutes, f.them.replyMedianMinutes!.round()); // 16분
      expect(stats.warmPercent, (f.them.warmRate * 100).round()); // 2/7
      expect(stats.warmPercent, 29);
      // 앞 절반(18일) → 뒤 절반(19일): 답장 8 → 39분, 질문 2/3 → 1/4, 따뜻한 표현 2/3 → 0
      expect(
        stats.change,
        '분석 기간 앞쪽보다 상대 답장이 31분 느려졌고, 질문이 42%p 줄었고, '
        '따뜻한 표현이 67%p 줄었어요.',
      );
    });

    group('④⑤⑥ 점수 · 추론 · 멘트', () {
      test('호감 신호가 강한 대화', () {
        final insight = infer(computeFeatures(convo, '민수'));
        expect(insight.interest.level, InterestLevel.high);
        expect(insight.intimacy, Intimacy.close); // 밥 제안을 받아들임
        expect(insight.strategy, '약속 제안해보기');
        expect(insight.lines.length, 2);
        expect(insight.interest.plus, isNotEmpty);
      });

      test('반응이 적은 대화', () {
        final cold = [
          m('민수', t(18, 20, 0), '오늘 수업 어땠어?'),
          m('지민', t(18, 23, 0), 'ㅇㅇ'),
          m('민수', t(19, 12, 0), '점심 뭐 먹었어?'),
          m('지민', t(19, 18, 30), '그냥'),
          m('민수', t(20, 12, 0), '주말에 뭐해?'),
        ];
        final insight = infer(computeFeatures(cold, '민수'));
        expect(insight.interest.level, InterestLevel.low);
        expect(insight.interest.confidenceLabel, '적음');
        expect(insight.intimacy, Intimacy.faceOnly);
        expect(insight.strategy, '가볍게 말 걸기'); // 짧은 대답이 많음
      });
    });
  });

  group('읽기 · 분석', () {
    const export = '''지민 님과 카카오톡 대화
저장한 날짜 : 2026년 11월 19일 오후 1:00


2026년 11월 18일 오후 8:00
2026년 11월 18일 오후 8:00, 민수 : 오늘 수업 어땠어?
2026년 11월 18일 오후 8:05, 지민 : 재밌었어 ㅎㅎ
너는?
2026년 11월 18일 오후 8:06, 민수님이 지민님을 초대했습니다.
메시지가 삭제되었습니다.
2026년 11월 18일 오후 8:07, 민수 : 나도 좋았어
2026년 11월 18일 오후 8:20, 지민 : 주말에 뭐해?''';

    test('안드로이드 내보내기 형식', () {
      final messages = parseKakaoChat(export);
      expect(messages.length, 4); // 시스템 줄 · 삭제 줄은 버림
      expect(messages[1].text, '재밌었어 ㅎㅎ\n너는?'); // 여러 줄 메시지
      expect(guessMyName(export), '민수');
    });

    test('오래된 대화 버리기 (최근 31일만)', () {
      const text = '''지민 님과 카카오톡 대화
저장한 날짜 : 2026년 11월 20일 오후 1:00

2025년 1월 1일 오후 8:00, 민수 : 작년 대화
둘째 줄
2026년 11월 18일 오후 8:00, 민수 : 오늘 수업 어땠어?
2026년 11월 18일 오후 8:05, 지민 : 재밌었어''';
      final cut = dropOldLines(text, now: DateTime(2026, 11, 20));
      expect(cut, startsWith('지민 님과 카카오톡 대화')); // 머리말은 유지
      expect(cut, isNot(contains('작년 대화')));
      expect(cut, isNot(contains('둘째 줄'))); // 오래된 메시지의 다음 줄도
      expect(parseKakaoChat(cut).length, 2);
      // 날짜 줄이 없는 PC 대화는 그대로
      expect(dropOldLines('[민수] [오후 1:00] 안녕'), '[민수] [오후 1:00] 안녕');
    });

    test('한 번 읽고 기간만 바꿔 쓰기 (ParsedChat)', () {
      final chat = ParsedChat.parse(export);
      expect(chat.titlePartner, '지민');
      expect(chat.guessMe(), '민수');
      expect(chat.senders(), unorderedEquals(['민수', '지민']));
      expect(chat.senders(from: DateTime(2026, 11, 18, 20, 10)), ['지민']);

      // 최근 10분만: 머리말 + 8시 20분 메시지
      final trimmed = chat.keepRecent(
        range: const Duration(minutes: 10),
        now: DateTime(2026, 11, 18, 20, 25),
      );
      expect(trimmed, startsWith('지민 님과 카카오톡 대화'));
      expect(parseKakaoChat(trimmed).single.text, '주말에 뭐해?');
      // 한 번만 쓸 때 부르는 함수와 같은 결과
      expect(
        trimmed,
        keepRecent(
          export,
          range: const Duration(minutes: 10),
          now: DateTime(2026, 11, 18, 20, 25),
        ),
      );
    });

    test('분석 결과에 주고받기 지표 포함', () {
      final stats = analyzeChat(
        export,
        range: const Duration(days: 7),
        now: DateTime(2026, 11, 19, 13, 0),
      );
      expect(stats.features, isNotNull);
      expect(stats.features!.askBackRate, 1.0);
      expect(stats.period, startsWith('지민님과')); // 1:1은 상대 자동
      expect(stats.replyMinutes, 9); // 5분, 13분의 중간값
      expect(stats.warmPercent, 50); // 2개 중 '재밌었어 ㅎㅎ'
      expect(stats.change, isNull); // 메시지가 적어서 앞뒤 비교 안 함

      // 기록용 숫자 (대화 글자는 없음)
      final record = stats.record!;
      expect(record.partner, '지민');
      expect(record.lastMessageAt, DateTime(2026, 11, 18, 20, 20));
      expect(record.messageCount, 4);
      expect(record.score, stats.insight!.interest.score);
    });

    test('단톡방은 짝사랑 상대를 골라야 함', () {
      const group = '''해커톤 4조 카카오톡 대화
저장한 날짜 : 2026년 11월 19일 오후 1:00

2026년 11월 18일 오후 8:00
2026년 11월 18일 오후 8:00, 민수 : 다들 저녁 먹었어?
2026년 11월 18일 오후 8:02, 철수 : 아직 ㅠㅠ
2026년 11월 18일 오후 8:05, 지민 : 난 먹었어 ㅎㅎ 너는?
2026년 11월 18일 오후 8:06, 민수 : 나도 먹었어''';
      final now = DateTime(2026, 11, 19, 13, 0);

      expect(
        () => analyzeChat(group, myName: '민수', now: now),
        throwsA(isA<ChatAnalysisError>()),
      );

      final stats =
          analyzeChat(group, myName: '민수', partnerName: '지민', now: now);
      expect(stats.features!.them.count, 1); // 철수 메시지는 빠짐
      expect(stats.features!.askBackRate, 1.0); // 지민이 되물음
    });
  });

  group('분석 기록', () {
    ChatRecord record(int day, int score, {double? reply, double start = 0.2}) =>
        ChatRecord(
          analyzedAt: DateTime(2026, 11, day, 21),
          partner: '지민',
          lastMessageAt: DateTime(2026, 11, day, 20),
          score: score,
          replyMinutes: reply,
          warmRate: 0.5,
          startRate: start,
          askBackRate: null,
          messageCount: 40,
        );

    test('DB 행으로 바꿨다 되돌리기', () {
      final r = record(13, 64, reply: 42.5);
      final back = ChatRecord.fromRow(r.toRow());
      expect(back.lastMessageAt, r.lastMessageAt);
      expect(back.score, 64);
      expect(back.replyMinutes, 42.5);
      expect(back.askBackRate, isNull);
    });

    test('첫 분석은 비교 없음', () {
      expect(compareWithHistory(const [], record(20, 72)), isNull);
    });

    test('지난 분석과 비교', () {
      final previous = [
        for (var i = 0; i < 5; i++) record(10 + i, 50 + i),
        record(15, 64, reply: 43),
      ];
      final c = compareWithHistory(
        previous,
        record(20, 72, reply: 25, start: 0.4),
      )!;
      expect(c.scoreDiff, 8);
      expect(c.title, '지난 분석보다 호감 신호 +8점');
      expect(c.lines, contains('보통 답장 43분 → 25분 (빨라졌어요)'));
      expect(c.lines, contains('상대가 먼저 말 걸기 20% → 40%'));
      expect(c.recentScores, [52, 53, 54, 64, 72]); // 최근 5개
    });

    test('분 표시', () {
      expect(formatMinutes(0), '1분 안');
      expect(formatMinutes(25), '25분');
      expect(formatMinutes(120), '2시간');
      expect(formatMinutes(90), '1시간 30분');
    });
  });
}
