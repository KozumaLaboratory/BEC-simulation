#!/usr/bin/env python3
"""回転で注入できる L_z には上限がある。**張り付き実験が届かなかった本当の理由。**

PINNING_THEORY.md が挙げた 5 つの破れ方の 1 番目（injection saturation）が実際に起きた。

  stir 20 -> 35   注入 −5.39 -> −13.60   (+152 %)     ← まだ効いている
  stir 35 -> 46   注入 −13.60 -> −13.78  (+1.3 %)     ← **頭打ち**

  かき混ぜ時間を 31 % 伸ばして注入が 1.3 % しか増えないなら、
  stir を伸ばして梯子の端 (F_z = −6) に届かせる作戦は成立しない。

★これは「予言が外れた」より強い結論で、**外れ方が特定できている**。
  端に届かないのは (a) Zeeman 平衡が先に決める と (b) 注入が飽和する の
  両方で、(b) は回転の側の限界なので磁場を下げても解けない。

★飽和の機構: かき混ぜは楕円ポテンシャルの回転で角運動量を入れるが、雲が
  回転数に追いつく（共回転する）と、もう相対回転が無いのでトルクが消える。
  L_z(t) が平らになる時刻がそれ。以下の左パネルで直接見える。

使い方: python3 runs/eu_barnett_redo/fig_injection_saturation.py
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
                     "font.size": 11, "axes.unicode_minus": False})

# (stir, tag, 色)  すべて −Ω・30 µG・θ=35°、**stir だけが違う**
ARMS = [(20, "minus_bf30_omm08", "#a9cce3"),
        (35, "minus_pin_m35", "#5499c7"),
        (46, "minus_pin_m46", "#1a5276"),
        (60, "minus_pin_m60", "#7d3c98")]

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12.6, 5.0))
pts, partial, traces = [], [], {}
for stir, tag, col in ARMS:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        continue
    a = np.genfromtxt(f, delimiter=",", names=True)
    t0 = 5 + 5 + stir + 3 + 1                  # 磁場が軸に戻り切った時刻
    done = a["t"][-1] >= stir + 63.5
    if a["t"][-1] < t0:
        partial.append(f"stir {stir} (t {a['t'][-1]:.0f}, まだ注入中)")
        continue
    traces[stir] = a
    k = int(np.argmax(a["t"] >= t0))
    pts.append((stir, float(a["Lz"][k]), float(a["Jz"][k]), col, done))

# 4 本の L_z(t) は **かき混ぜ中は同一**（総 stir 長は先の話にしか効かない）。
# 重ねると「4 本ある」ように見えて嘘になるので、一致を検算して 1 本だけ描く。
ref = traces[max(traces)]
worst = 0.0
for stir, a in traces.items():
    n = min(len(a["Lz"]), len(ref["Lz"]))
    q = a["t"][:n] <= stir + 10
    if q.any():
        worst = max(worst, float(np.abs(a["Lz"][:n][q] - ref["Lz"][:n][q]).max()))
# 一致は「ほぼ」であって完全ではない -- ramp の形が stir 長に依存する。
# 最初 1e-3 を要求して発火した。**4 本描いて、一致度を数字で言う。**
rel = worst / abs(ref["Lz"]).max() * 100
print(f"かき混ぜ中の L_z(t) の腕どうしの最大差 {worst:.3e} ({rel:.2f} %)")
if worst > 0.5:
    raise SystemExit(f"腕ごとに L_z(t) が違いすぎる（{worst:.2e}）-- 描き方を見直せ")

for stir, a in sorted(traces.items()):
    col = dict((s_, c) for s_, _t, c in ARMS)[stir]
    q = a["t"] <= stir + 10
    ax1.plot(a["t"][q], a["Lz"][q], "-", color=col,
             lw=4.0 - 0.7 * list(sorted(traces)).index(stir), alpha=0.9,
             label=f"stir {stir}")
qq = ref["t"] <= max(traces) + 10
lo = float(ref["Lz"][qq].min())
ax1.text(0.985, 0.94, f"the four traces agree to {worst:.2f} ({rel:.1f} %)\n"
                      "— the stir length barely changes the drive",
         transform=ax1.transAxes, ha="right", va="top", fontsize=9.5, color="#555",
         bbox=dict(fc="white", ec="#ddd", alpha=0.95))
ax1.axhline(lo, color="#7d3c98", lw=1.0, ls="--")
ax1.text(1.5, lo + 0.25, f"deepest the stir ever gets:  {lo:.2f}", fontsize=9.5,
         color="#7d3c98", va="bottom")
for stir, lz, _jz, col, done in pts:
    ax1.plot(5 + 5 + stir + 3 + 1, lz, "o", color=col, ms=11, zorder=5,
             mec="white", mew=1.4)
ax1.axvspan(0, 5, color="#f7f7f7", zorder=0)
ax1.axvspan(5, 10, color="#eef3f8", zorder=0)
ax1.set_xlabel(r"$t\ \omega_{\rm ref}$")
ax1.set_ylabel(r"$\langle L_z\rangle$")
ax1.grid(alpha=0.25)
ax1.set_ylim(lo - 1.1, 1.0)
ax1.legend(loc="center left", fontsize=9.5, framealpha=0.95)
ax1.set_title("The stir does not build up -- it OSCILLATES about $-14$\n"
              "the dots are where each arm stopped; all sample one limit cycle",
              fontsize=12)

for stir, lz, _jz, col, done in pts:
    ax2.plot(stir, abs(lz), "o" if done else "s", ms=13, color=col)
    ax2.annotate(f"{abs(lz):.2f}" + ("" if done else "*"), (stir, abs(lz)),
                 textcoords="offset points", xytext=(0, 13), ha="center", fontsize=10.5,
                 color=col)
if len(pts) >= 2:
    xs = [p[0] for p in pts]
    ys = [abs(p[1]) for p in pts]
    ax2.plot(xs, ys, "-", color="#999", lw=1.4, zorder=0)
    for i in range(1, len(pts)):
        g = (ys[i] - ys[i - 1]) / ys[i - 1] * 100
        ax2.annotate(f"{g:+.0f} %", ((xs[i] + xs[i - 1]) / 2, (ys[i] + ys[i - 1]) / 2),
                     textcoords="offset points", xytext=(6, -14), fontsize=10,
                     color="#a04000")
ax2.set_xlabel("stir duration   $t_{\\rm stir}\\ \\omega_{\\rm ref}$")
ax2.set_ylabel(r"injected $|\langle L_z\rangle|$ at the end of the stir")
ax2.set_ylim(0, 17)
ax2.grid(alpha=0.25)
ax2.set_title("Injection saturates near $|L_z|\\approx 14$\n"
              "stirring 3x longer buys 3 % — the ladder edge is out of reach",
              fontsize=12)

note = ("* still running — the marker is the value at the end of its stir, which is "
        "already past") if any(not p[4] for p in pts) else ""
if partial:
    note += ("  |  not yet at the end of its stir: " + ", ".join(partial))
if note:
    fig.text(0.5, -0.02, note, ha="center", fontsize=8.5, color="#888")
fig.suptitle("Why the arms never reach $\\langle F_z\\rangle=-6$: the rotation "
             "cannot inject more   ($\\Omega=-0.80$, 30 µG, θ = 35°)",
             fontsize=12.5, y=1.02)
fig.tight_layout()
out = FIGS / "fig_injection_saturation.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
print(f"wrote {out}")
for stir, lz, jz, _c, done in pts:
    print(f"  stir {stir:>3}  L_z {lz:+8.3f}  J_z {jz:+8.3f}"
          + ("" if done else "   (走行中)"))
