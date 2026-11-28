// 가이드 규칙: 고른 조건(장소 · 날씨 · 시간 · 인원) + 상황(사이 · 용기 · 목표 · 대화 주제) → DateGuide
//   AI 없이 date_lines.dart 문장 사전에서 고름, 조건에 맞는 문장 중 seed로 돌려 고름
//   OOTD · 메뉴: 장소 문장 + 날씨 문장, 코스: 장소 문장 (시간 · 날씨 · 인원 조건 반영)
//   대화 소재: 장소 문장 + 대화에 자주 나온 주제가 있으면 그 주제 질문 (채팅 멘트 사전)
//   분위기: 지금 사이 문장 + 목표 문장
//   한마디 팁: 용기 단계 문장, 목표보다 앞서가지 않게 (친해지기면 '표준'까지, 썸이면 '고속충전'까지)
//   만난 뒤 톡: 채팅의 '만난 뒤 이어가기' 멘트 (시간대 맞춰)
//   한마디 팁 · 대화 소재 질문 · 만난 뒤 톡의 웃음(ㅋㅋ · ㅎㅎ)은 말투에 맞춰 (basis.tone, chat/rules/tone.dart)
//   맞춤 추천(sayOrder)을 주면 말해볼 문장(한마디 팁 · 대화 소재 질문 · 만난 뒤 톡)은 학습 순서에서 round번째
//     (멘트 학습과 같은 분야, date_store.dart), 나머지 항목은 늘 위처럼 seed로 (고른 걸 알 수 있는 신호가 없어서)
import '../../shared/models.dart';
import '../chat/chat_stats.dart';
import '../chat/rules/lexicon.dart';
import '../chat/rules/lines.dart';
import '../chat/rules/tone.dart';
import '../chat/rules/topics.dart';
import 'date_guide.dart';
import 'date_lines.dart';

/// 온보딩 입력값 + 대화 분석 결과 → 가이드에 반영할 상황
/// 실제 대화 분석이 있으면 지금 사이 · 주제 · 존댓말은 대화 기준, 없으면 온보딩 기준
/// useChat: 마지막 분석이 지금 상대와의 대화일 때만 true (다른 상대 대화면 온보딩 기준)
/// laugh · speech: 설정에서 고른 웃음 표현 · 말 높이 (대화에 맞춤이면 대화 기준, 대화가 없으면 기본 말투 · 반말)
GuideBasis guideBasisOf(
  Profile profile,
  ChatStats chat, {
  bool useChat = true,
  LaughStyle laugh = LaughStyle.auto,
  SpeechLevel speech = SpeechLevel.auto,
}) {
  final features = chat.features;
  final insight = chat.insight;
  final courage = CourageLevel.of(profile.courage);
  if (!useChat || chat.isExample || features == null || insight == null) {
    return GuideBasis(
      intimacy: profile.intimacy,
      courage: courage,
      goal: profile.goal,
      formal: speech.formalOr(false),
      tone: const Tone().withStyle(laugh),
    );
  }
  return GuideBasis(
    intimacy: insight.intimacy,
    courage: courage,
    goal: profile.goal,
    topics: features.topics,
    formal: speech.formalOr(features.me.rate(MessageTag.honorific) >= 0.5),
    fromChat: true,
    tone: insight.tone.withStyle(laugh),
  );
}

/// 말해볼 문장 학습 순서 (slot: 'tip' · 'question' · 'after', pool: 조건에 맞는 사전 문장)
typedef SayOrder = List<Line> Function(String slot, List<Line> pool);

