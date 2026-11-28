"""멘트 특징 φ (lib/learning/line_features.dart와 같은 순서 · 값)

멘트 표시(tagMessage로): question · invite · share · care · warm(칭찬 · 애정) · laugh · react(리액션 · 맞장구)
문맥: interest low|mid|high · short 상대 짧은 대답 비율 · hour 0~23
"""
from __future__ import annotations

import chat_rules as C

LINE_TAGS = ['question', 'invite', 'share', 'care', 'warm', 'laugh', 'react']
NAMES = ['bias', *[f'tag.{t}' for t in LINE_TAGS], 'short', 'long', 'timed',
         'questionShortReply', 'inviteHigh', 'warmNight']
D = len(NAMES)  # 14

SHORT_MAX = 15
LONG_MIN = 30
SHORT_REPLY_RATE = 0.3


def line_tags(text: str) -> list[str]:
    """멘트 글자 → 학습 표시 (LINE_TAGS 순서)"""
    t = C.tag_message(text)
    have = {
        'question': 'question' in t,
        'invite': 'invite' in t,
        'share': 'share' in t,
        'care': 'care' in t,
        'warm': bool(t & {'compliment', 'affection'}),
        'laugh': 'laugh' in t,
        'react': bool(t & {'surprise', 'empathy'}),
    }
    return [k for k in LINE_TAGS if have[k]]


def arm_of(line: C.Line) -> dict:
    return {'tags': line_tags(line.text), 'len': C.text_length(line.text),
            'timed': line.slot is not None or line.weekend is not None}


def features(ctx: dict) -> list[float]:
    tags = set(ctx['tags'])
    f = lambda b: 1.0 if b else 0.0
    hour = ctx.get('hour')
    night = hour is not None and (hour >= 23 or hour < 5)
    return [
        1.0,
        *[f(t in tags) for t in LINE_TAGS],
        f(ctx['len'] <= SHORT_MAX),
        f(ctx['len'] >= LONG_MIN),
        f(ctx['timed']),
        f('question' in tags) * f((ctx.get('short') or 0) >= SHORT_REPLY_RATE),
        f('invite' in tags) * f(ctx.get('interest') == 'high'),
        f('warm' in tags) * f(night),
    ]


def prior():
    """평균 0, 표시 · 길이 λ 2, 나머지 6"""
    mean = [0.0] * D
    lam = [2.0 if n.startswith('tag.') or n in ('short', 'long', 'timed') else 6.0 for n in NAMES]
    return mean, lam
