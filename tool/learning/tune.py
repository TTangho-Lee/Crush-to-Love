"""보상 · 사전 · 탐색 세기 고르기 (학습 정책, 상대 3명을 차례로, 규칙 대비 개선)

    python tune.py [runs]
"""
import itertools
import sys
from dataclasses import replace

import numpy as np

import simulate as S

RUNS = int(sys.argv[1]) if len(sys.argv) > 1 else 60
ROUNDS = 3


def table(pol, params):
    out = {}
    for p in S.PERSONAS:
        rows = [r for k in range(RUNS) for r in S.run_once(p, pol, params, k, rounds=ROUNDS)]
        out[p.name] = {m: np.mean([r[m] for r in rows]) for m in ('done', 'pick')}
    return out


base = table('rules', S.Params())
orc = table('oracle', S.Params())


def gains(t):
    return np.array([[t[p.name][m] - base[p.name][m] for p in S.PERSONAS] for m in ('done', 'pick')])


g = gains(orc)
print('oracle done', np.round(g[0], 3), 'pick', np.round(g[1], 3))
best = []
for scale, lam_tag, lam_g, missed in itertools.product([0.1, 0.2, 0.3], [1.0, 2.0], [3.0, 6.0], [-0.5, -1.0]):
    p = replace(S.Params(), scale=scale, lam_tag=lam_tag, lam_global=lam_g, r_missed=missed,
                lam_rule=5.0, )
    g = gains(table('full', p))
    score = g.mean()
    best.append((score, scale, lam_tag, lam_g, missed))
    print(f'v={scale} lam_tag={lam_tag} lam_g={lam_g} missed={missed}: '
          f'done {g[0].mean():+.4f} (min {g[0].min():+.3f}) pick {g[1].mean():+.4f} (min {g[1].min():+.3f})',
          flush=True)
best.sort(reverse=True)
print('best', best[:3])
