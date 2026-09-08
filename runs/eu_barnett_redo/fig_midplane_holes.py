"""中面と柱密度を同じスケールで並べ、渦コアが柱密度で消える理由を見せる図.

スケールを 3 回間違えたので、選び方を書いておく。t=30 の中面は密度が細い筋に
集中していて、雲内セルの中央値が最大の 0.088 しかない。だから 0..max の線形では
ほぼ全部が暗部に潰れ、コアも背景も見分けが付かない。各パネルを **自分の 95 分位**
で割ると、bulk が中間調に来てコアが底に落ちる。

正規化 (n/smooth(n)) は中面では不要だった — 生の密度でコアが見える。柱密度では
逆に正規化しても 0.68 止まり (FINDINGS.md M19)。
"""
import h5py, numpy as np, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

SL = 'data/slices_plus_pk_s30_om092_prod_box35.jld2'
CM = 'data/colmaps_plus_movie_prod_box35.jld2'
VMAX = 1.15


def scaled(n, x, crop):
    s = np.abs(x) <= crop
    ref = np.percentile(n[n > 0.02 * n.max()], 95)
    return n[np.ix_(s, s)] / ref, [x[s][0], x[s][-1], x[s][0], x[s][-1]]


f = h5py.File(SL, 'r')
x = f['x'][:]
om = float(f['omega'][()])

fig = plt.figure(figsize=(19, 7.8), dpi=100)
fig.patch.set_facecolor('#08080b')
gs = fig.add_gridspec(2, 5, height_ratios=[1, 1.35], hspace=0.16, wspace=0.06)

for k, i in enumerate((1, 3, 4, 6, 7)):
    g = f[f'slice_{i:03d}']
    a = g['psi'][:]
    psi = a['re'] + 1j * a['im']
    t = float(g['t'][()])
    n = (np.abs(psi) ** 2).sum(0)
    v, ext = scaled(n, x, 13.0)
    A = fig.add_subplot(gs[0, k])
    A.imshow(v, origin='lower', extent=ext, cmap='inferno', vmin=0, vmax=VMAX)
    A.set_title(f'$t$={t:.0f}  ({t / 0.6283:.0f} ms)', color='#e8e8f0', fontsize=11)
    A.set_facecolor('#08080b')
    A.set_xticks([]); A.set_yticks([])
    for s_ in A.spines.values():
        s_.set_color('#33333d')

g = f['slice_007']
a = g['psi'][:]
psi = a['re'] + 1j * a['im']
n = (np.abs(psi) ** 2).sum(0)
Z = fig.add_subplot(gs[1, :3])
v, ext = scaled(n, x, 7.0)
Z.imshow(v, origin='lower', extent=ext, cmap='inferno', vmin=0, vmax=VMAX,
         interpolation='nearest')
Z.set_title(r'$t$=30 mid-plane, zoom $|x|,|y|\leq 7\,a_{ho}$  —  the dark spots are the '
            r'cores ($2\xi_n$ = 2.6 cells)', color='#e8e8f0', fontsize=12)

c = h5py.File(CM, 'r')
xc = c['x'][:]
nc = c['n_col'][300].astype(np.float64)
C = fig.add_subplot(gs[1, 3:])
vc, extc = scaled(nc, xc, 7.0)
C.imshow(vc, origin='lower', extent=extc, cmap='inferno', vmin=0, vmax=VMAX,
         interpolation='nearest')
C.set_title('column density, identical scale  —  the $z$ integral fills the cores in',
            color='#ff9c6c', fontsize=12)

for P in (Z, C):
    P.set_facecolor('#08080b')
    P.set_xlabel(r'$x\ [a_{ho}]$', color='#c8c8d0')
    P.tick_params(colors='#8a8a96', labelsize=9)
    for s_ in P.spines.values():
        s_.set_color('#33333d')
Z.set_ylabel(r'$y\ [a_{ho}]$', color='#c8c8d0')

fig.suptitle(rf'mid-plane vs column density,  $\Omega$={om},  $\theta=90^\circ$   '
             r'(every panel scaled to its own 95th percentile)',
             color='#e8e8f0', fontsize=13)
fig.savefig('midplane_holes.png', facecolor=fig.get_facecolor(), bbox_inches='tight')
print('wrote midplane_holes.png')
