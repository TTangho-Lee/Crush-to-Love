"""가상 사용자 시뮬레이션: 규칙만 쓸 때 vs 학습할 때 (오프라인 평가)

    python simulate.py              # 기본 평가 (사람마다 200번)
    python simulate.py --runs 50    # 빠르게
    python simulate.py --tune       # 보상 · 탐색 세기 고르기

가상 사용자: 미션 특징에 대한 숨은 선호(진짜 완료 확률)가 서로 다름, 앱은 이 값을 모름
  하루: 앱을 열 확률 → 오늘의 미션을 보고 할 확률 (안 내키면 ↻) → 체크 목록에서 하나 더 할 확률
  상대: 따뜻함 w가 연락 미션으로 오르고 날마다 조금 식음, 7일마다 대화 분석(호감 점수 = w)
정책
  rules  지금 앱 (임의 순서 주차 구성 + 규칙 점수 순 오늘의 미션)
  today  오늘의 미션만 학습
  full   오늘의 미션 + 주차 구성 학습 (앱에 넣는 것)
  crush  full + 상대 층 (상대마다 따로 배우는 특징 11개 더) — 효과가 없어서 앱에는 안 넣음
  oracle 진짜 완료 확률을 아는 경우 (위쪽 한계)
"""
from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass, field, replace
from datetime import date, datetime, timedelta

import numpy as np

import dart_rules as R
import mission_features as F
from linear_ts import FastModel, Rng, fnv1a


# 주차 구성을 학습 순서로 고르기 시작하는 완료 기록 수
COMPOSE_MIN_DONE = 5


def sigmoid(x):
    return 1 / (1 + math.exp(-x))


# ---------- 학습 설정 (Dart 기본값 후보) ----------

@dataclass
class Params:
    """tune.py로 고른 값 (Dart MissionLearning 기본값과 같게)"""
    rule_weight: float = 1.0  # μ₀: 규칙 점수/5 가중치
    lam_rule: float = 5.0  # 규칙 점수 가중치를 붙잡는 세기
    lam_global: float = 6.0  # 나머지 특징 λ
    lam_crush: float = 6.0
    lam_tag: float | None = 2.0  # 태그 · 대면 특징 λ (더 빨리 배움)
    scale: float = 0.15  # 탐색 세기 v
    r_done: float = 1.0
    r_missed: float = -0.5
    r_skip: float = -0.2
    r_ignore: float = 0.0  # 오늘의 미션을 보고도 그날 안 함 (효과 없어서 안 씀)
    chat_div: float = 20.0
    chat_cap: float = 0.5
    crush_layer: bool = False


# ---------- 가상 사용자 ----------

@dataclass
class Persona:
    name: str
    label: str
    courage: int = 50
    intimacy: str = 'smallTalk'
    goal: str = 'some'
    meetings: int = 2
    weekday_activity: float = 0.55
    weekend_activity: float = 0.55
    evening_share: float = 0.5  # 앱을 저녁 · 밤에 여는 비율
    rule_driven: bool = False
    # (조건 이름, 크기): 숨은 선호
    prefs: dict = field(default_factory=dict)
    # 상대마다 다른 선호 (상대 key → 태그 → 크기)
    crush_prefs: dict = field(default_factory=dict)
    brave_ok: bool = False


PERSONAS = [
    Persona('online', '온라인파', prefs={'offline': -2.0, 'online': 0.3}),
    Persona('evening', '저녁형', evening_share=0.5,
            prefs={'offline_day': 0.8, 'offline_evening': -1.5, 'online_evening': 1.2, 'online_day': -0.8}),
    Persona('brave', '용감형', courage=80, prefs={'bold': 1.2, 'prep': -1.2}, brave_ok=True),
    Persona('careful', '조심형', courage=30, prefs={'prep': 1.0, 'react': 0.8, 'push': -1.5, 'offline': -0.6}),
    Persona('weekend', '주말형', weekday_activity=0.3, weekend_activity=0.8,
            prefs={'offline_weekend': 1.2, 'offline_weekday': -1.2}),
    Persona('rule', '규칙대로형', rule_driven=True),
    Persona('two', '상대마다 다름', crush_prefs={
        'A': {'care': 1.2, 'share': 1.2, 'ask': -0.8},
        'B': {'ask': 1.2, 'invite': 1.2, 'care': -0.8},
    }),
]


