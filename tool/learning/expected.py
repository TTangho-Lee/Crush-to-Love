"""test/learning_test.dart 기대값 (Dart와 같은 계산을 파이썬으로)

    python expected.py
"""
import dart_rules as R
import mission_features as F
from linear_ts import Model, Rng, fnv1a

# ---------- 해시 · 난수 ----------
print('fnv1a a', fnv1a('a'))
print('fnv1a mission|1|20261120', fnv1a('mission|1|20261120'))
print('fnv1a 지민', fnv1a('지민'))
rng = Rng(12345)
print('xorshift 12345', [rng.next_u32() for _ in range(3)])
rng = Rng(fnv1a('x'))
print('normal x', [repr(rng.normal()) for _ in range(2)])

# ---------- 특징 ----------
C1 = dict(rule=3.5, maxLv=2, pace='behind', meet=2, elapsed=0.5, rest=4, gap=3,
          interest='high', weekday=6, hour=21)
A1 = dict(level=3, offline=False, tags={'push', 'invite'})
C2 = dict(rule=-1.0, maxLv=1, pace='onTrack', meet=0, elapsed=0.25, rest=None, gap=None,
          interest='low', weekday=None, hour=None)
A2 = dict(level=1, offline=True, tags={'greet'})
phi1 = F.features(C1, A1['level'], A1['offline'], A1['tags'])[:F.D_GLOBAL]
phi2 = F.features(C2, A2['level'], A2['offline'], A2['tags'])[:F.D_GLOBAL]
print('phi1', phi1)
print('phi2', [repr(v) for v in phi2])

# ---------- 모델 ----------
mean0, lam = F.prior(1.0, 5.0, 6.0, 6.0)
mean0, lam = mean0[:F.D_GLOBAL], lam[:F.D_GLOBAL]
for i, n in enumerate(F.GLOBAL_NAMES):
    if n.startswith('tag.') or n.startswith('offline'):
        lam[i] = 2.0
print('lam', lam)

m = Model(mean0, lam)
seq = [(phi1, 1.0), (phi2, -0.5), (phi1, -0.2), (phi2, 1.0), (phi1, 1.0)]
for phi, r in seq:
    m.update(phi, r)
mu = m.mean()
print('mean[0:4]', [repr(v) for v in mu[:4]])
print('mean·phi1', repr(sum(a * b for a, b in zip(mu, phi1))))
print('mean·phi2', repr(sum(a * b for a, b in zip(mu, phi2))))
th = m.sample(Rng(fnv1a('mission|t')), 0.15)
print('sample[0:3]', [repr(v) for v in th[:3]])
print('sample·phi1', repr(sum(a * b for a, b in zip(th, phi1))))

# 앞 기록 빼기 → 4개만 넣은 것과 같음
m.update(phi1, 1.0, -1)
m4 = Model(mean0, lam)
for phi, r in seq[:4]:
    m4.update(phi, r)
print('cancel same', max(abs(a - b) for a, b in zip(m.mean(), m4.mean())) < 1e-12)

# 상대 2 기록(phi2 두 개)을 지운 것 = phi1 셋
m3 = Model(mean0, lam)
for phi, r in seq:
    if phi is phi1:
        m3.update(phi, r)
print('forget mean·phi1', repr(sum(a * b for a, b in zip(m3.mean(), phi1))))

# ---------- 규칙 옮긴 것: 로드맵 ----------
from datetime import date, timedelta
today = date(2026, 11, 20)
p = R.Profile(today + timedelta(days=20), 'smallTalk', 2, 50, 'friends')
r = R.build_roadmap(1, p, today)
print('roadmap', [[m.id for m in w.missions] for w in r.weeks])
