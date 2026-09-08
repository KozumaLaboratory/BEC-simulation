"""密度の窪みが見える動画。新規計算ゼロ — 既存の柱密度を割り直して印を付けるだけ。

**窪みは渦ではない** (FINDINGS.md M17: 巻き数との重なり 0.0 %)。フィラメント間の隙間。

なぜ生の柱密度では見えないか（FINDINGS.md M19/M21/M22）:
  窪みは低密度の外殻（r >= 4）にあり、そこは柱密度でも既に暗い。さらに z 積分
  （120 セル / 18 a_ho）が平滑化して、中面で背景の 0.161 まで落ちる窪みが
  柱密度では 0.719 止まりになる。

正規化: q = n / smooth(n, k)。局所背景で割るので、暗い外殻の窪みも明るい中心の
窪みと同じスケールで出る。

  * 方位平均で割るのは誤り: 雲が磁歪で楕円なので短軸側が丸ごと「穴」に見え、
    t=0 の対照で 1008 セルが 0.5 未満になった。
  * k はコア直径 2.6 セル(=2 xi_n) より広く、雲の外形より狭く選ぶ。対照で決定:
    k=6 は t=0 で q<0.8 が 0 セル / k=12 で 76 / k=20 で 356（外形が漏れる）。

表示で二度失敗したので、両方ここに書いておく:

  1. レンジを [0.62, 1.04] にした。実データの 99% は [0.78, 1.23]、中央値 0.996 で、
     雲全体が上端に張り付き 25% が飽和した。1.0 を中心に対称に取る。
  2. 窪みは雲の面積の 1.03% しかなく、1 セル = 表示 2.6 px なので colormap だけでは
     見えない。検出した極小に明示的に丸を打つ。
"""
import h5py, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.animation import FFMpegWriter

SRC = 'data/colmaps_plus_movie_prod_box35.jld2'
K = 6                  # 平滑回数。対照で選定
QSPAN = 0.30           # 表示は 1 +- QSPAN。実データの 1/99 分位が 0.78/1.23
QMARK = 0.82           # ここより深い極小に印。t=0 の対照で 0 個になる値
CROP = 14.0            # a_ho


def box(a, k):
    o = a.astype(np.float64)
    for _ in range(k):
        o = (o + np.roll(o, 1, 0) + np.roll(o, -1, 0)
             + np.roll(o, 1, 1) + np.roll(o, -1, 1)) / 5.0
    return o


def normalized(n):
    bg = box(n, K)
    m = bg > 0.05 * bg.max()
    return np.where(m, n / np.maximum(bg, 1e-30), np.nan), m


def sites(q, x, thr=QMARK, rmin=3):
    """thr より深いセルを近傍でまとめ、各クラスタの最深点を 1 個の印にする。
    3 セル広がる 1 個の窪みに 3 個の丸を打たないため。"""
    cand = np.argwhere(np.nan_to_num(q, nan=9.0) < thr)
    if not len(cand):
        return np.empty((0, 2)), np.empty(0)
    order = np.argsort([q[i, j] for i, j in cand])
    keep = []
    for i, j in cand[order]:
        if all((i - a) ** 2 + (j - b) ** 2 >= rmin ** 2 for a, b in keep):
            keep.append((i, j))
    keep = np.array(keep)
    # axis0 = y, axis1 = x  (h5py が Julia の (nx,ny) を反転して返す。校正は
    # ledger の L_z 符号: FINDINGS.md §5 / issue #498 §5)
    return np.stack([x[keep[:, 1]], x[keep[:, 0]]], 1), np.array([q[i, j] for i, j in keep])


f = h5py.File(SRC, 'r')
x = f['x'][:]
t = f['t'][:]
om = float(f['omega'][()])
t_stir = float(f['t_stir'][()])
t_quench = float(f['t_quench'][()])
sel = np.abs(x) <= CROP
xs = x[sel]
ext = [xs[0], xs[-1], xs[0], xs[-1]]

# 対照: t=0 に印が出たら閾値か k が緩い
q0, m0 = normalized(f['n_col'][0].astype(np.float64))
p0, _ = sites(q0, x)
assert len(p0) == 0, f"control failed: t=0 marked {len(p0)} sites (K={K}, QMARK={QMARK})"
print(f"control OK: t=0 marks 0 sites   (q_min={np.nanmin(q0[m0]):.4f})")

