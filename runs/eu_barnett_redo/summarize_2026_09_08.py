#!/usr/bin/env python3
"""2026-09-08 の投入を 1 枚にまとめる。**手元にある腕だけで走る。**

まだ走っている腕は「未完」と表示して飛ばす。**欠けているものを黙って埋めない** ──
表が埋まっていることと測定が済んでいることを取り違えないため。

3 つのパネル:
  A  Omega 依存（B_final = 0 と 30 uG を重ねる）と EdH 基準
  B  Omega についての偶奇分解。**主張の判定**
  C  F_z(終) 対 J_z。**梯子の端への飽和が折れとして見える場所**

使い方:
  python3 runs/eu_barnett_redo/summarize_2026_09_08.py          # 表だけ
  python3 runs/eu_barnett_redo/summarize_2026_09_08.py --fig    # 図も
"""
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"

# (表示名, tag, B_final[uG], Omega, stir)
ARMS = [
    ("B=0   −Ω",   "minus_b8_omm08",   0,   -0.80, 20),
    ("B=0    0",   "zero_b8_om0",      0,    0.00, 20),
    ("B=0   +Ω",   "plus_b8_omp08",    0,   +0.80, 20),
    ("B=0   +0.9", "plus_b8_omp09",    0,   +0.90, 20),
    ("B=0   DDIoff", "plus_nodd_b8_nodd", 0, +0.80, 20),
    ("B=0   dt/2", "plus_b8_dt5e4",    0,   +0.80, 20),
    ("30uG  −Ω",   "minus_bf30_omm08", 30,  -0.80, 20),
    ("30uG   0",   "zero_bf30_om0",    30,   0.00, 20),
    ("30uG  +Ω",   "plus_bf30_omp08",  30,  +0.80, 20),
    ("49uG  +Ω",   "plus_bf49_omp08",  49,  +0.80, 20),
    ("30uG  −Ω s35", "minus_pin_m35",  30,  -0.80, 35),
    ("30uG  −Ω s46", "minus_pin_m46",  30,  -0.80, 46),
    ("30uG  −Ω s60", "minus_pin_m60",  30,  -0.80, 60),
    ("30uG   0 s60", "zero_pin_z60",   30,   0.00, 60),
    ("30uG  +Ω s60", "plus_pin_p60",   30,  +0.80, 60),
]

# 台帳の窓は磁場が軸方向になってから。stir + tilt(5) + spinup(5) + rampdown(4)
def ledger_start(stir):
    return 5 + 5 + stir + 3 + 1


rows, missing = [], []
for name, tag, bf, om, stir in ARMS:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        missing.append((name, tag))
        continue
    d = np.genfromtxt(f, delimiter=",", names=True)
    t, Fz, Lz, Jz, Fm = d["t"], d["Fz"], d["Lz"], d["Jz"], d["Fmag"]
    t0 = ledger_start(stir)
    # ★終端まで到達しているかを **設計値** と突き合わせる。走行中の腕を rsync で
    # 取ってくると途中までの CSV がローカルに残り、**黙って短い窓の数字が出る**。
    # 実際に dt/2 の腕でそれをやり、走行自身の報告 4.924 に対して 4.264 と表示した。
    t_end_expected = stir + 64  # tilt5 + spinup5 + stir + rotback3 + fielddown1 + quench50
    if t[-1] < t_end_expected - 0.5:
        missing.append((name, f"{tag}（t {t[-1]:.0f} / {t_end_expected} まで — 未完 or 古いコピー）"))
        continue
    k = int(np.argmax(t >= t0))
    conv = Fz[-1] - Fz[k]
    leak = float(np.abs(Jz[t >= t0] - Jz[k]).max())
    inj = Lz[k]
    rows.append(dict(name=name, tag=tag, bf=bf, om=om, stir=stir, t_end=float(t[-1]),
                     Fz0=float(Fz[k]), Fz1=float(Fz[-1]), Lz0=float(inj),
                     Lz1=float(Lz[-1]), Jz=float(Jz[k]), conv=float(conv),
                     leak=leak, Fmag1=float(Fm[-1])))

print(f"{'腕':<15} {'B_f':>4} {'stir':>4} {'注入L_z':>8} {'J_z':>8} "
      f"{'F_z(終)':>8} {'ΔF_z':>7} {'|F|終':>6} {'leak':>8}")
print("-" * 82)
for r in rows:
    print(f"{r['name']:<15} {r['bf']:>4} {r['stir']:>4} {r['Lz0']:+8.3f} {r['Jz']:+8.3f} "
          f"{r['Fz1']:+8.3f} {r['conv']:+7.3f} {r['Fmag1']:6.3f} {r['leak']:8.1e}")
