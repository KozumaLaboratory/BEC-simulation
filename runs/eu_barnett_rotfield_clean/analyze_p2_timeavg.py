"""Time-averaged P2 observables — the endpoint Fz is a single-phase snapshot of a
fast Larmor oscillation, so net M_z must be the time MEAN over the last several
periods. Also flags |F| runaway (non-stationary depolarisation) that would make a
'net M_z' ill-defined.

Window: t >= T_WIN (last ~third, ~8 Larmor periods at gamma*B=4, period ~1.57).
"""
import os
import numpy as np
import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
T_WIN = 20.0


def stats(tag):
    p = os.path.join(HERE, f"traj_p2_{tag}.csv")
    if not os.path.exists(p):
        return None
    d = pd.read_csv(p)
    w = d[d["t"] >= T_WIN]
    # |F| drift over the window: (start-end)/start -> runaway flag
    fmag_slope = (w["Fmag"].iloc[0] - w["Fmag"].iloc[-1]) / w["Fmag"].iloc[0]
    return dict(
        fz_mean=w["Fz"].mean(), fz_std=w["Fz"].std(),
        fz_end=d["Fz"].iloc[-1],
        fmag_mean=w["Fmag"].mean(), fmag_end=d["Fmag"].iloc[-1],
        fmag_drift=fmag_slope, lz_mean=w["Lz"].mean(),
    )


print(f"{'run':16s} {'Fz_mean':>9s}{'Fz_std':>8s}{'Fz_end':>8s}"
      f"{'|F|_mean':>9s}{'|F|_end':>8s}{'|F|drift':>9s}{'Lz_mean':>8s}")
print("-" * 78)
OM = [0.5, 0.65, 0.74, 0.8, 0.85]
tags = []
for O in OM:
    tags += [(f"on {O}", "on" if O == 0.85 else f"on_p{O:.2f}"),
             (f"off {O}", "off" if O == 0.85 else f"off_p{O:.2f}")]
tags += [("on CW 0.74", "on_m0.74"), ("off CW 0.74", "off_m0.74")]
S = {}
for name, tag in tags:
    s = stats(tag)
    S[tag] = s
    if s:
        print(f"{name:16s} {s['fz_mean']:9.3f}{s['fz_std']:8.3f}{s['fz_end']:8.3f}"
              f"{s['fmag_mean']:9.3f}{s['fmag_end']:8.3f}{s['fmag_drift']:9.3f}"
              f"{s['lz_mean']:8.3f}")

print("\n=== Task 2: Delta-Fz(Omega) from TIME-MEAN ===")
for O in OM:
    on = S["on" if O == 0.85 else f"on_p{O:.2f}"]
    off = S["off" if O == 0.85 else f"off_p{O:.2f}"]
    print(f"  Omega={O:.2f}  dFz_mean={on['fz_mean']-off['fz_mean']:+.3f}  "
          f"(on {on['fz_mean']:+.3f} +/-{on['fz_std']:.2f}, "
          f"off {off['fz_mean']:+.3f} +/-{off['fz_std']:.2f})")

print("\n=== Task 3: CW-CCW double difference @0.74 (TIME-MEAN) ===")
onC, onW = S["on_p0.74"], S["on_m0.74"]
offC, offW = S["off_p0.74"], S["off_m0.74"]
d_on = onC["fz_mean"] - onW["fz_mean"]
d_off = offC["fz_mean"] - offW["fz_mean"]
dd = d_on - d_off
print(f"  on : CCW {onC['fz_mean']:+.3f}+/-{onC['fz_std']:.2f}  "
      f"CW {onW['fz_mean']:+.3f}+/-{onW['fz_std']:.2f}  d_on={d_on:+.3f}")
print(f"  off: CCW {offC['fz_mean']:+.3f}+/-{offC['fz_std']:.2f}  "
      f"CW {offW['fz_mean']:+.3f}+/-{offW['fz_std']:.2f}  d_off={d_off:+.3f}")
print(f"  DOUBLE DIFF = {dd:+.3f}")
print(f"  CW |F| runaway: on drift={onW['fmag_drift']:+.2f} "
      f"(|F|_end={onW['fmag_end']:.2f}) -> {'NON-STATIONARY' if onW['fmag_drift']>0.05 else 'ok'}")
print(f"  CCW |F| drift : on drift={onC['fmag_drift']:+.2f} "
      f"(|F|_end={onC['fmag_end']:.2f})")
