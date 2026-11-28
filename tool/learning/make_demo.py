"""시연용 가상 기록 만들기 → lib/learning/demo_records.dart

    python make_demo.py            # 만들고 효과 확인 (넣기 전 → 넣고 이번 주 다시 고르기: 1순위 · 이유)
    python make_demo.py --check    # 파일은 안 쓰고 효과만

가상 사용자 '온라인파': 직접 만나는 미션 · 혼자 준비 미션은 잘 안 하고, 톡으로 반응 · 질문하는 미션을 잘 함
simulate.py로 7주(D-48) 동안 앱을 쓴 기록 26개 (오늘의 미션만 학습, 주차 구성은 지금 앱 그대로라 대면 미션도 섞임)
활동 정도 · 기간 · seed를 바꿔 가며, 기록이 20~30개이고 배운 선호가 이름대로이고
넣었을 때 오늘의 미션 1순위 · 이유 줄이 가장 많이 바뀌는 것을 고름 (_sweep 기준, 시연용이라 일부러 고른 것)
"""
from __future__ import annotations

import argparse
import os
from datetime import date, datetime, timedelta

import numpy as np

import dart_rules as R
import mission_features as F
import simulate as S
from linear_ts import Model, Rng, fnv1a

DEMO = S.Persona('demo', '온라인파', weekday_activity=0.45, weekend_activity=0.45, evening_share=0.4,
                 prefs={'offline': -2.5, 'online_evening': 0.6, 'react': 1.0, 'ask': 1.0, 'prep': -1.2})
RUN = 5
DAYS = 48  # 7주

MIN_EVIDENCE = 3  # Dart reasonMinEvidence

KEYS = ['rule', 'maxLv', 'pace', 'meet', 'elapsed', 'rest', 'gap', 'interest', 'weekday', 'hour']


def demo_log():
    params = S.Params()
    policy = S.LearnPolicy(params, RUN, compose=False, name='today')
    rng = np.random.default_rng(RUN)
    start = date(2026, 11, 2)
    prof = R.Profile(start + timedelta(days=DAYS), 'smallTalk', 2, 50, 'some')
    road = R.build_roadmap(1, prof, start)
    c = S.CrushState(1, 'A', prof, road, warmth=0.45, composed_weeks={0})
    S.simulate_crush(DEMO, policy, params, [c], start, DAYS, rng, switch_daily=False)
    return policy.log


def ctx_of(ctx: dict, m: R.Mission) -> dict:
    out = {k: ctx[k] for k in KEYS if ctx.get(k) is not None}
    out['rule'] = round(float(out['rule']), 6)
    out['elapsed'] = round(float(out['elapsed']), 6)
    out['lv'] = m.level
    out['off'] = m.offline
    out['tags'] = [t for t in R.TAGS if t in m.tags]
    return out


def dart_value(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, float):
        return repr(round(v, 6))
    if isinstance(v, int):
        return str(v)
    if isinstance(v, str):
        return f"'{v}'"
    if isinstance(v, list):
        return '[' + ', '.join(dart_value(x) for x in v) + ']'
    raise TypeError(v)


def write_dart(rows, path):
    lines = [
        "// 시연용 가상 기록 (디버그 빌드 '학습한 내용' 화면의 '시연용 기록 넣기'), tool/learning/make_demo.py로 만듦 — 직접 고치지 말 것",
        f"//   가상 사용자 '온라인파' 7주 기록 {len(rows)}개: 직접 만나는 미션 · 혼자 준비 미션은 잘 안 하고, 톡으로 반응 · 질문하는 미션을 잘 함",
        "//   상대 번호 0으로 넣음 (상대를 지워도 남고, '학습 기록 지우기'로 지움), 꺼져 있으면 켜고 넣음",
        "import 'learning_db.dart';",
        "import 'learning_store.dart';",
        "import 'mission_features.dart';",
        "",
        "/// (미션 id, 종류, 보상, 문맥)",
        "const _records = <(String, LearnKind, double, Map<String, Object?>)>[",
    ]
    for arm, kind, reward, ctx in rows:
        body = ', '.join(f"'{k}': {dart_value(v)}" for k, v in ctx.items())
        lines.append(f"  ('{arm}', LearnKind.{kind}, {dart_value(float(reward))}, {{{body}}}),")
    lines += [
        "];",
        "",
        "/// 시연용 기록 수",
        "int get demoRecordCount => _records.length;",
        "",
        "/// 시연용 기록 넣기, 넣은 수를 돌려줌",
        "Future<int> seedDemoRecords(LearningStore store) async {",
        "  if (!store.enabled) await store.setEnabled(true);",
        "  var n = 0;",
        "  for (final (arm, kind, reward, ctx) in _records) {",
        "    final saved = await store.record(",
        "      domain: missionDomain,",
        "      crushId: 0,",
        "      arm: arm,",
        "      ctx: ctx,",
        "      reward: reward,",
        "      kind: kind,",
        "    );",
        "    if (saved != null) n++;",
        "  }",
        "  store.touch();",
        "  return n;",
        "}",
        "",
    ]
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write('\n'.join(lines))


