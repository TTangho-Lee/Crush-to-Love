"""베이지안 선형 회귀 + Thompson sampling (lib/learning/linear_ts.dart와 같은 계산)

    사전: θ ~ N(μ₀, v²Λ₀⁻¹), Λ₀ = diag(λ)
    기록 하나(φ, r, w): A += w·φφᵀ, b += w·r·φ (w = -1이면 앞 기록 빼기)
    평균 μ = A⁻¹b, 뽑기 θ̃ = μ + v·L⁻ᵀz (A = LLᵀ)
난수: xorshift32 + Box–Muller (Dart와 같은 값, 웹에서도 32비트 연산만)
Model은 순수 파이썬 (Dart 테스트 기대값), FastModel은 numpy (시뮬레이션)
"""
from __future__ import annotations

import math

import numpy as np

MASK = 0xFFFFFFFF


def fnv1a(text: str) -> int:
    """글자 → 32비트 해시 (Dart와 같게, UTF-16 코드 단위마다)"""
    h = 0x811C9DC5
    raw = text.encode('utf-16-le')
    for c in (int.from_bytes(raw[i:i + 2], 'little') for i in range(0, len(raw), 2)):
        h ^= c
        # h * 16777619 mod 2^32 (= h*403 + (h << 24)), 웹에서 2^53을 넘지 않게
        h = (h * 403 + ((h & 0xFF) << 24)) % 4294967296
    return h


class Rng:
    """xorshift32, seed가 0이면 1로"""

    def __init__(self, seed: int):
        self.x = (seed & MASK) or 1

    def next_u32(self) -> int:
        x = self.x
        x = (x ^ (x << 13)) & MASK
        x ^= x >> 17
        x = (x ^ (x << 5)) & MASK
        self.x = x
        return x

    def uniform(self) -> float:
        """(0, 1]"""
        return self.next_u32() / 4294967296.0

    def normal(self) -> float:
        u1 = self.uniform()
        u2 = self.uniform()
        return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2)


# ---------- 순수 파이썬 (Dart와 같은 순서로 계산) ----------

def cholesky(a: list[list[float]]) -> list[list[float]]:
    n = len(a)
    L = [[0.0] * n for _ in range(n)]
    for i in range(n):
        for j in range(i + 1):
            s = a[i][j]
            for k in range(j):
                s -= L[i][k] * L[j][k]
            if i == j:
                L[i][i] = math.sqrt(max(s, 1e-12))
            else:
                L[i][j] = s / L[j][j]
    return L


def solve_lower(L, b):
    n = len(b)
    y = [0.0] * n
    for i in range(n):
        s = b[i]
        for k in range(i):
            s -= L[i][k] * y[k]
        y[i] = s / L[i][i]
    return y


def solve_upper_t(L, y):
    """Lᵀx = y"""
    n = len(y)
    x = [0.0] * n
    for i in range(n - 1, -1, -1):
        s = y[i]
        for k in range(i + 1, n):
            s -= L[k][i] * x[k]
        x[i] = s / L[i][i]
    return x


class Model:
    def __init__(self, prior_mean, prior_precision):
        d = len(prior_mean)
        self.d = d
        self.a = [[prior_precision[i] if i == j else 0.0 for j in range(d)] for i in range(d)]
        self.b = [prior_precision[i] * prior_mean[i] for i in range(d)]
        self.n = 0

    def update(self, phi, reward, weight=1.0):
        for i in range(self.d):
            if phi[i] == 0:
                continue
            for j in range(self.d):
                self.a[i][j] += weight * phi[i] * phi[j]
            self.b[i] += weight * reward * phi[i]
        self.n += 1 if weight > 0 else -1

    def mean(self):
        L = cholesky(self.a)
        return solve_upper_t(L, solve_lower(L, self.b))

    def sample(self, rng: Rng, scale: float):
        L = cholesky(self.a)
        mu = solve_upper_t(L, solve_lower(L, self.b))
        z = [rng.normal() for _ in range(self.d)]
        e = solve_upper_t(L, z)
        return [mu[i] + scale * e[i] for i in range(self.d)]


# ---------- numpy (시뮬레이션) ----------

class FastModel:
    def __init__(self, prior_mean, prior_precision):
        self.a = np.diag(np.asarray(prior_precision, float))
        self.b = np.asarray(prior_precision, float) * np.asarray(prior_mean, float)
        self.n = 0

    def update(self, phi, reward, weight=1.0):
        phi = np.asarray(phi, float)
        self.a += weight * np.outer(phi, phi)
        self.b += weight * reward * phi
        self.n += 1

    def mean(self):
        return np.linalg.solve(self.a, self.b)

    def sample(self, rng: Rng, scale: float):
        L = np.linalg.cholesky(self.a)
        mu = np.linalg.solve(self.a, self.b)
        z = np.array([rng.normal() for _ in range(len(self.b))])
        return mu + scale * np.linalg.solve(L.T, z)
