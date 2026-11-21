// 가이드 규칙: 고른 조건(장소 · 날씨 · 시간 · 인원) + 상황(사이 · 용기 · 목표 · 대화 주제) → DateGuide
//   AI 없이 date_lines.dart 문장 사전에서 고름, 조건에 맞는 문장 중 seed로 돌려 고름
//   OOTD · 메뉴: 장소 문장 + 날씨 문장, 코스: 장소 문장 (시간 · 날씨 · 인원 조건 반영)
//   대화 소재: 장소 문장 + 대화에 자주 나온 주제가 있으면 그 주제 질문 (채팅 멘트 사전)
//   분위기: 지금 사이 문장 + 목표 문장
//   한마디 팁: 용기 단계 문장, 목표보다 앞서가지 않게 (친해지기면 '표준'까지, 썸이면 '고속충전'까지)
//   만난 뒤 톡: 채팅의 '만난 뒤 이어가기' 멘트 (시간대 맞춰)
import '../../shared/models.dart';
import '../chat/chat_stats.dart';
import '../chat/rules/lexicon.dart';
import '../chat/rules/lines.dart';
import '../chat/rules/topics.dart';
import 'date_guide.dart';
import 'date_lines.dart';

/// 온보딩 입력값 + 대화 분석 결과 → 가이드에 반영할 상황
/// 실제 대화 분석이 있으면 지금 사이 · 주제 · 존댓말은 대화 기준, 없으면 온보딩 기준
GuideBasis guideBasisOf(Profile profile, ChatStats chat) {
  final features = chat.features;
  final insight = chat.insight;
  final courage = CourageLevel.of(profile.courage);
  if (chat.isExample || features == null || insight == null) {
    return GuideBasis(
      intimacy: profile.intimacy,
      courage: courage,
      goal: profile.goal,
    );
  }
  return GuideBasis(
    intimacy: insight.intimacy,
    courage: courage,
    goal: profile.goal,
    topics: features.topics,
    formal: features.me.rate(MessageTag.honorific) >= 0.5,
    fromChat: true,
  );
}

/// seed: 0 이상, 같은 seed · 조건이면 같은 가이드
/// now: 만난 뒤 톡 날짜 (기본은 오늘)
DateGuide buildDateGuide({
  required DateChoice choice,
  required GuideBasis basis,
  int seed = 0,
  DateTime? now,
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

  final topic = basis.topics.isEmpty ? null : basis.topics.first;
  final question = topic == null ? null : _topicQuestion(topic, basis, seed);
  final topicLine = topic == null || question == null
      ? null
      : '${topic.label} · “$question”';
  final tipLevel = _capByGoal(basis.courage, basis.goal);
  final tipPool = (basis.formal ? formalTipLines : tipLines)[tipLevel];

  final day = now ?? DateTime.now();
  final at = DateTime(
    day.year,
    day.month,
    day.day,
    choice.time == MeetTime.day ? 15 : 21,
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
        if (topicLine != null) topicLine,
      ]),
      GuideItem(GuideKind.mood, [
        ...pick(moodLines[basis.intimacy], 6),
        ...pick(goalLines[basis.goal], 7),
      ]),
      GuideItem(GuideKind.tip, [
        for (final line in pick(tipPool, 8)) '“$line”',
      ]),
    ],
    afterLines: pickLines(
      Approach.afterMeet,
      now: at,
      seed: seed,
      formal: basis.formal,
      count: 2,
    ),
  );
}

/// 대화에 자주 나온 주제로 물어볼 말 (채팅 주제 멘트 중 시간 상관없는 '묻기')
String? _topicQuestion(Topic topic, GuideBasis basis, int seed) {
  final lines = (basis.formal ? formalTopicLines : topicLines)[topic]?.ask;
  final pool = [
    for (final line in lines ?? const <Line>[])
      if (line.slot == null && line.weekend == null) line.text,
  ];
  return pool.isEmpty ? null : pool[seed % pool.length];
}

/// 목표보다 앞서가지 않는 용기 단계 (친해지기 → 표준까지, 썸 타기 → 고속충전까지)
CourageLevel _capByGoal(CourageLevel courage, Goal goal) {
  final max = switch (goal) {
    Goal.friends => CourageLevel.standard,
    Goal.some => CourageLevel.boost,
    Goal.dating => CourageLevel.full,
  };
  return courage.index <= max.index ? courage : max;
}
