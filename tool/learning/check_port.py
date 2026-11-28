"""dart_rules.py가 Dart 규칙과 같은지 확인 (test/roadmap_test.dart와 같은 경우)

    python check_port.py
"""
from dataclasses import replace
from datetime import date, timedelta

import dart_rules as R

TODAY = date(2026, 11, 20)


def profile(days_left=20, intimacy='smallTalk', goal='friends', meetings=2, courage=50):
    return R.Profile(TODAY + timedelta(days=days_left), intimacy, meetings, courage, goal)


def build(p):
    return R.build_roadmap(1, p, TODAY)


def done_week(r, index, brave=False):
    weeks = list(r.weeks)
    w = weeks[index]
    weeks[index] = replace(w, missions=tuple(m.mark(True, TODAY, brave) for m in w.missions))
    return replace(r, weeks=tuple(weeks))


def stages(r):
    return [w.stage for w in r.weeks]


def main():
    # 주차 나누기
    assert R.week_ranges(20) == [(20, 14), (13, 7), (6, 0)]
    assert R.week_ranges(0) == [(0, 0)]
    far = R.week_ranges(100)
    assert len(far) == 8 and far[0][0] == 100 and far[-1][1] == 0

    # 단계
    assert stages(build(profile())) == ['topic', 'follow', 'often']
    assert [R.STAGES[i] for i in R.stages_for(profile(intimacy='faceOnly', goal='dating'), 3)] == \
        ['greet', 'follow', 'plan']

    # 미션
    r = build(profile())
    ids = [m.id for w in r.weeks for m in w.missions]
    assert all(len(w.missions) == 3 for w in r.weeks) and len(set(ids)) == len(ids)
    assert all(not m.offline for w in build(profile(meetings=0, goal='dating')).weeks for m in w.missions)
    assert all(m.level == 1 for w in build(profile(courage=10)).weeks for m in w.missions)

    # 진척도
    f = R.read_situation(profile(), done_week(build(profile()), 0), TODAY).progress
    d = R.read_situation(profile(goal='dating'), done_week(build(profile(goal='dating')), 0), TODAY).progress
    assert f > d
    b = R.read_situation(profile(), done_week(build(profile()), 0, brave=True), TODAY).progress
    assert abs(b - f * 1.5) < 1e-3

    # 오늘의 미션
    p = profile(intimacy='close', goal='some')
    r = build(p)
    assert r.weeks[0].stage == 'plan'

    def first(chat, prof=None):
        prof = prof or p
        rr = r if prof is p else build(prof)
        return R.rank_today(R.read_situation(prof, rr, TODAY, chat), TODAY)[0]

    assert 'care' in first(R.Chat('mid', 'comfort')).tags
    assert 'invite' in first(R.Chat('mid', 'invite')).tags
    assert not (first(R.Chat('low')).tags & R.BOLD)
    assert first(None, profile(courage=10)).level == 1

    # 자동 조정
    p = profile(goal='some')
    r = done_week(build(p), 0)
    assert stages(r) == ['topic', 'often', 'alone']
    day3 = TODAY + timedelta(days=3)
    fast = R.read_situation(p, r, day3)
    assert fast.pace == 'ahead'
    shift = R.adapt_shift(fast)
    assert shift == 1
    ahead = R.adapt_roadmap(r, p, day3, shift)
    assert stages(ahead) == ['topic', 'plan', 'show']
    assert ahead.weeks[0].missions == r.weeks[0].missions
    assert R.adapt_shift(R.read_situation(p, ahead, day3)) is None
    careful = R.adapt_shift(R.read_situation(p, ahead, day3, R.Chat('low')))
    assert careful == -1
    slow = R.adapt_roadmap(ahead, p, day3, careful)
    assert stages(slow) == ['topic', 'follow', 'plan']

    # 사전
    assert sum(len(v) for v in R.LINES.values()) == 67
    print('ok: 규칙 옮긴 것이 Dart 테스트와 같음')
    print('예: 기본 로드맵 1주차', [m.id for m in build(profile()).weeks[0].missions])


if __name__ == '__main__':
    main()
