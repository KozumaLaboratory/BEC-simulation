"""theta 別の一枚図。密度スナップショット + Delta L_z + Delta F_z / |<F>|.

`python3 fig_theta_summary.py 35` / `... 90`。theta=35 と 90 で同じ体裁にして
並べて比較できるようにする。両者はプロトコルが違うので、その差は CONFIG に書く:

  theta=35 : PROTOCOL=adiabatic。m=-6 から 35 度へ断熱に傾ける。GS 修正後
             (Fz(0) = -5.999)。掻き混ぜ終了 t=40 でランが終わり、変換相は無い。
  theta=90 : PROTOCOL=sudden。THETA_GS = THETA = 90 なので最初から面内
             (Fz(0) = 0)。これは設計どおりでバグではない。t=80 まで走り、
             t~37 で B が切れて変換相がある。

初期値からの差分で描く。生値だと theta=35 の F_z = -4.84 というオフセットが
変換量を隠す。差分にすると両 theta を同じ軸で比べられる。

GS バグの見分け方は台帳の Fz(0): theta=35 で -5.999 なら修正後、-4.84 なら修正前
(ad35 / bs / sl35 は全部修正前)。FINDINGS.md §0 / §5。

軸順: 配列は [y,x]。imshow(A) が正しく `.T` は鏡映で回転が逆になる。
"""
import numpy as np, pathlib, sys, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

MS = 0.6283
CROP = 13.0
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'
DENS = matplotlib.colors.LinearSegmentedColormap.from_list(
    'white_to_ink', ['#ffffff', '#ffe08a', '#f08c3c', '#c2296b', '#5c1a6b', '#14061f'])

CONFIG = {
    35: dict(oms=[0.55, 0.70, 0.80, 0.90, 1.00], res=0.80,
             led='ledger_plus_gf35_om{:03d}_prod_box35.csv',
             cmap_file='colmaps_plus_gf35_om{:03d}_prod_box35.jld2', cmap_om=0.80,
             fz0=-5.999, tsnap=[0, 10, 20, 30, 40],
             note='adiabatic from $m=-6$;  runs stop at the end of the stir, '
                  'so there is no conversion phase'),
    90: dict(oms=[0.55, 0.70, 0.80, 0.90, 1.00], res=0.90,
             led='ledger_plus_om{:03d}_prod_box35.csv',
             cmap_file='colmaps_plus_movie_prod_box35.jld2', cmap_om=0.74,
             fz0=0.0, tsnap=[0, 10, 30, 50, 80],
             note='sudden, spin starts in-plane ($F_z(0)=0$, by design);  '
                  '$B$ goes off near $t=37$, so the conversion phase is included'),
}
COL = {0.55: '#9aa0a6', 0.70: '#3d8bd4', 0.80: '#d1332e',
       0.90: '#2e9e5b', 1.00: '#8a63d2'}

TH = int(sys.argv[1]) if len(sys.argv) > 1 else 35
C = CONFIG[TH]
OMS, RES = C['oms'], C['res']

LD = {}
for om in OMS:
    p = pathlib.Path(C['led'].format(int(om * 100)))
    assert p.exists(), f'missing {p}'
    LD[om] = np.genfromtxt(p, delimiter=',', names=True)
    got = LD[om]['Fz'][0]
    assert abs(got - C['fz0']) < 0.02, \
        f'Omega={om}: Fz(0)={got:.3f}, expected {C["fz0"]:.3f} for theta={TH}'
print(f'control OK: every arm starts at Fz(0) = {C["fz0"]:+.3f}')

import h5py
cf = pathlib.Path(C['cmap_file'].format(int(C['cmap_om'] * 100)) if '{' in C['cmap_file']
                  else C['cmap_file'])
H = h5py.File(cf, 'r') if cf.exists() else None
TS = C['tsnap']

fig = plt.figure(figsize=(16.5, 9.8 if H is not None else 5.4), dpi=110)
fig.patch.set_facecolor(BG)
if H is not None:
    gs = fig.add_gridspec(2, 2, height_ratios=[1.0, 1.15], hspace=0.34, wspace=0.16)
    gtop = gs[0, :].subgridspec(1, len(TS), wspace=0.05)
    x, tt = H['x'][:], H['t'][:]
    sel = np.abs(x) <= CROP
    ext = [x[sel][0], x[sel][-1]] * 2
    vmax = max(float(H['n_col'][int(np.argmin(np.abs(tt - s)))].max()) for s in TS)
    for k, s in enumerate(TS):
        i = int(np.argmin(np.abs(tt - s)))
        A = fig.add_subplot(gtop[0, k])
        A.imshow(H['n_col'][i][np.ix_(sel, sel)] * 1e4, origin='lower', extent=ext,
                 cmap=DENS, vmin=0, vmax=vmax * 1e4)
        A.set_title(f'{tt[i] / MS:.0f} ms', color=FG, fontsize=12, pad=5)
        A.set_facecolor(BG); A.set_xticks([]); A.set_yticks([])
        for sp in A.spines.values():
            sp.set_color(GRID)
        if k == 0:
            A.set_ylabel(rf'column density,  $\Omega$={C["cmap_om"]}', color=FG, fontsize=11)
    L = fig.add_subplot(gs[1, 0]); R = fig.add_subplot(gs[1, 1])
else:
    gs = fig.add_gridspec(1, 2, wspace=0.18)
    L = fig.add_subplot(gs[0, 0]); R = fig.add_subplot(gs[0, 1])

for om in OMS:
    d = LD[om]
    lw = 2.6 if om == RES else 1.5
    L.plot(d['t'] / MS, d['Lz'] - d['Lz'][0], color=COL[om], lw=lw, label=rf'$\Omega$={om}')
    R.plot(d['t'] / MS, d['Fz'] - d['Fz'][0], color=COL[om], lw=lw, label=rf'$\Omega$={om}')
    R.plot(d['t'] / MS, d['Fmag'], color=COL[om], lw=lw * 0.55, ls=':')

for P, ttl, yl in ((L, r'$\Delta L_z$ — injected orbital angular momentum',
                    r'$\Delta L_z$ per atom  $[\hbar]$'),
                   (R, r'$\Delta F_z$ (solid)  and  $|\langle F\rangle|$ (dotted)',
                    r'per atom  $[\hbar]$')):
    for xs in (5, 10):
        P.axvline(xs / MS, color='#b8b8c2', lw=0.9, ls=':')
    P.axvspan(0, 5 / MS, color='#f0f0f4')
    P.axvspan(5 / MS, 10 / MS, color='#f7f7fa')
    P.axhline(0, color='#9a9aa4', lw=0.8)
    P.set_xlabel(r'$t$  [ms]', color=FG, fontsize=11)
    P.set_ylabel(yl, color=FG, fontsize=11)
    P.set_title(ttl, color=FG, fontsize=12)
    P.set_facecolor('#fcfcfe')
    P.tick_params(colors='#55555f', labelsize=9)
    P.grid(alpha=0.28, color='#c0c0ca')
    for sp in P.spines.values():
        sp.set_color(GRID)
    P.legend(frameon=False, labelcolor=FG, fontsize=10, ncol=2)

fig.suptitle(rf'$\theta = {TH}^\circ$ — {C["note"]}', color=FG, fontsize=13.5,
             y=0.985 if H is not None else 1.02)
fig.tight_layout(rect=[0, 0.01, 1, 0.955 if H is not None else 0.93])
out = sys.argv[2] if len(sys.argv) > 2 else f'theta{TH}_summary.png'
fig.savefig(out, facecolor=BG, bbox_inches='tight')
print(f'wrote {out}')
