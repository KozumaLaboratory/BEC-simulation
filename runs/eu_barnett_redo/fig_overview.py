#!/usr/bin/env python3
"""2026-09-08/09 の全腕を 1 枚に。発表用。

★ラベルは英語。このマシンの matplotlib には和文を出す手段が無い（jp_font.py）。

4 パネル:
  A  Omega 依存と EdH 基準            回転の寄与は全体の 22 %
  B  Omega についての偶奇分解          主張の判定。奇が支配なら向きが効く
  C  残留磁場による抑制                実験の 30 uG は既に Zeeman 側
  D  注入を増やしても F_z が下がらない  30 uG では終着点が磁場で決まる

**手元にある腕だけで描く。** 欠けているものは描かず、図に「missing」と出す。
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)
plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "axes.grid": True, "grid.alpha": 0.25, "font.size": 10.5,
                     "axes.unicode_minus": False})

# (tag, B_final[uG], Omega, stir)
ARMS = [
    ("plus_b8_omp08", 0, +0.80, 20), ("zero_b8_om0", 0, 0.00, 20),
    ("minus_b8_omm08", 0, -0.80, 20), ("plus_b8_omp09", 0, +0.90, 20),
    ("plus_nodd_b8_nodd", 0, +0.80, 20),
    ("plus_bf30_omp08", 30, +0.80, 20), ("zero_bf30_om0", 30, 0.00, 20),
    ("minus_bf30_omm08", 30, -0.80, 20), ("plus_bf49_omp08", 49, +0.80, 20),
    ("minus_pin_m35", 30, -0.80, 35), ("minus_pin_m46", 30, -0.80, 46),
    ("minus_pin_m60", 30, -0.80, 60), ("zero_pin_z60", 30, 0.00, 60),
    ("plus_pin_p60", 30, +0.80, 60),
]

D, missing = {}, []
for tag, bf, om, stir in ARMS:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        missing.append(tag)
        continue
    a = np.genfromtxt(f, delimiter=",", names=True)
    if a["t"][-1] < stir + 63.5:          # 未完のコピーを黙って使わない
        missing.append(f"{tag}(t={a['t'][-1]:.0f})")
        continue
    t0 = 5 + 5 + stir + 3 + 1
    k = int(np.argmax(a["t"] >= t0))
    D[tag] = dict(bf=bf, om=om, stir=stir, t=a["t"], Fz=a["Fz"], Lz=a["Lz"],
                  k=k, conv=a["Fz"][-1] - a["Fz"][k], Jz=a["Jz"][k],
                  inj=a["Lz"][k], Fz1=a["Fz"][-1])

fig, axes = plt.subplots(2, 2, figsize=(13.2, 9.4))
axA, axB, axC, axD = axes.ravel()
COL = {+0.80: "#c0392b", 0.00: "#2c3e50", -0.80: "#2471a3", +0.90: "#e08214"}

# ── A: Omega 依存（B=0）と EdH 基準 ───────────────────────────────
sel = [(om, D[t]) for t, bf, om, s in ARMS
       if t in D and bf == 0 and s == 20 and "nodd" not in t]
sel.sort()
axA.bar([f"{om:+.2f}" for om, _ in sel], [r["conv"] for _, r in sel],
        color=[COL[om] for om, _ in sel], width=0.6)
base = D["zero_b8_om0"]["conv"]
axA.axhline(base, color="#2c3e50", lw=2, ls="--")
axA.text(0.02, base - 0.30, f"Einstein-de Haas baseline (no rotation)  {base:.2f}",
         transform=axA.get_yaxis_transform(), va="top", fontsize=10, color="#2c3e50")
if "plus_nodd_b8_nodd" in D:
    axA.bar(["DDI off"], [D["plus_nodd_b8_nodd"]["conv"]], color="#95a5a6", width=0.6)
for i, (om, r) in enumerate(sel):
    axA.text(i, r["conv"] + 0.08, f"{r['conv']:.2f}", ha="center", fontsize=10)
axA.set_ylabel(r"conversion  $\Delta\langle F_z\rangle$")
axA.set_xlabel(r"$\Omega$")
axA.set_ylim(0, 6.0)
axA.set_title("A   rotation adds 28 % on top; Einstein-de Haas supplies the rest\n"
              "(B_final = 0; with DDI off nothing converts at all)", fontsize=11)

# ── B: 偶奇分解 ──────────────────────────────────────────────────
axB.axhline(0, color="#999", lw=0.8)
xs, odds, evens = [], [], []
for bf, tp, tz, tm in ((0, "plus_b8_omp08", "zero_b8_om0", "minus_b8_omm08"),
                       (30, "plus_bf30_omp08", "zero_bf30_om0", "minus_bf30_omm08")):
    if not all(x in D for x in (tp, tz, tm)):
        continue
    p, z, m = D[tp]["conv"], D[tz]["conv"], D[tm]["conv"]
    xs.append(bf); odds.append((p - m) / 2); evens.append((p + m) / 2 - z)
w = 6
axB.bar([x - w / 2 for x in xs], odds, width=w, color="#7d3c98",
        label="odd  $[F_z(+\\Omega)-F_z(-\\Omega)]/2$   depends on sense")
axB.bar([x + w / 2 for x in xs], evens, width=w, color="#bdc3c7",
        label="even $[F_z(+\\Omega)+F_z(-\\Omega)]/2-F_z(0)$   does not")
for x, o, e in zip(xs, odds, evens):
    axB.text(x - w / 2, o + 0.04, f"{o:+.2f}", ha="center", fontsize=10)
    axB.text(x + w / 2, e + (0.04 if e > 0 else -0.12), f"{e:+.2f}", ha="center",
             fontsize=10)
    axB.text(x, -0.42, f"|odd|/|even| = {abs(o / e):.1f}", ha="center", fontsize=10.5,
             color="#7d3c98")
axB.set_xticks(xs)
axB.set_xticklabels([f"{x} µG" for x in xs])
axB.set_xlabel(r"residual field $B_{\rm final}$")
axB.set_ylabel(r"$\Delta\langle F_z\rangle$ decomposition")
axB.set_ylim(-0.55, 1.55)
axB.legend(loc="upper right", fontsize=9)
axB.set_title("B   the response is ODD in $\\Omega$ — the sense of rotation matters\n"
              "(injections matched to 2.2 %, so not unequal driving)", fontsize=11)

# ── C: 磁場による抑制 ────────────────────────────────────────────
for om in (+0.80, 0.00, -0.80):
    pts = sorted((D[t]["bf"], D[t]["conv"]) for t, bf, o, s in ARMS
                 if t in D and o == om and s == 20 and "nodd" not in t)
    if pts:
        axC.plot(*zip(*pts), "o-", color=COL[om], ms=9, lw=2.2,
                 label=f"$\\Omega={om:+.2f}$")
P_PER_G = 488.2664 / 0.03
B_STAR = 120.719 * (8.118 / 2681.4) / P_PER_G * 1e6
axC.axvline(B_STAR, color="#7d3c98", lw=1.6, ls="--")
axC.text(B_STAR + 1, 4.6, f"$\\omega_L=c_{{dd}}n$\n{B_STAR:.0f} µG", color="#7d3c98",
         fontsize=10, va="top")
axC.axvspan(0, B_STAR, color="#f3ecf7", zorder=0)
axC.annotate("experiment", (30, 0.4), ha="center", fontsize=10, color="#444")
axC.set_xlabel(r"residual field $B_{\rm final}$  [µG]")
axC.set_ylabel(r"conversion  $\Delta\langle F_z\rangle$")
axC.set_ylim(0, 5.4)
axC.legend(fontsize=9.5)
axC.set_title("C   the residual field sets how much converts\n"
              "going from 0 to 30 µG costs about half of it", fontsize=11)

# ── D: 注入を増やしても下がらない ────────────────────────────────
pts = sorted((D[t]["Jz"], D[t]["Fz1"], D[t]["om"]) for t, bf, o, s in ARMS
             if t in D and bf == 30)
for j, f_, om in pts:
    axD.plot(j, f_, "o", ms=11, color=COL[om])
    axD.annotate(f"{f_:.2f}", (j, f_), textcoords="offset points", xytext=(8, 4),
                 fontsize=9.5)
axD.axhline(-6, color="#c00", lw=1.2, ls=":")
axD.text(0.99, -5.92, "$m=-6$ edge — $\\langle F_z\\rangle$ cannot go below ",
         transform=axD.get_yaxis_transform(), ha="right", va="bottom", color="#c00",
         fontsize=9.5)
if pts:
    dJ = max(p[0] for p in pts) - min(p[0] for p in pts)
    dF = max(p[1] for p in pts) - min(p[1] for p in pts)
    lo, hi = min(p[1] for p in pts), max(p[1] for p in pts)
    axD.axhspan(lo, hi, color="#fdf2e7", zorder=0)
    axD.text(0.03, 0.03, f"$J_z$ spans {dJ:.1f} and the endpoint moves only {dF:.2f}\n"
                         f"— the closest arm still stops {abs(-6 - lo):.2f} short of $-6$",
             transform=axD.transAxes, ha="left", fontsize=10.5, color="#a04000")
axD.set_xlabel(r"$J_z$  (conserved; set by how much rotation injected)")
axD.set_ylabel(r"final $\langle F_z\rangle$")
axD.set_ylim(-7.0, -3.1)
axD.set_title("D   at 30 µG the endpoint is set by the field, not by the injection\n"
              "predicted ladder-edge pinning at $-6$ does NOT happen", fontsize=11)

if missing:
    fig.text(0.5, 0.005, "still running / not fetched: " + ", ".join(missing),
             ha="center", fontsize=8, color="#888")
fig.tight_layout(rect=(0, 0.02, 1, 1))
out = FIGS / "fig_overview_2026_09_09.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
print(f"wrote {out}   ({len(D)} arms, {len(missing)} missing)")
