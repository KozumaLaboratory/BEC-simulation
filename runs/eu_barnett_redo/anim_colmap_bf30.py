#!/usr/bin/env python3
"""+Ω / 0 / −Ω の滑らかな動画。**補間なし、実フレーム 846 枚。**

★なぜ slices ではなく colmaps を使うか: `slices_*.jld2` は 13 成分の複素 ψ を
  持つが **43 枚しか無い**（BR_SLICE_DT = 2）。`colmaps_*.jld2` は柱積分の
  n と f_z だけだが **846 枚**（dt ≈ 0.1）。位相と m 分解が要らない絵なら
  colmaps の方が 20 倍滑らかで、しかも同じランの同じ物理。
  ⇒ ffmpeg の minterpolate で水増しする必要が無い。**合成フレームは使わない。**

  失うもの: 成分ごとの位相（渦の巻き数）。それが要るときは slices を使うこと。

3 行 × 3 列:
    行1  column density n            雲の形。渦の穴はここに出る
    行2  magnetisation f_z           どこが磁化しているか
    行3  local polarisation f_z / n  **これが物理。割って初めて m が見える**
    下   F_z(t) と、いま何時か

使い方: python3 runs/eu_barnett_redo/anim_colmap_bf30.py [--stride=2] [--fps=30]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import h5py
import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

HERE = Path(__file__).resolve().parent
DATA, FIGS = HERE / "data", HERE / "figures"
FIGS.mkdir(exist_ok=True)


def _arg(name, default):
    for a in sys.argv[1:]:
        if a.startswith(f"--{name}="):
            return int(a.split("=", 1)[1])
    return default


STRIDE, FPS = _arg("stride", 2), _arg("fps", 30)
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found")

# (表示名, tag, 色, 終端 F_z の期待値 ── bf30 の同じ物理の腕から)
ARMS = [(r"$\Omega=+0.80$", "plus_sl_omp08", "#c0392b", -3.375),
        (r"$\Omega=0$", "zero_sl_om0", "#2c3e50", -4.345),
        (r"$\Omega=-0.80$", "minus_sl_omm08", "#2471a3", -4.868)]
T_STIR_END, T_LEDGER = 30.0, 34.0

led, fh, times = {}, {}, None
for _n, tag, _c, want in ARMS:
    a = np.genfromtxt(DATA / f"ledger_{tag}_prod_box35.csv", delimiter=",", names=True)
    if abs(a["Fz"][-1] - want) > 0.01:       # 腕の取り違えをここで殺す
        sys.exit(f"{tag}: F_z 終端 {a['Fz'][-1]:.3f} != {want:.3f}")
    led[tag] = a
    f = h5py.File(DATA / f"colmaps_{tag}_prod_box35.jld2", "r")
    tt = f["t"][()]
    if times is None:
        times = tt
    elif len(tt) != len(times) or abs(tt[-1] - times[-1]) > 1e-9:
        sys.exit(f"{tag} の時刻が揃っていない ── 並べて比べられない")
    fh[tag] = f
idx = list(range(0, len(times), STRIDE))
print(f"台帳 3 本 OK / colmap {len(times)} 枚 -> {len(idx)} 枚 "
      f"(stride {STRIDE}, dt {times[STRIDE]-times[0]:.2f})")

# 共通の色スケール。フレームごとに変えると密度変化と配色変化が区別できない
nmax = max(float(fh[t]["n_col"][j].max()) for _n, t, _c, _w in ARMS
           for j in range(0, len(times), 60))
print(f"共通の密度スケール 0 .. {nmax:.3g}")

# 表示範囲: 最終フレームで柱密度の 99.9 % を含む最小の対称窓
last = fh[ARMS[0][1]]["n_col"][-1]
ny, nx = last.shape
tot, R = last.sum(), min(nx, ny) // 2
for r in range(6, min(nx, ny) // 2):
    if last[ny // 2 - r:ny // 2 + r, nx // 2 - r:nx // 2 + r].sum() >= 0.999 * tot:
        R = r
        break
sl = np.s_[ny // 2 - R:ny // 2 + R, nx // 2 - R:nx // 2 + R]
print(f"表示は中央 {2*R}x{2*R} セル（最終フレームの 99.9 %）")

plt.rcParams.update({"figure.facecolor": "white", "font.size": 10,
                     "axes.unicode_minus": False})
fig = plt.figure(figsize=(10.2, 12.0))
gs = fig.add_gridspec(4, 3, height_ratios=[1, 1, 1, 0.62], hspace=0.06, wspace=0.06,
                      top=0.93, bottom=0.055, left=0.085, right=0.99)
axes = np.array([[fig.add_subplot(gs[i, j]) for j in range(3)] for i in range(3)])
axL = fig.add_subplot(gs[3, :])

ims, spread = {}, {}
for j, (name, tag, _c, _w) in enumerate(ARMS):
    nt = fh[tag]["n_col"][0][sl]
    fz = fh[tag]["fz_col"][0][sl]
    ims[(0, j)] = axes[0, j].imshow(nt, cmap="magma", vmin=0, vmax=nmax, origin="lower")
    ims[(1, j)] = axes[1, j].imshow(fz, cmap="RdBu_r", vmin=-6 * nmax, vmax=6 * nmax,
                                    origin="lower")
    ims[(2, j)] = axes[2, j].imshow(np.where(nt > 1e-3 * nmax, fz / np.maximum(nt, 1e-30),
                                             np.nan), cmap="RdBu_r", vmin=-6, vmax=6,
                                    origin="lower")
    axes[0, j].set_title(name, fontsize=13)
    spread[j] = axes[2, j].text(0.5, 0.015, "", transform=axes[2, j].transAxes,
                                ha="center", fontsize=10, color="#111",
                                bbox=dict(fc="white", ec="none", alpha=0.75))
for i, lab in enumerate(["column density  $n$", "magnetisation  $f_z$",
                         "local polarisation  $f_z/n$"]):
    axes[i, 0].set_ylabel(lab, fontsize=10.5)
for ax in axes.ravel():
    ax.set_xticks([])
    ax.set_yticks([])
fig.colorbar(ims[(2, 2)], ax=axes[2, :], fraction=0.028,
             pad=0.012).set_label("local $m$   (−6 … +6)", fontsize=10)

for name, tag, col, _w in ARMS:
    axL.plot(led[tag]["t"], led[tag]["Fz"], "-", color=col, lw=2.0, label=name)
axL.axhline(-6, color="#c00", lw=1.0, ls=":")
axL.text(83.5, -5.85, "$m=-6$ edge", color="#c00", ha="right", va="bottom", fontsize=9)
axL.axvspan(0, T_STIR_END, color="#eef3f8", zorder=0)
axL.axvspan(T_STIR_END, T_LEDGER, color="#f6eef8", zorder=0)
axL.text(T_STIR_END / 2, 5.2, "tilt · spin up · stir   (inject $L_z$)", ha="center",
         fontsize=9.5, color="#41668c", va="top")
axL.text((T_LEDGER + 84) / 2, 5.2, "hold at 30 µG   (spin ↔ orbital conversion)",
         ha="center", fontsize=9.5, color="#666", va="top")
cursor = axL.axvline(times[0], color="#111", lw=1.4)
axL.set_xlim(0, 84)
axL.set_ylim(-6.6, 5.6)
axL.set_xlabel(r"$t\ \omega_{\rm ref}$")
axL.set_ylabel(r"$\langle F_z\rangle$")
axL.grid(alpha=0.25)
axL.legend(loc="center left", fontsize=9.5, framealpha=0.95)

sup = fig.suptitle("", fontsize=13)
fig.text(0.5, 0.008, f"protocol sl_* : θ = 35°, rotate_back, B_final = 30 µG, box 35 "
                     f"— {len(idx)} real frames, no interpolation", ha="center",
         fontsize=8, color="#888")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for i, k in enumerate(idx):
        t = float(times[k])
        for j, (_n, tag, _c, _w) in enumerate(ARMS):
            nt = fh[tag]["n_col"][k][sl]
            fz = fh[tag]["fz_col"][k][sl]
            ims[(0, j)].set_data(nt)
            ims[(1, j)].set_data(fz)
            ims[(2, j)].set_data(np.where(nt > 1e-3 * nmax,
                                          fz / np.maximum(nt, 1e-30), np.nan))
            g = nt > 1e-3 * nmax
            if g.any():
                m, w = fz[g] / nt[g], nt[g]
                bar = (w * m).sum() / w.sum()
                sd = np.sqrt((w * (m - bar) ** 2).sum() / w.sum())
                spread[j].set_text(f"mean $m$ {bar:+.2f}   spread {sd:.2f}")
        cursor.set_xdata([t, t])
        st = ("injecting $L_z$" if t < T_STIR_END else
              "field back to axis" if t < T_LEDGER else "converting at 30 µG")
        sup.set_text(f"$t\\ \\omega_{{\\rm ref}} = {t:5.1f}$    [{st}]")
        fig.savefig(tmp / f"f{i:04d}.png", dpi=88)
        if i % 50 == 0:
            print(f"  rendered {i}/{len(idx)}", flush=True)
    out = FIGS / f"anim_colmap_bf30_{FPS}fps.mp4"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS),
                    "-i", str(tmp / "f%04d.png"), "-c:v", "libx264", "-crf", "20",
                    "-pix_fmt", "yuv420p",
                    "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)], check=True)
    print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
          f"{len(idx)/FPS:.1f} s at {FPS} fps)")
for tag in fh:
    fh[tag].close()
