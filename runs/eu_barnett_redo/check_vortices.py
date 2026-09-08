#!/usr/bin/env python3
"""渦があるかを数で決める。動画を見た印象ではなく。

渦の判定は **2π の位相巻きと密度コアの共局在**。片方だけでは足りない:
  ・位相巻きだけ → 密度がほぼ 0 の場所ではランダムに立つ。数値ノイズの巻き
  ・密度の穴だけ → 単なる密度の谷。トラップの形や干渉で出る

★spinor では成分ごとに渦があっても、他の m がコアを埋めて **全密度には穴が出ない**。
  だから m 成分ごとに見る。「動画に穴が見えない」は「渦が無い」を意味しない。

★陽性対照を内蔵する。渦を 1 本手で埋め込んだ場を作って、同じ判定器が
  それを検出できることを見せる。検出できない判定器で「無い」と言ってはいけない。

使い方:
  python3 runs/eu_barnett_redo/check_vortices.py [--tag=_30mG_omp] [--thresh=0.05]
"""
import sys
from pathlib import Path

import h5py
import numpy as np

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"

TAG = "_30mG_omp"
# コアと認める密度の下限（そのスライスの成分ピークに対する比）。
# これより薄い所の巻きは数えない ── 真空では位相が定義されないので。
CORE_FRAC = 0.05
for a in sys.argv[1:]:
    if a.startswith("--tag="):
        TAG = a.split("=", 1)[1]
    elif a.startswith("--thresh="):
        CORE_FRAC = float(a.split("=", 1)[1])


def winding(phase):
    """各プラケットの巻き数。位相差を (-π, π] に折り返して 4 辺を足す。"""
    def d(a, b):
        return (a - b + np.pi) % (2 * np.pi) - np.pi
    p = phase
    w = (d(p[1:, :-1], p[:-1, :-1]) + d(p[1:, 1:], p[1:, :-1])
         + d(p[:-1, 1:], p[1:, 1:]) + d(p[:-1, :-1], p[:-1, 1:]))
    return np.rint(w / (2 * np.pi)).astype(int)


def find_vortices(psi_m, core_frac=CORE_FRAC):
    """1 成分の (ny, nx) 複素場から渦を数える。

    返り値: (巻きの総数, コアと共局在した数, 使った密度しきい値)
    """
    n = np.abs(psi_m) ** 2
    peak = n.max()
    if peak <= 0:
        return 0, 0, 0.0
    w = winding(np.angle(psi_m))
    thr = core_frac * peak
    # プラケットの密度は 4 隅の平均
    nq = 0.25 * (n[1:, 1:] + n[1:, :-1] + n[:-1, 1:] + n[:-1, :-1])
    live = nq >= thr           # 位相が意味を持つ濃さがある所だけ
    wind = (w != 0) & live
    if not wind.any():
        return 0, 0, thr
    # コア判定: 巻きの位置の密度が、その 5x5 近傍の中位より十分低い
    from numpy.lib.stride_tricks import sliding_window_view
    pad = np.pad(nq, 2, mode="edge")
    med = np.median(sliding_window_view(pad, (5, 5)).reshape(*nq.shape, 25), axis=-1)
    core = wind & (nq < 0.5 * med)
    return int(wind.sum()), int(core.sum()), thr


def selftest():
    """陽性対照: 渦を 1 本埋め込んだ場を、判定器が拾えるか。"""
    ny = nx = 121
    y, x = np.mgrid[-1:1:1j * ny, -1:1:1j * nx]
    r = np.hypot(x, y)
    env = np.exp(-(r ** 2) / 0.5)
    # 中心に電荷 +1 の渦（コアが空く）
    psi = env * np.tanh(r / 0.05) * np.exp(1j * np.arctan2(y, x))
    w, c, _ = find_vortices(psi)
    ok1 = (w >= 1 and c >= 1)
    # 陰性対照: 渦なしの同じ包絡線
    w0, c0, _ = find_vortices(env.astype(complex))
    ok2 = (w0 == 0 and c0 == 0)
    print(f"陽性対照（渦 1 本を埋め込み）: 巻き {w}, コア共局在 {c}  -> "
          f"{'ok' if ok1 else 'FAIL'}")
    print(f"陰性対照（渦なし）:            巻き {w0}, コア共局在 {c0}  -> "
          f"{'ok' if ok2 else 'FAIL'}")
    return ok1 and ok2


print("=== 判定器の校正 ===")
if not selftest():
    sys.exit("判定器が対照を通らない。この状態で「渦が無い」と言ってはいけない")

src = DATA / f"slices_plus{TAG}.jld2"
if not src.exists():
    sys.exit(f"{src} が無い")

print(f"\n=== {src.name} ===")
with h5py.File(src, "r") as f:
    keys = sorted(k for k in f.keys() if k.startswith("slice_"))
    print(f"{len(keys)} スライス、各 13 成分\n")
    print(f"{'t':>6}  {'m':>3}  {'占有%':>6}  {'巻き':>5}  {'コア共局在':>9}")
    print("-" * 42)
    tot_core = 0
    for k in keys:
        g = f[k]
        t = float(g["t"][()])
        raw = g["psi"][()]                      # (13, ny, nx) の re/im
        psi = raw["re"].astype(np.float64) + 1j * raw["im"].astype(np.float64)
        n_all = (np.abs(psi) ** 2).sum()
        rows = []
        for mi in range(psi.shape[0]):
            m = 6 - mi                          # c=1 -> m=+F, c=D -> m=-F
            frac = (np.abs(psi[mi]) ** 2).sum() / n_all
            if frac < 1e-4:                     # 空の成分は飛ばす
                continue
            w, c, _ = find_vortices(psi[mi])
            rows.append((m, frac, w, c))
            tot_core += c
        # 全密度（成分をまたいで足したもの）でも見る
        n_tot = (np.abs(psi) ** 2).sum(axis=0)
        shown = [r for r in rows if r[3] > 0 or r[2] > 0]
        if not shown:
            print(f"{t:6.1f}   ─    ─       0         0")
        for m, frac, w, c in shown:
            print(f"{t:6.1f}  {m:+3d}  {100*frac:6.2f}  {w:5d}  {c:9d}")
    print("-" * 42)
    print(f"全スライス・全成分でコアと共局在した巻き: {tot_core}")
    if tot_core == 0:
        print("\n⇒ **渦は無い。** 位相巻きが密度コアと共局在した箇所が 1 つも無い。")
        print("   判定器は上の陽性対照を通っているので、これは「見えていない」ではない。")
