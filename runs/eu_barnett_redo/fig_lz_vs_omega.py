"""注入 L_z を回転速度 Omega に対してプロットする (theta=90, 共通時刻 t=38).

読むときの注意: 閾値の下では L_z は振動して戻るので、ここに描いた「t=38 の値」は
いつ切ったかに依存する (FINDINGS.md M9)。窓の中 (Omega ~ 0.85-0.95) では単調成長
しているので終端値と最大値がほぼ一致するが、窓の外では最大値の方が大きい。
形の解釈を窓の外まで延ばさないこと。

theta=90 は PROTOCOL=sudden で THETA_GS = THETA = 90、つまり最初から面内
(Fz(0) = 0)。これは設計どおりでバグではない。台帳の Fz(0) で検証している。
"""
import numpy as np, pathlib, sys, matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

TC = 38.0
OMS = [0.55, 0.60, 0.65, 0.70, 0.74, 0.80, 0.85, 0.90, 0.95, 1.00, 1.10, 1.20]
PAT = 'ledger_plus_om{:03d}_prod_box35.csv'
FG, BG, GRID = '#1a1a1f', '#ffffff', '#c8c8d0'

om, lz = [], []
for o in OMS:
    p = pathlib.Path(PAT.format(int(round(o * 100))))
    assert p.exists(), f'missing {p}'
    d = np.genfromtxt(p, delimiter=',', names=True)
    assert abs(d['Fz'][0]) < 0.02, f'{p}: Fz(0)={d["Fz"][0]:.3f}, not the theta=90 protocol'
    t = d['t']
    assert t[-1] >= TC - 1, f'{p}: ends at t={t[-1]:.1f}, before t={TC}'
    m = t <= TC + 0.5
    om.append(o)
    lz.append(float(d['Lz'][m][-1]))
om, lz = np.array(om), np.array(lz)
print(f'control OK: {len(om)} arms, all with Fz(0) = 0 and reaching t = {TC}')

fig, ax = plt.subplots(figsize=(8.4, 5.8), dpi=110)
fig.patch.set_facecolor(BG)
ax.plot(om, lz, 'o-', color='#2e6fb7', lw=2.4, ms=9, mfc='#2e6fb7', mec='white', mew=1.4)

k = int(np.argmax(lz))
ax.annotate(rf'$\Omega$ = {om[k]:.2f},   $L_z$ = {lz[k]:.1f}$\,\hbar$',
            xy=(om[k], lz[k]), xytext=(14, -4), textcoords='offset points',
            color='#2e6fb7', fontsize=13, weight='bold', va='center')
ax.axvline(1 / np.sqrt(2), color='#8a8a92', lw=1.3, ls='--')
ax.text(1 / np.sqrt(2) - 0.012, 0.97, r'$\omega_\perp/\sqrt{2}=0.707$', color='#66666f',
        fontsize=11, transform=ax.get_xaxis_transform(), va='top', ha='right')

ax.set_xlabel(r'rotation rate  $\Omega\ [\omega_\perp]$', color=FG, fontsize=13)
ax.set_ylabel(r'injected  $L_z$  per atom  $[\hbar]$', color=FG, fontsize=13)
ax.set_title(rf'$\theta = 90^\circ$,  measured at $t = {TC:.0f}\ \omega_{{ref}}^{{-1}}$ '
             rf'({TC / 0.6283:.0f} ms)', color=FG, fontsize=13)
ax.set_facecolor('#fcfcfe')
ax.tick_params(colors='#55555f', labelsize=11)
ax.grid(alpha=0.28, color='#c0c0ca')
for s in ax.spines.values():
    s.set_color(GRID)
ax.set_ylim(0, max(lz) * 1.12)

fig.tight_layout()
out = sys.argv[1] if len(sys.argv) > 1 else 'lz_vs_omega.png'
fig.savefig(out, facecolor=BG, bbox_inches='tight')
print(f'wrote {out}   peak at Omega={om[k]:.2f}, Lz={lz[k]:.2f}')
