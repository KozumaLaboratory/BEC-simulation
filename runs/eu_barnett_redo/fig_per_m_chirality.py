"""±Omega の m 分布を並べ、「-Omega は m=-6 が多いのか」に答える.

区別すべき 2 つの状態があり、平均の向きだけでは分けられない:
  A  m=-6 に人口が溜まっている              -> 本当に磁化している
  B  広がった分布の平均がたまたま -z を向く  -> 磁化していない

判別は局所 |<F>|/F。1 なら各点でスピンコヒーレント状態で、m 分布は傾き角
beta の二項分布で厳密に決まる（= 情報は beta ひとつ）。1 未満なら本当の脱偏極で、
そのとき初めて m 分布が独立な情報を持つ。

だから 3 段で描く:
  上  m 分布（実測）と、実測 beta でのコヒーレント状態（灰）
  中  残差 = 実測 - コヒーレント。ここに出るものだけが「分布の物理」
  下  局所 |<F>|/F と beta の時間発展

theta=35 の掻き混ぜ中は |F|/F = 1.00000 で残差 0.001 % だった（FINDINGS.md M26 系）。
クエンチ後に何が起きるかがこの図の問い。
"""
import h5py, numpy as np, math, sys, matplotlib
from math import comb
matplotlib.use('Agg')
import matplotlib.pyplot as plt

F = 6
ARMS = [('+$\\Omega$', 'slices_plus_conv35_omp_prod_box35.jld2', '#2e6fb7'),
        ('$-\\Omega$', 'slices_minus_conv35_omm_prod_box35.jld2', '#c0392b')]
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'
MS = 0.6283


def mats(F):
    d = int(2 * F + 1)
    m = np.arange(F, -F - 1, -1.0)
    sp = np.zeros((d, d))
    for i in range(1, d):
        sp[i - 1, i] = np.sqrt(F * (F + 1) - m[i] * (m[i] + 1))
    return (sp + sp.T) / 2, (sp - sp.T) / (2j), np.diag(m)


Fx, Fy, Fz = mats(F)


def coherent(beta):
    c, s = math.cos(beta / 2) ** 2, math.sin(beta / 2) ** 2
    p = np.array([comb(2 * F, F - m) * c ** (F + m) * s ** (F - m)
                  for m in range(F, -F - 1, -1)])
    return p / p.sum()


def analyse(h, i):
    g = h[f'slice_{i:03d}']
    a = g['psi'][:]
    psi = a['re'] + 1j * a['im']
    n = (np.abs(psi) ** 2).sum(0)
    tot = float((np.abs(psi) ** 2).sum())
    pops = np.array([float((np.abs(psi[c]) ** 2).sum()) / tot for c in range(2 * F + 1)])
    fx = np.einsum('cxy,cd,dxy->xy', psi.conj(), Fx, psi).real
    fy = np.einsum('cxy,cd,dxy->xy', psi.conj(), Fy, psi).real
    fz = np.einsum('cxy,cd,dxy->xy', psi.conj(), Fz, psi).real
    w = n / n.sum()
    L = np.sqrt(fx ** 2 + fy ** 2 + fz ** 2)
    with np.errstate(invalid='ignore', divide='ignore'):
        loc = np.where(n > 1e-6 * n.max(), L / np.maximum(n, 1e-300) / F, np.nan)
        cb = np.where(n > 1e-6 * n.max(), fz / np.maximum(L, 1e-300), np.nan)
    locm = float(np.nansum(np.where(np.isnan(loc), 0, loc) * w))
    beta = math.acos(max(-1, min(1, float(np.nansum(np.where(np.isnan(cb), 0, cb) * w)))))
    return float(g['t'][()]), pops, beta, locm


H = [h5py.File(a[1], 'r') for a in ARMS]
NS = [int(h['n_slices'][()]) for h in H]
ms = np.arange(F, -F - 1, -1)
print(f'slices: {NS[0]} / {NS[1]}')

fig, ax = plt.subplots(3, 2, figsize=(13.0, 12.4), dpi=110,
                       gridspec_kw=dict(height_ratios=[1.15, 0.75, 0.95], hspace=0.34))
fig.patch.set_facecolor(BG)