def true_utility(persona: Persona, m: R.Mission, ctx: dict, crush_key: str, shown: bool) -> float:
    """진짜 완료 확률의 logit (앱은 모름)"""
    shown_term = 1.0 if shown else -1.0
    if persona.rule_driven:
        return -1.6 + 0.6 * ctx['rule'] + shown_term
    u = -1.0 + shown_term
    diff = m.level - ctx['maxLv']
    if diff <= 0:
        u += 0.2 * (-diff)
    elif diff == 1:
        u += 0.0 if persona.brave_ok else -1.0
    else:
        u += -1.0 if persona.brave_ok else -2.5
    tags = m.tags
    if ctx.get('interest') == 'low' and tags & R.BOLD:
        u -= 1.0
    p = persona.prefs
    off = m.offline
    evening = F.evening_of(ctx) >= 0.5
    weekend = F.weekend_of(ctx) >= 0.5
    u += p.get('offline', 0) * off + p.get('online', 0) * (not off)
    u += p.get('offline_day', 0) * (off and not evening) + p.get('offline_evening', 0) * (off and evening)
    u += p.get('online_evening', 0) * (not off and evening) + p.get('online_day', 0) * (not off and not evening)
    u += p.get('offline_weekend', 0) * (off and weekend) + p.get('offline_weekday', 0) * (off and not weekend)
    u += p.get('bold', 0) * bool(tags & R.BOLD)
    for t in R.TAGS:
        u += p.get(t, 0) * (t in tags)
    for t, v in persona.crush_prefs.get(crush_key, {}).items():
        u += v * (t in tags)
    return u


# ---------- 정책 ----------

def context(s: R.Situation, today: datetime, hour: int | None, rule: float) -> dict:
    gap = s.talk_gap(today)
    return {
        'rule': rule,
        'maxLv': R.courage_max(s.profile.courage),
        'courage': R.courage_level(s.profile.courage),
        'pace': s.pace,
        'rest': s.rest_days,
        'gap': gap,
        'interest': s.chat.interest if s.chat else None,
        'weekday': None if hour is None else today.isoweekday(),
        'hour': hour,
        'meet': s.profile.meetings,
        'elapsed': s.elapsed,
    }


def forbidden_top(m: R.Mission, ctx: dict) -> bool:
    """학습이 1순위로 못 올리는 미션 (안전 규칙)"""
    return m.level >= ctx['maxLv'] + 2 or (ctx.get('interest') == 'low' and bool(m.tags & R.BOLD))


class RulePolicy:
    name = 'rules'
    learns_compose = False

    def __init__(self, params=None, run=0):
        pass

    def order_for(self, crush, s, stage, week_index, used, today):
        return None

    def rank(self, crush, s, today, hour):
        return R.rank_today(s, today)

    def observe(self, crush, m, ctx, reward, weight=1.0, kind='done'):
        pass