print("-" * 82)
if missing:
    print(f"\n未完 / 未取得 {len(missing)} 件（**埋めていない**）:")
    for n, t_ in missing:
        print(f"  {n:<15} {t_}")

# 偶奇分解。B_final ごとに、揃っている三つ組だけ
print("\n偶奇分解（三つ組が揃っている B_final だけ）")
by = {}
for r in rows:
    if r["stir"] == 20 and "DDIoff" not in r["name"] and "dt/2" not in r["name"] \
            and abs(r["om"]) in (0.0, 0.80):
        by.setdefault(r["bf"], {})[r["om"]] = r
for bf in sorted(by):
    g = by[bf]
    if not all(k in g for k in (-0.80, 0.00, 0.80)):
        print(f"  B_final = {bf:2d} uG: 三つ組が揃っていない（{sorted(g)}）── 出さない")
        continue
    p, z, m = g[0.80]["conv"], g[0.00]["conv"], g[-0.80]["conv"]
    odd, even = (p - m) / 2, (p + m) / 2 - z
    ip, im = abs(g[0.80]["Lz0"]), abs(g[-0.80]["Lz0"])
    gap = abs(ip - im) / ((ip + im) / 2) * 100
    ratio = abs(odd / even) if abs(even) > 1e-9 else float("inf")
    print(f"  B_final = {bf:2d} uG: +Ω {p:.3f}  0 {z:.3f}  −Ω {m:.3f}")
    print(f"      奇 {odd:+.3f}   偶 {even:+.3f}   |奇|/|偶| = {ratio:.1f}"
          f"   注入の非対称 {gap:.1f} %")

# 飽和: F_z(終) 対 J_z
sat = [r for r in rows if r["bf"] == 30]
if len(sat) >= 3:
    J = np.array([r["Jz"] for r in sat])
    F = np.array([r["Fz1"] for r in sat])
    o = np.argsort(J)
    print("\nF_z(終) 対 J_z（30 uG の腕、飽和はここに折れとして出る）")
    for i in o:
        print(f"  J_z {J[i]:+8.3f}  ->  F_z {F[i]:+7.3f}   ({sat[i]['name']})")
    if len(sat) >= 4:
        b, a = np.polyfit(J, F, 1)
        res = F - (a + b * J)
        print(f"  直線当てはめ F_z = {a:+.3f} {b:+.3f}·J_z   残差 rms {res.std():.3f}")
        print("  ★残差が大きければ直線から外れている = 折れている = 飽和の証拠")

if "--fig" not in sys.argv:
    sys.exit(0)

import matplotlib
matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt

for _pat in ("NotoSansCJK", "NotoSerifCJK", "Moralerspace"):
    hit = [f for f in fm.findSystemFonts() if _pat in f.replace(" ", "")]
    if hit:
        fm.fontManager.addfont(hit[0])
        plt.rcParams["font.family"] = [fm.FontProperties(fname=hit[0]).get_name(),
                                       "DejaVu Sans"]
        break
plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "axes.grid": True, "grid.alpha": 0.25, "axes.unicode_minus": False})

fig, ax = plt.subplots(figsize=(7.6, 5.4))
for bf, mk, col in ((0, "o", "#2c3e50"), (30, "s", "#c0392b"), (49, "^", "#e08214")):
    s = [r for r in rows if r["bf"] == bf and "DDIoff" not in r["name"]
         and "dt/2" not in r["name"]]
    if not s:
        continue
    ax.plot([r["Jz"] for r in s], [r["Fz1"] for r in s], mk, ms=9, color=col,
            label=f"B_final = {bf} µG", linestyle="none")
ax.axhline(-6, color="#c00", lw=1.2, ls=":")
ax.text(ax.get_xlim()[0], -6.15, "  m = −6 の端（F_z はここより下へ行けない）",
        color="#c00", va="top", fontsize=9.5)
ax.set_xlabel(r"$J_z$（保存量。回転で注入した量で決まる）")
ax.set_ylabel(r"$\langle F_z\rangle$（終端）")
ax.set_title("梯子の端への飽和 ── 直線から折れれば張り付き", fontsize=12)
ax.legend(loc="upper left", fontsize=10)
out = FIGS / "summary_2026_09_08_saturation.png"
fig.savefig(out, dpi=150, bbox_inches="tight")
print(f"\nwrote {out}")
