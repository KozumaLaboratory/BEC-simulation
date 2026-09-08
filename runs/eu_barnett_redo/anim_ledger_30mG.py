#!/usr/bin/env python3
"""30 mG 回転駆動プロトコルの台帳を動画にする。

`anim_ledger.py` は box47 と box28 の ±Ω 対に固定されているので、別に置いた。
こちらは **段の構造が見えること**が主眼 ── 4 区間が別のことをしているので、
1 本の曲線だけ見せても何が起きたか分からない。

    傾ける       F_z が −6 → −6·cos35°、|F| は不変。**磁化ではない**
    回す         F_z は固定、L_z が注入される。J_z も動く（傾いた回転場では非保存）
    上に戻す     F_z が −6 に復帰、**J_z が凍結**（B ∥ z ⇒ Noether）
    弱磁場で保持  L_z が spin に変換され、F_z が上がる

★ここで測っているのは「F_z がどこまで上がったか」だけ。よく引用される
  「変換効率 ΔF_z/|ΔL_z| ≈ 1」は **J_z 保存の恒等式**なので、何も測っていない。
  だから効率は描かない。描くのは J_z の凍結（数値の正しさ）と F_z の到達点。

★−Ω と Ω=0 の腕はまだ無いので、これは**対照のない 1 本**。図にもそう書く。

使い方:
  python3 runs/eu_barnett_redo/anim_ledger_30mG.py [--fps=30] [--stride=1]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)

TAG = "_30mG_omp"
FPS, STRIDE = [], 1
for a in sys.argv[1:]:
    if a.startswith("--tag="):
        TAG = a.split("=", 1)[1]
    elif a.startswith("--fps="):
        FPS.append(int(a.split("=", 1)[1]))
    elif a.startswith("--stride="):
        STRIDE = int(a.split("=", 1)[1])
if not FPS:
    FPS = [30]
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found — it is what turns the frames into a file")

led = DATA / f"ledger_plus{TAG}.csv"
if not led.exists():
    sys.exit(f"{led} が無い")
d = np.genfromtxt(led, delimiter=",", names=True)
t, Fz, Lz, Jz, Fmag = d["t"], d["Fz"], d["Lz"], d["Jz"], d["Fmag"]

# 段の境界は colmaps の metadata から取る（run_core が書いている値そのもの）。
# ここで手打ちすると、走行を変えたときに図だけが古くなる。
stages = None
try:
    import h5py
    with h5py.File(DATA / f"colmaps_plus{TAG}.jld2", "r") as f:
        t_tilt, t_spin = float(f["t_tilt"][()]), float(f["t_spinup"][()])
        t_steady, t_stir = float(f["t_steady"][()]), float(f["t_stir"][()])
        theta = float(f["theta_deg"][()])
    stages = [
        (0.0, t_tilt, f"傾ける 0→{theta:.0f}°"),
        (t_tilt, t_stir, "回す（L_z 注入）"),
        (t_stir, t_stir + 3.0, "上に戻す"),
        (t_stir + 3.0, float(t[-1]), "弱磁場で保持（変換）"),
    ]
except Exception as e:  # noqa: BLE001
    print("段の境界が読めないので区間は描かない:", str(e)[:60])

# ── 図 ──────────────────────────────────────────────────────────────
# 日本語フォントを明示的に登録する。**やらないと和文が豆腐になる** ── matplotlib は
# fontconfig を見ないので、システムに Noto CJK があっても ttflist には入らない。
# 2026-09-08 に一度豆腐で描いた（"Font 'default' does not have a glyph for
# '\u9053'" が出ていた。警告は出るが図は生成されるので、見ないと気づけない）。
import matplotlib.font_manager as fm

_JP = None
for _pat in ("Noto Sans CJK", "Noto Serif CJK", "Moralerspace"):
    for _f in fm.findSystemFonts():
        if _pat.replace(" ", "") in _f.replace(" ", ""):
            try:
                fm.fontManager.addfont(_f)
                _JP = fm.FontProperties(fname=_f).get_name()
            except Exception:  # noqa: BLE001
                continue
            break
    if _JP:
        break
if _JP is None:
    print("!! 和文フォントが見つからない。ラベルが豆腐になるので確認して")

# 背景は白、軸は線形、シミュレーションの線は marker なしの滑らかな曲線。
plt.rcParams.update({"figure.facecolor": "white", "axes.facecolor": "white",
                     "font.size": 11, "axes.grid": True, "grid.alpha": 0.25,
                     "axes.unicode_minus": False})
if _JP:
    plt.rcParams["font.family"] = [_JP, "DejaVu Sans"]
fig, (ax, ax2) = plt.subplots(2, 1, figsize=(8.4, 6.6), sharex=True,
                              gridspec_kw={"height_ratios": [3, 1.15]})

if stages:
    for k, (a, b, lab) in enumerate(stages):
        ax.axvspan(a, b, color=["#eef3fb", "#fdf2e7", "#eaf5ec", "#f6eef7"][k], zorder=0)
        ax.text((a + b) / 2, 6.6, lab, ha="center", va="bottom", fontsize=9.5,
                color="#444")
        ax2.axvspan(a, b, color=["#eef3fb", "#fdf2e7", "#eaf5ec", "#f6eef7"][k], zorder=0)

ax.axhline(0, color="#999", lw=0.8)
ax.axhline(-6, color="#c00", lw=0.8, ls=":", zorder=1)
ax.text(t[-1] - 0.5, -6.25, "m = −6 の端（これ以上は磁化できない）",
        color="#c00", ha="right", va="top", fontsize=9)
(lFz,) = ax.plot([], [], lw=2.4, color="#1f4e9c", label=r"$\langle F_z\rangle$  磁化")
(lLz,) = ax.plot([], [], lw=2.4, color="#c8641e", label=r"$\langle L_z\rangle$  軌道")
(lJz,) = ax.plot([], [], lw=2.0, color="#2e7d4f", ls="--",
                 label=r"$J_z = L_z + F_z$")
(lFm,) = ax.plot([], [], lw=1.4, color="#777", ls="-.", label=r"$|\langle F\rangle|$")
ax.set_ylim(-7.2, 7.4)
ax.set_ylabel(r"$\hbar$ / atom")
ax.legend(loc="lower left", framealpha=0.9, fontsize=10)
ax.set_title(f"回転駆動 Barnett   θ={theta:.0f}°,  30 mG,  +Ω   "
             f"(240³ / box 35, DDI on)\n"
             f"対照（−Ω と Ω=0）は未実施 ── この 1 本だけでは向きへの依存が言えない",
             fontsize=11)

# 下段: J_z の初期値からのずれ。**凍結を見せるための panel**。
(lDJ,) = ax2.plot([], [], lw=2.0, color="#2e7d4f")
ax2.axhline(0, color="#999", lw=0.8)
ax2.set_ylabel(r"$J_z - J_z(0)$")
ax2.set_xlabel(r"$t\ \omega_{\rm ref}$")
ax2.set_xlim(t[0], t[-1])
ax2.set_ylim(-0.4, 6.2)

read = ax.text(0.985, 0.30, "", transform=ax.transAxes, ha="right", va="bottom",
               fontsize=10, family="monospace",
               bbox=dict(fc="white", ec="#bbb", alpha=0.92))

idx = list(range(0, len(t), STRIDE))
print(f"{len(t)} frames, stride {STRIDE} -> {len(idx)} "
      f"({', '.join(f'{len(idx)/f:.1f} s at {f} fps' for f in FPS)})")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for j, k in enumerate(idx):
        s = slice(0, k + 1)
        lFz.set_data(t[s], Fz[s])
        lLz.set_data(t[s], Lz[s])
        lJz.set_data(t[s], Jz[s])
        lFm.set_data(t[s], Fmag[s])
        lDJ.set_data(t[s], Jz[s] - Jz[0])
        read.set_text(f"t   {t[k]:5.1f}\nF_z {Fz[k]:+6.3f}\nL_z {Lz[k]:+6.3f}\n"
                      f"J_z {Jz[k]:+6.3f}")
        fig.savefig(tmp / f"f{j:05d}.png", dpi=110)
        if j % 100 == 0:
            print(f"  rendered {j}/{len(idx)}")
    for fps in FPS:
        out = FIGS / f"anim_ledger{TAG}_{fps}fps.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
             "-i", str(tmp / "f%05d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)],
            check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(idx)/fps:.1f} s at {fps} fps)")