class LearnPolicy:
    def __init__(self, params: Params, run: int, compose: bool, name: str):
        self.p = params
        self.run = run
        self.learns_compose = compose
        self.name = name
        self.models: dict[int, FastModel] = {}
        self.events: list = []
        self.log: list = []  # (상대, 미션 id, 종류, 보상, 문맥) — make_demo.py

    def _new_model(self) -> FastModel:
        mean, lam = F.prior(self.p.rule_weight, self.p.lam_rule, self.p.lam_global, self.p.lam_crush)
        if self.p.lam_tag is not None:
            for i, n in enumerate(F.NAMES):
                if n.startswith('tag.') or n.startswith('offline'):
                    lam[i] = self.p.lam_tag
        return FastModel(mean, lam)

    def model(self, crush: int) -> FastModel:
        m = self.models.get(crush)
        if m is None:
            m = self._new_model()
            for c, phi, r, w in self.events:
                m.update(self._view(phi, c == crush), r, w)
            self.models[crush] = m
        return m

    def _view(self, phi, own: bool):
        if own and self.p.crush_layer:
            return phi
        return list(phi[:F.D_GLOBAL]) + [0.0] * (F.D - F.D_GLOBAL)

    def observe(self, crush, m, ctx, reward, weight=1.0, kind='done'):
        self.log.append((crush, m, kind, reward, ctx))
        phi = F.features(ctx, m.level, m.offline, m.tags)
        self.model(crush)  # 처음 보는 상대면 지난 기록으로 먼저 만듦
        self.events.append((crush, phi, reward, weight))
        for c, model in self.models.items():
            model.update(self._view(phi, c == crush), reward, weight)

    def done_count(self) -> int:
        return sum(1 for _, _, kind, _, _ in self.log if kind == 'done')

    def _sample(self, crush, key: str):
        rng = Rng(fnv1a(f'{key}|{crush}|{self.run}'))
        return self.model(crush).sample(rng, self.p.scale)

    def rank(self, crush, s, today, hour):
        week, _, cands = R.today_candidates(s)
        stage = R.STAGES.index(week.stage)
        theta = self._sample(crush, f'today|{today:%Y%m%d}')
        rows = []
        for i, m in cands:
            ctx = context(s, today, hour, R.rule_score(m, s, stage, today))
            phi = np.asarray(F.features(ctx, m.level, m.offline, m.tags))
            rows.append((forbidden_top(m, ctx), -float(theta @ self._view_np(phi)), i, m))
        rows.sort(key=lambda x: (x[0], x[1], x[2]))
        return [m for *_, m in rows]

    def _view_np(self, phi):
        if self.p.crush_layer:
            return phi
        out = phi.copy()
        out[F.D_GLOBAL:] = 0
        return out

    def order_for(self, crush, s, stage, week_index, used, today):
        # 완료 기록이 COMPOSE_MIN_DONE개 미만이면 지금 순서 (Dart learnedWeekMinDone)
        if not self.learns_compose or self.done_count() < COMPOSE_MIN_DONE:
            return None
        name = R.STAGES[stage]
        lines = R.LINES[name]
        theta = self._sample(crush, f'week|{week_index}|{today:%Y%m%d}')
        scores = []
        for i, line in enumerate(lines):
            m = R.Mission(f'{name}-{i}')
            ctx = context(s, today, None, R.rule_score(m, s, stage, today))
            phi = np.asarray(F.features(ctx, m.level, m.offline, m.tags))
            scores.append((-float(theta @ self._view_np(phi)), i))
        scores.sort()
        return [i for _, i in scores]


class OraclePolicy:
    """진짜 완료 확률 순 (위쪽 한계)"""
    name = 'oracle'
    learns_compose = True

    def __init__(self, persona, crush_keys):
        self.persona = persona
        self.keys = crush_keys

    def observe(self, *a, **k):
        pass  # noqa

    def rank(self, crush, s, today, hour):
        week, _, cands = R.today_candidates(s)
        stage = R.STAGES.index(week.stage)
        rows = []
        for i, m in cands:
            ctx = context(s, today, hour, R.rule_score(m, s, stage, today))
            rows.append((-true_utility(self.persona, m, ctx, self.keys[crush], True), i, m))
        rows.sort(key=lambda x: (x[0], x[1]))
        return [m for *_, m in rows]

    def order_for(self, crush, s, stage, week_index, used, today):
        name = R.STAGES[stage]
        scores = []
        for i in range(len(R.LINES[name])):
            m = R.Mission(f'{name}-{i}')
            ctx = context(s, today, None, R.rule_score(m, s, stage, today))
            scores.append((-true_utility(self.persona, m, ctx, self.keys[crush], True), i))
        scores.sort()
        return [i for _, i in scores]


# ---------- 세계 ----------

APPROACH_BY_INTEREST = {
    'low': ['patience', 'rest', 'light'],
    'mid': ['common', 'askBack', 'react', 'light', 'laughTopic', 'routine'],
    'high': ['invite', 'openUp', 'askBack'],
}


