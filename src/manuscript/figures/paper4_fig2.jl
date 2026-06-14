# Paper #4 FIG-2: σ/μ vs N showing 1/√N breakdown.
# Data from Round-5 GPU + Round-6 Sinatra runs (see Ch.5 §5.6-5.9).

function build_paper4_fig2(io::IO, paper::AbstractString, fig::AbstractString)
    csv = """
N,sigma_over_mu,sigma_x_sqrt_N,prediction_1_over_sqrt_N
1000,0.56,17.7,0.0316
10000,0.41,41.0,0.01
100000,0.82,259.3,0.00316
"""
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #4 FIG-2: σ/μ vs N showing 1/√N breakdown.
\"\"\"
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
          label=r'Observed \$\\\\sigma/\\\\mu\$ (TWA, 50 trajectories)')
ax.loglog(N, pred, '--', color='gray',
          label=r'Standard TWA: \$\\\\sigma/\\\\mu \\\\sim 1/\\\\sqrt{N}\$')

ax.set_xlabel(r'Particle number \$N\$', fontsize=11)
ax.set_ylabel(r'\$\\\\sigma/\\\\mu\$', fontsize=11)
ax.set_title(r'F=6 dipolar BEC \$\\\\sigma/\\\\mu\$ vs \$N\$: '
             r'1/\\\\sqrt{N} breakdown', fontsize=11)
ax.grid(alpha=0.3, which='both')
ax.legend(loc='best', fontsize=9)
plt.tight_layout()
$(_PY_SAVEFIG_FOOTER)
"""
    _emit_csv_py(io, paper, fig, csv, py)
end
