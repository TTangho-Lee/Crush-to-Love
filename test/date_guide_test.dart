// 데이트 가이드 규칙 테스트 (flutter test test/date_guide_test.dart)
// 문장 사전 · 규칙을 고친 뒤 돌려서 빈 항목이나 조건에 안 맞는 문장이 없는지 확인
import 'package:flutter_test/flutter_test.dart';
import 'package:one_way_love/analysis/chat/chat_analyzer.dart';
import 'package:one_way_love/analysis/chat/chat_stats.dart';
import 'package:one_way_love/analysis/chat/rules/lines.dart';
import 'package:one_way_love/analysis/chat/rules/topics.dart';
import 'package:one_way_love/analysis/date/date_guide.dart';
import 'package:one_way_love/analysis/date/date_guide_rules.dart';
import 'package:one_way_love/analysis/date/date_lines.dart';
import 'package:one_way_love/shared/models.dart';

/// 문장 목록 → 글자만
List<String> textsOf(List<GuideLine>? lines) =>
    [for (final l in lines ?? const <GuideLine>[]) l.text];

/// 조건에 맞는 문장 글자만
List<String> fitting(List<GuideLine>? lines, DateChoice choice) =>
    [for (final l in lines ?? const <GuideLine>[]) if (l.fits(choice)) l.text];

