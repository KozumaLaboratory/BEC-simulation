#!/usr/bin/env python3
"""
Paper #3 FIG-2: Sign Pattern prefactor β_S^(λ_spin) / β_S^(c0) vs S
across F = 3, 4, 6, 8, 10, 12. Vertical lines mark S_bd = sqrt(2F(F+1))
where the prefactor changes sign (Sign Pattern Lemma 2).
"""
import csv
import matplotlib.pyplot as plt
import numpy as np

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)

F_vals = sorted(set(int(r['F']) for r in rows))
fig, ax = plt.subplots(figsize=(6.5, 4.5))
colors = plt.cm.viridis(np.linspace(0, 0.85, len(F_vals)))

for k, F in enumerate(F_vals):
    sub = [r for r in rows if int(r['F']) == F]
    S = np.array([int(r['S']) for r in sub])
    pre = np.array([float(r['prefactor_lambda_over_c0']) for r in sub])
    S_bd = float(sub[0]['sign_boundary_S_bd'])
    ax.plot(S, pre, 'o-', color=colors[k], lw=1.5, ms=6,
            label=f'F={F} (S_bd={S_bd:.2f})')
    ax.axvline(S_bd, ls=':', color=colors[k], alpha=0.5, lw=0.8)

ax.axhline(0, color='black', lw=0.8, alpha=0.5)
ax.set_xlabel('Total spin channel S', fontsize=11)
ax.set_ylabel(r'$\beta_S^{(\lambda_{\rm spin})} / \beta_S^{(c_0)}$',
              fontsize=11)
ax.set_title('Sign Pattern Lemma 2: single sign change at $S_{\rm bd} = \sqrt{2F(F+1)}$',
             fontsize=11)
ax.legend(loc='best', fontsize=8, ncol=2)
ax.grid(alpha=0.3)
plt.tight_layout()
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
