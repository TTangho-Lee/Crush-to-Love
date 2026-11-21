// 대화 분석 규칙 테스트 (flutter test test/chat_rules_test.dart)
// 단어 사전 · 규칙을 고친 뒤 돌려서 다른 결과가 망가지지 않았는지 확인
// 예시 대화는 지어낸 것 (실제 대화 아님)
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/chat_analyzer.dart';
import 'package:one_way_love/analysis/chat/history/chat_record.dart';
import 'package:one_way_love/analysis/chat/rules/features.dart';
import 'package:one_way_love/analysis/chat/rules/inference.dart';
import 'package:one_way_love/analysis/chat/rules/lexicon.dart';
import 'package:one_way_love/analysis/chat/rules/lines.dart';
import 'package:one_way_love/analysis/chat/rules/normalizer.dart';
import 'package:one_way_love/analysis/chat/rules/scoring.dart';
import 'package:one_way_love/analysis/chat/rules/tagger.dart';
import 'package:one_way_love/analysis/chat/rules/topics.dart';
import 'package:one_way_love/shared/models.dart';

/// 멘트 목록 → 글자만
List<String> textsOf(List<Line> lines) => [for (final l in lines) l.text];

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
      '좋아요!': {MessageTag.agree, MessageTag.positive, MessageTag.honorific},
      '그래서 그랬구나': {MessageTag.empathy},
      '사진': {MessageTag.media},
      '이모티콘': {MessageTag.sticker},
      '바빠서 나중에 연락할게': {MessageTag.busy, MessageTag.goodbye},
      '잘 자': {MessageTag.care, MessageTag.goodbye},
      '미안 오늘은 어려울 것 같아': {MessageTag.apology, MessageTag.decline},
      '다음에 또 보자': {MessageTag.future}, // 지금 하는 제안은 아님
    };

    for (final entry in cases.entries) {
      test(entry.key, () => expect(tagMessage(entry.key), entry.value));
    }
  });

  group('② 단어 사전 (리액션 · 말투 · 약속)', () {
    const cases = <String, Set<MessageTag>>{
      '보고 싶다 ㅠㅠ': {MessageTag.affection, MessageTag.sad},
      '헐 대박 진짜?': {MessageTag.surprise, MessageTag.question},
      'ㅋㅋ 바보야': {MessageTag.laugh, MessageTag.tease},
      '좋아용': {MessageTag.positive, MessageTag.aegyo},
      '감사합니다!': {MessageTag.thanks, MessageTag.honorific},
      '그렇죠?': {MessageTag.honorific, MessageTag.question},
      '나 지금 집 가는 중': {MessageTag.share},
      '퇴근했어?': {MessageTag.question}, // 묻는 말은 일상 공유 아님
      '이거 봐봐 ㅋㅋ https://youtu.be/x': {
        MessageTag.laugh,
        MessageTag.recommend,
      },
      '몇 시에 볼까?': {
        MessageTag.plan,
        MessageTag.question,
        MessageTag.invite,
      },
      '7시에 보자': {MessageTag.invite, MessageTag.plan},
      '글쎄 시간 되면?': {MessageTag.vague, MessageTag.question},
      '이제 봤어 미안 ㅠ': {
        MessageTag.lateReplySorry,
        MessageTag.apology,
        MessageTag.sad,
      },
      '피곤해서 먼저 잘게': {MessageTag.tired, MessageTag.goodbye},
      '굿모닝!': {MessageTag.greeting, MessageTag.positive},
      '맞아 ㅋㅋ 완전 공감': {MessageTag.empathy, MessageTag.laugh},
      '그래서 어떻게 됐어?': {MessageTag.interest, MessageTag.question},
      '우리 영화 볼래?': {MessageTag.invite, MessageTag.question},
      '다음에 같이 가자': {MessageTag.future},
      '안 예뻐': {MessageTag.negative},
      'ㅋㅋㅋㅋ': {MessageTag.laugh}, // 웃음만 있으면 짧은 대답 아님
      '하이볼 마시자': {MessageTag.invite}, // '하이'는 인사 아님
      '이만원이야': {}, // '이만'은 마무리 인사 아님
      '나도! 잘 들어갔어?': {
        MessageTag.care,
        MessageTag.metUp,
        MessageTag.question,
      },
      '다음엔 내가 살게 ㅋㅋ': {
        MessageTag.future,
        MessageTag.laugh,
        MessageTag.metUp,
      },
      '여행 즐거웠어?': {MessageTag.positive, MessageTag.question}, // 만난 뒤 인사 아님
      '조심히 들어가~': {MessageTag.care}, // 배웅은 만난 뒤로 안 봄
    };

    for (final entry in cases.entries) {
      test(entry.key, () => expect(tagMessage(entry.key), entry.value));
    }
  });

  group('③-2 대화 주제', () {
    test('두 번 이상 나온 주제만, 많은 순', () {
      expect(detectTopics(['영화봤어', '영화재밌다', '밥먹자']), [Topic.movie]);
      // 같은 수면 표 순서 (맛집 · 음식이 먼저)
      expect(detectTopics(['영화', '밥', '영화', '밥']), [Topic.food, Topic.movie]);
      expect(detectTopics(['산책하자', '산책']), [Topic.exercise]); // '책' 아님
    });
  });

  group('⑥ 멘트 사전', () {
    final friday = DateTime(2026, 11, 20, 14);

    test('시간대 · 요일', () {
      expect(TimeSlot.of(DateTime(2026, 11, 20, 7)), TimeSlot.morning);
      expect(TimeSlot.of(DateTime(2026, 11, 20, 14)), TimeSlot.day);
      expect(TimeSlot.of(DateTime(2026, 11, 20, 20)), TimeSlot.evening);
      expect(TimeSlot.of(DateTime(2026, 11, 20, 23, 30)), TimeSlot.night);
      expect(TimeSlot.of(DateTime(2026, 11, 20, 2)), TimeSlot.night);

      const atNight = Line('아직 안 자?', slot: TimeSlot.night);
      expect(atNight.fits(DateTime(2026, 11, 20, 23, 30)), isTrue);
      expect(atNight.fits(friday), isFalse);
      const weekend = Line('주말에 뭐 해?', weekend: true);
      expect(weekend.fits(friday), isTrue); // 금요일
      expect(weekend.fits(DateTime(2026, 11, 17, 14)), isFalse); // 화요일
    });

    test('주제가 있으면 첫 줄은 주제 멘트, 세 줄은 서로 다름', () {
      final lines = pickLines(
        Approach.invite,
        now: friday,
        seed: 3,
        topic: Topic.movie,
      );
      expect(lines.length, 3);
      expect(textsOf(topicLines[Topic.movie]!.invite), contains(lines.first));
      expect(lines.toSet().length, 3);
      // 같은 seed면 같은 멘트
      expect(
        pickLines(Approach.invite, now: friday, seed: 3, topic: Topic.movie),
        lines,
      );
    });

    test('존댓말 사이는 존댓말 멘트만 (주제 멘트도 존댓말)', () {
      final lines = pickLines(
        Approach.light,
        now: friday,
        seed: 1,
        topic: Topic.food,
        formal: true,
      );
      expect(lines.length, 3);
      expect(
        textsOf(formalTopicLines[Topic.food]!.open),
        contains(lines.first),
      );
      expect(textsOf(formalLines[Approach.light]!), contains(lines.last));
    });

    test('설명은 방향마다 여러 개, seed로 하나', () {
      for (final approach in Approach.values) {
        final hints = approachHints[approach]!;
        expect(hints.length, greaterThanOrEqualTo(3), reason: '$approach');
        expect(hints, contains(pickHint(approach, seed: 7)));
      }
    });

    test('모든 주제에 시간과 상관없는 멘트가 종류마다 있음 (반말 · 존댓말)', () {
      for (final table in [topicLines, formalTopicLines]) {
        for (final topic in Topic.values) {
          final lines = table[topic];
          expect(lines, isNotNull, reason: '$topic');
          for (final kind in TopicKind.values) {
            expect(
              lines!.of(kind).where((l) => l.slot == null && l.weekend == null),
              isNotEmpty,
              reason: '$topic $kind',
            );
          }
        }
      }
    });

    test('모든 방향 · 시간대 · 요일에 멘트가 3개씩', () {
      for (final approach in Approach.values) {
        for (final day in [17, 21]) {
          for (final hour in [7, 14, 20, 1]) {
            final now = DateTime(2026, 11, day, hour);
            for (final formal in [false, true]) {
              expect(
                pickLines(approach, now: now, seed: 5, formal: formal).length,
                3,
                reason: '$approach $now formal=$formal',
              );
            }
          }
        }
      }
    });
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
      expect(stats.change, '보통 답장 +31분 · 질문 -42%p · 긍정 표현 -67%p');
    });

    group('④⑤⑥ 점수 · 추론 · 멘트', () {
      // 기준 시각 고정 (마지막 메시지와 3일 넘게 벌어지면 '오랜만에 연락하기')
      Insight inferOf(List<ChatMessage> messages, {int? totalMessages}) =>
          infer(
            computeFeatures(messages, '민수'),
            now: t(20, 14, 0),
            totalMessages: totalMessages,
          );

      test('호감 신호가 강한 대화', () {
        final insight = inferOf(convo);
        expect(insight.interest.level, InterestLevel.high);
        expect(insight.intimacy, Intimacy.close); // 밥 제안을 받아들임
        expect(insight.strategy, '약속 구체적으로 잡기'); // 이미 수락했으니 날짜 정하기
        expect(insight.lines.length, 3);
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
        final insight = inferOf(cold);
        expect(insight.interest.level, InterestLevel.low);
        expect(insight.interest.confidenceLabel, '적음');
        expect(insight.intimacy, Intimacy.faceOnly);
        expect(insight.strategy, '가볍게 말 걸기'); // 짧은 대답이 많음
      });

      test('바쁘다는 말 → 잠시 쉬어가기', () {
        final insight = inferOf([
          m('민수', t(18, 20, 0), '오늘 뭐해?'),
          m('지민', t(18, 20, 5), '요즘 너무 바빠서 정신없어 ㅠ'),
          m('민수', t(18, 20, 6), '헐 고생이다'),
          m('지민', t(18, 20, 30), '응 이따 연락할게'),
        ]);
        expect(insight.strategy, Approach.rest.label);
      });

      test('속상한 일 → 마음 다독여주기', () {
        final insight = inferOf([
          m('민수', t(18, 20, 0), '오늘 하루 어땠어?'),
          m('지민', t(18, 20, 5), '오늘 진짜 속상한 일 있었어'),
          m('지민', t(18, 20, 6), '너무 우울해 ㅠㅠ'),
          m('민수', t(18, 20, 7), '헐 무슨 일인데'),
          m('지민', t(18, 20, 20), '팀플 때문에 그래'),
        ]);
        expect(insight.strategy, Approach.comfort.label);
      });

      test('서로 존댓말 → 말 편하게 하기, 존댓말 멘트', () {
        final insight = inferOf([
          m('민수', t(18, 20, 0), '안녕하세요! 오늘 수업 어떠셨어요?'),
          m('지민', t(18, 20, 5), '재밌었어요 ㅎㅎ'),
          m('민수', t(18, 20, 6), '다행이네요'),
          m('지민', t(18, 20, 30), '발표 준비는 잘 되세요?'),
          m('민수', t(18, 20, 31), '아직이에요 ㅠ'),
          m('지민', t(18, 20, 40), '화이팅하세요!'),
        ]);
        expect(insight.strategy, Approach.breakIce.label);
        expect(insight.intimacy, Intimacy.faceOnly); // 대화가 아직 적음
        final formal = textsOf(formalLines[Approach.breakIce]!);
        expect(insight.lines.every(formal.contains), isTrue);
      });

      final sharing = [
        m('민수', t(18, 20, 0), '뭐해?'),
        m('지민', t(18, 20, 5), '나 지금 집 가는 중'),
        m('지민', t(18, 20, 6), '오늘 알바 끝나고 맛집 다녀왔어'),
        m('민수', t(18, 20, 7), '오 어디?'),
        m('지민', t(18, 20, 20), '학교 앞에 새로 생긴 데 있잖아 거기 완전 맛있어'),
        m('민수', t(18, 20, 21), '헐 가보고 싶다'),
      ];

      test('일상을 먼저 들려줌 → 리액션 크게 해주기', () {
        final insight = inferOf(sharing, totalMessages: 100);
        expect(insight.strategy, Approach.react.label);
        expect(insight.topics, ['맛집·음식']);
        expect(textsOf(topicLines[Topic.food]!.ask), contains(insight.lines.first));
      });

      test('자주 나온 주제 → 첫 멘트가 그 주제', () {
        final insight = inferOf([
          m('민수', t(18, 20, 0), '어제 영화 봤어?'),
          m('지민', t(18, 20, 5), '응 그 영화 완전 재밌더라'),
          m('민수', t(18, 20, 6), '나도 보고 싶다'),
          m('지민', t(18, 20, 30), '영화 보고 나서 소름 돋았어 ㅋㅋ'),
        ]);
        expect(insight.topics, ['영화·드라마']);
        expect(insight.strategy, Approach.laughTopic.label);
        expect(textsOf(topicLines[Topic.movie]!.open), contains(insight.lines.first));
      });

      test('마지막 대화가 3일 넘게 전 → 오랜만에 연락하기', () {
        final insight = inferOf([
          m('민수', t(10, 20, 0), '오늘 수업 어땠어?'),
          m('지민', t(10, 20, 5), '재밌었어 ㅎㅎ'),
          m('민수', t(10, 20, 6), '다행이다'),
        ]);
        expect(insight.strategy, Approach.reconnect.label);
        final banmal = textsOf(approachLines[Approach.reconnect]!);
        expect(insight.lines.every(banmal.contains), isTrue);
      });

      final metUp = [
        m('지민', t(18, 21, 0), '오늘 진짜 재밌었어 ㅎㅎ'),
        m('민수', t(18, 21, 2), '나도! 잘 들어갔어?'),
        m('지민', t(18, 21, 10), '응 방금 도착했어'),
        m('지민', t(18, 21, 11), '다음엔 내가 살게 ㅋㅋ'),
      ];

      test('만나고 온 날 → 만난 뒤 이어가기', () {
        final insight = inferOf(metUp);
        expect(insight.strategy, Approach.afterMeet.label);
        expect(insight.intimacy, Intimacy.close); // 실제로 만난 사이
        expect(
          insight.interest.plus.map((s) => s.label),
          contains('만난 뒤 즐거웠다는 말을 해요'),
        );
      });

      test('만난 뒤라도 3일 넘게 조용하면 오랜만에 연락하기가 먼저', () {
        final insight = infer(
          computeFeatures(metUp, '민수'),
          now: t(22, 22, 0),
        );
        expect(insight.strategy, Approach.reconnect.label);
      });

      test('주고받은 메시지가 15개 미만 → 첫 대화 시작하기', () {
        expect(
          inferOf(sharing, totalMessages: 6).strategy,
          Approach.firstTalk.label,
        );
        // 전체 수를 모르면 첫 대화인지 안 봄
        expect(inferOf(sharing).strategy, Approach.react.label);
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
      // 읽어 온 대화 전체가 4개뿐 → 첫 대화
      expect(stats.insight!.strategy, Approach.firstTalk.label);
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
      expect(c.lines, contains('보통 답장 43분 → 25분'));
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
