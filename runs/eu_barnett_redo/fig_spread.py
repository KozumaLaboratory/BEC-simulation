#!/usr/bin/env python3
"""局所偏極 m(r) = f_z/n の**ばらつき**。張り付きと拡散を分ける唯一の量。

⟨F_z⟩ は雲全体の平均なので、「一様に −5」と「半分が −6 で半分が −4」を
区別できない。**割って、空間分布の幅を見て初めて区別できる。**

  spread = sqrt( Σ n (m − m̄)² / Σ n )      密度で重みづけ

  −Ω  一様に下に寄る   spread 小
   0  中間
  +Ω  場所ごとに違う m  spread 大

★判定（後半 1/3 の平均、窓内 sd を誤差として）:
    +Ω  2.80 ± 0.06     0  1.37 ± 0.26     −Ω  1.20 ± 0.08
  **+Ω だけが分離している。−Ω と 0 は差 0.17 に対し誤差 0.26 で、区別できない。**
  奇 +0.80 / 偶 +0.63 ── ΔF_z（奇/偶 = 3.3）と違い、**ここは奇が支配的ではない**。
  ⇒ この量は「向きが効く」の証拠には**ならない**。言えるのは
     「+Ω は m をばらけさせる」だけ。

★これを終端 1 点で読むと奇/偶 = 6.4 に見えるが、それは Ω=0 の腕の振動を
  拾っているだけ（1.83 対 窓平均 1.37）。**振動する量を 1 点で読むな。**

★実験で見えるか: Stern-Gerlach で m ごとに分ければ、spread は **m 分布の幅**
  として直接出る。⟨F_z⟩ は 1 次モーメント、spread は 2 次モーメント。
  どちらも同じ吸収像から取れる。

使い方: python3 runs/eu_barnett_redo/fig_spread.py
"""
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)
plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "font.size": 11, "axes.unicode_minus": False})

ARMS = [(r"$\Omega=+0.80$", "plus_sl_omp08", "#c0392b", -3.375),
        (r"$\Omega=0$", "zero_sl_om0", "#2c3e50", -4.345),
        (r"$\Omega=-0.80$", "minus_sl_omm08", "#2471a3", -4.868)]
M = np.arange(6, -7, -1)
T_LEDGER = 34.0

res = {}
for _n, tag, _c, want in ARMS:
    a = np.genfromtxt(DATA / f"ledger_{tag}_prod_box35.csv", delimiter=",", names=True)
    if abs(a["Fz"][-1] - want) > 0.01:          # 腕の取り違えをここで殺す
        raise SystemExit(f"{tag}: F_z 終端 {a['Fz'][-1]:.3f} != {want}")
    f = h5py.File(DATA / f"slices_{tag}_prod_box35.jld2", "r")
    ks = sorted(k for k in f if k.startswith("slice_"))
    t, mb, sd = [], [], []
    for k in ks:
        r = f[k]["psi"][()]
        n = np.abs(r["re"].astype(float) + 1j * r["im"].astype(float)) ** 2
        w, fz = n.sum(0), (M[:, None, None] * n).sum(0)
        g = w > 1e-3 * w.max()                  # 真空を平均に入れない
        m, ww = fz[g] / w[g], w[g]
        bar = (ww * m).sum() / ww.sum()
        t.append(float(f[k]["t"][()]))
        mb.append(bar)
        sd.append(np.sqrt((ww * (m - bar) ** 2).sum() / ww.sum()))
    f.close()
    res[tag] = (np.array(t), np.array(mb), np.array(sd))

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.6, 5.0))

for name, tag, col, _w in ARMS:
    t, mb, sd = res[tag]
    q = t >= T_LEDGER - 4
    ax1.plot(t[q], sd[q], "o-", color=col, ms=5, lw=2.2, label=name)
    ax1.fill_between(t[q], 0, sd[q], color=col, alpha=0.07)
# ★終端 1 点で語らない。Omega=0 の腕は振動していて、t<62 では順序が入れ替わる。
#   後半 1/3 の平均と、その窓内の標準偏差を誤差として出す。
T_AVG = 34.0 + (84.0 - 34.0) * 2 / 3
ax1.axvspan(T_AVG, 84, color="#f2f2f2", zorder=0)
ax1.text((T_AVG + 84) / 2, 3.08, "averaging window", ha="center", fontsize=9,
         color="#777", va="top")
