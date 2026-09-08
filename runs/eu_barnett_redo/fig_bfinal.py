#!/usr/bin/env python3
"""残留磁場が変換をどれだけ殺すか、そしてそれが速さでなく行き先の問題であること。

左: ΔF_z 対 B_final。3 つの Ω。
右: クエンチ中の F_z(t)。**B=0 はまだ動き、30 µG は平らになっている** ──
    「長く回せば追いつく」ではないことの直接の証拠。

★閾値は μ ではなく **c_dd n** と比べる。μ は c₀（スピンに依らない項）が支配する
  ので、スピン混合とは無関係。私は最初 ω_L/μ = 0.06 を見て「効かない」と判断し、
  実測で 2 倍以上効いていた。正しい比は ω_L/(c_dd n) = 1.34。

使い方: python3 runs/eu_barnett_redo/fig_bfinal.py
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)

# ★ラベルは英語。このマシンの matplotlib には和文を出す手段が無い
# （Noto CJK は .ttc で FreeType が拒否、残るのはコーディング用の等幅だけ。
#  詳細は jp_font.py）。物理の図では英語ラベルが標準なので、そちらに寄せる。
plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "axes.grid": True, "grid.alpha": 0.25, "font.size": 11,
                     "axes.unicode_minus": False})

# (B_final[uG], Omega, tag)
ARMS = [
    (0, +0.80, "plus_b8_omp08"), (0, 0.00, "zero_b8_om0"), (0, -0.80, "minus_b8_omm08"),
    (30, +0.80, "plus_bf30_omp08"), (30, 0.00, "zero_bf30_om0"),
    (30, -0.80, "minus_bf30_omm08"),
    (49, +0.80, "plus_bf49_omp08"),
]
T_LEDGER = 34.0   # 磁場が軸方向になる時刻（tilt5+spinup5+stir20+rotback3+fd1）

d = {}
for bf, om, tag in ARMS:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        raise SystemExit(f"{f} が無い")
    a = np.genfromtxt(f, delimiter=",", names=True)
    if a["t"][-1] < 83.5:          # 未完のコピーを黙って使わない
        raise SystemExit(f"{tag} が t={a['t'][-1]:.0f} までしか無い（84 必要）")
    k = int(np.argmax(a["t"] >= T_LEDGER))
    d[(bf, om)] = dict(t=a["t"], Fz=a["Fz"], k=k, conv=a["Fz"][-1] - a["Fz"][k])

# c_dd n と釣り合う磁場。p/B は走行ログの実測 (p=-488.2664 at B=0.03 G)
P_PER_G = 488.2664 / 0.03
CDD_N = 120.719 * (8.118 / 2681.4)        # c_dd * (mu/c0) ≈ 密度を消した尺度
B_STAR = CDD_N / P_PER_G * 1e6            # µG

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.4, 5.2))

# ── 左: ΔF_z 対 B_final ──────────────────────────────────────────
STY = {+0.80: ("#c0392b", "o", "$\\Omega=+0.80$"), 0.00: ("#2c3e50", "s", "$\\Omega=0$  (EdH only)"),
       -0.80: ("#2471a3", "^", "$\\Omega=-0.80$")}
for om, (col, mk, lab) in STY.items():
    xs = sorted(bf for (bf, o) in d if o == om)
    ys = [d[(bf, om)]["conv"] for bf in xs]
    ax1.plot(xs, ys, mk + "-", color=col, ms=10, lw=2.2, label=lab)
    for x, y in zip(xs, ys):
        ax1.annotate(f"{y:.2f}", (x, y), textcoords="offset points", xytext=(7, 5),
                     fontsize=9.5, color=col)
ax1.axvline(B_STAR, color="#7d3c98", lw=1.6, ls="--")
ax1.text(B_STAR + 1.2, 4.7, f"$\\omega_L = c_{{dd}}n$\n{B_STAR:.0f} µG",
         color="#7d3c98", fontsize=10, va="top")
ax1.axvspan(0, B_STAR, color="#f3ecf7", zorder=0)
ax1.text(B_STAR / 2, 0.15, "DDI wins", ha="center", color="#7d3c98", fontsize=10)
ax1.text((B_STAR + 52) / 2, 0.15, "Zeeman wins", ha="center", color="#888", fontsize=10)
ax1.set_xlim(-3, 58)
ax1.set_ylim(0, 5.4)
ax1.set_xlabel("residual field  $B_{\\rm final}$   [µG]")
ax1.set_ylabel(r"conversion   $\Delta\langle F_z\rangle$")
ax1.set_title("Residual field suppresses the conversion\nthe experiment sits at 30 µG, already on the Zeeman side", fontsize=12)
ax1.legend(loc="upper right", fontsize=10)
ax1.annotate("experiment\n30 µG", (30, 0.55), ha="center", fontsize=10, color="#444")

# ── 右: クエンチ中の F_z(t) ──────────────────────────────────────
for om, (col, _mk, lab) in STY.items():
    for bf, ls, a in ((0, "-", 1.0), (30, "--", 0.85)):
        if (bf, om) not in d:
            continue
        r = d[(bf, om)]
        q = r["t"] >= T_LEDGER
        ax2.plot(r["t"][q], r["Fz"][q], ls, color=col, lw=2.2, alpha=a,
                 label=f"{lab.split('（')[0]}  {bf} µG")
ax2.axhline(-6, color="#c00", lw=1.0, ls=":")
ax2.text(84, -6.05, "$m=-6$ edge ", color="#c00", ha="right", va="top", fontsize=9)
ax2.set_xlabel(r"$t\ \omega_{\rm ref}$")
ax2.set_ylabel(r"$\langle F_z\rangle$")
ax2.set_title("Not a rate effect: where it ends changes\nsolid $B=0$ still rising, dashed 30 µG flat",
              fontsize=12)
ax2.legend(loc="lower right", fontsize=8, ncol=2, framealpha=0.95)
ax2.set_xlim(T_LEDGER, 84)

# 後半 1/3 の変化量を右パネルに数値で
txt = []
for om, (_c, _m, lab) in STY.items():
    for bf in (0, 30):
        if (bf, om) not in d:
            continue
        r = d[(bf, om)]
        q = r["t"] >= 44
        ff = r["Fz"][q]
        n = len(ff) // 3
        txt.append(f"{lab.split('（')[0]} {bf:>3d}uG : {ff[2*n:].mean()-ff[n:2*n].mean():+.3f}")
# ★等幅にしない（DejaVu Sans Mono に和文が無く豆腐になる）。凡例と重ならない位置へ。
ax2.text(0.02, 0.97, "late third − middle third of the quench\n" + "\n".join(txt),
         transform=ax2.transAxes, fontsize=8.5, va="top",
         bbox=dict(fc="white", ec="#bbb", alpha=0.93))

fig.tight_layout()
out = FIGS / "fig_bfinal_suppression.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
print(f"wrote {out}")
print(f"閾値 omega_L = c_dd n  ->  B = {B_STAR:.1f} uG")
for om in (+0.80, 0.00, -0.80):
    s = [(bf, d[(bf, om)]["conv"]) for bf in sorted(b for (b, o) in d if o == om)]
    print(f"  Omega {om:+.2f}: " + "  ".join(f"{b}µG {c:.3f}" for b, c in s))
