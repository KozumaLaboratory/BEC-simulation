#!/usr/bin/env python3
"""+Ω / 0 / −Ω の 3 腕。**物理的主張が立つかを図の中で判定する。**

主張: θ=35° で、磁化変化は回転の**向き**に依存する。

判定の仕方 ── Ω についての偶奇に分解する。この分け方を選ぶ理由は、
**回転が原因なら奇、そうでなければ偶**になるから:

    奇成分  odd(t)  = [F_z(+Ω) − F_z(−Ω)] / 2        向きを変えると符号が変わる分
    偶成分  even(t) = [F_z(+Ω) + F_z(−Ω)] / 2 − F_z(0)  向きに依存しない分

  ・回転が磁化を駆動しているなら odd が大きい
  ・「磁場を傾けて回した」ことの副作用（加熱・変形など）なら even に出る
  ・Ω=0 を引いてあるので、**EdH の背景は両方から落ちている**

これは片側スキャンでは出せない。+Ω だけ見ると EdH の +3.83 に埋もれて
「回転で磁化した」と読めてしまう。

★交絡の確認も図に出す: ±の注入量 |L_z| が揃っていなければ、非対称は
  「回転の向き」ではなく「注入量の差」で説明できてしまう。

★描かないもの:
  ・変換効率 ΔF_z/|ΔL_z| ── J_z 保存の恒等式なので何も測っていない
  ・渦 ── 回していない腕が渦最多で変換ゼロだった。経路ではない

使い方:
  python3 runs/eu_barnett_redo/anim_parity_triple.py [--fps=30]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)

FPS = []
for a in sys.argv[1:]:
    if a.startswith("--fps="):
        FPS.append(int(a.split("=", 1)[1]))
if not FPS:
    FPS = [30]
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found")

_JP = None
for _pat in ("NotoSansCJK", "NotoSerifCJK", "Moralerspace"):
    for _f in fm.findSystemFonts():
        if _pat in _f.replace(" ", ""):
            try:
                fm.fontManager.addfont(_f)
                _JP = fm.FontProperties(fname=_f).get_name()
            except Exception:  # noqa: BLE001
                continue
            break
    if _JP:
        break
if _JP is None:
    print("!! 和文フォントが無い。ラベルが豆腐になる")

TRIPLE = [("+Ω = +0.80", "plus_b8_omp08", "#c0392b"),
          ("Ω = 0", "zero_b8_om0", "#2c3e50"),
          ("−Ω = −0.80", "minus_b8_omm08", "#2471a3")]

d = {}
for _, tag, _c in TRIPLE:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        sys.exit(f"{f} が無い")
    d[tag] = np.genfromtxt(f, delimiter=",", names=True)

t = d["zero_b8_om0"]["t"]
for _, tag, _c in TRIPLE:
    if len(d[tag]["t"]) != len(t):
        sys.exit(f"{tag} の時間格子が違う ── 偶奇分解は同じ格子でしか取れない")

Fp, Fz0, Fm = (d["plus_b8_omp08"]["Fz"], d["zero_b8_om0"]["Fz"],
               d["minus_b8_omm08"]["Fz"])
odd = (Fp - Fm) / 2.0
even = (Fp + Fm) / 2.0 - Fz0

# 交絡の確認: ±の注入量が揃っているか。かき混ぜ終わり (t=30) の |L_z|。
i30 = int(np.argmin(np.abs(t - 30.0)))
inj_p, inj_m = d["plus_b8_omp08"]["Lz"][i30], d["minus_b8_omm08"]["Lz"][i30]
inj_gap = abs(abs(inj_p) - abs(inj_m)) / ((abs(inj_p) + abs(inj_m)) / 2) * 100

T_TILT, T_STIR_END, T_LEDGER = 5.0, 30.0, 34.0
STAGES = [(0, T_TILT, "傾ける", "#eef3fb"),
          (T_TILT, T_STIR_END, "回す（L_z 注入）", "#fdf2e7"),
          (T_STIR_END, T_LEDGER, "戻す", "#eaf5ec"),
          (T_LEDGER, t[-1], "弱磁場で保持（変換）", "#f6eef7")]

plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "font.size": 11, "axes.grid": True, "grid.alpha": 0.25,
                     "axes.unicode_minus": False})
if _JP:
    plt.rcParams["font.family"] = [_JP, "DejaVu Sans"]

fig, (axF, axD) = plt.subplots(2, 1, figsize=(9.2, 7.6), sharex=True,
                               gridspec_kw={"height_ratios": [1.3, 1.0]})
for ax in (axF, axD):
    for a, b, _l, col in STAGES:
        ax.axvspan(a, b, color=col, zorder=0)
    ax.axhline(0, color="#999", lw=0.8)
for a, b, lab, _c in STAGES:
    axF.text((a + b) / 2, 0.965, lab, ha="center", va="top", fontsize=9.5,
             color="#444", transform=axF.get_xaxis_transform())

axF.axhline(-6, color="#c00", lw=0.8, ls=":")
lF = {}
for name, tag, col in TRIPLE:
    (ln,) = axF.plot([], [], lw=2.8, color=col, label=name)
    lF[tag] = ln
axF.set_ylim(-6.8, 0.6)
axF.set_ylabel(r"$\langle F_z\rangle$   磁化")
axF.legend(loc="lower left", framealpha=0.92, fontsize=10)
axF.set_title("回転の向きは磁化を変えるか ── +Ω / 0 / −Ω の 3 腕\n"
              "30 mG, θ=35°, 240³/box35, DDI on, 同一基底状態", fontsize=11.5)

(lOdd,) = axD.plot([], [], lw=3.0, color="#7d3c98",
                   label=r"奇 $[F_z(+\Omega)-F_z(-\Omega)]/2$   向きに依存")
(lEven,) = axD.plot([], [], lw=2.2, color="#7f8c8d", ls="--",
                    label=r"偶 $[F_z(+\Omega)+F_z(-\Omega)]/2-F_z(0)$   向きに無関係")
axD.set_ylim(-0.65, 1.55)
axD.set_ylabel("Ω についての分解")
axD.set_xlabel(r"$t\ \omega_{\rm ref}$")
axD.set_xlim(t[0], t[-1])
axD.legend(loc="upper left", framealpha=0.92, fontsize=9.5)

read = axF.text(0.985, 0.045, "", transform=axF.transAxes, ha="right", va="bottom",
                fontsize=10, family="monospace",
                bbox=dict(fc="white", ec="#bbb", alpha=0.94))
# ★family="monospace" にすると和文が当たらない（DejaVu Sans Mono に日本語が無く、
# 「支配」が豆腐になった）。数値の桁揃えより読めることを取る。
verdict = axD.text(0.985, 0.045, "", transform=axD.transAxes, ha="right", va="bottom",
                   fontsize=10.5,
                   bbox=dict(fc="#fffbe6", ec="#c8a415", alpha=0.96))

print(f"{len(t)} frames ({len(t)/FPS[0]:.1f} s at {FPS[0]} fps)")
print(f"注入の対称性: |L_z| +Ω {inj_p:+.4f} / −Ω {inj_m:+.4f}  差 {inj_gap:.1f} %")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for j in range(len(t)):
        s = slice(0, j + 1)
        for _n, tag, _c in TRIPLE:
            lF[tag].set_data(t[s], d[tag]["Fz"][s])
        lOdd.set_data(t[s], odd[s])
        lEven.set_data(t[s], even[s])
        read.set_text(f"t = {t[j]:5.1f}\n"
                      f"  +Ω  {Fp[j]:+6.3f}\n   0  {Fz0[j]:+6.3f}\n  −Ω  {Fm[j]:+6.3f}")
        if t[j] < T_LEDGER:
            verdict.set_text("変換はまだ始まっていない\n"
                             f"注入の対称性 |L_z| の差 {inj_gap:.1f} %")
        else:
            r = abs(odd[j] / even[j]) if abs(even[j]) > 1e-9 else float("inf")
            verdict.set_text(f"奇 {odd[j]:+.3f}   偶 {even[j]:+.3f}\n"
                             f"|奇|/|偶| = {r:.1f}"
                             + ("   → 向きが支配" if r > 3 else "   → 判定不能"))
        fig.savefig(tmp / f"f{j:05d}.png", dpi=104)
        if j % 150 == 0:
            print(f"  rendered {j}/{len(t)}")
    for fps in FPS:
        out = FIGS / f"anim_parity_triple_b8_{fps}fps.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
             "-i", str(tmp / "f%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)],
            check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(t)/fps:.1f} s at {fps} fps)")
