#!/usr/bin/env python3
"""+Ω / 0 / −Ω を、断面と台帳で同時に見る動画。**発表で使う組。**

★プロトコル: `sl_*`（θ=35°、rotate_back あり、**B_final = 30 µG**、t 0→84）。
  8-26 の `conv35`（B_final = 0、rotate_back 無し、t 0→90）とは**別物**。
  終端 F_z が 3 腕とも bf30 の腕と一致するので、同じ物理の腕である
  （−3.375 / −4.345 / −4.868）── これはこのスクリプトが起動時に検算する。

★ラベルは英語。このマシンの matplotlib は和文を出せない（jp_font.py）。

3 行 × 3 列 ＋ 台帳:
    行1  column density n = Σ_m |ψ_m|²      雲の形。渦の穴はここに出る
    行2  magnetisation f_z = Σ_m m |ψ_m|²   どこが磁化しているか
    行3  local polarisation f_z / n         **これが物理**。割って初めて m が見える
    下   F_z(t) の 3 本と、いま何時か

★行 3 を入れる理由: 行 2 は密度と磁化の積なので、濃い所が明るく見えるだけ。
  割って初めて「そこは m=−6 なのか、混ざっているのか」が分かる。

使い方: python3 runs/eu_barnett_redo/anim_slices_bf30.py [--fps=8]
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

FPS = [int(a.split("=", 1)[1]) for a in sys.argv[1:] if a.startswith("--fps=")] or [8]
if shutil.which("ffmpeg") is None:
    sys.exit("ffmpeg not found")

# (表示名, tag, 色, 終端 F_z の期待値 ── bf30 の同じ物理の腕から)
ARMS = [(r"$\Omega=+0.80$", "plus_sl_omp08", "#c0392b", -3.375),
        (r"$\Omega=0$",     "zero_sl_om0",   "#2c3e50", -4.345),
        (r"$\Omega=-0.80$", "minus_sl_omm08", "#2471a3", -4.868)]
T_STIR_END, T_LEDGER = 30.0, 34.0     # tilt5+spinup5+stir20 / +rotback3+fielddown1

# ── 台帳を先に読む。腕の取り違えをここで殺す ──────────────────────
led = {}
for _n, tag, _c, want in ARMS:
    p = DATA / f"ledger_{tag}_prod_box35.csv"
    if not p.exists():
        sys.exit(f"{p} が無い")
    a = np.genfromtxt(p, delimiter=",", names=True)
    if a["t"][-1] < 83.5:
        sys.exit(f"{tag} は t={a['t'][-1]:.0f} までしか無い（84 必要）── 走行中のコピー")
    if abs(a["Fz"][-1] - want) > 0.01:
        sys.exit(f"{tag} の終端 F_z が {a['Fz'][-1]:.3f}、期待 {want:.3f} ── "
                 "別のプロトコルの腕を掴んでいる")
    led[tag] = a
print("台帳 3 本 OK（終端 F_z が bf30 の腕と一致）")

# ── スライスを開く。1 腕 258 MB なので一括ロードしない ────────────
fh, keys, times = {}, {}, None
for _n, tag, _c, _w in ARMS:
    p = DATA / f"slices_{tag}_prod_box35.jld2"
    if not p.exists():
        sys.exit(f"{p} が無い")
    fh[tag] = h5py.File(p, "r")
    keys[tag] = sorted(k for k in fh[tag].keys() if k.startswith("slice_"))
    tt = [float(fh[tag][k]["t"][()]) for k in keys[tag]]
    if times is None:
        times = tt
    elif len(tt) != len(times) or abs(tt[-1] - times[-1]) > 1e-9:
        sys.exit(f"{tag} の時刻が揃っていない ── 並べて比べられない")
print(f"スライス {len(times)} 枚 / 腕、t {times[0]:.1f} .. {times[-1]:.1f}")

M = np.arange(6, -7, -1)   # c=1 -> m=+6 ... c=13 -> m=−6


def read(tag, k):
    raw = fh[tag][k]["psi"][()]
    psi = raw["re"].astype(np.float64) + 1j * raw["im"].astype(np.float64)
    n = np.abs(psi) ** 2                          # (13, ny, nx)
    return n.sum(axis=0), (M[:, None, None] * n).sum(axis=0)


# 色スケールは**全時刻・全腕で共通**。フレームごとに変えると
# 「明るくなった」が密度の変化か配色の変化か区別できなくなる。
nmax = max(float(read(tag, k)[0].max())
           for _n, tag, _c, _w in ARMS for k in keys[tag][::6])
print(f"共通の密度スケール 0 .. {nmax:.3g}")

nt_last, _ = read(ARMS[0][1], keys[ARMS[0][1]][-1])
ny, nx = nt_last.shape
tot = nt_last.sum()
R = min(nx, ny) // 2
for r in range(4, min(nx, ny) // 2):
    if nt_last[ny // 2 - r:ny // 2 + r, nx // 2 - r:nx // 2 + r].sum() >= 0.999 * tot:
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
    nt, fz = read(tag, keys[tag][0])
    ims[(0, j)] = axes[0, j].imshow(nt[sl], cmap="magma", vmin=0, vmax=nmax,
                                    origin="lower")
    ims[(1, j)] = axes[1, j].imshow(fz[sl], cmap="RdBu_r", vmin=-6 * nmax,
                                    vmax=6 * nmax, origin="lower")
    pol = np.where(nt > 1e-3 * nmax, fz / np.maximum(nt, 1e-30), np.nan)
    ims[(2, j)] = axes[2, j].imshow(pol[sl], cmap="RdBu_r", vmin=-6, vmax=6,
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
cb = fig.colorbar(ims[(2, 2)], ax=axes[2, :], fraction=0.028, pad=0.012)
cb.set_label("local $m$   (−6 … +6)", fontsize=10)

# ── 台帳パネル ────────────────────────────────────────────────────
for name, tag, col, _w in ARMS:
    a = led[tag]
    axL.plot(a["t"], a["Fz"], "-", color=col, lw=2.0, label=name)
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
axL.legend(loc="center left", fontsize=9.5, ncol=1, framealpha=0.95)

sup = fig.suptitle("", fontsize=13)
fig.text(0.5, 0.008, "protocol sl_* : θ = 35°, rotate_back, B_final = 30 µG, box 35 "
                     "— NOT the 08-26 conv35 set", ha="center", fontsize=8,
         color="#888")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for i, t in enumerate(times):
        for j, (_n, tag, _c, _w) in enumerate(ARMS):
            nt, fz = read(tag, keys[tag][i])
            ims[(0, j)].set_data(nt[sl])
            ims[(1, j)].set_data(fz[sl])
            pol = np.where(nt > 1e-3 * nmax, fz / np.maximum(nt, 1e-30), np.nan)
            ims[(2, j)].set_data(pol[sl])
            # 密度で重みづけた局所 m の平均とばらつき。一様に張り付けば sd -> 0
            w = nt[sl]
            mloc = fz[sl] / np.maximum(w, 1e-30)
            mbar = float((w * mloc).sum() / w.sum())
            sd = float(np.sqrt((w * (mloc - mbar) ** 2).sum() / w.sum()))
            spread[j].set_text(f"mean $m$ {mbar:+.2f}   spread {sd:.2f}")
        cursor.set_xdata([t, t])
        st = ("injecting $L_z$" if t < T_STIR_END else
              "field back to axis" if t < T_LEDGER else "converting at 30 µG")
        sup.set_text(f"$t\\ \\omega_{{\\rm ref}} = {t:5.1f}$    [{st}]")
        fig.savefig(tmp / f"f{i:04d}.png", dpi=100)
        if i % 20 == 0:
            print(f"  rendered {i}/{len(times)}")
    for fps in FPS:
        out = FIGS / f"anim_slices_bf30_{fps}fps.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
             "-i", str(tmp / "f%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)], check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(times)/fps:.1f} s at {fps} fps)")
for tag in fh:
    fh[tag].close()
