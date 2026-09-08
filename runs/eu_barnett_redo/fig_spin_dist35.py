"""theta=35 に偏極したときの m 分布 (一枚).

傾け終了直後の状態。m=-6 から断熱に傾けた結果で、z 基底では広がって見えるが
これは幾何であって脱偏極ではない: 局所 |<F>|/F = 1.00000 のまま。

実測分布は「実測の傾き角 beta でのスピンコヒーレント状態」の二項分布と
rms 0.001 % で一致する。つまり 13 個の人口は独立ではなく、beta ひとつで決まる。
比較の基準を「35 度」と決め打ちしないこと — スピンは場に遅れて実際は 38.7 度。
"""
import h5py, numpy as np, math, sys, matplotlib
from math import comb
matplotlib.use('Agg')
import matplotlib.pyplot as plt

F = 6
SRC = 'slices_plus_gf35_om080_prod_box35.jld2'
SLICE = 3                       # 傾け完了直後 (t = 10 omega_ref^-1 = 16 ms)
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'


def mats(F):
    d = int(2 * F + 1)
    m = np.arange(F, -F - 1, -1.0)
    sp = np.zeros((d, d))
    for i in range(1, d):
        sp[i - 1, i] = np.sqrt(F * (F + 1) - m[i] * (m[i] + 1))
    return (sp + sp.T) / 2, (sp - sp.T) / (2j), np.diag(m)


Fx, Fy, Fz = mats(F)
h = h5py.File(SRC, 'r')
g = h[f'slice_{SLICE:03d}']
a = g['psi'][:]
psi = a['re'] + 1j * a['im']
t = float(g['t'][()])

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
tilt = math.degrees(math.pi - beta)

c2, s2 = math.cos(beta / 2) ** 2, math.sin(beta / 2) ** 2
pred = np.array([comb(2 * F, F - m) * c2 ** (F + m) * s2 ** (F - m)
                 for m in range(F, -F - 1, -1)])
pred /= pred.sum()
rms = float(np.sqrt(((pops - pred) ** 2).mean())) * 100

ms = np.arange(F, -F - 1, -1)
fig, ax = plt.subplots(figsize=(9.2, 5.8), dpi=110)
fig.patch.set_facecolor(BG)
bars = ax.bar(ms, pops * 100, 0.68, color='#c0392b', edgecolor='white', lw=0.8)
for m, p in zip(ms, pops):
    if p > 0.004:
        ax.text(m, p * 100 + 0.7, f'{p * 100:.1f}', ha='center', color='#8c2a20',
                fontsize=11, weight='bold')

ax.set_xticks(ms)
ax.set_xlabel(r'magnetic sublevel  $m$', color=FG, fontsize=13)
ax.set_ylabel('population  [%]', color=FG, fontsize=13)
ax.set_title(rf'$\theta = 35^\circ$', color=FG, fontsize=14)
ax.set_facecolor('#fcfcfe')
ax.tick_params(colors='#55555f', labelsize=11)
ax.grid(alpha=0.28, color='#c0c0ca', axis='y')
for s in ax.spines.values():
    s.set_color(GRID)
ax.set_ylim(0, max(pops) * 100 * 1.22)

fig.tight_layout()
out = sys.argv[1] if len(sys.argv) > 1 else 'spin_dist35.png'
fig.savefig(out, facecolor=BG, bbox_inches='tight')
print(f'wrote {out}   beta={tilt:.2f} deg  |F|/F={locm:.5f}  residual rms={rms:.4f}%')
print('  ' + '  '.join(f'm={m:+d}:{p*100:.2f}%' for m, p in zip(ms, pops) if p > 1e-4))
