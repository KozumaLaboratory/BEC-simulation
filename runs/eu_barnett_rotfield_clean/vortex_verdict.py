#!/usr/bin/env python3
"""Did vortices enter, or is the cloud just oscillating?

The obvious test — "L_z stays up" — DOES NOT WORK, and this is measured, not
argued. At Omega = 0.55 the cloud performs a pure quadrupole oscillation with no
vortices at all, and L_z there runs 0 -> 3.2 -> 0.08 -> 3.4: its final value and
its late-window mean (+3.03, +2.70) are indistinguishable from Omega = 0.85,
where the cloud has genuinely broken up. Sampling L_z at one time samples the
phase of an oscillation.

What separates them is the SHAPE of the time series, plus the state of the cloud:

  oscillating  : L_z swings through ~0 every half period; the mid-plane stays
                 smooth (roughness ~0.03 at Omega 0.55)
  broken up    : the quadrupole collapses and stops, L_z settles at a non-zero
                 value, and the cloud is rough (~0.9 at Omega 0.85)

"Rough" is not the same as "clean vortices", though. A legible run needs L_z to
settle AND the cloud to stay smooth — that is the band this script looks for.
"""
import sys
import h5py
import numpy as np


def roughness(a):
    lap = np.abs(4 * a[1:-1, 1:-1] - a[2:, 1:-1] - a[:-2, 1:-1]
                 - a[1:-1, 2:] - a[1:-1, :-2])
    core = a[1:-1, 1:-1] > 0.2 * a.max()
    return float(lap[core].mean() / a[1:-1, 1:-1][core].mean())


def verdict(path, late=0.5):
    f = h5py.File(path, "r")
    nf = int(np.asarray(f["n_frames"]))
    t = np.asarray(f["times"])[:nf]
    lz = np.asarray(f["Lz"])[:nf]
    ar = np.asarray(f["AR"])[:nf]
    Om = float(np.asarray(f["Omega"]))
    i0 = int(late * nf)
    lz_l, ar_l = lz[i0:], ar[i0:]
    # swing relative to level: ~2 for an oscillation through zero, ~0 if settled
    swing = (lz_l.max() - lz_l.min()) / max(abs(lz_l.mean()), 1e-9)
    rough = np.mean([roughness(np.asarray(f[f"nmid_{i:05d}"]))
                     for i in range(i0 + 1, nf + 1, max(1, (nf - i0) // 8))])
    settled = swing < 0.5 and abs(lz_l.mean()) > 1.0
    if settled and rough < 0.3:
        tag = "VORTICES, cloud still smooth  <- the legible case"
    elif settled:
        tag = "settled but ROUGH (broken up / turbulent)"
    elif rough < 0.3:
        tag = "oscillating, smooth (no vortices)"
    else:
        tag = "oscillating AND rough (?)"
    return dict(Om=Om, nf=nf, tend=t[-1], lz_mean=lz_l.mean(), swing=swing,
                ar_mean=ar_l.mean(), rough=rough, tag=tag)


if __name__ == "__main__":
    print(f"{'Omega':>6} {'t_end':>6} {'Lz(late)':>9} {'swing':>7} "
          f"{'AR(late)':>9} {'rough':>7}  verdict")
    for p in sys.argv[1:]:
        try:
            v = verdict(p)
        except Exception as e:
            print(f"{p}: {e}")
            continue
        print(f"{v['Om']:6.2f} {v['tend']:6.0f} {v['lz_mean']:+9.2f} "
              f"{v['swing']:7.2f} {v['ar_mean']:9.2f} {v['rough']:7.3f}  {v['tag']}")
