// 가짜 데이터 (피그마 예시 그대로). 실제 기능이 생기면 교체
import 'models.dart';

/// 온보딩 입력값 예시 (D-Day는 오늘부터 20일 뒤)
Profile fakeProfile() {
  return Profile(
    dDay: DateTime.now().add(const Duration(days: 20)),
    reason: '종강',
    intimacy: Intimacy.smallTalk,
    meetingsPerWeek: 2,
    courage: 50,
    goal: Goal.friends,
  );
}

/// 로드맵 예시 (3주, 주마다 미션 3개)
const fakeWeeks = [
  WeekPlan(
    weekNo: 1,
    title: '인사할 틈 만들기',
    fromDDay: 20,
    toDDay: 14,
    missions: [
      Mission(
        id: 'w1-1',
        title: '마주치면 먼저 인사하기',
        tip: '눈이 마주쳤을 때 짧게 인사해요.',
        done: true,
      ),
      Mission(
        id: 'w1-2',
        title: '스토리에 가볍게 반응 남기기',
        tip: '관심 있는 스토리에 이모지 하나를 남겨봐요.',
      ),
      Mission(
        id: 'w1-3',
        title: '눈이 마주치면 가볍게 웃기',
        tip: '다음에 마주치면 편하게 웃어봐요.',
      ),
    ],
  ),
  WeekPlan(
    weekNo: 2,
    title: '이야기할 거리 찾기',
    fromDDay: 13,
    toDDay: 7,
    missions: [
      Mission(
        id: 'w2-1',
        title: '공통 관심사 하나 찾아보기',
        tip: '같이 듣는 수업이나 즐겨 하는 활동을 떠올려요.',
      ),
      Mission(
        id: 'w2-2',
        title: '스토리에 짧게 답글 남기기',
        tip: '궁금한 점이 있다면 질문 하나만 건네요.',
      ),
      Mission(
        id: 'w2-3',
        title: '공통 관심사 하나 물어보기',
        tip: '답하기 쉬운 질문으로 대화를 열어봐요.',
      ),
    ],
  ),
  WeekPlan(
    weekNo: 3,
    title: '다음 대화 이어가기',
    fromDDay: 6,
    toDDay: 0,
    missions: [
      Mission(
        id: 'w3-1',
        title: '지난 대화에서 주제 하나 고르기',
        tip: '서로 재밌게 이야기한 내용을 떠올려요.',
      ),
      Mission(
        id: 'w3-2',
        title: '최근 이야기한 주제로 먼저 연락하기',
        tip: '관련 링크나 소식이 있다면 가볍게 공유해요.',
      ),
      Mission(
        id: 'w3-3',
        title: '다음에 이야기할 계기 만들기',
        tip: '상대가 편하게 반응하면 다음에 또 이야기하자고 전해요.',
      ),
    ],
  ),
];

/// 대화 분석 결과 예시
const fakeChatStats = ChatStats(
  summary: '답장이 오간 리듬',
  avgReplyMinutes: 25,
  avgLength: 17,
  messagesPerDay: 6,
  positivePercent: 67,
);

/// 데이트 가이드 예시
const fakeDateGuide = DateGuide(
  place: '감성 카페',
  weather: '맑음',
  items: [
    GuideItem(title: 'OOTD', content: '깔끔한 셔츠나 가벼운 니트에 편한 신발'),
    GuideItem(title: '데이트 코스', content: '카페에서 대화 → 근처에서 가볍게 산책'),
    GuideItem(title: '추천 메뉴', content: '나눠 먹기 쉬운 디저트와 각자 좋아하는 음료'),
    GuideItem(title: '분위기 가이드', content: '가벼운 질문으로 시작하고 상대의 반응을 살펴요.'),
    GuideItem(title: '한마디 팁', content: '"오늘 이야기 즐거웠어, 다음에도 여기 올래?"'),
  ],
);