@dataclass
class CrushState:
    id: int
    key: str
    profile: R.Profile
    roadmap: R.Roadmap
    warmth: float
    chat: R.Chat | None = None
    last_score: int | None = None
    last_contact: datetime | None = None
    since_analysis: list = field(default_factory=list)  # (mission, ctx)
    judged_weeks: set = field(default_factory=set)
    composed_weeks: set = field(default_factory=set)
    stats: dict = field(default_factory=lambda: dict(sessions=0, shown_done=0, skips=0))


def week_index_of(r: R.Roadmap, days_left: int) -> int:
    return R.current_week_index([(w.from_dday, w.to_dday) for w in r.weeks], days_left)


def mark_done(c: CrushState, mission_id: str, at: datetime):
    max_lv = R.courage_max(c.profile.courage)
    weeks = []
    for w in c.roadmap.weeks:
        weeks.append(replace(w, missions=tuple(
            m.mark(True, at, m.level > max_lv) if m.id == mission_id else m for m in w.missions)))
    c.roadmap = replace(c.roadmap, weeks=tuple(weeks))


def recompose_week(c: CrushState, policy, today: datetime):
    """주차가 시작되는 날: 아직 한 미션이 없으면 학습 순서로 다시 고름"""
    left = R.days_until(c.profile.dday, today)
    wi = week_index_of(c.roadmap, left)
    if wi in c.composed_weeks:
        return
    c.composed_weeks.add(wi)
    week = c.roadmap.weeks[wi]
    if any(m.done for m in week.missions) or not policy.learns_compose:
        return
    s = R.read_situation(c.profile, c.roadmap, today, c.chat)
    stage = R.STAGES.index(week.stage)
    used = {m.id for k, w in enumerate(c.roadmap.weeks) if k != wi for m in w.missions}
    order = policy.order_for(c.id, s, stage, wi, used, today)
    if order is None:
        return
    missions = R.pick(stage, seed=c.id * 31 + (wi + 1) * 7, can_meet=c.profile.meetings > 0,
                      max_level=R.courage_max(c.profile.courage), used=used, order=order)
    weeks = list(c.roadmap.weeks)
    weeks[wi] = replace(week, missions=tuple(missions))
    c.roadmap = replace(c.roadmap, weeks=tuple(weeks))


def judge_weeks(c: CrushState, policy, params: Params, today: datetime):
    """끝난 주차의 안 한 미션 → 아쉬움(−) 기록 (그 주 마지막 날 문맥)"""
    left = R.days_until(c.profile.dday, today)
    for w in c.roadmap.weeks:
        if w.to_dday <= left or w.week_no in c.judged_weeks:
            continue
        c.judged_weeks.add(w.week_no)
        last_day = datetime.combine(c.profile.dday - timedelta(days=w.to_dday), datetime.min.time())
        s = R.read_situation(c.profile, c.roadmap, last_day, c.chat)
        stage = R.STAGES.index(w.stage)
        for m in w.missions:
            if m.done:
                continue
            ctx = context(s, last_day, None, R.rule_score(m, s, stage, last_day))
            policy.observe(c.id, m, ctx, params.r_missed, kind='missed')


def analyze_chat(c: CrushState, policy, params: Params, today: datetime, rng):
    score = int(round(min(100, max(0, 30 + 60 * c.warmth + rng.normal(0, 4)))))
    interest = 'high' if score >= 70 else 'mid' if score >= 45 else 'low'
    approach = APPROACH_BY_INTEREST[interest][int(rng.integers(len(APPROACH_BY_INTEREST[interest])))]
    if c.last_score is not None and c.since_analysis:
        delta = score - c.last_score
        r = max(-params.chat_cap, min(params.chat_cap, delta / params.chat_div)) / len(c.since_analysis)
        for m, ctx in c.since_analysis:
            policy.observe(c.id, m, ctx, r, kind='chat')
    c.since_analysis = []
    c.last_score = score
    c.chat = R.Chat(interest, approach, None, c.last_contact)


def adapt(c: CrushState, policy, today):
    s = R.read_situation(c.profile, c.roadmap, today, c.chat)
    shift = R.adapt_shift(s)
    if shift is None:
        return
    order_for = None
    if policy.learns_compose:
        order_for = lambda stage, i, used: policy.order_for(c.id, s, stage, i, used, today)
    c.roadmap = R.adapt_roadmap(c.roadmap, c.profile, today, shift, order_for=order_for)


