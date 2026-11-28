"""멘트 학습 시뮬레이션: 지금 앱(돌려 고르기) vs 학습 (오프라인 평가)

    python simulate_lines.py            # 사람마다 300번
    python simulate_lines.py --runs 50

가상 사용자: 멘트 특징에 대한 숨은 선호가 다름 (질문형 · 다정형 · 짧게형 · 아무거나형)
  대화 분석 10번 (방향 · 주제 · 시각은 무작위), 분석마다 멘트 3개를 보고
  가장 마음에 드는 것을 복사할 확률 sigmoid(u), 안 하면 '↻' (최대 세 화면)
정책
  rules  지금 앱 (pickLines, seed로 돌려 고름)
  learn  학습 (분야 'line', Thompson sampling, 주제 멘트 1 + 방향 멘트 2, 화면마다 다음 것)
  oracle 진짜 선호 순서 (위쪽 한계)
보상: 복사 +1 (Dart line_learning.dart와 같게)
  '↻'에 복사 안 한 줄마다 약한 −를 주면 오히려 나빠져서 안 씀 (−0.03 ~ −0.3 모두, R_SHUFFLE로 확인)
"""
from __future__ import annotations

import argparse
import math

import numpy as np

import chat_rules as C
import line_features as L
from linear_ts import FastModel, Rng, fnv1a

R_COPY = 1.0
R_SHUFFLE = 0.0  # 안 씀 (위 설명)
SCALE = 0.15
SESSIONS = 10
MAX_ROUNDS = 3

PERSONAS = {
    'question': ('질문형', {'tag.question': 1.5, 'long': -0.8}),
    'warm': ('다정형', {'tag.care': 1.2, 'tag.warm': 1.0}),
    'short': ('짧게형', {'short': 1.2, 'tag.laugh': 0.8, 'long': -1.0}),
    'none': ('아무거나형', {}),
}

# 자주 나오는 방향 (대화 분석에서)
APPROACHES = ['common', 'askBack', 'react', 'light', 'laughTopic', 'routine', 'invite', 'openUp', 'rest', 'reconnect']


def utility(prefs: dict, ctx: dict) -> float:
    phi = L.features(ctx)
    return -2.2 + sum(prefs.get(n, 0) * v for n, v in zip(L.NAMES, phi))


def rotation_rank(i: int, n: int, seed: int) -> int:
    return (i - seed) % n


class Deck:
    """한 분석의 멘트 순서 (Dart LineDeck)"""

    def __init__(self, theta, topic, generic, seed, base):
        def order(pool):
            rows = []
            for i, line in enumerate(pool):
                ctx = {**base, **L.arm_of(line)}
                score = 0.0 if theta is None else float(np.dot(theta, L.features(ctx)))
                rows.append((-score, rotation_rank(i, len(pool), seed), line))
            rows.sort(key=lambda x: (x[0], x[1]))
            return [x[2] for x in rows]

        self.topic = order(topic)
        self.generic = order(generic)

    def round(self, r: int) -> list:
        out = []
        if self.topic:
            out.append(self.topic[r % len(self.topic)])
            k = 2
        else:
            k = 3
        g = len(self.generic)
        for i in range(min(k, g)):
            line = self.generic[(k * r + i) % g]
            if all(line.text != x.text for x in out):
                out.append(line)
        return out


def run(persona: str, policy: str, run_id: int) -> dict:
    rng = np.random.default_rng(run_id * 104729 + fnv1a(persona) % 1000)
    _, prefs = PERSONAS[persona]
    mean, lam = L.prior()
    model = FastModel(mean, lam)
    first = rounds = copied = 0
    for k in range(SESSIONS):
        approach = APPROACHES[int(rng.integers(len(APPROACHES)))]
        topic = C.TOPICS[int(rng.integers(len(C.TOPICS)))] if rng.random() < 0.5 else None
        hour = int(rng.integers(8, 25)) % 24
        weekday = int(rng.integers(1, 8))
        seed = int(rng.integers(0, 10_000))
        interest = ['low', 'mid', 'high'][int(rng.integers(3))]
        base = {'interest': interest, 'short': float(rng.uniform(0, 0.5)), 'hour': hour}
        topic_pool, generic = C.line_pools(approach, hour, weekday, topic, False)
        if policy == 'learn':
            theta = model.sample(Rng(fnv1a(f'line|deck|{seed}|0|{run_id}')), SCALE)
            deck = Deck(theta, topic_pool, generic, seed, base)
        elif policy == 'oracle':
            deck = Deck(np.array([prefs.get(n, 0) for n in L.NAMES]), topic_pool, generic, seed, base)
        for r in range(MAX_ROUNDS):
            if policy == 'rules':
                texts = C.pick_lines(approach, hour, weekday, seed + r * 3, topic)
                shown = [C.Line(t) for t in texts]
                # 시간대 · 요일 표시는 사전에서 찾아 붙임
                lookup = {l.text: l for l in topic_pool + generic}
                shown = [lookup.get(t, C.Line(t)) for t in texts]
            else:
                shown = deck.round(r)
            ctxs = [{**base, **L.arm_of(l)} for l in shown]
            us = [utility(prefs, c) for c in ctxs]
            best = int(np.argmax(us))
            rounds += 1
            if rng.random() < 1 / (1 + math.exp(-us[best])):
                copied += 1
                first += r == 0
                model.update(L.features(ctxs[best]), R_COPY)
                break
            if R_SHUFFLE:
                for c in ctxs:
                    model.update(L.features(c), R_SHUFFLE)
    return dict(first=first / SESSIONS, copied=copied / SESSIONS, rounds=rounds / SESSIONS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--runs', type=int, default=300)
    ap.add_argument('--md', default=None)
    args = ap.parse_args()
    lines = ['### 멘트: 분석 10번 중 첫 화면에서 복사한 비율 (괄호는 세 화면 안에 복사)', '',
             '| 사람 | rules | learn | oracle |', '|---|---|---|---|']
    for p, (label, _) in PERSONAS.items():
        cells = []
        base = None
        for pol in ('rules', 'learn', 'oracle'):
            rows = [run(p, pol, k) for k in range(args.runs)]
            f = np.mean([r['first'] for r in rows])
            se = np.std([r['first'] for r in rows]) / math.sqrt(len(rows))
            c = np.mean([r['copied'] for r in rows])
            base = f if pol == 'rules' else base
            diff = '' if pol == 'rules' else f' **{(f - base) * 100:+.1f}**'
            cells.append(f'{f:.3f}±{se:.3f}{diff} ({c:.2f})')
        lines.append(f'| {label} | ' + ' | '.join(cells) + ' |')
    text = '\n'.join(lines)
    print(text)
    if args.md:
        open(args.md, 'w', encoding='utf-8').write(text + '\n')


if __name__ == '__main__':
    main()
