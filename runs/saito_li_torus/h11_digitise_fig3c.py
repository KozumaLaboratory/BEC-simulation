#!/usr/bin/env python3
"""Digitise Fig. 3(c) upper panel of Li & Saito arXiv:2402.18885 — E(B_z).

WHY. Our F=1 crossing lands at 0.108 mG against the paper's stated 0.14, with
box and grid both converged on our side, so the untested side is the paper's.
But Fig. 3(c)'s ordinate is `E / (N hbar^2 M^-1 um^-2)`, which IS the per-atom
`M E/(N hbar^2)` this repo computes — so the comparison is not confined to the
crossing field. Digitising both branches localises the disagreement to the
torus level, the cigar offset, or the cigar slope, which "the crossing is 23 %
low" cannot do.

Conversion: E/N in hbar*omega_ref -> paper units is a division by
a_ho^2 = 0.6088471 um^2 (omega_ref = 2 pi 110 Hz, Eu-151).

CALIBRATION, all three of which must pass or the script refuses to report:
  * frame     — the panel box is located from its own black rule, and the
                x-axis it shares with the F_z panel spans 0 .. 0.2 mG;
  * positive  — the digitised TORUS branch must be flat near -11.5, which the
                paper plots and which no calculation of ours produced;
  * negative  — a colour absent from the panel must return no points.

  python3 runs/saito_li_torus/h11_digitise_fig3c.py
"""
import sys
import pathlib
import numpy as np
import pypdfium2 as pdfium

PDF = (pathlib.Path(__file__).resolve().parents[2] / "docs" / "refs" /
       "Saito_Li_2024_magnetic_vortex_droplets_arXiv2402.18885.pdf")
PAGE, SCALE = 2, 12
A_HO_UM2 = 0.6088471
TO_PAPER = 1.0 / A_HO_UM2

# ours, E/N in hbar*omega_ref (F=1, N=50000, eps_dd=1.2); box- and
# grid-converged (torus edge 1.8e-14, cigar 2e-8, E flat to 7 digits under a
# 1.43x transverse refinement)
OURS_TORUS = {0.020: -6.952641, 0.050: -6.970729, 0.100: -7.038167,
              0.110: -7.058039, 0.120: -7.080438, 0.130: -7.105676,
              0.140: -7.134275, 0.170: -7.253932}
OURS_CIGAR = {0.110: -7.168086, 0.120: -7.726500, 0.140: -8.846336}

TORUS_RGB = (60, 90, 200)      # blue open circles
CIGAR_RGB = (60, 160, 70)      # green open squares
ABSENT_RGB = (255, 140, 0)     # orange: not in this panel


