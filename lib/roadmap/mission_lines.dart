// 미션 사전 (미션 67개 · 단계 · 용기 · 대면 · 태그)
// 단계(RoadmapStage) 8개를 차례로 밟아 감: 사이에서 시작, 목표에서 멈춤 (roadmap_generator.dart)
//   미션마다 offline(직접 만나야 하는지) · level(필요한 용기 1 ~ 3) · tags(어떤 행동인지)
//     만남 빈도가 주 0회면 offline 미션은 빼고, 용기 단계보다 어려운 미션은 뒤로 미룸
//     tags는 오늘의 미션 고르기에 씀: 대화 분석 추천 방향 · 상대 반응에 맞는 행동을 먼저 (roadmap_rules.dart)
//   팁은 한 문장, 빈칸(○○) 없이
//   이 파일은 /tmp/dm/gen_lines.py로 만듦 (문장만 고칠 땐 직접 고쳐도 됨)

/// 미션이 어떤 행동인지
enum MissionTag {
  prep('혼자 준비'),
  greet('인사'),
  react('반응'),
  ask('질문'),
  share('내 이야기 · 공유'),
  care('챙김'),
  push('먼저 연락'),
  invite('약속'),
  express('마음 표현');

  const MissionTag(this.label);

  final String label;
}

/// 미션 하나 (사전)
class MissionLine {
  const MissionLine(
    this.title,
    this.tip, {
    this.offline = false,
    this.level = 1,
    this.tags = const {},
  });

  final String title;
  final String tip;

  /// 직접 만나야 할 수 있으면 true (만남 빈도가 주 0회면 안 고름)
  final bool offline;

  /// 필요한 용기 1(가벼움) ~ 3(큰 용기)
  final int level;

  final Set<MissionTag> tags;
}

/// 로드맵 단계 (주차 제목 · 이번 주 목표 한 줄)
enum RoadmapStage {
  greet('인사할 틈 만들기', '얼굴을 익히고 가볍게 인사를 주고받아요.'),
  topic('이야기할 거리 찾기', '서로 이야기할 소재를 찾아요.'),
  follow('다음 대화 이어가기', '한 번 한 대화를 다음으로 이어 가요.'),
  often('연락 자주 주고받기', '연락을 자연스러운 일상으로 만들어요.'),
  plan('가볍게 약속 잡기', '부담 없는 약속을 잡아 봐요.'),
  alone('단둘이 시간 보내기', '단둘이 보내는 시간을 만들어요.'),
  show('마음 살짝 보여주기', '호감을 살짝 보여 줘요.'),
  confess('마음 전하기', '마음을 전할 준비를 하고 전해요.');

  const RoadmapStage(this.title, this.description);

  final String title;

  /// 이 단계에서 할 일 한 줄 (주차 상세 맨 위)
  final String description;
}

