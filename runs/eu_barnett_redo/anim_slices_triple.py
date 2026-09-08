#!/usr/bin/env python3
"""+Ω / 0 / −Ω の 3 腕を、密度と磁化の断面で比べる動画。

★どのプロトコルか: `conv35`（θ=35°、B_final = 0、rotate_back 無し、t 0→90）。
  2026-09-08 に投げた新しい組（rotate_back あり、B_final = 30 µG）とは**別**。
  新しい組はスライスを保存していない（`BR_SLICE_DT` を渡さなかった）ので、
  断面の動画はこちらでしか作れない。**発表で混ぜないこと。**

3 行 × 3 列:
    行1  柱密度 n = Σ_m |ψ_m|²          雲の形。渦の穴があればここに出る
    行2  磁化密度 f_z = Σ_m m |ψ_m|²    どこが磁化しているか
    行3  局所偏極 f_z / n                **これが物理。密度で割ると m の分布が見える**

★行 3 を入れる理由: 行 2 は密度と磁化の積なので、雲が濃い所が明るく見えるだけ。
  割って初めて「この場所は m = −6 なのか、混ざっているのか」が分かる。
  ⇒ 張り付き（一様 −6）と拡散（場所ごとに違う m）が目で区別できる。

使い方:
  python3 runs/eu_barnett_redo/anim_slices_triple.py [--fps=6]
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import h5py
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
    FPS = [6]
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

ARMS = [("+Ω", "plus_conv35_omp"), ("Ω = 0", "zero_conv35_om0"),
        ("−Ω", "minus_conv35_omm")]

# 全部開いたまま、スライスごとに読む（1 腕 275 MB なので一括ロードしない）
fh, keys, times = {}, {}, None
for _n, tag in ARMS:
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

M = np.arange(6, -7, -1)   # c=1 -> m=+6 ... c=13 -> m=−6

def read(tag, k):
    raw = fh[tag][k]["psi"][()]
    psi = raw["re"].astype(np.float64) + 1j * raw["im"].astype(np.float64)
    n = (np.abs(psi) ** 2)                       # (13, ny, nx)
    ntot = n.sum(axis=0)
    fz = (M[:, None, None] * n).sum(axis=0)
    return ntot, fz

# 色スケールは**全時刻・全腕で共通**にする。フレームごとに変えると
# 「明るくなった」が密度の変化か配色の変化か区別できなくなる。
nmax = 0.0
for _n, tag in ARMS:
    for k in keys[tag][::6]:
        nt, _ = read(tag, k)
        nmax = max(nmax, float(nt.max()))
print(f"共通の密度スケール: 0 .. {nmax:.3g}")

# 表示範囲: 最終フレームで柱密度の 99.9 % を含む最小の対称窓
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
if _JP:
    plt.rcParams["font.family"] = [_JP, "DejaVu Sans"]

fig, axes = plt.subplots(3, 3, figsize=(9.6, 9.9))
ims = {}
for j, (name, tag) in enumerate(ARMS):
    nt, fz = read(tag, keys[tag][0])
    ims[(0, j)] = axes[0, j].imshow(nt[sl], cmap="magma", vmin=0, vmax=nmax,
                                    origin="lower")
    ims[(1, j)] = axes[1, j].imshow(fz[sl], cmap="RdBu_r", vmin=-6 * nmax,
                                    vmax=6 * nmax, origin="lower")
    pol = np.where(nt > 1e-3 * nmax, fz / np.maximum(nt, 1e-30), np.nan)
    ims[(2, j)] = axes[2, j].imshow(pol[sl], cmap="RdBu_r", vmin=-6, vmax=6,
                                    origin="lower")
    axes[0, j].set_title(name, fontsize=13)
for i, lab in enumerate(["柱密度  n", r"磁化密度  $f_z$", r"局所偏極  $f_z/n$"]):
    axes[i, 0].set_ylabel(lab, fontsize=11)
for ax in axes.ravel():
    ax.set_xticks([])
    ax.set_yticks([])
fig.colorbar(ims[(2, 2)], ax=axes[2, :], fraction=0.03, pad=0.01,
             label="m （−6 … +6）")

sup = fig.suptitle("", fontsize=12.5)
fig.text(0.5, 0.012,
         "プロトコル conv35（θ=35°, B_final=0, rotate_back なし）── "
         "2026-09-08 の組とは別。混ぜないこと",
         ha="center", fontsize=8.5, color="#666")

with tempfile.TemporaryDirectory() as tmp:
    tmp = Path(tmp)
    for i in range(len(times)):
        for j, (_n, tag) in enumerate(ARMS):
            nt, fz = read(tag, keys[tag][i])
            ims[(0, j)].set_data(nt[sl])
            ims[(1, j)].set_data(fz[sl])
            pol = np.where(nt > 1e-3 * nmax, fz / np.maximum(nt, 1e-30), np.nan)
            ims[(2, j)].set_data(pol[sl])
        st = ("傾ける／回す（L_z 注入）" if times[i] < 40 else "弱磁場で保持（変換）")
        sup.set_text(f"密度・磁化・局所偏極   t = {times[i]:5.1f}   [{st}]")
        fig.savefig(tmp / f"f{i:04d}.png", dpi=104, bbox_inches="tight")
        if i % 10 == 0:
            print(f"  rendered {i}/{len(times)}")
    for fps in FPS:
        out = FIGS / f"anim_slices_triple_conv35_{fps}fps.mp4"
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
             "-i", str(tmp / "f%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
             "-vf", "pad=ceil(iw/2)*2:ceil(ih/2)*2", str(out)],
            check=True)
        print(f"wrote {out}  ({out.stat().st_size/1e6:.1f} MB, "
              f"{len(times)/fps:.1f} s at {fps} fps)")
for tag in fh:
    fh[tag].close()
