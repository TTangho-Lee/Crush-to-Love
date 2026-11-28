"""test/learning_mission_test.dart 기대값: DummyMissionStore에 학습을 붙였을 때 (Dart와 같은 계산)

    python expected_mission.py

2026-11-20(금) 14시, 지민 D-20 · 스몰토크 · 친해지기 · 주 2회 · 용기 50, 상대 번호 1
① 학습 켬, 기록 없음: 완료 기록이 5개 미만이라 로드맵은 지금 순서, 오늘의 미션은 학습 순서
② 시연용 기록(make_demo.py) 넣고 이번 주 다시 고르기: 1주차 · 오늘의 미션 · 이유 · 잘 해낸/안 한 종류
③ 쉬운 미션 최소 1개: topic 단계를 용기 2 먼저 세운 순서로 고르기
"""
from datetime import datetime, timedelta

import dart_rules as R
import demo_effect as E
import make_demo as D
import mission_features as F

NOW = datetime(2026, 11, 20, 14)
P = R.Profile(NOW.date() + timedelta(days=20), 'smallTalk', 2, 50, 'friends')

LABELS = {'tag.prep': '혼자 준비', 'tag.greet': '인사', 'tag.react': '반응 남기기', 'tag.ask': '질문',
          'tag.share': '내 이야기', 'tag.care': '챙기기', 'tag.push': '먼저 연락', 'tag.invite': '약속 잡기',
          'tag.express': '마음 표현', 'offline': '직접 만나기', 'offlineWeekend': '주말에 만나기',
          'onlineEvening': '저녁에 만나지 않고'}


def traits(rows):
    """Dart missionTraits (가중치 1e-9 반올림, 같으면 특징 순서)"""
    model, mean0 = D.model_of(rows)
    mu = model.mean()
    seen = set()
    for _, _, _, c in rows:
        phi = D.phi_of(c, c['lv'], c['off'], set(c['tags']))
        seen |= {i for i, v in enumerate(phi) if v}
    all_ = [(LABELS[n], mu[i] - mean0[i], i) for i, n in enumerate(F.GLOBAL_NAMES)
            if n in LABELS and i in seen and abs(mu[i] - mean0[i]) >= 0.05]
    good = sorted([t for t in all_ if t[1] > 0], key=lambda t: (-round(t[1] * 1e9), t[2]))[:3]
    bad = sorted([t for t in all_ if t[1] < 0], key=lambda t: (round(t[1] * 1e9), t[2]))[:3]
    return [t[0] for t in good], [t[0] for t in bad]


def main():
    road = R.build_roadmap(1, P, NOW.date())
    print('① 로드맵 (지금 순서)', [[m.id for m in w.missions] for w in road.weeks])
    rows = [(m.id, k, r, D.ctx_of(c, m)) for _, m, k, r, c in D.demo_log()]
    e = E.effect(rows, P, NOW)
    print('① 오늘의 미션', e['before'])
    print('② 기록', len(rows), '완료', sum(1 for r in rows if r[1] == 'done'))
    print('② 다시 고른 1주차', e['week'], '→ 오늘의 미션', e['after'], '이유', e['why'])
    good, bad = traits(rows)
    print('② 잘 해낸', good, '잘 안 한', bad)
    order = [1, 2, 4, 5, 6, 8, 0, 3, 7]
    print('③', [m.id for m in R.pick(1, seed=38, can_meet=True, max_level=2, used=set(), order=order)])


if __name__ == '__main__':
    main()
