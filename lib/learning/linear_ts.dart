// 학습하는 추천의 계산: 베이지안 선형 회귀 + Thompson sampling
//   사전: θ ~ N(μ₀, v²Λ₀⁻¹), Λ₀ = diag(λ)
//   기록 하나 (φ, r, w): A += w·φφᵀ, b += w·r·φ (w = -1이면 앞 기록을 정확히 뺌)
//   평균 μ = A⁻¹b, 뽑기 θ̃ = μ + v·L⁻ᵀz (A = LLᵀ, Cholesky)
//   난수: xorshift32 + Box–Muller, 32비트 연산만 써서 웹(크롬)에서도 같은 값
//   tool/learning/linear_ts.py와 같은 순서로 계산 (테스트 기대값)
import 'dart:math' as math;

/// 글자 → 32비트 해시 (FNV-1a, 뽑기 seed)
int fnv1a(String text) {
  var h = 0x811C9DC5;
  for (final c in text.codeUnits) {
    h ^= c;
    // h × 16777619 mod 2³², 웹에서 2⁵³을 넘지 않게 나눠서
    h = (h * 403 + ((h & 0xFF) << 24)) % 4294967296;
  }
  return h;
}

/// 32비트 난수 (xorshift32), 같은 seed면 늘 같은 값
class LearnRng {
  LearnRng(int seed) : _x = (seed & _mask) == 0 ? 1 : seed & _mask;

  static const _mask = 0xFFFFFFFF;
  int _x;

  int nextUint32() {
    var x = _x;
    x = (x ^ (x << 13)) & _mask;
    x ^= x >> 17;
    x = (x ^ (x << 5)) & _mask;
    return _x = x;
  }

  /// (0, 1)
  double uniform() => nextUint32() / 4294967296.0;

  /// 표준 정규분포 (Box–Muller, 한 번에 하나)
  double normal() {
    final u1 = uniform();
    final u2 = uniform();
    return math.sqrt(-2.0 * math.log(u1)) * math.cos(2.0 * math.pi * u2);
  }
}

/// 두 벡터 곱
double dot(List<double> a, List<double> b) {
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    s += a[i] * b[i];
  }
  return s;
}

/// 선형 보상 모델 하나 (A · b만 들고 있고 평균 · 뽑기는 그때 계산)
class LinearModel {
  LinearModel._(this.dim, this._a, this._b, this.count);

  /// 사전만 있는 모델
  factory LinearModel.prior(List<double> mean, List<double> precision) {
    final d = mean.length;
    return LinearModel._(
      d,
      [
        for (var i = 0; i < d; i++)
          for (var j = 0; j < d; j++) i == j ? precision[i] : 0.0,
      ],
      [for (var i = 0; i < d; i++) precision[i] * mean[i]],
      0,
    );
  }

  final int dim;

  /// 정밀도 행렬 (줄 순서로 d×d)
  final List<double> _a;
  final List<double> _b;

  /// 반영한 기록 수 (뺀 기록은 -1)
  int count;

  /// 평균 · Cholesky (기록이 들어오면 다시)
  List<double>? _mean;
  List<double>? _chol;

  /// 기록 하나 반영 (weight -1이면 같은 기록을 뺌)
  void update(List<double> phi, double reward, {double weight = 1}) {
    final d = dim;
    for (var i = 0; i < d; i++) {
      final pi = phi[i];
      if (pi == 0) continue;
      for (var j = 0; j < d; j++) {
        _a[i * d + j] += weight * pi * phi[j];
      }
      _b[i] += weight * reward * pi;
    }
    count += weight > 0 ? 1 : -1;
    _mean = null;
    _chol = null;
  }

  /// 사후 평균 μ
  List<double> mean() {
    final chol = _cholesky();
    return _mean ??= _solveUpperT(chol, _solveLower(chol, _b));
  }

  /// 사후에서 하나 뽑기 (scale: 탐색 세기 v)
  List<double> sample(LearnRng rng, double scale) {
    final mu = mean();
    final chol = _cholesky();
    final z = [for (var i = 0; i < dim; i++) rng.normal()];
    final e = _solveUpperT(chol, z);
    return [for (var i = 0; i < dim; i++) mu[i] + scale * e[i]];
  }

  LinearModel copy() =>
      LinearModel._(dim, [..._a], [..._b], count);

  Map<String, Object?> toJson() => {'dim': dim, 'a': _a, 'b': _b, 'count': count};

  /// 모양이 안 맞으면 null
  static LinearModel? fromJson(Map<String, Object?> json) {
    final dim = json['dim'];
    final a = json['a'];
    final b = json['b'];
    if (dim is! int || a is! List || b is! List) return null;
    if (a.length != dim * dim || b.length != dim) return null;
    return LinearModel._(
      dim,
      [for (final v in a) (v as num).toDouble()],
      [for (final v in b) (v as num).toDouble()],
      json['count'] as int? ?? 0,
    );
  }

  // ---------- 안쪽 ----------

  /// A = LLᵀ의 L (줄 순서로 d×d)
  List<double> _cholesky() {
    final cached = _chol;
    if (cached != null) return cached;
    final d = dim;
    final l = List<double>.filled(d * d, 0);
    for (var i = 0; i < d; i++) {
      for (var j = 0; j <= i; j++) {
        var s = _a[i * d + j];
        for (var k = 0; k < j; k++) {
          s -= l[i * d + k] * l[j * d + k];
        }
        l[i * d + j] = i == j ? math.sqrt(math.max(s, 1e-12)) : s / l[j * d + j];
      }
    }
    return _chol = l;
  }

  /// Ly = b
  List<double> _solveLower(List<double> l, List<double> b) {
    final d = dim;
    final y = List<double>.filled(d, 0);
    for (var i = 0; i < d; i++) {
      var s = b[i];
      for (var k = 0; k < i; k++) {
        s -= l[i * d + k] * y[k];
      }
      y[i] = s / l[i * d + i];
    }
    return y;
  }

  /// Lᵀx = y
  List<double> _solveUpperT(List<double> l, List<double> y) {
    final d = dim;
    final x = List<double>.filled(d, 0);
    for (var i = d - 1; i >= 0; i--) {
      var s = y[i];
      for (var k = i + 1; k < d; k++) {
        s -= l[k * d + i] * x[k];
      }
      x[i] = s / l[i * d + i];
    }
    return x;
  }
}
