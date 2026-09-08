#!/usr/bin/env python3
"""位相が保存されている全ての腕に渦判定をかけ、渦とスピンの関係を出す。

なぜ先にこれをやるか: 「渦ができてスピンに影響する」を示すには渦が要るが、
30 mG の腕は渦を作っていない（`check_vortices.py`）。**新しく投げる前に、
既に位相が保存されている 19 腕を全部見る** ── Ω 0.86〜0.94 の細かい走査を
含むので、渦が立つ条件が既に手元にある可能性がある。GPU 数時間ではなく CPU 数分。

出すのは 3 列だけ:
    渦（コアと共局在した位相巻き）の最大数
    注入された L_z
    変換された F_z
これで「渦の数」と「スピンの動き」が相関するかが見える。**相関は因果ではない**が、
相関が無ければ因果は主張できない。

使い方:
  python3 runs/eu_barnett_redo/scan_vortices.py [--stride=1]
"""
import re
import sys
from pathlib import Path

import h5py
import numpy as np

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
sys.path.insert(0, str(HERE))
from check_vortices import find_vortices, selftest  # noqa: E402

STRIDE = 1
for a in sys.argv[1:]:
    if a.startswith("--stride="):
        STRIDE = int(a.split("=", 1)[1])

print("=== 判定器の校正 ===")
if not selftest():
    sys.exit("判定器が対照を通らない")


def ledger_summary(tag):
    """同じ腕の台帳から注入と変換を読む。窓は磁場が軸方向になった後。"""
    f = DATA / f"ledger_{tag}.csv"
    if not f.exists():
        return None
    d = np.genfromtxt(f, delimiter=",", names=True)
    t, Fz, Lz, Jz = d["t"], d["Fz"], d["Lz"], d["Jz"]
    # 注入 = L_z の最大値（かき混ぜの終わり）
    k = int(np.argmax(np.abs(Lz)))
    inj = Lz[k]
    # 変換 = そこから終わりまでの F_z の変化
    conv = Fz[-1] - Fz[k]
    # J_z がその窓で保存しているか（数値の質）
    m = t >= t[k]
    leak = float(np.abs(Jz[m] - Jz[k]).max())
    return inj, conv, leak, float(t[k])


rows = []
files = sorted(DATA.glob("slices_*.jld2"))
print(f"\n=== 位相を持つ腕 {len(files)} 本 ===\n")
print(f"{'arm':34s} {'渦max':>6} {'合計':>5} {'inj L_z':>8} {'conv F_z':>9} {'leak':>9}")
print("-" * 78)
for src in files:
    tag = src.stem.replace("slices_", "")
    if "smoke" in tag:
        continue
    peak, total, when = 0, 0, None
    try:
        with h5py.File(src, "r") as f:
            keys = sorted(k for k in f.keys() if k.startswith("slice_"))[::STRIDE]
            for k in keys:
                g = f[k]
                t = float(g["t"][()])
                raw = g["psi"][()]
                psi = raw["re"].astype(np.float64) + 1j * raw["im"].astype(np.float64)
                n_all = float((np.abs(psi) ** 2).sum())
                here = 0
                for mi in range(psi.shape[0]):
                    if (np.abs(psi[mi]) ** 2).sum() / n_all < 1e-4:
                        continue
                    _, c, _ = find_vortices(psi[mi])
                    here += c
                total += here
                if here > peak:
                    peak, when = here, t
    except Exception as e:  # noqa: BLE001
        print(f"{tag:34s} 読めない: {str(e)[:30]}")
        continue
    led = ledger_summary(tag)
    if led:
        inj, conv, leak, tq = led
        print(f"{tag:34s} {peak:6d} {total:5d} {inj:+8.3f} {conv:+9.3f} {leak:9.1e}")
        rows.append((tag, peak, total, inj, conv, leak))
    else:
        print(f"{tag:34s} {peak:6d} {total:5d} {'台帳なし':>8}")
print("-" * 78)

if not rows:
    sys.exit("\n台帳と対応する腕が無い")

peaks = np.array([r[1] for r in rows], float)
convs = np.array([r[4] for r in rows], float)
injs = np.array([r[3] for r in rows], float)

print(f"\n渦が 1 つ以上立った腕: {int((peaks > 0).sum())} / {len(rows)}")
if (peaks > 0).sum() == 0:
    print("\n⇒ **位相を持つ全ての腕で渦が立っていない。**")
    print("   判定器は陽性対照を通っているので「見えていない」ではない。")
    print("   ⇒ 『渦ができてスピンに影響する』は、この protocol の現行パラメータでは")
    print("      示せない。渦を立てる条件を変えた新しい腕が必要（下の考察）。")
else:
    # 渦の数と変換の相関。**相関が無ければ因果は主張できない**
    if len(rows) >= 4 and peaks.std() > 0 and convs.std() > 0:
        r = float(np.corrcoef(peaks, convs)[0, 1])
        print(f"渦の総数 と conv F_z の相関: r = {r:+.3f}  (n = {len(rows)})")
        r2 = float(np.corrcoef(np.abs(injs), convs)[0, 1])
        print(f"注入 |L_z| と conv F_z の相関: r = {r2:+.3f}  ← 渦を経由しない経路")
        print("\n★どちらの相関が強いかが問い。渦の方が強ければ渦が経路の候補、")
        print("  注入の方が強ければ渦は付随物で、経路は別（非回転流）。")