avg = {}
for _n, tag, _c, _w in ARMS:
    t, mb, sd = res[tag]
    q = t >= T_AVG
    avg[tag] = (sd[q].mean(), sd[q].std(), mb[q].mean(), mb[q].std())
ax1.axvline(T_LEDGER, color="#999", lw=1.0, ls="--")
ax1.text(T_LEDGER + 0.6, 0.06, "field back on axis", fontsize=9, color="#666")
ax1.set_xlabel(r"$t\ \omega_{\rm ref}$")
ax1.set_ylabel(r"spread of local $m$   $\sqrt{\langle (m-\bar m)^2\rangle_n}$")
ax1.set_xlim(T_LEDGER - 4, 84)
ax1.set_ylim(0, 3.2)
ax1.grid(alpha=0.25)
ax1.legend(loc="upper left", fontsize=10)
ax1.text(0.985, 0.60, "last third:\n" + "\n".join(
    f"{n.replace('$','').replace(chr(92)+'Omega','Om')}   {avg[t][0]:.2f} ± {avg[t][1]:.2f}"
    for n, t, _c, _w in ARMS), transform=ax1.transAxes, ha="right", va="top",
    fontsize=9.5, bbox=dict(fc="white", ec="#ccc", alpha=0.95))
ax1.set_title("How uniform the magnetisation is\n"
              r"$+\Omega$ tears the $m$ apart; $-\Omega$ and $0$ are not resolved",
              fontsize=12)

# 右: 終端の (mean, spread) 平面。**張り付きは左下の隅**
OFF = {"plus_sl_omp08": (-14, 22, "right"), "zero_sl_om0": (4, 28, "left"),
       "minus_sl_omm08": (-6, -30, "right")}
for name, tag, col, _w in ARMS:
    sdm, sde, mbm, mbe = avg[tag]
    ax2.errorbar(mbm, sdm, xerr=mbe, yerr=sde, fmt="o", ms=15, color=col,
                 ecolor=col, elinewidth=1.6, capsize=4)
    dx, dy, ha = OFF[tag]
    ax2.annotate(f"{name}\n$\\bar m$ {mbm:+.2f}±{mbe:.2f}\nspread {sdm:.2f}±{sde:.2f}",
                 (mbm, sdm), textcoords="offset points", xytext=(dx, dy),
                 fontsize=9.5, color=col, ha=ha, va="center")
ax2.plot(-6, 0, "*", ms=22, color="#c00")
ax2.annotate("perfect pinning\nall atoms in $m=-6$", (-6, 0),
             textcoords="offset points", xytext=(14, 10), fontsize=10, color="#c00")
mbs = [avg[t][2] for _n, t, _c, _w in ARMS]
sds = [avg[t][0] for _n, t, _c, _w in ARMS]
o = np.argsort(mbs)
ax2.plot(np.array(mbs)[o], np.array(sds)[o], "-", color="#999", lw=1.2, zorder=0)
ax2.set_xlabel(r"mean local $m$")
ax2.set_ylabel(r"spread of local $m$")
ax2.set_xlim(-6.6, -2.7)
ax2.set_ylim(-0.45, 3.7)
ax2.grid(alpha=0.25)
ax2.set_title("No arm reaches the pinned corner\n"
              r"the MEAN separates all three; the SPREAD only isolates $+\Omega$",
              fontsize=12)

fig.suptitle("Local polarisation at 30 µG — separates $+\\Omega$ cleanly, "
             "but does NOT separate $-\\Omega$ from $0$", fontsize=12.5, y=1.02)
fig.tight_layout()
out = FIGS / "fig_spread_2026_09_09.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
print(f"wrote {out}")
print(f"後半 1/3 (t >= {T_AVG:.0f}) の平均 ± その窓内の標準偏差")
for name, tag, _c, _w in ARMS:
    sdm, sde, mbm, mbe = avg[tag]
    print(f"  {name:<18} mean m {mbm:+.3f} ± {mbe:.3f}   spread {sdm:.3f} ± {sde:.3f}")
p, z, m = (avg[t][0] for _n, t, _c, _w in ARMS)
print(f"  spread の奇成分 (p−m)/2 = {(p - m) / 2:+.3f}   "
      f"偶成分 (p+m)/2 − z = {(p + m) / 2 - z:+.3f}")
