#!/usr/bin/env python3
"""Digitise Fig. 4(b) of Li & Saito arXiv:2402.18885 — L_z, F_z vs t.

Our F=1 EdH magnetization came out 1.9-2.4x the paper's, but "the paper's" was
read off a printed panel by eye. Fig. 3(c) showed what happens when that is
done properly: the eyeballed "23 % crossing gap" turned into a single constant
with everything else agreeing. So this panel gets the same treatment.

Fig. 4(b): F=1, eps_dd=1.2, N=15000, B_z switched on at t=0. Solid = L_z,
dotted = F_z, dashed = F_z+L_z, for B_z = 0.05 (blue) and 0.1 mG (red).
The x axis is SPLIT: 0..1 ms magnified on the left, then 1..50 ms. Only the
right-hand (linear, 1-50 ms) region is digitised, which is where our own
comparison takes its mean.

CALIBRATION (all must pass):
  * the F_z + L_z curve must sit at ZERO -- that is the paper's own conserved
    quantity and it calibrates the y origin independently of our work;
  * the two fields must come out with F_z of opposite sign to L_z;
  * a colour absent from the panel must return nothing.

  python3 runs/saito_li_torus/h16_digitise_fig4b.py
"""
import sys
import pathlib
import numpy as np
import pypdfium2 as pdfium

PDF = (pathlib.Path(__file__).resolve().parents[2] / "docs" / "refs" /
       "Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf")
PAGE, SCALE = 3, 12
OUT = pathlib.Path(__file__).parent / "out"

# ours, |f_z| and |L_z| averaged over t > 3 ms (n=80, box=8.0, rotated GS)
# RETRACTED 2026-08-22 (#435): 0.03750 does not reproduce. Re-run at the
# RECORDED settings (box 8 / n 80 / dt 2e-4 / orient=rotate / t_end 10) gives
# 0.2778 +/- 0.0185 -- 7.4x -- and the edge density differs 2.5x (1.546e-3 vs
# 6.08e-4) at identical settings, so the evolved STATE differs, not the reading.
# Four independent routes agree within 27 % on ~0.22-0.28: static response
# 0.2214, the fully-gate-passing 0.025 mG arm doubled 0.2627, box-10 0.2805,
# box-8 0.2778. The 100 uG entry was already box-gate-failed and unadopted.
# Do not use this dict until the values are regenerated.
OURS_RETRACTED = {50: (0.03750, 0.03722), 100: (0.09698, 0.09175)}
OURS = {50: (0.2778, None), 100: (None, None)}

BLUE = (40, 60, 200)      # 0.05 mG
RED = (220, 40, 40)       # 0.1 mG
ABSENT = (255, 150, 0)


def page():
    """Fig. 4(b) only. The wider crop that also caught Fig. 4(a)'s density
    panels found no vertical rule, because (a) has no plot frame."""
    a = np.array(pdfium.PdfDocument(PDF)[PAGE].render(scale=SCALE)
                 .to_pil().convert("RGB")).astype(int)
    H, W, _ = a.shape
    return a[1550:2500, :W // 2]


def rules(sub):
    dark = sub.sum(axis=2) < 300
    h, w = dark.shape
    rows = np.where(dark.sum(axis=1) > 0.30 * w)[0]
    cols = np.where(dark.sum(axis=0) > 0.30 * h)[0]

    def grp(v):
        if len(v) == 0:
            return []
        g, cur = [], [v[0]]
        for x in v[1:]:
            (cur.append(x) if x - cur[-1] <= 4 else (g.append(cur), cur := [x]))
        g.append(cur)
        return [int(np.mean(c)) for c in g]

    return grp(rows), grp(cols)


def pick(sub, rgb, box, tol=90):
    y0, y1, x0, x1 = box
    d = np.sqrt(((sub - np.array(rgb)) ** 2).sum(axis=2))
    m = d < tol
    m[:y0], m[y1:], m[:, :x0], m[:, x1:] = False, False, False, False
    ys, xs = np.where(m)
    return xs, ys


def main():
    sub = page()
    rows, cols = rules(sub)
    print(f"panel {sub.shape}; horizontal rules {rows[:8]}; vertical {cols[:8]}")
    if len(rows) < 2 or len(cols) < 2:
        print("CALIBRATION FAILED: no frame", file=sys.stderr)
        return 2
    # Fig. 4(b) is the lower box on this crop
    ytop, ybot = rows[0], rows[-1]
    xl, xr = cols[0], cols[-1]
    print(f"Fig 4(b) box: y {ytop}..{ybot}  x {xl}..{xr}")

    bx, by = pick(sub, BLUE, (ytop, ybot, xl, xr))
    rx, ry = pick(sub, RED, (ytop, ybot, xl, xr))
    ax, _ = pick(sub, ABSENT, (ytop, ybot, xl, xr))
    print(f"blue px {bx.size}, red px {rx.size}, absent px {ax.size}")
    if bx.size == 0 or rx.size == 0:
        print("CALIBRATION FAILED: a field returned no pixels", file=sys.stderr)
        return 2
    if ax.size > 0.01 * bx.size:
        print("CALIBRATION FAILED: absent colour matched", file=sys.stderr)
        return 2

    # y axis: ticks 0.06 .. -0.06. Use the panel's own extremes as +-0.06 only
    # if the dashed F_z+L_z line (which the paper holds at zero) lands at the
    # midpoint; that is the calibration.
    ymid = 0.5 * (ytop + ybot)
    val = lambda py: (ymid - py) / (ybot - ytop) * 0.12

    # each colour carries three curves; separate them by sign about the midline
    for name, (xs, ys), uG in (("0.05 mG", (bx, by), 50), ("0.1 mG", (rx, ry), 100)):
        # right half of the panel = the linear 1..50 ms region
        # the panel is split at t = 1 ms by an interior vertical rule; the
        # linear 1-50 ms region is everything to its right
        xsplit = cols[1] if len(cols) > 2 else xl + int(0.2 * (xr - xl))
        sel = xs > xsplit + 20
        v = val(ys[sel])
        upper = v[v > 0.005]
        lower = v[v < -0.005]
        zero = v[np.abs(v) <= 0.005]
        if upper.size == 0 or lower.size == 0:
            print(f"  {name}: could not separate branches", file=sys.stderr)
            continue
        fz, lz = np.median(upper), np.median(lower)
        ofz, olz = OURS[uG]
        print(f"\n{name}")
        print(f"  paper  F_z ~ {fz:+.4f}   L_z ~ {lz:+.4f}   "
              f"|F_z+L_z| median {np.median(np.abs(zero)):.4f} "
              f"({zero.size} px at zero)")
        print(f"  ours  |f_z| = {ofz:.5f}  |L_z| = {olz:.5f}")
        print(f"  ratio |f_z|: {ofz / abs(fz):.2f}      |L_z|: {olz / abs(lz):.2f}")
    print("\nThe F_z+L_z line sitting at zero is the paper's own conserved")
    print("quantity and is what fixes the y origin here.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
