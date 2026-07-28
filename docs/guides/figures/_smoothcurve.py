"""Monotone cubic (PCHIP / Fritsch–Carlson) interpolation in pure numpy — draw
simulation results as smooth curves, not scatter points, without overshoot.

Shape-preserving (no spurious wiggles/overshoot beyond the data), so it does NOT
invent structure: it just renders the smooth underlying function a simulation
samples. Use for CONVERGED simulation output; genuinely jagged data is a
convergence red flag to investigate, not to hide under a spline.
"""
import numpy as np


def smooth(x, y, n=400):
    x = np.asarray(x, float)
    y = np.asarray(y, float)
    idx = np.argsort(x)
    x, y = x[idx], y[idx]
    if len(x) < 3:
        xs = np.linspace(x[0], x[-1], n)
        return xs, np.interp(xs, x, y)
    h = np.diff(x)
    delta = np.diff(y) / h
    d = np.zeros_like(y)
    for i in range(1, len(x) - 1):
        if delta[i - 1] * delta[i] > 0:
            w1 = 2 * h[i] + h[i - 1]
            w2 = h[i] + 2 * h[i - 1]
            d[i] = (w1 + w2) / (w1 / delta[i - 1] + w2 / delta[i])
        else:
            d[i] = 0.0
    # non-overshooting one-sided endpoint slopes
    d[0] = ((2 * h[0] + h[1]) * delta[0] - h[0] * delta[1]) / (h[0] + h[1])
    if d[0] * delta[0] <= 0:
        d[0] = 0.0
    elif abs(d[0]) > 3 * abs(delta[0]):
        d[0] = 3 * delta[0]
    d[-1] = ((2 * h[-1] + h[-2]) * delta[-1] - h[-1] * delta[-2]) / (h[-1] + h[-2])
    if d[-1] * delta[-1] <= 0:
        d[-1] = 0.0
    elif abs(d[-1]) > 3 * abs(delta[-1]):
        d[-1] = 3 * delta[-1]
    xs = np.linspace(x[0], x[-1], n)
    i = np.clip(np.searchsorted(x, xs) - 1, 0, len(x) - 2)
    t = (xs - x[i]) / h[i]
    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2
    ys = h00 * y[i] + h10 * h[i] * d[i] + h01 * y[i + 1] + h11 * h[i] * d[i + 1]
    return xs, ys
