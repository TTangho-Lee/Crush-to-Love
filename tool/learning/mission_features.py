"""미션 특징 φ (lib/learning/mission_features.dart와 같은 순서 · 값)

문맥 ctx (DB에 JSON으로 저장하는 값과 같은 이름, 숫자 · 이름만):
  rule 규칙 점수 · maxLv 용기 최대 1~3 · courage 용기 단계 0~3 · pace behind|onTrack|ahead
  rest 쉰 날(없으면 None) · gap 마지막 대화 뒤 날(없으면 None) · interest low|mid|high|None
  weekday 1(월)~7(일) · hour 0~23 (주차 구성처럼 시각이 없으면 None → 평균값)
  meet 만남 빈도 0~7 · elapsed 지난 비율 0~1
미션: level · offline · tags
"""
from __future__ import annotations

from dart_rules import BOLD, TAGS

GLOBAL_NAMES = [
    'rule', 'bias', 'levelGap', 'offline', 'offlineWeekend', 'offlineMeet',
    *[f'tag.{t}' for t in TAGS],
    'contactGap', 'boldHigh', 'boldLow', 'hardBehind', 'easyRested', 'onlineEvening', 'hardLate',
]
CRUSH_NAMES = [*[f'crush.tag.{t}' for t in TAGS], 'crush.offline', 'crush.levelGap']
NAMES = GLOBAL_NAMES + CRUSH_NAMES
D_GLOBAL = len(GLOBAL_NAMES)  # 22
D = len(NAMES)  # 33

# 시각을 모를 때 (주차 구성) 평균값
WEEKEND_AVG = 3 / 7
EVENING_AVG = 0.5


def weekend_of(ctx) -> float:
    wd = ctx.get('weekday')
    return WEEKEND_AVG if wd is None else (1.0 if wd >= 5 else 0.0)


def evening_of(ctx) -> float:
    h = ctx.get('hour')
    return EVENING_AVG if h is None else (1.0 if h >= 17 or h < 5 else 0.0)


def features(ctx: dict, level: int, offline: bool, tags) -> list[float]:
    """φ = [나 22개, 상대 11개]"""
    tags = set(tags)
    gap = (level - ctx['maxLv']) / 2
    off = 1.0 if offline else 0.0
    bold = 1.0 if tags & BOLD else 0.0
    contact = 1.0 if tags - {'prep'} else 0.0
    g = ctx.get('gap')
    rest = ctx.get('rest')
    interest = ctx.get('interest')
    tag_vec = [1.0 if t in tags else 0.0 for t in TAGS]
    glob = [
        ctx['rule'] / 5,
        1.0,
        gap,
        off,
        off * weekend_of(ctx),
        off * ctx['meet'] / 7,
        *tag_vec,
        contact * (1.0 if g is not None and g >= 3 else 0.0),
        bold * (1.0 if interest == 'high' else 0.0),
        bold * (1.0 if interest == 'low' else 0.0),
        (1.0 if level >= 2 else 0.0) * (1.0 if ctx['pace'] == 'behind' else 0.0),
        (1.0 if level == 1 else 0.0) * (1.0 if rest is not None and rest >= 3 else 0.0),
        (1.0 - off) * evening_of(ctx),
        (level - 1) / 2 * ctx['elapsed'],
    ]
    crush = [*tag_vec, off, gap]
    return glob + crush


def prior(rule_weight: float, lam_rule: float, lam_global: float, lam_crush: float):
    """(μ₀, λ): 규칙 점수에만 가중치, 상대 층은 더 세게 0으로"""
    mean = [0.0] * D
    mean[0] = rule_weight
    lam = [lam_global] * D_GLOBAL + [lam_crush] * (D - D_GLOBAL)
    lam[0] = lam_rule
    return mean, lam
