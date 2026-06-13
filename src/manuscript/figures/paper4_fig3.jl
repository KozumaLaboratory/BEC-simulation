# Paper #4 FIG-3: σ/μ vs ε_dd species universality.

function build_paper4_fig3(io::IO, paper::AbstractString, fig::AbstractString)
    csv = """
species,epsilon_dd,sigma_over_mu,regime
Cr,0.15,0.001,sub-instability
Eu,0.55,0.423,chaos-onset (peak)
Er,0.88,0.127,chaos-saturated
Dy,1.39,0.049,full-collapse
"""
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #4 FIG-3: σ/μ vs ε_dd species universality.
\"\"\"
import csv, matplotlib.pyplot as plt

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)

fig, ax = plt.subplots(figsize=(6.0, 4.0))
species = [r['species'] for r in rows]
e_dd = [float(r['epsilon_dd']) for r in rows]
s = [float(r['sigma_over_mu']) for r in rows]

colors = ['C0', 'C3', 'C2', 'C1']
bars = ax.bar(e_dd, s, width=0.12, color=colors,
              edgecolor='black', linewidth=1)
for i, (b, sp) in enumerate(zip(bars, species)):
    h = b.get_height()
    ax.text(b.get_x() + b.get_width() / 2, h + 0.02, sp,
            ha='center', fontsize=11, fontweight='bold')

ax.set_xlabel(r'\$\\\\epsilon_{dd}\$ (dipolar / contact ratio)',
              fontsize=11)
ax.set_ylabel(r'\$\\\\sigma/\\\\mu\$', fontsize=11)
ax.set_title(r'Species universality: chaos onset at Eu',
             fontsize=11)
ax.axvline(0.55, ls='--', color='red', alpha=0.5,
           label='Chaos-onset boundary (Eu)')
ax.set_xlim(0, 1.6)
ax.set_ylim(0, 0.55)
ax.legend(loc='upper right', fontsize=9)
ax.grid(alpha=0.3, axis='y')
plt.tight_layout()
$(_PY_SAVEFIG_FOOTER)
"""
    _emit_csv_py(io, paper, fig, csv, py)
end