def simulate_crush(persona: Persona, policy, params: Params, cs: list[CrushState], start: date,
                   days: int, rng, switch_daily: bool):
    for d in range(days + 1):
        day = start + timedelta(days=d)
        c = cs[d % len(cs)] if switch_daily else cs[0]
        for other in cs:
            other.warmth = max(0.0, other.warmth - 0.004)
        weekend = day.isoweekday() >= 6
        if rng.random() > (persona.weekend_activity if weekend else persona.weekday_activity):
            # 안 열어도 주차 판정 · 분석은 다음에 열 때 (여기선 날마다 판정만)
            judge_weeks(c, policy, params, datetime.combine(day, datetime.min.time()))
            continue
        evening = rng.random() < persona.evening_share
        hour = int(rng.integers(18, 24)) if evening else int(rng.integers(9, 17))
        now = datetime.combine(day, datetime.min.time()) + timedelta(hours=hour)
        judge_weeks(c, policy, params, now)
        if d > 0 and d % 7 == 6:
            analyze_chat(c, policy, params, now, rng)
            adapt(c, policy, now)
        recompose_week(c, policy, now)
        s = R.read_situation(c.profile, c.roadmap, now, c.chat)
        if s.passed:
            continue
        ranked = policy.rank(c.id, s, now, hour)
        if not ranked:
            continue
        c.stats['sessions'] += 1
        week, _, _ = R.today_candidates(s)
        stage = R.STAGES.index(week.stage)
        did = None
        for k in range(min(3, len(ranked))):
            m = ranked[k]
            ctx = context(s, now, hour, R.rule_score(m, s, stage, now))
            p_done = sigmoid(true_utility(persona, m, ctx, c.key, shown=True))
            if rng.random() < p_done:
                did = m
                if k == 0:
                    c.stats['shown_done'] += 1
                break
            if p_done < 0.35 and rng.random() < 0.5 and k + 1 < len(ranked):
                c.stats['skips'] += 1
                policy.observe(c.id, m, ctx, params.r_skip, kind='skip')
                continue
            if params.r_ignore:
                policy.observe(c.id, m, ctx, params.r_ignore)
            break
        rest = [m for m in ranked if did is None or m.id != did.id]
        extra = rest[int(rng.integers(len(rest)))] if rest and rng.random() < 0.5 else None
        for m, shown in ((did, True), (extra, False)):
            if m is None:
                continue
            ctx = context(s, now, hour, R.rule_score(m, s, stage, now))
            if not shown and rng.random() >= sigmoid(true_utility(persona, m, ctx, c.key, shown=False)):
                continue
            mark_done(c, m.id, now)
            policy.observe(c.id, m, ctx, params.r_done)
            if m.tags - {'prep'}:
                prefs = persona.crush_prefs.get(c.key, {})
                aff = 1 + 0.5 * sum(prefs.get(t, 0) for t in m.tags)
                c.warmth = min(1.0, c.warmth + 0.04 * max(aff, 0.2))
                c.last_contact = now
                c.since_analysis.append((m, ctx))
        adapt(c, policy, now)


def result_of(c: CrushState, end: date) -> dict:
    s = R.read_situation(c.profile, c.roadmap, end, c.chat)
    return dict(
        done=s.done_count / max(1, s.total_count),
        progress=s.progress,
        pick=c.stats['shown_done'] / max(1, c.stats['sessions']),
        skips=c.stats['skips'] / max(1, c.stats['sessions']),
        warmth=c.warmth,
    )


