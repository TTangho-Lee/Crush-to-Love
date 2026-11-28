# 미션 흐름 (홈 7 · 로드맵 8 · 우리 사이 업데이트 11 · 주차 상세 14~16)

지금 앱이 쓰는 미션 흐름. 팀원 `lib/mission/`과 클래스 이름이 겹치지 않게 `Roadmap*` · `MissionLine`으로 둠.

- 상대별 로드맵 · 다시 짜기 · 자동 조정: `roadmap_store.dart` · `roadmap_generator.dart` · `roadmap_rules.dart`
- 미션 맞춤 추천 연결: `roadmap_learning.dart` (미션 → `MissionArm` · `MissionContext`로 바꿔 `lib/learning`에 기록)
- 미션 사전: `mission_lines.dart` (미션 67개 · 용기 · 대면 · 태그)
- 화면: `roadmap_home_screen.dart` · `roadmap_overview_screen.dart` · `roadmap_week_screen.dart` · `roadmap_relation_screen.dart`
- 저장: `roadmap.db` (상대마다 로드맵 한 줄)

## 팀원 것과 합칠 때
팀원 `lib/mission/`과 이 폴더 중 무엇을 남길지 정한 뒤, 남기는 쪽으로 `main.dart` · `app/main_shell.dart`의 미션 부분을 맞추기.