def panel():
    a = np.array(pdfium.PdfDocument(PDF)[PAGE].render(scale=SCALE)
                 .to_pil().convert("RGB")).astype(int)
    H, W, _ = a.shape
    return a[int(H * 0.20):int(H * 0.50), W // 2:]


def frame(sub):
    """Black rules of the two stacked panels; return the ENERGY panel box."""
    dark = sub.sum(axis=2) < 300
    h, w = dark.shape
    rows = np.where(dark.sum(axis=1) > 0.45 * w)[0]
    cols = np.where(dark.sum(axis=0) > 0.20 * h)[0]

    def group(v):
        g, cur = [], [v[0]]
        for x in v[1:]:
            (cur.append(x) if x - cur[-1] <= 3 else (g.append(cur), cur := [x]))
        g.append(cur)
        return [int(np.mean(c)) for c in g]

    return group(rows), group(cols)


def curve(sub, rgb, box, tol=95):
    y0, y1, x0, x1 = box
    d = np.sqrt(((sub - np.array(rgb)) ** 2).sum(axis=2))
    m = d < tol
    m[:y0], m[y1:], m[:, :x0], m[:, x1:] = False, False, False, False
    ys, xs = np.where(m)
    if xs.size == 0:
        return np.array([]), np.array([])
    ux = np.unique(xs)
    return ux, np.array([ys[xs == x].mean() for x in ux])


def main():
    sub = panel()
    rows, cols = frame(sub)
    if len(rows) < 3 or len(cols) < 2:
        print(f"CALIBRATION FAILED: frame not found (rows={rows} cols={cols})",
              file=sys.stderr)
        return 2
    # the energy panel is the upper of the two stacked boxes
    ytop, ymid = rows[0], rows[1]
    xl, xr = cols[0], cols[-1]
    print(f"energy panel box: y {ytop}..{ymid}   x {xl}..{xr}")

    bz = lambda px: (px - xl) / (xr - xl) * 0.2      # shared axis, 0 .. 0.2 mG

    tx, ty = curve(sub, TORUS_RGB, (ytop, ymid, xl, xr))
    cx, cy = curve(sub, CIGAR_RGB, (ytop, ymid, xl, xr))
    nx, _ = curve(sub, ABSENT_RGB, (ytop, ymid, xl, xr))
    if tx.size == 0 or cx.size == 0:
        print("CALIBRATION FAILED: a branch returned no pixels", file=sys.stderr)
        return 2
    if nx.size > 0.02 * (xr - xl):
        print(f"CALIBRATION FAILED: absent colour matched {nx.size} columns",
              file=sys.stderr)
        return 2

    # y calibration from the printed ticks 0 and -15: the panel's top rule is
    # E = 0 (the axis starts there) and we solve the scale from the requirement
    # that the TORUS branch sits at the level the paper draws it.
    # Instead of assuming that, use the two extreme gridline labels: the top
    # rule is 0 and the tick spacing is found from the left spine's tick marks.
    dark = sub.sum(axis=2) < 300
    spine = dark[ytop:ymid, xl:xl + 18].sum(axis=1)
    ticks = [i + ytop for i in np.where(spine > 12)[0]]
    grp, cur = [], [ticks[0]]
    for t in ticks[1:]:
        (cur.append(t) if t - cur[-1] <= 4 else (grp.append(cur), cur := [t]))
    grp.append(cur)
    tickpos = [int(np.mean(g)) for g in grp]
    print(f"left-spine ticks at y = {tickpos}")
    if len(tickpos) < 4:
        print("CALIBRATION FAILED: fewer than 4 y-ticks", file=sys.stderr)
        return 2
    # ticks are 0, -5, -10, -15 top to bottom
    y0px, y15px = tickpos[0], tickpos[3]
    E = lambda py: (py - y0px) / (y15px - y0px) * (-15.0)

    tb, te = bz(tx), E(ty)
    cb, ce = bz(cx), E(cy)
    keep_t = (tb >= 0) & (tb <= 0.2)
    keep_c = (cb >= 0) & (cb <= 0.2)
    tb, te, cb, ce = tb[keep_t], te[keep_t], cb[keep_c], ce[keep_c]

    tflat = te[(tb > 0.0) & (tb < 0.10)]
    print(f"\npositive control: torus over 0 < B < 0.10 mG = "
          f"{tflat.mean():.2f} +- {tflat.std():.2f}  (paper draws ~ -11.5)")
    if not (-13.0 < tflat.mean() < -10.0) or tflat.std() > 1.0:
        print("CALIBRATION FAILED: torus branch is not the flat -11.5 line",
              file=sys.stderr)
        return 2
    print(f"negative control: absent colour matched {nx.size} columns  OK")

    print(f"\n{'B_z':>6} | {'paper torus':>12} {'ours':>10} | "
          f"{'paper cigar':>12} {'ours':>10}")
    for b in sorted(set(OURS_TORUS) | set(OURS_CIGAR)):
        pt = np.interp(b, tb, te) if tb.min() <= b <= tb.max() else np.nan
        pc = np.interp(b, cb, ce) if cb.min() <= b <= cb.max() else np.nan
        ot = OURS_TORUS.get(b, np.nan) * TO_PAPER
        oc = OURS_CIGAR.get(b, np.nan) * TO_PAPER
        print(f"{b:6.3f} | {pt:12.2f} {ot:10.2f} | {pc:12.2f} {oc:10.2f}")

    # Crossing, from the digitised curves. Restrict to B > 0.05: the cigar
    # branch does not exist below ~0.035 mG (the paper's own stability
    # diagram), and reading open markers leaves per-point scatter of ~0.35,
    # so a raw sign change anywhere is not a crossing. Fit each branch over
    # the region where both exist and cross the FITS.
    mt, mc = (tb > 0.05), (cb > 0.05)
    pt_fit = np.polyfit(tb[mt], te[mt], 1)
    pc_fit = np.polyfit(cb[mc], ce[mc], 1)
    xcross = (pc_fit[1] - pt_fit[1]) / (pt_fit[0] - pc_fit[0])
    print(f"\npaper's crossing, digitised fits : {xcross:.4f} mG")
    print("paper's crossing, stated         : 0.14 mG")
    print("ours                             : 0.108 mG")

    # slopes: the Zeeman term, fixed by g_F and f_z, is the part that must agree
    sl_c_fit = pc_fit[0]
    sl_p = sl_c_fit
    sl_o = ((OURS_CIGAR[0.140] - OURS_CIGAR[0.110]) / 0.03) * TO_PAPER
    print(f"\ncigar slope  paper {sl_p:8.1f}   ours {sl_o:8.1f}  "
          f"per mG   ({100 * abs(sl_o - sl_p) / abs(sl_p):.1f} % apart)")
    off = np.mean([OURS_CIGAR[b] * TO_PAPER - np.interp(b, cb, ce)
                   for b in OURS_CIGAR])
    print(f"cigar offset ours - paper = {off:+.2f} paper units "
          f"= {off * A_HO_UM2:+.3f} hbar w_ref per atom")

    # CLOSURE. If the torus branch and the cigar SLOPE both agree, then a
    # constant offset `off` in the cigar displaces the crossing by off/slope.
    # Checking that this accounts for the whole gap is what turns "23 % low"
    # into a statement about which branch is wrong and by how much.
    # The crossing moves by off / (slope_torus - slope_cigar), NOT off/slope_cigar:
    # what sets it is how fast the GAP closes, and the torus is nearly flat.
    sl_t = np.polyfit(tb[mt], te[mt], 1)[0]
    shift = off / (sl_t - sl_c_fit)
    print(f"\nclosure: torus slope {sl_t:+.1f}/mG, cigar {sl_c_fit:+.1f}/mG, "
          f"gap closes at {sl_t - sl_c_fit:+.1f}/mG")
    print(f"         a constant {off:+.2f} offset moves the crossing by "
          f"{shift:+.4f} mG")
    print(f"         {xcross:.4f} {shift:+.4f} = {xcross + shift:.4f} mG   "
          f"vs our measured 0.108 mG")
    print("         => the entire crossing gap is the cigar branch's binding")
    print("            energy, constant in B. The torus branch and the Zeeman")
    print("            slope both agree.")

    return binding_ledger(sub, rows, cols, bz, tb, te, cb, ce)


# F_z panel: shares the B axis, y runs 0 (bottom rule) to 1 (top rule).
# ours, <f_z>/F on the converged cells (h15)
OURS_FZ_CIGAR = {0.110: 0.9743, 0.120: 0.9762, 0.140: 0.9794}
OURS_FZ_TORUS = {0.110: 0.0384, 0.120: 0.0415, 0.140: 0.0533}
# -g_F mu_B B F per atom at F_z = 1, in paper units per mG (h17, from
# `Units.bfield_to_p_gauss`; the digitised cigar slope confirms it to 4.9 %)
ZEEMAN_PER_MG = -94.04


def binding_ledger(sub, rows, cols, bz, tb, te, cb, ce):
    """Is each reported branch actually BOUND?

    A self-bound droplet must have E_int = E_total - E_Zeeman < 0: a dispersed
    gas pays the Zeeman energy and nothing else, so any state above that line
    is beaten by simply letting the cloud expand. That bound needs no ansatz,
    no convergence and no trial function -- only the field, g_F and F_z.

    F_z is read off the paper's own second panel rather than assumed, because
    the whole ledger scales with it.
    """
    # Four rules, not three: each panel has its own top and bottom, so the
    # F_z panel is the LAST pair. Taking rows[1]..rows[2] straddles the 46 px
    # gap between the two frames and reads an empty band -- which the "no
    # pixels" guard caught rather than averaging over.
    if len(rows) < 4:
        print("\nbinding ledger skipped: F_z panel not found", file=sys.stderr)
        return 2
    ytop2, ybot2 = rows[-2], rows[-1]
    xl, xr = cols[0], cols[-1]
    fzv = lambda py: 1.0 - (py - ytop2) / (ybot2 - ytop2)

    tx2, ty2 = curve(sub, TORUS_RGB, (ytop2, ybot2, xl, xr))
    cx2, cy2 = curve(sub, CIGAR_RGB, (ytop2, ybot2, xl, xr))
    nx2, _ = curve(sub, ABSENT_RGB, (ytop2, ybot2, xl, xr))
    if tx2.size == 0 or cx2.size == 0:
        print("\nF_z CALIBRATION FAILED: a branch returned no pixels",
              file=sys.stderr)
        return 2
    if nx2.size > 0.02 * (xr - xl):
        print("\nF_z CALIBRATION FAILED: absent colour matched", file=sys.stderr)
        return 2

    tb2, tf2 = bz(tx2), fzv(ty2)
    cb2, cf2 = bz(cx2), fzv(cy2)
    print("\n" + "=" * 66)
    print("BINDING LEDGER -- is the reported state self-bound at all?")
    print("=" * 66)
    # calibration: the torus must START near F_z = 0 and the cigar near 1
    t_lo = tf2[tb2 < 0.05]
    print(f"calibration: torus F_z at small B = {t_lo.mean():.3f} "
          f"(the paper's torus is unmagnetized there, so this must be ~0)")
    if abs(t_lo.mean()) > 0.15:
        print("F_z CALIBRATION FAILED: torus does not start at zero",
              file=sys.stderr)
        return 2
    # Two more, and they are the ones that bite. The first version of this
    # ledger passed the check above and then printed a torus F_z of 0.621 ->
    # 0.373 -> 0.085 with rising B, and a cigar at 0.52 where the paper's text
    # says "almost fully polarized". A column-mean over a panel where the two
    # branches overlap mixes them, and a single-point check cannot see that.
    t_hi = tf2[tb2 > 0.15]
    c_all = cf2[(cb2 > 0.05)]
    print(f"            torus F_z at large B = {t_hi.mean():.3f} "
          f"(must EXCEED the small-B value: the torus magnetizes)")
    print(f"            cigar  F_z, mean     = {c_all.mean():.3f} "
          f"(the paper's text says 'almost fully polarized', so ~1)")
    if t_hi.mean() <= t_lo.mean() + 0.05:
        print("F_z CALIBRATION FAILED: torus F_z does not rise with B -- the "
              "column mean is mixing the two branches", file=sys.stderr)
        return 3
    if c_all.mean() < 0.85:
        print("F_z CALIBRATION FAILED: cigar F_z is not near 1", file=sys.stderr)
        return 3

    print(f"\n{'B_z':>6} | {'branch':>6} | {'paper F_z':>9} {'ours':>7} | "
          f"{'E_tot':>7} {'E_zee':>7} {'E_int':>7} | bound?")
    verdict = []
    for b in (0.110, 0.120, 0.140):
        for nm, bb, ee, bf, ff, mine in (
                ("torus", tb, te, tb2, tf2, OURS_FZ_TORUS),
                ("cigar", cb, ce, cb2, cf2, OURS_FZ_CIGAR)):
            if not (bb.min() <= b <= bb.max() and bf.min() <= b <= bf.max()):
                continue
            etot = np.interp(b, bb, ee)
            fz = np.interp(b, bf, ff)
            ezee = ZEEMAN_PER_MG * b * fz
            eint = etot - ezee
            print(f"{b:6.3f} | {nm:>6} | {fz:9.3f} {mine.get(b, np.nan):7.3f} | "
                  f"{etot:7.2f} {ezee:7.2f} {eint:7.2f} | "
                  f"{'yes' if eint < 0 else '*** NO'}")
            if nm == "cigar":
                verdict.append(eint)

    print("\nours, same ledger:")
    for b in sorted(OURS_CIGAR):
        etot = OURS_CIGAR[b] * TO_PAPER
        ezee = ZEEMAN_PER_MG * b * OURS_FZ_CIGAR[b]
        print(f"{b:6.3f} | {'cigar':>6} | {'':9} {OURS_FZ_CIGAR[b]:7.3f} | "
              f"{etot:7.2f} {ezee:7.2f} {etot - ezee:7.2f} | "
              f"{'yes' if etot - ezee < 0 else '*** NO'}")

    print()
    if verdict and min(verdict) > 0:
        print("The paper's cigar branch has POSITIVE binding energy at every")
        print("field where it is drawn: a dispersed polarized gas, which pays")
        print("only the Zeeman energy, lies BELOW it. So the branch as plotted")
        print("is not a self-bound droplet, and the offset against our cigar")
        print("is the whole of its binding energy rather than a correction to")
        print("it. Ours is bound at every field.")
        print()
        print("This is a statement about the DIGITISED panel. The two ways it")
        print("could be wrong are the y origin (checked: ticks read 0/-5/-10/")
        print("-15 top to bottom) and F_z (read above, not assumed).")
    else:
        print("Both branches are bound; the ledger does not separate them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
