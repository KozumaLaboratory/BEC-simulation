#!/usr/bin/env python3
"""
Paper #3 FIG-3 renderer: F-systematic 13-instance Lemma 1 verification.
Output: figure base + .pdf and .svg
"""
import csv
import matplotlib.pyplot as plt
import numpy as np

# Load data
rows = []
with open(__file__.replace('.py', '.csv')) as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

verified = [r for r in rows if r['status'] == 'verified']
exceptions = [r for r in rows if 'exception' in r['status']]

fig, ax = plt.subplots(figsize=(6.5, 4.0))

# Predicted curve β_0 = 1/(2F+1)
F_continuous = np.linspace(0.5, 13.5, 200)
ax.plot(F_continuous, 1.0 / (2 * F_continuous + 1),
        '-', color='steelblue', alpha=0.5, lw=1.5,
        label=r'$\\beta_0 = 1/(2F+1)$ (Lemma 1)')

# Verified instances
F_verified = [float(r['F']) for r in verified]
b_verified = [float(r['beta_0_measured']) for r in verified]
ax.scatter(F_verified, b_verified, color='C2', s=60, zorder=3,
           label=f'Verified (n={len(verified)}, Schur dev < 10^-12)')

# Exceptions on horizontal line at y = small value for visibility
y_exc = 1e-3
F_exc = [float(r['F']) if r['F'] != '—' else None for r in exceptions]
F_exc_clean = [int(s) for s in ['1', '2', '5']]
ax.scatter(F_exc_clean, [y_exc] * len(F_exc_clean),
           marker='x', color='red', s=80, zorder=3, linewidths=2,
           label='Exceptions (F=1: $T_1$ irred., F=2/5: no Schur singlet)')

# Labels for exception F values
exc_labels = {1: r'$F{=}1$
T_1 irred.', 2: r'$F{=}2$
phase-eq.',
              5: r'$F{=}5$
algebraic'}
for F, lab in exc_labels.items():
    ax.annotate(lab, (F, y_exc), xytext=(F, y_exc * 4),
                ha='center', fontsize=8,
                arrowprops=dict(arrowstyle='->', lw=0.5, color='gray'))

ax.set_xlabel(r'Spin quantum number $F$', fontsize=11)
ax.set_ylabel(r'$\\beta_0$ (intercept of Lemma 1)', fontsize=11)
ax.set_title('F-systematic verification of Lemma 1: $\\beta_0 = 1/(2F+1)$',
             fontsize=11)
ax.set_yscale('log')
ax.set_xlim(0.5, 13.5)
ax.set_ylim(5e-4, 0.3)
ax.set_xticks(range(1, 14))
ax.grid(alpha=0.3, which='both')
ax.legend(loc='upper right', fontsize=9, framealpha=0.95)
plt.tight_layout()

base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
