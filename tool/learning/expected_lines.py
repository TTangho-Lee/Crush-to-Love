"""test/learning_line_test.dart 기대값: 멘트 표시 · 특징 · 학습 순서 (Dart와 같은 계산)

    python expected_lines.py
"""
import chat_rules as C
import line_features as L
from linear_ts import Model, Rng, fnv1a

SAMPLES = [
    '요즘 많이 바쁘지? 무리하지 말고 밥 잘 챙겨 먹어!',
    '바쁜 거 끝나면 맛있는 거 먹으러 가자 ㅎㅎ',
    '아 그렇구나! 완전 괜찮아 ㅎㅎ',
    '그 와중에 다 해내는 거 진짜 대단하다',
    '자기 전에 너랑 얘기하니까 좋다 ㅎㅎ',
    '오늘 진짜 고생 많았어',
]

# 2026-11-20(금) 21시, 방향 common, 주제 food, seed 123, 반말
HOUR, WEEKDAY, SEED = 21, 5, 123
BASE = {'interest': 'mid', 'short': 0.1, 'hour': HOUR}


def deck(model, seed, approach='common', topic='food'):
    th = model.sample(Rng(fnv1a(f'line|deck|{seed}|0')), 0.15)
    topic_pool, generic = C.line_pools(approach, HOUR, WEEKDAY, topic, False)

    def order(pool):
        rows = []
        for i, line in enumerate(pool):
            phi = L.features({**BASE, **L.arm_of(line)})
            rows.append((-sum(a * b for a, b in zip(th, phi)), (i - seed) % len(pool), line))
        rows.sort(key=lambda x: (x[0], x[1]))
        return [x[2] for x in rows]

    return order(topic_pool), order(generic)


def round_of(topic, generic, r):
    out = []
    k = 3 if not topic else 2
    if topic:
        out.append(topic[r % len(topic)])
    for i in range(min(k, len(generic))):
        line = generic[(k * r + i) % len(generic)]
        if all(line.text != x.text for x in out):
            out.append(line)
    return [l.text for l in out]


def main():
    for t in SAMPLES:
        print(repr(t), L.line_tags(t), C.text_length(t))
    print('fnv', fnv1a(SAMPLES[0]))
    phi = L.features({'interest': 'high', 'short': 0.4, 'hour': 23, **L.arm_of(C.Line(SAMPLES[1]))})
    print('phi2', phi)
    mean, lam = L.prior()
    empty = Model(mean, lam)
    topic, generic = deck(empty, SEED)
    print('pools', len(topic), len(generic))
    print('round0', round_of(topic, generic, 0))
    print('round1', round_of(topic, generic, 1))
    # 질문 멘트를 5번 복사한 뒤 다른 대화(seed 7, 방향 react, 주제 없음)
    model = Model(mean, lam)
    qs = [l for l in C.APPROACH_LINES['common'] if 'question' in L.line_tags(l.text)][:5]
    for l in qs:
        model.update(L.features({**BASE, **L.arm_of(l)}), 1.0)
    print('copied', [l.text for l in qs])
    t2, g2 = deck(model, 7, approach='react', topic=None)
    r0 = round_of(t2, g2, 0)
    print('after round0', r0, [L.line_tags(x) for x in r0])
    mu = model.mean()
    traits = sorted([(n, mu[i]) for i, n in enumerate(L.NAMES) if abs(mu[i]) >= 0.05], key=lambda x: -x[1])
    print('traits', [(n, round(v, 3)) for n, v in traits])


if __name__ == '__main__':
    main()
