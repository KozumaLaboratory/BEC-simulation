"""窪みが渦かどうかを拡大して確定させる図.

パネルを小さく描くと確定できない: コア直径は 2*xi_n = 2.6 セルで、24 a_ho を 140 px
で描くと表示 2 px になる。ここでは +-3 a_ho (41 セル) を 500 px で描くので 1 セル
12 px。

判定は密度だけでは付かない。渦なら位相が 2pi 巻く。巻かない密度極小は
フィラメント間の暗いレーンであって渦ではない。だから
  左  : 総密度
  中  : 最大人口成分の位相
  右  : プラケットごとの巻き数
を同じ領域で並べ、|w|=1 の位置に印を打つ。

軸順は h5py が Julia の (nx,ny,nc) を (nc,ny,nx) で返すので axis0=y, axis1=x。
校正は ledger の L_z 符号 (FINDINGS.md §5 / issue #498 §5)。
"""
import h5py, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

SRC = 'slices_plus_pk_s30_om092_prod_box35.jld2'
HALF = 3.0          # a_ho。片側
K = 6


def box(a, k):
    o = a.astype(np.float64)
    for _ in range(k):
        o = (o + np.roll(o, 1, 0) + np.roll(o, -1, 0)
             + np.roll(o, 1, 1) + np.roll(o, -1, 1)) / 5.0
    return o


def wmap(ph):
    d = lambda a, b: np.angle(np.exp(1j * (a - b)))
    return np.rint((d(ph[1:, :-1], ph[:-1, :-1]) + d(ph[1:, 1:], ph[1:, :-1])
                    + d(ph[:-1, 1:], ph[1:, 1:]) + d(ph[:-1, :-1], ph[:-1, 1:]))
                   / (2 * np.pi)).astype(int)


h = h5py.File(SRC, 'r')
x = h['x'][:]
om = float(h['omega'][()])
dx = x[1] - x[0]

rows = []
for i in (5, 7):                      # t = 20, 30
    g = h[f'slice_{i:03d}']
    a = g['psi'][:]
    psi = a['re'] + 1j * a['im']
    t = float(g['t'][()])
    n = (np.abs(psi) ** 2).sum(0)
    bg = box(n, K)
    m = bg > 0.05 * bg.max()
    q = np.where(m, n / np.maximum(bg, 1e-30), 9.0)
    jy, jx = np.unravel_index(np.argmin(q), q.shape)
    half = int(HALF / dx)
    sy = slice(jy - half, jy + half + 1)
    sx = slice(jx - half, jx + half + 1)
    c = int(np.argmax([(np.abs(psi[cc]) ** 2).sum() for cc in range(13)]))
    w = wmap(np.angle(psi[c]))
    rows.append(dict(t=t, n=n[sy, sx], ph=np.angle(psi[c])[sy, sx],
                     w=w[sy, sx], q=q[sy, sx], m=6 - c,
                     ext=[x[sx][0], x[sx][-1], x[sy][0], x[sy][-1]]))

fig, ax = plt.subplots(2, 3, figsize=(16.5, 11.0), dpi=100)
fig.patch.set_facecolor('#08080b')

for r, d in enumerate(rows):
    ref = np.percentile(d['n'], 95)
    A, B, C = ax[r]
    A.imshow(d['n'] / ref, origin='lower', extent=d['ext'], cmap='inferno',
             vmin=0, vmax=1.2, interpolation='nearest')
    B.imshow(d['ph'], origin='lower', extent=d['ext'], cmap='twilight_shifted',
             vmin=-np.pi, vmax=np.pi, interpolation='nearest')
    C.imshow(np.clip(d['w'], -1, 1), origin='lower', extent=d['ext'],
             cmap='bwr', vmin=-1, vmax=1, interpolation='nearest')

    xs = np.linspace(d['ext'][0], d['ext'][1], d['w'].shape[1])
    ys = np.linspace(d['ext'][2], d['ext'][3], d['w'].shape[0])
    jj, ii = np.where(d['w'] != 0)
    npos = int((d['w'] > 0).sum()); nneg = int((d['w'] < 0).sum())
    for P in (A, B, C):
        P.plot(xs[ii], ys[jj], 'o', mfc='none', mec='#00ff9c', mew=1.6, ms=16)

    A.set_title(rf'$t$={d["t"]:.0f}   total density'
                f'\ndeepest here = {d["q"].min():.3f} of local background',
                color='#e8e8f0', fontsize=11)
    B.set_title(f'phase of $m$={d["m"]:+d}  (largest population)'
                '\na vortex = one full colour wheel around a point',
                color='#e8e8f0', fontsize=11)
    C.set_title(f'plaquette winding:  {npos} of $+1$,  {nneg} of $-1$'
                '\ncircles mark every $|w|=1$', color='#e8e8f0', fontsize=11)
    for P in (A, B, C):
        P.set_facecolor('#08080b')
        P.set_xlabel(r'$x\ [a_{ho}]$', color='#c8c8d0', fontsize=9)
        P.tick_params(colors='#8a8a96', labelsize=8)
        for s_ in P.spines.values():
            s_.set_color('#33333d')
    A.set_ylabel(r'$y\ [a_{ho}]$', color='#c8c8d0')

fig.suptitle(rf'is a depletion a vortex?   $\Omega$={om}, $\theta=90^\circ$,  '
             rf'zoom $\pm${HALF} $a_{{ho}}$ = {rows[0]["n"].shape[0]} cells  '
             r'(core diameter $2\xi_n$ = 2.6 cells)',
             color='#e8e8f0', fontsize=14)
fig.tight_layout(rect=[0, 0, 1, 0.945])
fig.savefig('vortex_zoom.png', facecolor=fig.get_facecolor(), bbox_inches='tight')
print('wrote vortex_zoom.png')
for d in rows:
    print(f"  t={d['t']:.0f}  zoom {d['n'].shape}  windings "
          f"+{int((d['w']>0).sum())}/-{int((d['w']<0).sum())}  "
          f"q_min={d['q'].min():.4f}")
