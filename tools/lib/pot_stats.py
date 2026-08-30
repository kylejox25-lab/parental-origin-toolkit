#!/usr/bin/env python3
"""Stats helpers for pot-* tools: two-sided binomial test + Benjamini-Hochberg FDR.

No third-party dependencies (scipy not required).
"""
import math


def binomial_pval(k, n, p=0.5):
    """Two-sided binomial test of parental imbalance.

    Exact (sum of probabilities <= observed probability) for n <= 2000;
    normal approximation with continuity correction above that, since the
    exact sum over n+1 terms becomes slow for deep-coverage regions.
    """
    if n == 0:
        return 1.0
    k, n = int(k), int(n)
    if n <= 2000:
        p_obs = math.comb(n, k) * (p ** k) * ((1.0 - p) ** (n - k))
        total = 0.0
        for i in range(n + 1):
            pi = math.comb(n, i) * (p ** i) * ((1.0 - p) ** (n - i))
            if pi <= p_obs * (1.0 + 1e-12):
                total += pi
        return min(1.0, total)
    mean = n * p
    sd = math.sqrt(n * p * (1.0 - p))
    z = (abs(k - mean) - 0.5) / sd
    return min(1.0, math.erfc(z / math.sqrt(2.0)))


def bh_fdr(pairs):
    """Benjamini-Hochberg FDR correction.

    pairs: iterable of (key, pvalue). Returns {key: qvalue}.
    Keys whose pvalue is None are not corrected and get no entry.
    """
    items = [(k, float(p)) for k, p in pairs if p is not None]
    items.sort(key=lambda t: t[1])
    n = len(items)
    qs = {}
    prev = None
    for i, (k, p) in enumerate(items, start=1):
        q = min(1.0, p * n / i)
        if prev is not None:
            q = max(q, prev)  # enforce monotonicity
        qs[k] = q
        prev = q
    return qs
