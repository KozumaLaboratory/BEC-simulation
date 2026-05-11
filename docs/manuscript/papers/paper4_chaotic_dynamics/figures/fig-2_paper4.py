#!/usr/bin/env python3
"""
Paper #4 FIG-2: σ/μ vs N showing 1/√N breakdown.
"""
import csv, matplotlib.pyplot as plt, numpy as np

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)

N = np.array([float(r['N']) for r in rows])
sm = np.array([float(r['sigma_over_mu']) for r in rows])
pred = np.array([float(r['prediction_1_over_sqrt_N']) for r in rows])

fig, ax = plt.subplots(figsize=(6.0, 4.0))
ax.loglog(N, sm, 'o-', color='C0', ms=10, lw=2,
          label=r'Observed $\\sigma/\\mu$ (TWA, 50 trajectories)')
ax.loglog(N, pred, '--', color='gray',
          label=r'Standard TWA: $\\sigma/\\mu \\sim 1/\\sqrt{N}$')

ax.set_xlabel(r'Particle number $N$', fontsize=11)
ax.set_ylabel(r'$\\sigma/\\mu$', fontsize=11)
ax.set_title(r'F=6 dipolar BEC $\\sigma/\\mu$ vs $N$: '
             r'1/\\sqrt{N} breakdown', fontsize=11)
ax.grid(alpha=0.3, which='both')
ax.legend(loc='best', fontsize=9)
plt.tight_layout()
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
