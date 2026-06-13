# Paper #3 FIG-3: F-systematic 13-instance Lemma 1 verification
# (β_0 = 1/(2F+1)). Data is the verification table + three exceptions.

function build_paper3_fig3(io::IO, paper::AbstractString, fig::AbstractString)
    csv = """
F,group,irrep,beta_0_predicted,beta_0_measured,schur_dev,status
3,O,A_2,0.142857,0.142857,1e-14,verified
4,O,A_1,0.111111,0.111111,1e-14,verified
6,T,A,0.076923,0.076923,1e-13,verified
6,O,A_1,0.076923,0.076923,1e-13,verified
6,O,A_2,0.076923,0.076923,1e-13,verified
6,I,A,0.076923,0.076923,1e-13,verified
7,T,A,0.066667,0.066667,3e-13,verified
7,O,A_2,0.066667,0.066667,4e-14,verified
8,O,A_1,0.058824,0.058824,1e-13,verified
9,O,A_1,0.052632,0.052632,1e-13,verified
9,O,A_2,0.052632,0.052632,6e-13,verified
10,O,A_1,0.047619,0.047619,1e-13,verified
10,O,A_2,0.047619,0.047619,2e-13,verified
10,I,A,0.047619,0.047619,3e-13,verified
11,T,A,0.043478,0.043478,7e-13,verified
11,O,A_2,0.043478,0.043478,4e-13,verified
12,O,A_1,0.040000,0.040000,1e-13,verified
13,O,A_1,0.037037,0.037037,6e-13,verified
13,O,A_2,0.037037,0.037037,6e-13,verified
1,—,—,—,—,—,exception_T1_irreducible
2,—,—,—,—,—,exception_T_E1_phase_eq
5,—,—,—,—,—,exception_algebraic_no_1d_real_irrep
"""
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #3 FIG-3 renderer: F-systematic 13-instance Lemma 1 verification.
Output: figure base + .pdf and .svg
\"\"\"
import csv
import matplotlib.pyplot as plt
import numpy as np

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    reader = csv.DictReader(f)
    for r in reader:
        rows.append(r)

verified = [r for r in rows if r['status'] == 'verified']
exceptions = [r for r in rows if 'exception' in r['status']]

fig, ax = plt.subplots(figsize=(6.5, 4.0))

F_continuous = np.linspace(0.5, 13.5, 200)
ax.plot(F_continuous, 1.0 / (2 * F_continuous + 1),
        '-', color='steelblue', alpha=0.5, lw=1.5,
        label=r'\$\\\\beta_0 = 1/(2F+1)\$ (Lemma 1)')

F_verified = [float(r['F']) for r in verified]
b_verified = [float(r['beta_0_measured']) for r in verified]
ax.scatter(F_verified, b_verified, color='C2', s=60, zorder=3,
           label=f'Verified (n={len(verified)}, Schur dev < 10^-12)')

y_exc = 1e-3
F_exc_clean = [int(s) for s in ['1', '2', '5']]
ax.scatter(F_exc_clean, [y_exc] * len(F_exc_clean),
           marker='x', color='red', s=80, zorder=3, linewidths=2,
           label='Exceptions (F=1: \$T_1\$ irred., F=2/5: no Schur singlet)')

exc_labels = {1: r'\$F{=}1\$\nT_1 irred.', 2: r'\$F{=}2\$\nphase-eq.',
              5: r'\$F{=}5\$\nalgebraic'}
for F, lab in exc_labels.items():
    ax.annotate(lab, (F, y_exc), xytext=(F, y_exc * 4),
                ha='center', fontsize=8,
                arrowprops=dict(arrowstyle='->', lw=0.5, color='gray'))

ax.set_xlabel(r'Spin quantum number \$F\$', fontsize=11)
ax.set_ylabel(r'\$\\\\beta_0\$ (intercept of Lemma 1)', fontsize=11)
ax.set_title('F-systematic verification of Lemma 1: \$\\\\beta_0 = 1/(2F+1)\$',
             fontsize=11)
ax.set_yscale('log')
ax.set_xlim(0.5, 13.5)
ax.set_ylim(5e-4, 0.3)
ax.set_xticks(range(1, 14))
ax.grid(alpha=0.3, which='both')
ax.legend(loc='upper right', fontsize=9, framealpha=0.95)
plt.tight_layout()

$(_PY_SAVEFIG_FOOTER)
"""
    _emit_csv_py(io, paper, fig, csv, py)
end
