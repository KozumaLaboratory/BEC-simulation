"""密度の窪みの出現と、その Omega 依存.

**これは渦ではない。** 巻き数の位置と窪みの位置の重なりは 0.0 % (FINDINGS.md M17)。
正体はフィラメント化 — 明るい筋とその間の暗いレーン。

主張は 3 つで、どれも同じ 10 本のランから出る:
  1. 窪みは t=10 で一斉に現れる。tilt(5) + spinup(5) が終わって定常回転が始まる時刻。
     t=0 と t=5 は 10 本すべてで厳密に 0 セルなので、対照が 2 時刻ある。
  2. 深さは局所背景の 0.04-0.08 まで達する(96% 欠乏)。柱密度では 0.68 止まりで、
     これが「動画に穴が見えない」理由 (FINDINGS.md M19)。ただし埋められているのは
     渦コアではなくフィラメント間の隙間。
  3. この Omega 帯では低い方が早く核生成する(t=15 で Om=0.86 が 382 セル、
     0.94 が 36)。lambda のピークが 0.80 にあることと整合。

表示スケール: 各パネルを自分の 95 分位で規格化する。t=30 の中面は密度が細い筋に
集中していて中央値が最大の 0.088 しかなく、0..max の線形では全部潰れる。
"""
import h5py, numpy as np, glob, re, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OMS = [0.86, 0.88, 0.90, 0.92, 0.94]
TCOL = [0, 10, 15, 30]
CROP = 12.0
K = 6
VMAX = 1.15


def box(a, k):
    o = a.astype(np.float64)
    for _ in range(k):
        o = (o + np.roll(o, 1, 0) + np.roll(o, -1, 0)
             + np.roll(o, 1, 1) + np.roll(o, -1, 1)) / 5.0
    return o


def load(om, stir=30):
    return h5py.File(f'slices_plus_pk_s{stir}_om{int(om * 100):03d}_prod_box35.jld2', 'r')


def frame(h, tw):
    ts = h['t'][:]
    i = int(np.argmin(np.abs(ts - tw))) + 1
    g = h[f'slice_{i:03d}']
    a = g['psi'][:]
    psi = a['re'] + 1j * a['im']
    n = (np.abs(psi) ** 2).sum(0)
    bg = box(n, K)
    m = bg > 0.05 * bg.max()
    q = np.where(m, n / np.maximum(bg, 1e-30), np.nan)
    return float(g['t'][()]), n, q


x = load(0.92)['x'][:]
sel = np.abs(x) <= CROP
ext = [x[sel][0], x[sel][-1]] * 2

fig = plt.figure(figsize=(17.5, 12.2), dpi=100)
fig.patch.set_facecolor('#08080b')
gs = fig.add_gridspec(6, 4, height_ratios=[1, 1, 1, 1, 1, 1.5], hspace=0.09, wspace=0.05)

for r, om in enumerate(OMS):
    h = load(om)
    for c, tw in enumerate(TCOL):
        t, n, q = frame(h, tw)
        ref = np.percentile(n[n > 0.02 * n.max()], 95)
        A = fig.add_subplot(gs[r, c])
        A.imshow(n[np.ix_(sel, sel)] / ref, origin='lower', extent=ext,
                 cmap='inferno', vmin=0, vmax=VMAX, interpolation='nearest')
        nd = int(np.nansum(q < 0.5))
        A.set_facecolor('#08080b')
        A.set_xticks([]); A.set_yticks([])
        for s_ in A.spines.values():
            s_.set_color('#33333d')
        if r == 0:
            A.set_title(f'$t$ = {t:.0f}   ({t / 0.6283:.0f} ms)',
                        color='#e8e8f0', fontsize=12, pad=8)
        if c == 0:
            A.set_ylabel(rf'$\Omega$ = {om}', color='#e8e8f0', fontsize=12)
        A.text(0.035, 0.93, f'{nd}' if nd else '0', transform=A.transAxes,
               color='#00ff9c' if nd else '#55555f', fontsize=11, weight='bold',
               va='top', ha='left')

B = fig.add_subplot(gs[5, :2])
for om in OMS:
    h = load(om)
    ts, cs = [], []
    for i in range(1, int(h['n_slices'][()]) + 1):
        g = h[f'slice_{i:03d}']
        a = g['psi'][:]
        psi = a['re'] + 1j * a['im']
        n = (np.abs(psi) ** 2).sum(0)
        bg = box(n, K); m = bg > 0.05 * bg.max()
        q = np.where(m, n / np.maximum(bg, 1e-30), np.nan)
        ts.append(float(g['t'][()])); cs.append(int(np.nansum(q < 0.5)))
    B.plot(ts, cs, 'o-', ms=5, lw=1.8, label=rf'$\Omega$={om}')
B.axvspan(0, 10, color='#ffffff', alpha=0.05)
B.text(5, B.get_ylim()[1] * 0.92, 'tilt + spin-up', color='#8a8a96',
       fontsize=9, ha='center')
B.set_xlabel(r'$t\ [\omega_{ref}^{-1}]$', color='#c8c8d0')
B.set_ylabel('cells below 0.5 of local background', color='#c8c8d0', fontsize=10)
B.legend(frameon=False, labelcolor='#c8c8d0', fontsize=9, ncol=2)

C = fig.add_subplot(gs[5, 2:])
for om in OMS:
    h = load(om)
    ts, ds = [], []
    for i in range(1, int(h['n_slices'][()]) + 1):
        g = h[f'slice_{i:03d}']
        a = g['psi'][:]
        psi = a['re'] + 1j * a['im']
        n = (np.abs(psi) ** 2).sum(0)
        bg = box(n, K); m = bg > 0.05 * bg.max()
        q = np.where(m, n / np.maximum(bg, 1e-30), np.nan)
        ts.append(float(g['t'][()])); ds.append(float(np.nanmin(q)))
    C.plot(ts, ds, 'o-', ms=5, lw=1.8, label=rf'$\Omega$={om}')
C.axhline(0.719, color='#ff9c6c', ls='--', lw=1.6)
C.text(30, 0.745, 'deepest the COLUMN density ever reaches',
       color='#ff9c6c', fontsize=9, ha='right')
C.set_xlabel(r'$t\ [\omega_{ref}^{-1}]$', color='#c8c8d0')
C.set_ylabel('deepest depletion  $n/\\langle n\\rangle_{local}$',
             color='#c8c8d0', fontsize=10)
C.set_ylim(0, 1.0)

for P in (B, C):
    P.set_facecolor('#0d0d11')
    P.tick_params(colors='#8a8a96', labelsize=9)
    P.grid(alpha=0.12, color='#8a8a96')
    for s_ in P.spines.values():
        s_.set_color('#33333d')

fig.suptitle(r'density depletions in the mid-plane,  $\theta = 90^\circ$,  stir 30 — '
             r'numbers are cells below half the local background.  '
             r'$t\leq5$ is empty in all ten runs (control).  '
             r'These are NOT vortices: the phase windings do not sit on them (0 % overlap).',
             color='#e8e8f0', fontsize=14, y=0.925)
fig.savefig('vortex_onset.png', facecolor=fig.get_facecolor(), bbox_inches='tight')
print('wrote vortex_onset.png')