def run_once(persona: Persona, policy_name: str, params: Params, run: int, days: int = 27,
             rounds: int = 3) -> list[dict]:
    """같은 사람이 상대 rounds번을 차례로 (학습은 이어짐), 상대마다 결과"""
    rng = np.random.default_rng(run * 7919 + fnv1a(persona.name) % 1000)
    two = persona.name == 'two'
    keys = ['A', 'B'] if two else ['A']
    if policy_name == 'rules':
        policy = RulePolicy()
    elif policy_name == 'oracle':
        policy = OraclePolicy(persona, {})
    else:
        p = replace(params, crush_layer=policy_name == 'crush')
        policy = LearnPolicy(p, run, compose=policy_name in ('full', 'crush'), name=policy_name)
    start = date(2026, 11, 23) + timedelta(days=int(rng.integers(7)))
    out = []
    next_id = 1
    for rnd in range(rounds):
        cs = []
        for key in keys:
            prof = R.Profile(start + timedelta(days=days), persona.intimacy, persona.meetings,
                             persona.courage, persona.goal)
            cid = run * 10 + next_id
            next_id += 1
            if isinstance(policy, OraclePolicy):
                policy.keys[cid] = key
            order_for = None
            if policy.learns_compose:
                def order_for(stage, i, used, _p=prof, _c=cid):
                    r0 = R.build_roadmap(_c, _p, start)
                    s0 = R.read_situation(_p, r0, start)
                    return policy.order_for(_c, s0, stage, i, used, datetime.combine(start, datetime.min.time()))
            road = R.build_roadmap(cid, prof, start, order_for=order_for)
            cs.append(CrushState(cid, key, prof, road, warmth=float(rng.uniform(0.3, 0.55)),
                                 composed_weeks={0}))
        simulate_crush(persona, policy, params, cs, start, days, rng, switch_daily=two)
        end = start + timedelta(days=days)
        for c in cs:
            out.append(dict(round=rnd, **result_of(c, end)))
        start = end + timedelta(days=1)
    return out


ROUNDS = 3


def evaluate(personas, policies, params: Params, runs: int):
    """(사람, 정책) → 상대 순서 → 지표 → (평균, 표준오차)"""
    table = {}
    for persona in personas:
        for pol in policies:
            rows = [r for k in range(runs) for r in run_once(persona, pol, params, k, rounds=ROUNDS)]
            agg = {}
            for rnd in range(ROUNDS):
                part = [r for r in rows if r['round'] == rnd]
                agg[rnd] = {m: (float(np.mean([r[m] for r in part])),
                                float(np.std([r[m] for r in part]) / math.sqrt(len(part))))
                            for m in ('done', 'progress', 'pick', 'skips', 'warmth')}
            table[(persona.name, pol)] = agg
    return table


METRICS = {'done': '미션 완료율', 'pick': '오늘의 미션 바로 함', 'progress': 'D-Day 진척도', 'warmth': '상대 따뜻함'}


def markdown(table, personas, policies, metric):
    """상대 3명 평균 (상대1 → 상대3), 규칙 대비 차이"""
    lines = [f'### {METRICS[metric]} (상대 3명 평균, 괄호는 상대1 → 상대3)', '',
             '| 사람 | ' + ' | '.join(policies) + ' |', '|---' * (len(policies) + 1) + '|']
    for persona in personas:
        base = np.mean([table[(persona.name, 'rules')][r][metric][0] for r in range(ROUNDS)])
        cells = []
        for pol in policies:
            a = table[(persona.name, pol)]
            mean = np.mean([a[r][metric][0] for r in range(ROUNDS)])
            se = np.sqrt(np.mean([a[r][metric][1] ** 2 for r in range(ROUNDS)]) / ROUNDS)
            diff = '' if pol == 'rules' else f' **{(mean - base) * 100:+.1f}**'
            cells.append(f'{mean:.3f}±{se:.3f}{diff} ({a[0][metric][0]:.2f}→{a[ROUNDS - 1][metric][0]:.2f})')
        lines.append(f'| {persona.label} | ' + ' | '.join(cells) + ' |')
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', type=int, default=200)
    ap.add_argument('--out', default='sim_result.json')
    ap.add_argument('--md', default='RESULTS.md')
    args = ap.parse_args()
    params = Params()
    policies = ['rules', 'today', 'full', 'crush', 'oracle']
    table = evaluate(PERSONAS, policies, params, args.runs)
    parts = [markdown(table, PERSONAS, policies, m) for m in ('done', 'pick', 'progress')]
    text = '\n\n'.join(parts)
    print(text)
    open(args.md, 'w', encoding='utf-8').write(text + '\n')
    json.dump({f'{k[0]}|{k[1]}': v for k, v in table.items()}, open(args.out, 'w'), indent=1)


if __name__ == '__main__':
    main()
