"""theta = 35 度、GS 修正後 (m=-6 から断熱に傾ける) の一枚図.

上段  : 共鳴アーム (Omega=0.80) の柱密度スナップショット
下段左: L_z(t) — 5 つの Omega
下段右: F_z(t) と |<F>|(t) — 磁化

読み方の核:
  * 傾けは断熱に効いている。F_z は -5.999 (m=-6) から -4.83 に落ちて平坦。
    -6 cos(35 deg) = -4.915 なので 1.3 度の遅れで場に追従しているだけ。
    |<F>| = 5.998 のまま = 完全偏極。
  * **掻き混ぜ中に磁化は動かない。それが正しい。** B が入っている間は J_z は
    保存しない (Noether は B=0 でのみ)。変換は B を切ってから起きる。
    この 5 本は t≈40 の掻き混ぜ終了で止まっており、クエンチに到達していない。
  * Omega=0.80 だけ L_z が単調に 14.5 まで伸びる。他は 5 以下で振動する。
    判別子は終端値ではなく **時系列の形** (折返し回数: 0.80 が 16、他は 19-27)。

GS バグの見分け方: 台帳の Fz(0) が -5.999 なら m=-6 (修正後)、-4.84 なら開始時に
既に 36 度傾いている (修正前)。ad35 / bs / sl35 は全部修正前 (FINDINGS.md §5)。

軸順: 配列は [y,x]。imshow(A) が正しく `.T` は鏡映で回転が逆になる。
"""
import numpy as np, pathlib, matplotlib, sys
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OMS = [0.55, 0.70, 0.80, 0.90, 1.00]
RES = 0.80
TSNAP = [0, 10, 20, 30, 40]
CROP = 13.0
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'
DENS = matplotlib.colors.LinearSegmentedColormap.from_list(
    'white_to_ink', ['#ffffff', '#ffe08a', '#f08c3c', '#c2296b', '#5c1a6b', '#14061f'])
COL = {0.55: '#9aa0a6', 0.70: '#3d8bd4', 0.80: '#d1332e', 0.90: '#2e9e5b', 1.00: '#8a63d2'}


def ledger(om):
    p = pathlib.Path(f'ledger_plus_gf35_om{int(om * 100):03d}_prod_box35.csv')
    return np.genfromtxt(p, delimiter=',', names=True) if p.exists() else None


def colmap(om):
    p = pathlib.Path(f'colmaps_plus_gf35_om{int(om * 100):03d}_prod_box35.jld2')
    if not p.exists():
        return None
    import h5py
    return h5py.File(p, 'r')


LD = {om: ledger(om) for om in OMS}
assert all(v is not None for v in LD.values()), 'missing ledger'
for om, d in LD.items():
    assert abs(d['Fz'][0] + 5.999) < 0.01, \
        f'Omega={om}: Fz(0)={d["Fz"][0]:.3f}, not m=-6 — this is a pre-GS-fix run'
print('control OK: every arm starts at m=-6  (Fz(0) = -5.999)')

H = colmap(RES) or colmap(0.55) or colmap(1.00)
SHOWN = RES if colmap(RES) else (0.55 if colmap(0.55) else 1.00)
ncol = len(TSNAP) if H is not None else 0

fig = plt.figure(figsize=(16.5, 9.6 if ncol else 5.4), dpi=110)
fig.patch.set_facecolor(BG)
if ncol:
    gs = fig.add_gridspec(2, 2, height_ratios=[1.0, 1.15], hspace=0.30, wspace=0.16)
    gtop = gs[0, :].subgridspec(1, ncol, wspace=0.05)
    x = H['x'][:]
    tt = H['t'][:]
    sel = np.abs(x) <= CROP
    ext = [x[sel][0], x[sel][-1]] * 2
    vmax = max(float(H['n_col'][int(np.argmin(np.abs(tt - s)))].max()) for s in TSNAP)
    for k, s in enumerate(TSNAP):
        i = int(np.argmin(np.abs(tt - s)))
        A = fig.add_subplot(gtop[0, k])
        A.imshow(H['n_col'][i][np.ix_(sel, sel)] * 1e4, origin='lower', extent=ext,
                 cmap=DENS, vmin=0, vmax=vmax * 1e4)
        A.set_title(f'$t$ = {tt[i]:.0f}   ({tt[i] / 0.6283:.0f} ms)', color=FG,
                    fontsize=12, pad=5)
        A.set_facecolor(BG); A.set_xticks([]); A.set_yticks([])
        for sp in A.spines.values():
            sp.set_color(GRID)
        if k == 0:
            A.set_ylabel(rf'column density,  $\Omega$={SHOWN}', color=FG, fontsize=11)
    L = fig.add_subplot(gs[1, 0]); R = fig.add_subplot(gs[1, 1])
else:
    gs = fig.add_gridspec(1, 2, wspace=0.18)
    L = fig.add_subplot(gs[0, 0]); R = fig.add_subplot(gs[0, 1])

# 初期値からの差分で描く。F_z の -6 というオフセットが変換量を隠すので。
MS = 0.6283
for om in OMS:
    d = LD[om]
    lw = 2.6 if om == RES else 1.5
    L.plot(d['t'] / MS, d['Lz'] - d['Lz'][0], color=COL[om], lw=lw, label=rf'$\Omega$={om}')
    R.plot(d['t'] / MS, d['Fz'] - d['Fz'][0], color=COL[om], lw=lw, label=rf'$\Omega$={om}')
    R.plot(d['t'] / MS, -(d['Lz'] - d['Lz'][0]), color=COL[om], lw=lw * 0.55, ls=':')

for P, ttl, yl in ((L, r'$\Delta L_z$ — injected orbital angular momentum',
                    r'$\Delta L_z$ per atom  $[\hbar]$'),
                   (R, r'$\Delta F_z$ (solid) vs $-\Delta L_z$ (dotted) — they would '
                    r'coincide if $J_z$ were conserved',
                    r'change from $t=0$, per atom  $[\hbar]$')):
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

L.text(0.02, 0.96, 'tilt', transform=L.transAxes, color='#88888f', fontsize=9, va='top')
L.text(0.11, 0.96, 'spin-up', transform=L.transAxes, color='#88888f', fontsize=9, va='top')
# 傾けだけで F_z は -6 -> -6 cos35 に動く。変換ではなく幾何。
R.axhline(6 - 6 * np.cos(np.radians(35)), color='#88888f', lw=1.0, ls='--')
R.text(0.99, 0.86, r'$6(1-\cos 35^\circ) = 1.08$   — the tilt alone, not conversion',
       transform=R.transAxes, color='#66666f', fontsize=9, ha='right')

fig.suptitle(r'$\theta = 35^\circ$, adiabatic from $m=-6$ — injection is resonant at '
             r'$\Omega \simeq 0.80$, and the magnetisation does not move during the stir '
             r'(as it must not: $J_z$ is conserved only once $B=0$).',
             color=FG, fontsize=13.5, y=0.985 if ncol else 1.02)
fig.tight_layout(rect=[0, 0.01, 1, 0.955 if ncol else 0.93])
out = sys.argv[1] if len(sys.argv) > 1 else 'theta35_summary.png'
fig.savefig(out, facecolor=BG, bbox_inches='tight')
print(f'wrote {out}   (density row: '
      + (f'Omega={SHOWN}' if ncol else 'none yet — colmaps still being written') + ')')