void main() {
  const basis = GuideBasis(
    intimacy: Intimacy.smallTalk,
    courage: CourageLevel.standard,
    goal: Goal.some,
  );
  final now = DateTime(2026, 11, 20);

  List<String> linesOf(DateGuide guide, GuideKind kind) =>
      guide.items[kind.index].lines;

  test('모든 조건 조합에서 항목 6개가 비지 않고, 조건에 맞는 문장만', () {
    for (final place in DatePlace.values) {
      for (final weather in DateWeather.values) {
        for (final time in MeetTime.values) {
          for (final company in Company.values) {
            final choice = DateChoice(
              place: place,
              weather: weather,
              time: time,
              company: company,
            );
            for (final seed in [0, 3, 11]) {
              final guide = buildDateGuide(
                choice: choice,
                basis: basis,
                seed: seed,
                now: now,
              );
              final reason = '$place $weather $time $company seed=$seed';
              expect(guide.items.map((i) => i.kind), GuideKind.values);
              for (final item in guide.items) {
                expect(item.lines, isNotEmpty, reason: '$reason ${item.kind}');
                expect(item.lines.toSet().length, item.lines.length,
                    reason: '$reason ${item.kind}');
              }
              expect(
                fitting(courseLines[place], choice),
                contains(linesOf(guide, GuideKind.course).single),
                reason: reason,
              );
              expect(
                fitting(outfitWeatherLines[weather], choice),
                contains(linesOf(guide, GuideKind.outfit).last),
                reason: reason,
              );
              expect(guide.afterLines.length, 2, reason: reason);
            }
          }
        }
      }
    }
  });

  test('OOTD · 메뉴는 장소 문장 + 날씨 문장', () {
    const choice = DateChoice(
      place: DatePlace.themePark,
      weather: DateWeather.cold,
    );
    final guide = buildDateGuide(choice: choice, basis: basis, now: now);
    final outfit = linesOf(guide, GuideKind.outfit);
    expect(textsOf(outfitLines[DatePlace.themePark]), contains(outfit.first));
    expect(textsOf(outfitWeatherLines[DateWeather.cold]), contains(outfit.last));
    final menu = linesOf(guide, GuideKind.menu);
    expect(textsOf(menuLines[DatePlace.themePark]), contains(menu.first));
    expect(textsOf(menuWeatherLines[DateWeather.cold]), contains(menu.last));
  });

  test('비 오는 날은 비 빼고 단 야외 문장이 안 나옴', () {
    const rainy = DateChoice(place: DatePlace.walk, weather: DateWeather.rain);
    final outdoor = [
      for (final l in courseLines[DatePlace.walk]!)
        if (l.weather != null && !l.weather!.contains(DateWeather.rain)) l.text,
    ];
    for (var seed = 0; seed < 20; seed++) {
      final guide = buildDateGuide(choice: rainy, basis: basis, seed: seed);
      expect(outdoor, isNot(contains(linesOf(guide, GuideKind.course).single)));
    }
  });

  test('대화에 자주 나온 주제가 있으면 대화 소재에 그 주제 질문', () {
    const withTopic = GuideBasis(
      intimacy: Intimacy.close,
      courage: CourageLevel.standard,
      goal: Goal.some,
      topics: [Topic.food],
      fromChat: true,
    );
    final talk = linesOf(
      buildDateGuide(choice: const DateChoice(), basis: withTopic, now: now),
      GuideKind.talk,
    );
    expect(talk.length, 2);
    expect(talk.last, startsWith('${Topic.food.label} · “'));
    final questions = [for (final l in topicLines[Topic.food]!.ask) l.text];
    expect(questions.any((q) => talk.last.contains(q)), isTrue);
    // 주제가 없으면 장소 문장 2개
    final plain = linesOf(
      buildDateGuide(choice: const DateChoice(), basis: basis, now: now),
      GuideKind.talk,
    );
    expect(plain.every(textsOf(talkLines[DatePlace.cafe]).contains), isTrue);
  });

  test('한마디 팁은 목표보다 앞서가지 않음', () {
    String tipOf(GuideBasis b) => linesOf(
          buildDateGuide(choice: const DateChoice(), basis: b, now: now),
          GuideKind.tip,
        ).single;
    List<String> quoted(CourageLevel level) =>
        [for (final t in textsOf(tipLines[level])) '“$t”'];

    const brave = GuideBasis(
      intimacy: Intimacy.close,
      courage: CourageLevel.full,
      goal: Goal.friends,
    );
    expect(quoted(CourageLevel.standard), contains(tipOf(brave)));
    const dating = GuideBasis(
      intimacy: Intimacy.close,
      courage: CourageLevel.full,
      goal: Goal.dating,
    );
    expect(quoted(CourageLevel.full), contains(tipOf(dating)));
    const shy = GuideBasis(
      intimacy: Intimacy.close,
      courage: CourageLevel.low,
      goal: Goal.dating,
    );
    expect(quoted(CourageLevel.low), contains(tipOf(shy)));
  });

  test('존댓말 사이는 한마디 팁 · 만난 뒤 톡도 존댓말', () {
    const formal = GuideBasis(
      intimacy: Intimacy.smallTalk,
      courage: CourageLevel.low,
      goal: Goal.friends,
      formal: true,
    );
    final guide =
        buildDateGuide(choice: const DateChoice(), basis: formal, now: now);
    expect(
      [for (final t in textsOf(formalTipLines[CourageLevel.low])) '“$t”'],
      contains(linesOf(guide, GuideKind.tip).single),
    );
    final after = [for (final l in formalLines[Approach.afterMeet]!) l.text];
    expect(guide.afterLines.every(after.contains), isTrue);
  });

  test('같은 seed는 같은 가이드, seed가 바뀌면 달라짐', () {
    List<List<String>> all(int seed) => [
          for (final item in buildDateGuide(
            choice: const DateChoice(),
            basis: basis,
            seed: seed,
            now: now,
          ).items)
            item.lines,
        ];
    expect(all(1), all(1));
    expect(all(1), isNot(all(2)));
  });

  test('문장 사전: 구역마다 조건 없는 문장 2개 이상', () {
    void check<K>(String name, Map<K, List<GuideLine>> table, List<K> keys) {
      for (final key in keys) {
        final free = (table[key] ?? const <GuideLine>[]).where(
          (l) => l.time == null && l.weather == null && l.company == null,
        );
        expect(free.length, greaterThanOrEqualTo(2), reason: '$name $key');
      }
    }

    check('outfitLines', outfitLines, DatePlace.values);
    check('outfitWeatherLines', outfitWeatherLines, DateWeather.values);
    check('courseLines', courseLines, DatePlace.values);
    check('menuLines', menuLines, DatePlace.values);
    check('menuWeatherLines', menuWeatherLines, DateWeather.values);
    check('talkLines', talkLines, DatePlace.values);
    check('moodLines', moodLines, Intimacy.values);
    check('goalLines', goalLines, Goal.values);
    check('tipLines', tipLines, CourageLevel.values);
    check('formalTipLines', formalTipLines, CourageLevel.values);
  });

  test('대화 주제 → 데이트 장소 (없으면 그대로)', () {
    expect(placeForTopic(Topic.food), DatePlace.restaurant);
    expect(placeForTopic(Topic.movie), DatePlace.movie);
    expect(placeForTopic(Topic.weather), isNull);
  });

  test('실제 대화 분석이 있으면 지금 사이 · 주제는 분석 기준', () {
    final profile = Profile(
      dDay: now,
      reason: '종강',
      intimacy: Intimacy.faceOnly,
      meetingsPerWeek: 1,
      courage: 70,
      goal: Goal.some,
    );

    // 예시 결과는 반영 안 함 (온보딩 입력값 그대로)
    final example = guideBasisOf(profile, fakeChatStats);
    expect(example.fromChat, isFalse);
    expect(example.intimacy, Intimacy.faceOnly);
    expect(example.courage, CourageLevel.boost);
    expect(example.topics, isEmpty);

    const chat = '''지민 님과 카카오톡 대화
저장한 날짜 : 2026년 11월 19일 오후 1:00

2026년 11월 18일 오후 8:00, 민수 : 오늘 점심 뭐 먹었어?
2026년 11월 18일 오후 8:05, 지민 : 학교 앞 떡볶이 먹었어 ㅎㅎ
2026년 11월 18일 오후 8:06, 민수 : 오 맛있겠다
2026년 11월 18일 오후 8:10, 지민 : 거기 맛집이야 다음에 가봐''';
    final stats = analyzeChat(chat, now: DateTime(2026, 11, 19, 13));
    final real = guideBasisOf(profile, stats);
    expect(real.fromChat, isTrue);
    expect(real.intimacy, stats.insight!.intimacy);
    expect(real.topics, stats.features!.topics);
    expect(real.goal, Goal.some);
  });
}