# ---------- 효과 확인 (Dart roadmap_learning.dart와 같은 계산) ----------

def prior22():
    mean, lam = F.prior(1.0, 5.0, 6.0, 6.0)
    mean, lam = mean[:F.D_GLOBAL], lam[:F.D_GLOBAL]
    for i, n in enumerate(F.GLOBAL_NAMES):
        if n.startswith('tag.') or n.startswith('offline'):
            lam[i] = 2.0
    return mean, lam


REASONS = ['offline', 'offlineWeekend', 'offlineMeet', *[f'tag.{t}' for t in R.TAGS], 'contactGap',
           'boldHigh', 'hardBehind', 'easyRested', 'onlineEvening', 'hardLate']


def phi_of(ctx, arm_level, arm_off, arm_tags):
    return F.features(ctx, arm_level, arm_off, arm_tags)[:F.D_GLOBAL]


def model_of(rows):
    mean0, lam = prior22()
    m = Model(mean0, lam)
    for _, _, reward, ctx in rows:
        m.update(phi_of(ctx, ctx['lv'], ctx['off'], set(ctx['tags'])), reward)
    return m, mean0


def reason(m, mean0, rows, phi):
    """몫이 큰 순서로, 근거가 3번 이상인 첫 특징 (Dart missionLearnedReason)"""
    mu = m.mean()
    part = [(mu[i] - mean0[i]) * phi[i] for i in range(F.D_GLOBAL)]
    cands = sorted((i for i, n in enumerate(F.GLOBAL_NAMES) if n in REASONS and part[i] >= 0.08),
                   key=lambda i: (-part[i], i))
    for i in cands:
        ev = sum(1 for _, _, r, c in rows if r > 0 and phi_of(c, c['lv'], c['off'], set(c['tags']))[i] != 0)
        if ev >= MIN_EVIDENCE:
            return F.GLOBAL_NAMES[i]
    return None


def check(rows):
    """배운 가중치 + 사람 4명 × 낮 · 밤: 넣기 전 1순위 → 넣고 이번 주 다시 고른 뒤 1순위 · 이유"""
    import demo_effect as E
    m, mean0 = model_of(rows)
    print('배운 가중치 (|μ−μ₀| ≥ 0.05)')
    for n, a, b in zip(F.GLOBAL_NAMES, m.mean(), mean0):
        if abs(a - b) >= 0.05:
            print(f'   {n:16} {a - b:+.3f}')
    for h in (14, 21):
        now = datetime(2026, 11, 20, h)
        for it, g, meet, cour in E.SCEN:
            p = R.Profile(now.date() + timedelta(days=20), it, meet, cour, g)
            e = E.effect(rows, p, now)
            print(f"{h}시 {it}/{g}: 1순위 {e['before']} → {e['after']} (이유 {e['why']}), 이번 주 {e['week']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    log = demo_log()
    rows = [(m.id, kind, reward, ctx_of(ctx, m)) for _, m, kind, reward, ctx in log]
    kinds = {}
    for _, k, _, _ in rows:
        kinds[k] = kinds.get(k, 0) + 1
    print('기록', len(rows), kinds)
    check(rows)
    if not args.check:
        path = os.path.join(R.DEFAULT_ROOT, 'lib', 'learning', 'demo_records.dart')
        write_dart(rows, path)
        print('wrote', path)


if __name__ == '__main__':
    main()
