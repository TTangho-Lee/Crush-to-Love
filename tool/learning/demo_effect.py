"""시연 효과: Dart 흐름(넣기 전 → 넣고 이번 주 다시 고르기)으로 오늘의 미션 1순위 · 이유가 바뀌는지

    python demo_effect.py [seed 수]   # 시연 seed 고르기 (make_demo.py의 DEMO · DAYS · RUN)
"""
import sys
from dataclasses import replace
from datetime import datetime, timedelta
import numpy as np
import dart_rules as R, make_demo as D, simulate as S, mission_features as F
from linear_ts import Model, Rng, fnv1a

def theta(m, key): return m.sample(Rng(fnv1a(f'mission|{key}')), 0.15)

def today_rank(model, s, now, cid=1):
    rules = R.rank_today(s, now)
    week, _, _ = R.today_candidates(s)
    stage = R.STAGES.index(week.stage)
    th = theta(model, f'today|{cid}|{now:%Y%m%d}')
    rows = []
    for i, m in enumerate(rules):
        ctx = S.context(s, now, now.hour, R.rule_score(m, s, stage, now))
        phi = D.phi_of(ctx, m.level, m.offline, m.tags)
        rows.append((S.forbidden_top(m, ctx), -sum(a*b for a, b in zip(th, phi)), i, m, phi))
    rows.sort(key=lambda x: (x[0], x[1], x[2]))
    return rules, rows

def week_order(model, s, stage, week_no, now, cid=1):
    th = theta(model, f'week|{cid}|{week_no}')
    name = R.STAGES[stage]
    rows = []
    for i in range(len(R.LINES[name])):
        m = R.Mission(f'{name}-{i}')
        ctx = S.context(s, now, None, R.rule_score(m, s, stage, now))
        rows.append((-sum(a*b for a, b in zip(th, D.phi_of(ctx, m.level, m.offline, m.tags))), i))
    rows.sort()
    return [i for _, i in rows]

def effect(rows, p, now, cid=1):
    mean0, lam = D.prior22()
    empty = Model(mean0, lam)
    road = R.build_roadmap(cid, p, now.date())   # 기록 없음 → 지금 순서
    s = R.read_situation(p, road, now)
    _, before = today_rank(empty, s, now, cid)
    model, _ = D.model_of(rows)
    # 이번 주 다시 고르기
    wi, week = s.week_index, s.week
    stage = R.STAGES.index(week.stage)
    order = week_order(model, s, stage, week.week_no, now, cid)
    used = {m.id for k, w in enumerate(road.weeks) if k != wi for m in w.missions}
    missions = R.pick(stage, seed=cid*31+(wi+1)*7, can_meet=p.meetings > 0, max_level=R.courage_max(p.courage), used=used, order=order)
    weeks = list(road.weeks); weeks[wi] = replace(week, missions=tuple(missions))
    road2 = replace(road, weeks=tuple(weeks))
    s2 = R.read_situation(p, road2, now)
    _, after = today_rank(model, s2, now, cid)
    why = D.reason(model, mean0, rows, after[0][4])
    # 다시 고르지 않을 때 (이번 주에 이미 한 게 있는 경우): 순서만
    _, same = today_rank(model, s, now, cid)
    why_same = D.reason(model, mean0, rows, same[0][4])
    return dict(before=before[0][3].id, week=[m.id for m in missions], after=after[0][3].id, why=why,
                same=same[0][3].id, why_same=why_same, rule=R.rank_today(s, now)[0].id)

SCEN = [('smallTalk', 'friends', 2, 50), ('faceOnly', 'friends', 2, 50), ('close', 'some', 2, 50), ('smallTalk', 'some', 1, 30)]

def score(rows):
    sc = 0
    out = []
    for h in (14, 21):
        now = datetime(2026, 11, 20, h)
        for it, g, meet, cour in SCEN:
            p = R.Profile(now.date() + timedelta(days=20), it, meet, cour, g)
            e = effect(rows, p, now)
            sc += (e['after'] != e['before']) + (e['why'] is not None) * 2 + (e['why_same'] is not None)
            out.append(e)
    return sc, out

if __name__ == '__main__':
    res = []
    for act in (0.45, 0.55):
      for days in (41, 48, 55):
        D.DAYS = days
        D.DEMO = S.Persona('demo', '온라인파', weekday_activity=act, weekend_activity=act, evening_share=0.4,
                           prefs={'offline': -2.5, 'online_evening': 0.6, 'react': 1.0, 'ask': 1.0, 'prep': -1.2})
        for run in range(int(sys.argv[1]) if len(sys.argv) > 1 else 40):
            D.RUN = run
            rows = [(m.id, k, r, D.ctx_of(c, m)) for _, m, k, r, c in D.demo_log()]
            if not 20 <= len(rows) <= 30:
                continue
            model, mean0 = D.model_of(rows)
            w = dict(zip(F.GLOBAL_NAMES, np.array(model.mean()) - np.array(mean0)))
            if w['offline'] >= 0 or w['tag.ask'] <= 0:
                continue
            sc, out = score(rows)
            sc += 2 * (w['tag.prep'] <= 0)
            res.append((sc, (act, days, run), len(rows), {k: round(v, 2) for k, v in w.items() if abs(v) > 0.08}, out))
    res.sort(key=lambda x: -x[0])
    for sc, run, n, w, out in res[:3]:
        print(sc, run, n, w)
        for e in out: print('   ', e)