/// seed: 0 이상, 같은 seed · 조건이면 같은 가이드
/// now: 만난 뒤 톡 날짜 (기본은 오늘)
/// sayOrder: 말해볼 문장 학습 순서, round: '다른 추천 보기' 횟수 (sayOrder가 있을 때만 씀)
DateGuide buildDateGuide({
  required DateChoice choice,
  required GuideBasis basis,
  int seed = 0,
  DateTime? now,
  SayOrder? sayOrder,
  int round = 0,
}) {
  /// 조건에 맞는 문장 중 count개 (겹치지 않게), salt: 항목마다 다르게 돌리기
  List<String> pick(List<GuideLine>? pool, int salt, {int count = 1}) {
    final fits = [
      for (final line in pool ?? const <GuideLine>[])
        if (line.fits(choice)) line.text,
    ];
    if (fits.isEmpty) return const [];
    final start = (seed + salt) % fits.length;
    return [
      for (var i = 0; i < count && i < fits.length; i++)
        fits[(start + i) % fits.length],
    ];
  }

  /// 학습 순서에서 round번째부터 count개 (겹치지 않게)
  List<String> ordered(String slot, List<Line> pool, {int count = 1}) {
    if (pool.isEmpty) return const [];
    final order = sayOrder!(slot, pool);
    return [
      for (var i = 0; i < count && i < order.length; i++)
        order[(round * count + i) % order.length].text,
    ];
  }

  // 말투 입힌 글자 → 사전 문장
  final sayings = <String, String>{};
  List<String> toned(List<String> raw) {
    final out = applyToneEach(raw, basis.tone, seed: seed);
    final shown = <String>[];
    for (var i = 0; i < raw.length; i++) {
      if (out[i].isEmpty) continue;
      sayings[out[i]] = raw[i];
      shown.add(out[i]);
    }
    return shown;
  }

  final topic = basis.topics.isEmpty ? null : basis.topics.first;
  final question = topic == null
      ? null
      : sayOrder == null
          ? _topicQuestion(topic, basis, seed)
          : ordered('question', _topicQuestions(topic, basis)).firstOrNull;
  final asked = question == null ? const <String>[] : toned([question]);
  final topicLine = topic == null || asked.isEmpty
      ? null
      : '${topic.label} · “${asked.single}”';
  final tipLevel = _capByGoal(basis.courage, basis.goal);
  final tipPool = (basis.formal ? formalTipLines : tipLines)[tipLevel];
  final tipRaw = sayOrder == null
      ? pick(tipPool, 8)
      : ordered('tip', [
          for (final line in tipPool ?? const <GuideLine>[])
            if (line.fits(choice)) Line(line.text),
        ]);

  final day = now ?? DateTime.now();
  final at = DateTime(
    day.year,
    day.month,
    day.day,
    choice.time == MeetTime.day ? 15 : 21,
  );
  final afterRaw = sayOrder == null
      ? pickLines(
          Approach.afterMeet,
          now: at,
          seed: seed,
          formal: basis.formal,
          count: 2,
        )
      : ordered(
          'after',
          linePools(Approach.afterMeet, now: at, formal: basis.formal).$2,
          count: 2,
        );

  return DateGuide(
    choice: choice,
    basis: basis,
    items: [
      GuideItem(GuideKind.outfit, [
        ...pick(outfitLines[choice.place], 0),
        ...pick(outfitWeatherLines[choice.weather], 1),
      ]),
      GuideItem(GuideKind.course, pick(courseLines[choice.place], 2)),
      GuideItem(GuideKind.menu, [
        ...pick(menuLines[choice.place], 3),
        ...pick(menuWeatherLines[choice.weather], 4),
      ]),
      GuideItem(GuideKind.talk, [
        ...pick(talkLines[choice.place], 5, count: topicLine == null ? 2 : 1),
        ?topicLine,
      ]),
      GuideItem(GuideKind.mood, [
        ...pick(moodLines[basis.intimacy], 6),
        ...pick(goalLines[basis.goal], 7),
      ]),
      GuideItem(GuideKind.tip, [
        for (final line in toned(tipRaw)) '“$line”',
      ]),
    ],
    afterLines: toned(afterRaw),
    sayings: sayings,
  );
}

/// 대화에 자주 나온 주제에 어울리는 데이트 장소, 없으면 null (대화 분석 → 데이트 준비하기에서 미리 고름)
DatePlace? placeForTopic(Topic topic) => switch (topic) {
      Topic.food || Topic.cook => DatePlace.restaurant,
      Topic.cafe || Topic.book => DatePlace.cafe,
      Topic.movie => DatePlace.movie,
      Topic.drink => DatePlace.bar,
      Topic.campus || Topic.study => DatePlace.campus,
      Topic.exercise || Topic.pet || Topic.travel => DatePlace.walk,
      Topic.photo || Topic.hobby => DatePlace.exhibition,
      _ => null,
    };

/// 대화에 자주 나온 주제로 물어볼 말 (채팅 주제 멘트 중 시간 상관없는 '묻기')
String? _topicQuestion(Topic topic, GuideBasis basis, int seed) {
  final pool = _topicQuestions(topic, basis);
  return pool.isEmpty ? null : pool[seed % pool.length].text;
}

/// 주제 질문 후보 (시간 상관없는 '묻기')
List<Line> _topicQuestions(Topic topic, GuideBasis basis) => [
      for (final line
          in (basis.formal ? formalTopicLines : topicLines)[topic]?.ask ??
              const <Line>[])
        if (line.slot == null && line.weekend == null) line,
    ];

/// 목표보다 앞서가지 않는 용기 단계 (친해지기 → 표준까지, 썸 타기 → 고속충전까지)
CourageLevel _capByGoal(CourageLevel courage, Goal goal) {
  final max = switch (goal) {
    Goal.friends => CourageLevel.standard,
    Goal.some => CourageLevel.boost,
    Goal.dating => CourageLevel.full,
  };
  return courage.index <= max.index ? courage : max;
}