fig, ax = plt.subplots(1, 2, figsize=(12.8, 6.4), dpi=100)
fig.patch.set_facecolor('#0d0d11')
for a in ax:
    a.set_facecolor('#0d0d11')
    a.set_xlabel(r'$x\ [a_{ho}]$', color='#c8c8d0')
    a.tick_params(colors='#8a8a96', labelsize=8)
    for s in a.spines.values():
        s.set_color('#3a3a44')
ax[0].set_ylabel(r'$y\ [a_{ho}]$', color='#c8c8d0')

n0 = f['n_col'][0].astype(np.float64)
im0 = ax[0].imshow(n0[np.ix_(sel, sel)] * 1e4, origin='lower', extent=ext,
                   cmap='magma', vmin=0, vmax=float(n0.max()) * 1e4)
im1 = ax[1].imshow(q0[np.ix_(sel, sel)], origin='lower', extent=ext,
                   cmap='RdBu_r', vmin=1 - QSPAN, vmax=1 + QSPAN)
mk, = ax[1].plot([], [], 'o', mfc='none', mec='#00ff9c', mew=1.4, ms=11)
mk0, = ax[0].plot([], [], 'o', mfc='none', mec='#00ff9c', mew=1.0, ms=11, alpha=0.55)

ax[0].set_title(r'column density  $n_{col}\times10^{4}$', color='#e8e8f0', fontsize=11)
ax[1].set_title(rf'$n_{{col}}/\langle n_{{col}}\rangle_{{local}}$  ($k$={K}),  '
                rf'depletions $<${QMARK} circled (not vortices)', color='#e8e8f0', fontsize=11)
for im, a in ((im0, ax[0]), (im1, ax[1])):
    cb = fig.colorbar(im, ax=a, fraction=0.046, pad=0.03)
    cb.ax.tick_params(colors='#8a8a96', labelsize=7)
    cb.outline.set_edgecolor('#3a3a44')

sup = fig.suptitle('', color='#e8e8f0', fontsize=12)
note = fig.text(0.5, 0.014, '', ha='center', color='#7a7a86', fontsize=8)
fig.tight_layout(rect=[0, 0.035, 1, 0.94])


def stage(tt):
    if tt < 5:  return 'tilt 0->35 deg'
    if tt < 10: return f'spin-up  ->  Omega={om}'
    if tt < t_stir + 10: return f'steady rotation  Omega={om}'
    if tt < t_quench:    return 'hold'
    return 'after quench'


def draw(i):
    n = f['n_col'][i].astype(np.float64)
    q, _ = normalized(n)
    pts, dep = sites(q, x)
    im0.set_data(n[np.ix_(sel, sel)] * 1e4)
    im0.set_clim(0, float(n.max()) * 1e4)
    im1.set_data(q[np.ix_(sel, sel)])
    inb = (np.abs(pts[:, 0]) <= CROP) & (np.abs(pts[:, 1]) <= CROP) if len(pts) else np.zeros(0, bool)
    p = pts[inb] if len(pts) else np.empty((0, 2))
    mk.set_data(p[:, 0], p[:, 1])
    mk0.set_data(p[:, 0], p[:, 1])
    sup.set_text(f'$t$ = {t[i]:6.2f} $\\omega_{{ref}}^{{-1}}$  ({t[i] / 0.6283:6.1f} ms)'
                 f'      {stage(t[i])}')
    note.set_text(f'{len(p)} depletions below {QMARK} of local background'
                  f'     deepest = {dep.min():.3f}' if len(dep) else
                  f'0 depletions below {QMARK} of local background')


if __name__ == '__main__':
    import sys
    mode = sys.argv[1] if len(sys.argv) > 1 else 'movie'
    if mode == 'still':
        for i in (0, 200, 300, 400):
            draw(i)
            fig.savefig(f'/tmp/hole_still_{i:03d}.png', facecolor=fig.get_facecolor())
            print(f'  t={t[i]:6.2f} -> /tmp/hole_still_{i:03d}.png')
    else:
        fps = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        out = sys.argv[3] if len(sys.argv) > 3 else f'holes_{fps}fps.mp4'
        w = FFMpegWriter(fps=fps, bitrate=6000,
                         metadata={'title': f'density depletion (not vortices), Omega={om}'})
        with w.saving(fig, out, dpi=100):
            for i in range(len(t)):
                draw(i)
                w.grab_frame()
                if i % 200 == 0:
                    print(f'  {i}/{len(t)}', flush=True)
        print(f'wrote {out}  ({len(t)} frames, {fps} fps, {len(t) / fps:.1f} s)')