/// 단계별 미션 (단계마다 7개 이상, 만나지 않고 할 수 있는 미션 3개 이상)
const Map<RoadmapStage, List<MissionLine>> missionLines = {
  RoadmapStage.greet: [
    MissionLine('마주치면 먼저 인사하기', '눈이 마주쳤을 때 짧게 인사해요.', offline: true, tags: {MissionTag.greet}),
    MissionLine('눈이 마주치면 가볍게 웃기', '다음에 마주치면 편하게 웃어 봐요.', offline: true, tags: {MissionTag.greet}),
    MissionLine('스토리에 가볍게 반응 남기기', '관심 있는 스토리에 이모지 하나를 남겨 봐요.', tags: {MissionTag.react}),
    MissionLine('자연스럽게 마주칠 곳 알아 두기', '수업 · 동아리 · 자주 가는 카페처럼 겹치는 곳을 떠올려요.', tags: {MissionTag.prep}),
    MissionLine('이름 불러서 인사하기', "'안녕' 대신 이름을 넣어 인사해 봐요.", offline: true, level: 2, tags: {MissionTag.greet}),
    MissionLine('단체 대화방에서 상대 말에 반응하기', '상대가 남긴 말에 짧게 공감해 줘요.', tags: {MissionTag.react}),
    MissionLine('게시물에 좋아요 누르기', '부담 없는 게시물 하나에 좋아요를 눌러요.', tags: {MissionTag.react}),
    MissionLine('짧은 안부 한마디 건네기', "'오늘 수업 힘들었지?'처럼 한 문장이면 충분해요.", offline: true, level: 2, tags: {MissionTag.greet, MissionTag.care}),
    MissionLine('먼저 톡으로 가볍게 인사하기', '같이 듣는 수업이나 모임 이야기를 핑계로 인사해요.', level: 3, tags: {MissionTag.greet, MissionTag.push}),
  ],
  RoadmapStage.topic: [
    MissionLine('공통 관심사 하나 찾아보기', '같이 듣는 수업이나 즐겨 하는 활동을 떠올려요.', tags: {MissionTag.prep}),
    MissionLine('스토리에 짧게 답글 남기기', '궁금한 점이 있다면 질문 하나만 건네요.', level: 2, tags: {MissionTag.react, MissionTag.ask}),
    MissionLine('공통 관심사 하나 물어보기', '답하기 쉬운 질문으로 대화를 열어 봐요.', level: 2, tags: {MissionTag.ask}),
    MissionLine('상대가 좋아하는 것 적어 두기', '대화에서 나온 취향을 잊지 않게 메모해 둬요.', tags: {MissionTag.prep}),
    MissionLine('요즘 빠진 것 물어보기', "'요즘 재밌는 거 있어?'처럼 열린 질문을 건네요.", level: 2, tags: {MissionTag.ask}),
    MissionLine('마주쳤을 때 한마디 더 하기', '인사 뒤에 날씨나 수업 이야기를 하나 덧붙여요.', offline: true, level: 2, tags: {MissionTag.greet, MissionTag.ask}),
    MissionLine('추천 하나 부탁하기', '맛집 · 노래 · 책처럼 가볍게 추천을 부탁해요.', level: 2, tags: {MissionTag.ask}),
    MissionLine('들은 이야기에서 하나 더 묻기', '상대 이야기에서 궁금한 걸 하나 더 물어봐요.', tags: {MissionTag.ask, MissionTag.react}),
    MissionLine('먼저 연락할 핑계 만들기', '과제 · 행사 · 공지처럼 물어볼 거리를 챙겨 둬요.', level: 2, tags: {MissionTag.prep, MissionTag.push}),
  ],
  RoadmapStage.follow: [
    MissionLine('지난 대화에서 주제 하나 고르기', '서로 재밌게 이야기한 내용을 떠올려요.', tags: {MissionTag.prep}),
    MissionLine('최근 이야기한 주제로 먼저 연락하기', '관련 링크나 소식이 있다면 가볍게 공유해요.', level: 2, tags: {MissionTag.push, MissionTag.share}),
    MissionLine('다음에 이야기할 계기 만들기', '상대가 편하게 반응하면 다음에 또 이야기하자고 전해요.', level: 2, tags: {MissionTag.ask}),
    MissionLine('추천받은 것 해 보고 후기 전하기', '추천해 준 노래나 가게를 해 보고 짧게 알려 줘요.', level: 2, tags: {MissionTag.share}),
    MissionLine('대화를 질문으로 끝내기', '답장하기 쉽게 가벼운 질문을 하나 남겨요.', tags: {MissionTag.ask}),
    MissionLine('들었던 일정 기억했다가 묻기', '시험 · 발표처럼 들었던 일이 어떻게 됐는지 물어봐요.', level: 2, tags: {MissionTag.care, MissionTag.ask}),
    MissionLine('마주치면 지난 이야기 꺼내기', "'그때 말한 거 어떻게 됐어?'로 이어 가요.", offline: true, level: 2, tags: {MissionTag.greet, MissionTag.share}),
    MissionLine('웃긴 짤이나 영상 하나 보내기', '같이 웃었던 주제와 이어지는 걸 골라요.', tags: {MissionTag.share}),
    MissionLine('답장 속도 맞춰 보기', '너무 빠르지도 느리지도 않게 상대 리듬에 맞춰요.', tags: {MissionTag.react}),
  ],
  RoadmapStage.often: [
    MissionLine('하루 한 번 먼저 톡 보내기', '짧은 안부나 오늘 있었던 일 하나면 충분해요.', level: 2, tags: {MissionTag.push}),
    MissionLine('상대 하루 물어보기', "'오늘 어땠어?'처럼 하루를 묻는 말로 시작해요.", tags: {MissionTag.ask, MissionTag.care}),
    MissionLine('내 이야기도 하나 꺼내기', '묻기만 하지 말고 내 일도 하나 들려줘요.', tags: {MissionTag.share}),
    MissionLine('힘들 때 응원 한마디 건네기', '바쁘거나 지친 날엔 짧게 응원해 줘요.', level: 2, tags: {MissionTag.care}),
    MissionLine('사진 한 장 공유하기', '맛있게 먹은 것이나 예쁜 하늘을 보내 봐요.', tags: {MissionTag.share}),
    MissionLine('함께 아는 이야기로 수다 떨기', '수업 · 동아리 · 친구 이야기로 편하게 떠들어요.', tags: {MissionTag.share, MissionTag.react}),
    MissionLine('마주치면 조금 더 오래 이야기하기', '인사만 하고 지나치지 말고 몇 마디 더 나눠요.', offline: true, level: 2, tags: {MissionTag.greet, MissionTag.ask}),
    MissionLine('잘 자 · 좋은 아침 인사하기', '하루의 시작이나 끝에 가볍게 인사해요.', level: 2, tags: {MissionTag.care, MissionTag.push}),
    MissionLine('전화나 음성 메시지 한 번 해 보기', '글자보다 목소리가 더 가깝게 느껴져요.', level: 3, tags: {MissionTag.push}),
  ],
  RoadmapStage.plan: [
    MissionLine('같이 갈 만한 곳 하나 찾아 두기', '상대 취향에 맞는 카페나 맛집을 골라 둬요.', tags: {MissionTag.prep}),
    MissionLine('가볍게 밥이나 커피 제안하기', "'시간 되면 같이 갈래?'처럼 부담 없이 물어봐요.", level: 2, tags: {MissionTag.invite}),
    MissionLine('날짜 · 시간 구체적으로 정하기', "'다음 주 수요일 점심 어때?'처럼 구체적으로 정해요.", level: 3, tags: {MissionTag.invite}),
    MissionLine('여럿이 같이 놀 자리 만들기', '친구들과 함께하는 자리에 초대해 봐요.', level: 2, tags: {MissionTag.invite}),
    MissionLine('끝나고 같이 걸어가기', '가는 방향이 같다면 자연스럽게 같이 걸어요.', offline: true, level: 2, tags: {MissionTag.greet, MissionTag.invite}),
    MissionLine('거절해도 괜찮게 말하기', "'안 되면 다음에!'를 붙여 부담을 덜어 줘요.", tags: {MissionTag.prep}),
    MissionLine('약속 전날 가볍게 확인하기', "'내일 기대된다'처럼 설렘을 살짝 전해요.", level: 2, tags: {MissionTag.care}),
    MissionLine('데이트 준비 가이드 보기', '데이트 탭에서 장소와 날씨에 맞게 준비해요.', tags: {MissionTag.prep}),
  ],
  RoadmapStage.alone: [
    MissionLine('단둘이 식사나 카페 가기', '편하게 이야기할 수 있는 조용한 곳을 골라요.', offline: true, level: 2, tags: {MissionTag.invite}),
    MissionLine('만나서 이야기 잘 들어 주기', '고개를 끄덕이며 질문으로 이어 가요.', offline: true, tags: {MissionTag.react}),
    MissionLine('만난 뒤 잘 들어갔는지 묻기', "'오늘 재밌었어, 잘 들어갔어?'로 마무리해요.", tags: {MissionTag.care}),
    MissionLine('다음 약속 먼저 꺼내기', '오늘 이야기한 것과 이어지는 다음 계획을 말해요.', level: 3, tags: {MissionTag.invite, MissionTag.push}),
    MissionLine('상대가 좋아하는 걸 함께 해 보기', '상대 취미를 같이 해 보자고 해요.', offline: true, level: 2, tags: {MissionTag.invite}),
    MissionLine('작은 간식 하나 챙기기', '음료나 간식처럼 부담 없는 걸로 골라요.', offline: true, level: 2, tags: {MissionTag.care}),
    MissionLine('오늘 즐거웠던 점 톡으로 남기기', '함께한 시간 중 좋았던 순간 하나를 짚어 말해요.', tags: {MissionTag.share, MissionTag.express}),
    MissionLine('영상 통화나 긴 통화 해 보기', '만나기 어려운 날엔 목소리로 이어 가요.', level: 3, tags: {MissionTag.push}),
  ],
  RoadmapStage.show: [
    MissionLine('칭찬 한마디 건네기', '옷 · 웃음 · 말투처럼 구체적으로 칭찬해요.', level: 2, tags: {MissionTag.express}),
    MissionLine('함께라서 즐겁다고 말하기', "'너랑 얘기하면 재밌어'처럼 살짝 전해요.", level: 2, tags: {MissionTag.express}),
    MissionLine('좋아한다던 것 기억해 챙기기', '말했던 간식이나 노래를 기억해 챙겨 줘요.', offline: true, level: 2, tags: {MissionTag.care}),
    MissionLine('생각났다고 연락하기', "'이거 보니까 너 생각나더라'로 시작해요.", level: 2, tags: {MissionTag.push, MissionTag.express}),
    MissionLine('단둘이 시간 한 번 더 만들기', '둘만의 약속을 자연스럽게 하나 더 잡아요.', level: 3, tags: {MissionTag.invite}),
    MissionLine('관심 표현에 대한 반응 살펴보기', '살짝 마음을 보였을 때 상대가 어떻게 반응하는지 봐요.', tags: {MissionTag.prep}),
    MissionLine('고마운 점 말로 전하기', '도와줬거나 챙겨 준 일을 고맙다고 말해요.', tags: {MissionTag.care, MissionTag.express}),
    MissionLine('둘만 아는 이야기 만들기', '둘만 웃을 수 있는 농담이나 장소를 만들어요.', level: 2, tags: {MissionTag.share}),
  ],
  RoadmapStage.confess: [
    MissionLine('마음 전할 때와 곳 정하기', '둘이 편하게 이야기할 수 있는 조용한 때를 골라요.', tags: {MissionTag.prep}),
    MissionLine('하고 싶은 말 미리 적어 보기', '길지 않게, 솔직한 마음 한두 문장이면 돼요.', tags: {MissionTag.prep}),
    MissionLine('상대 마음 한 번 더 살피기', '요즘 반응이 편안한지 차분히 돌아봐요.', tags: {MissionTag.prep}),
    MissionLine('진심으로 마음 전하기', '꾸미지 말고 내 마음을 그대로 말해요.', offline: true, level: 3, tags: {MissionTag.express}),
    MissionLine('대답을 재촉하지 않기', '상대가 생각할 시간을 충분히 줘요.', tags: {MissionTag.prep}),
    MissionLine('어떤 대답이든 고맙다고 말하기', '들어 준 것만으로도 고맙다고 전해요.', level: 2, tags: {MissionTag.care, MissionTag.express}),
    MissionLine('만나기 어렵다면 진심 담은 톡 보내기', '직접 못 만나면 차분한 글로 마음을 전해요.', level: 3, tags: {MissionTag.express}),
  ],
};