for k, (lab, src, col) in enumerate(ARMS):
    t, pops, beta, locm = analyse(H[k], NS[k])
    pred = coherent(beta)
    A, B = ax[0, k], ax[1, k]
    A.bar(ms - 0.19, pops * 100, 0.38, color=col, label='measured')
    A.bar(ms + 0.19, pred * 100, 0.38, color='#9a9aa4', alpha=0.8,
          label=r'coherent at measured $\beta$')
    A.set_title(rf'{lab}   $t$ = {t / MS:.0f} ms'
                '\n' rf'$\beta$ = {math.degrees(math.pi - beta):.1f}$^\circ$ from $-z$,   '
                rf'local $|\langle F\rangle|/F$ = {locm:.4f}', color=FG, fontsize=12)
    A.set_xticks(ms); A.set_xlabel('$m$', color=FG)
    A.legend(frameon=False, labelcolor=FG, fontsize=10)
    B.bar(ms, (pops - pred) * 100, 0.6, color=col)
    B.axhline(0, color='#9a9aa4', lw=0.9)
    B.set_xticks(ms); B.set_xlabel('$m$', color=FG)
    B.set_title(f'residual   (rms = {100 * np.sqrt(((pops - pred) ** 2).mean()):.3f} %)',
                color=FG, fontsize=11)
    if k == 0:
        A.set_ylabel('population  [%]', color=FG, fontsize=11)
        B.set_ylabel('measured $-$ coherent  [%]', color=FG, fontsize=11)

L, R = ax[2, 0], ax[2, 1]
for k, (lab, src, col) in enumerate(ARMS):
    ts, locs, bts, m6 = [], [], [], []
    for i in range(1, NS[k] + 1):
        t, pops, beta, locm = analyse(H[k], i)
        ts.append(t / MS); locs.append(locm)
        bts.append(math.degrees(math.pi - beta)); m6.append(pops[-1] * 100)
    L.plot(ts, locs, '-', color=col, lw=2.3, label=lab)
    R.plot(ts, bts, '-', color=col, lw=2.3, label=lab)
    R.plot(ts, m6, ':', color=col, lw=1.6)
L.axhline(1.0, color='#9a9aa4', lw=1.0, ls='--')
L.set_ylabel(r'local $|\langle F\rangle|/F$', color=FG, fontsize=11)
L.set_title('local polarisation  (1 = coherent spin at every point)', color=FG, fontsize=11)
R.set_ylabel(r'$\beta$ from $-z$ [deg]  /  $m{=}{-}6$ [%]', color=FG, fontsize=11)
R.set_title(r'tilt $\beta$ (solid) and $m=-6$ population (dotted)', color=FG, fontsize=11)
for P in (L, R):
    P.axvline(40 / MS, color='#b0b0ba', lw=1.0, ls=':')
    P.text(40 / MS, 0.02, ' $B$ off', transform=P.get_xaxis_transform(),
           color='#8a8a92', fontsize=9, va='bottom')
    P.set_xlabel(r'$t$  [ms]', color=FG, fontsize=11)
    P.legend(frameon=False, labelcolor=FG, fontsize=10)

for P in ax.ravel():
    P.set_facecolor('#fcfcfe')
    P.tick_params(colors='#55555f', labelsize=9)
    P.grid(alpha=0.25, color='#c0c0ca', axis='y')
    for s in P.spines.values():
        s.set_color(GRID)

fig.suptitle(r'$\theta = 35^\circ$, $\Omega = \pm 0.80$, adiabatic from $m=-6$ — '
             r'is the $-\Omega$ state really more magnetised, or just pointing that way?',
             color=FG, fontsize=13.5)
fig.tight_layout(rect=[0, 0, 1, 0.955])
out = sys.argv[1] if len(sys.argv) > 1 else 'per_m_chirality.png'
fig.savefig(out, facecolor=BG, bbox_inches='tight')
print(f'wrote {out}')
for k, (lab, src, col) in enumerate(ARMS):
    t, pops, beta, locm = analyse(H[k], NS[k])
    r = np.sqrt(((pops - coherent(beta)) ** 2).mean()) * 100
    print(f'  {lab:10s} t={t / MS:5.1f}ms  beta={math.degrees(math.pi - beta):5.1f}deg  '
          f'|F|/F={locm:.4f}  m=-6:{pops[-1] * 100:5.2f}%  residual={r:.3f}%')
