#!/usr/bin/env python3
"""2026-09-08 の Ω 組を動画にする。**Ω=0 を基準として引いた差**が主眼。

なぜ差を描くか: Ω=0 でも弱磁場に落とすだけで ΔF_z = +3.83 動く（Einstein–de Haas）。
だから F_z の生の曲線を並べても「回転で磁化した」ようにしか見えず、実際には
回転が足しているのは 22 % だけ。**基準を引いた第 3 パネルがその 22 % を示す。**

★描かないもの:
  ・変換効率 ΔF_z/|ΔL_z| ── J_z 保存の恒等式なので何も測っていない
  ・渦 ── 別に数えた結果、回していない腕が渦最多で変換ゼロだった（経路ではない）

使い方:
  python3 runs/eu_barnett_redo/anim_omega_set.py [--fps=30] [--stride=1]
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

FPS, STRIDE = [], 1
for a in sys.argv[1:]:
    if a.startswith("--fps="):
        FPS.append(int(a.split("=", 1)[1]))
    elif a.startswith("--stride="):
        STRIDE = int(a.split("=", 1)[1])
if not FPS:
    FPS = [30]
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found")

# 和文フォント。**登録しないと豆腐になる** ── matplotlib は fontconfig を見ない。
# 警告は出るが図は生成されるので、フレームを目で見るまで気づけない（2026-09-08 に一度やった）。
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

# 腕: (表示名, ファイル tag, 色, 線種, 太さ)
ARMS = [
    ("Ω = +0.80", "plus_b8_omp08", "#c0392b", "-", 2.6),
    ("Ω = +0.90", "plus_b8_omp09", "#e08214", "-", 2.2),
    ("Ω = 0  EdH 基準", "zero_b8_om0", "#2c3e50", "-", 3.0),
    ("Ω = −0.80", "minus_b8_omm08", "#2471a3", "-", 2.6),
    ("DDI off", "plus_nodd_b8_nodd", "#7f8c8d", "--", 1.8),
]

d = {}
for _, tag, *_r in ARMS:
    f = DATA / f"ledger_{tag}_prod_box35.csv"
    if not f.exists():
        sys.exit(f"{f} が無い")
    d[tag] = np.genfromtxt(f, delimiter=",", names=True)

t = d["zero_b8_om0"]["t"]
for _, tag, *_r in ARMS:
    if len(d[tag]["t"]) != len(t) or abs(d[tag]["t"][-1] - t[-1]) > 1e-9:
        sys.exit(f"{tag} の時間格子が基準と違う ── 差を取れない")
base = d["zero_b8_om0"]["Fz"]

# 段の境界（submit_edh_baseline.sh の COMMON と同じ値。ここを手打ちで
# 食い違わせないため、値は 1 か所にまとめてコメントで出所を書く）
T_TILT, T_SPINUP, T_STIR, T_ROT, T_FD = 5.0, 5.0, 20.0, 3.0, 1.0
S0 = T_TILT + T_SPINUP + T_STIR              # 30: かき混ぜ終わり
S1 = S0 + T_ROT + T_FD                        # 34: 磁場が軸方向に = 台帳の窓の始まり
STAGES = [(0, T_TILT, "傾ける 0→35°", "#eef3fb"),
          (T_TILT, S0, "回す（L_z 注入）", "#fdf2e7"),
          (S0, S1, "上に戻す＋磁場を下げる", "#eaf5ec"),
          (S1, t[-1], "弱磁場で保持（変換）", "#f6eef7")]

plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "font.size": 11, "axes.grid": True, "grid.alpha": 0.25,
                     "axes.unicode_minus": False})
if _JP:
    plt.rcParams["font.family"] = [_JP, "DejaVu Sans"]

fig, axes = plt.subplots(3, 1, figsize=(9.0, 9.6), sharex=True,
                         gridspec_kw={"height_ratios": [1.25, 1.0, 1.15]})
axF, axL, axD = axes

for ax in axes:
    for a, b, lab, col in STAGES:
        ax.axvspan(a, b, color=col, zorder=0)
    ax.axhline(0, color="#999", lw=0.8)
for a, b, lab, _c in STAGES:
    axF.text((a + b) / 2, 0.80, lab, ha="center", va="bottom", fontsize=9.5,
             color="#444", transform=axF.get_xaxis_transform())

axF.axhline(-6, color="#c00", lw=0.8, ls=":")
axF.text(t[-1] - 1, -6.35, "m = −6 の端（これ以上は磁化できない）",
         color="#c00", ha="right", va="top", fontsize=9)

lines = {}
for name, tag, col, ls, lw in ARMS:
    (lF,) = axF.plot([], [], lw=lw, ls=ls, color=col, label=name)
    (lL,) = axL.plot([], [], lw=lw, ls=ls, color=col)
    (lD,) = axD.plot([], [], lw=lw, ls=ls, color=col)
    lines[tag] = (lF, lL, lD)

axF.set_ylim(-6.9, 0.9)
axF.set_ylabel(r"$\langle F_z\rangle$   磁化")
axF.legend(loc="lower left", framealpha=0.92, fontsize=9.5, ncol=2)
axF.set_title("回転駆動 Barnett の Ω 依存 ── 30 mG, θ=35°, 240³/box35, DDI on\n"
              "Ω=0 でも +3.83 動く（EdH）。回転が足すのは全体の 22 %",
              fontsize=11)

axL.set_ylim(-9.0, 6.5)
axL.set_ylabel(r"$\langle L_z\rangle$   軌道")

# ★第 3 パネルが主眼: Ω=0 を引いた残り = 回転そのものの寄与
axD.set_ylim(-4.4, 1.8)
axD.set_ylabel(r"$\langle F_z\rangle - \langle F_z\rangle_{\Omega=0}$" "\n回転の寄与")
axD.set_xlabel(r"$t\ \omega_{\rm ref}$")
axD.set_xlim(t[0], t[-1])

read = axL.text(0.985, 0.045, "", transform=axL.transAxes, ha="right", va="bottom",
                fontsize=9.5, family="monospace",
                bbox=dict(fc="white", ec="#bbb", alpha=0.93))

idx = list(range(0, len(t), STRIDE))
print(f"{len(t)} frames, stride {STRIDE} -> {len(idx)} "
      f"({', '.join(f'{len(idx)/f:.1f} s at {f} fps' for f in FPS)})")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for j, k in enumerate(idx):
        s = slice(0, k + 1)
        txt = []
        for name, tag, *_r in ARMS:
            lF, lL, lD = lines[tag]
            lF.set_data(t[s], d[tag]["Fz"][s])
            lL.set_data(t[s], d[tag]["Lz"][s])
            lD.set_data(t[s], d[tag]["Fz"][s] - base[s])
            txt.append(f"{name:>16s} {d[tag]['Fz'][k]:+6.3f}")
        read.set_text(f"t = {t[k]:5.1f}\n" + "\n".join(txt))
        fig.savefig(tmp / f"f{j:05d}.png", dpi=104)
        if j % 150 == 0:
            print(f"  rendered {j}/{len(idx)}")
    for fps in FPS:
        out = FIGS / f"anim_omega_set_b8_{fps}fps.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
             "-i", str(tmp / "f%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)],
            check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(idx)/fps:.1f} s at {fps} fps)")
