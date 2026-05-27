# Manuscript figure rendering pipeline (scaffold).
#
# Usage:
#   julia --project=. scripts/manuscript/render_figures.jl --paper paper3 --fig 2
#
# Or list all available figures:
#   julia --project=. scripts/manuscript/render_figures.jl --list
#
# This script provides a unified entry point for rendering all figures
# referenced in docs/manuscript/shared/figures.md. Each figure has a
# dedicated builder function that loads the data, builds the plot, and
# writes both PDF (LaTeX-ready) and SVG (web preview).
#
# **Implementation status (2026-05-12)**: scaffold + dispatch table.
# Individual figure builders are NotImplementedError stubs pending
# the data-source paths in `runs/` being populated. The list / dispatch
# infrastructure is fully working and can be exercised via --list.

using Printf
import SpinorBEC

# ────────────────────────────────────────────────────────────────
# Figure dispatch table
# ────────────────────────────────────────────────────────────────

const FIGURE_REGISTRY = Dict{Tuple{String, String}, NamedTuple}(
    # Paper #1
    ("paper1", "FIG-1") => (
        title="F=2 cyclic Majorana tetrahedron",
        data_source="analytical",
        kind=:majorana_3d,
        builder=:build_paper1_fig1,
    ),
    ("paper1", "FIG-2") => (
        title="F=2 BdG block decomposition schematic",
        data_source="symbolic",
        kind=:tikz_diagram,
        builder=:build_paper1_fig2,
    ),
    ("paper1", "FIG-3") => (
        title="F=2 mode dispersion ω(k)",
        data_source="runs/paper1_dispersion_verify/",
        kind=:dispersion_plot,
        builder=:build_paper1_fig3,
    ),

    # Paper #2
    ("paper2", "FIG-1") => (
        title="F=6 icosahedron Majorana",
        data_source="analytical",
        kind=:majorana_3d,
        builder=:build_paper2_fig1,
    ),
    ("paper2", "FIG-2") => (
        title="F=6 mod-5 block structure (26-dim BdG → 5 blocks)",
        data_source="symbolic",
        kind=:tikz_diagram,
        builder=:build_paper2_fig2,
    ),
    ("paper2", "FIG-3") => (
        title="¹⁵¹Eu LHY/MF ratio vs trap omega",
        data_source="runs/paper2_Eu_predictions/",
        kind=:line_plot,
        builder=:build_paper2_fig3,
    ),

    # Paper #3
    ("paper3", "FIG-1") => (
        title="Schur-pipeline schematic (H ⊂ SO(3) → T₁ → isotropy → universal form)",
        data_source="conceptual",
        kind=:tikz_diagram,
        builder=:build_paper3_fig1,
    ),
    ("paper3", "FIG-2") => (
        title="Sign Pattern β_S^(λ_spin) vs S for 6 F-cases",
        data_source="scripts/manuscript/lemma1_general_S_verification.jl",
        kind=:scatter_grid,
        builder=:build_paper3_fig2,
    ),
    ("paper3", "FIG-3") => (
        title="F-systematic 13-instance verification (β_0 = 1/(2F+1))",
        data_source="scripts/manuscript/f_systematic_lemma1_predictions.jl",
        kind=:verification_table,
        builder=:build_paper3_fig3,
    ),
    ("paper3", "FIG-4") => (
        title="Three-exception classification {F=1, F=2, F=5}",
        data_source="conceptual",
        kind=:tikz_diagram,
        builder=:build_paper3_fig4,
    ),
    ("paper3", "FIG-6") => (
        title="Polyhedral inert state Majorana configurations",
        data_source="rendered 2026-05-11 (existing)",
        kind=:majorana_3d_grid,
        builder=:build_paper3_fig6,
    ),

    # Paper #4
    ("paper4", "FIG-1") => (
        title="Mean-field GP-LHY post-quench snapshot at t=5",
        data_source="runs/paper4_meanfield/",
        kind=:density_2d,
        builder=:build_paper4_fig1,
    ),
    ("paper4", "FIG-2") => (
        title="σ/μ vs N showing 1/√N breakdown",
        data_source="runs/sigma_mu_scan_round5/",
        kind=:loglog_plot,
        builder=:build_paper4_fig2,
    ),
    ("paper4", "FIG-3") => (
        title="Species universality: σ/μ vs ε_dd",
        data_source="runs/species_scan_round6/",
        kind=:scatter_plot,
        builder=:build_paper4_fig3,
    ),
    ("paper4", "FIG-4") => (
        title="Lyapunov trajectory divergence",
        data_source="runs/lyapunov_diagnostic_round6/",
        kind=:semilog_plot,
        builder=:build_paper4_fig4,
    ),
    ("paper4", "FIG-5") => (
        title="50-trajectory ensemble traces at Eu",
        data_source="runs/ensemble_traces_round5/",
        kind=:trace_overlay,
        builder=:build_paper4_fig5,
    ),
)

# ────────────────────────────────────────────────────────────────
# Output path conventions
# ────────────────────────────────────────────────────────────────

function output_path(paper::String, fig::String, ext::String)
    parts = Dict(
        "paper1" => "paper1_F2_cyclic",
        "paper2" => "paper2_F6_icosahedral",
        "paper3" => "paper3_universal_theorem",
        "paper4" => "paper4_chaotic_dynamics",
    )
    paper_dir = get(parts, paper, paper)
    return joinpath(@__DIR__, "..", "..", "docs", "manuscript", "papers",
        paper_dir, "figures", "$(lowercase(fig))_$(paper).$ext")
end

# ────────────────────────────────────────────────────────────────
# Builder stubs (to be implemented per-figure)
# ────────────────────────────────────────────────────────────────

# All builders take (paper::String, fig::String, info::NamedTuple) and
# emit data (CSV + companion matplotlib script) into `figures/` so any
# downstream tool can render to PDF. Builders that need to invoke the
# (Makie weak-dep) plotting stack remain stubs pending the ext load.

function build_stub(paper, fig, info)
    @printf("[NOT IMPLEMENTED] %s %s: %s\n", paper, fig, info.title)
    @printf("  data source: %s\n", info.data_source)
    @printf("  kind: %s\n", info.kind)
    @printf("  output target: %s\n", output_path(paper, fig, "pdf"))
    @printf("  → run the data-generating job first if data_source is a runs/ dir,\n")
    @printf("    or write the TikZ source if conceptual\n")
end

# Ensure figures/ directory exists
function _ensure_figures_dir(paper)
    parts = Dict(
        "paper1" => "paper1_F2_cyclic",
        "paper2" => "paper2_F6_icosahedral",
        "paper3" => "paper3_universal_theorem",
        "paper4" => "paper4_chaotic_dynamics",
    )
    paper_dir = get(parts, paper, paper)
    fig_dir = joinpath(@__DIR__, "..", "..", "docs", "manuscript", "papers",
        paper_dir, "figures")
    mkpath(fig_dir)
    return fig_dir
end

# Helper: write structured CSV alongside a matplotlib renderer.
function _emit_data_and_renderer(paper, fig, info, csv_content::String,
    py_template::String)
    dir = _ensure_figures_dir(paper)
    base = joinpath(dir, lowercase(fig) * "_" * paper)
    csv_path = base * ".csv"
    py_path = base * ".py"
    open(csv_path, "w") do io
        write(io, csv_content)
    end
    open(py_path, "w") do io
        write(io, py_template)
    end
    @printf("OK: %s %s\n", paper, fig)
    @printf("  data: %s\n", csv_path)
    @printf("  renderer: %s\n", py_path)
    @printf("  build PDF: python3 %s\n", py_path)
end

# ────────────────────────────────────────────────────────────────
# Paper #3 FIG-3: F-systematic 13-instance verification
# ────────────────────────────────────────────────────────────────
function build_paper3_fig3(paper::String, fig::String, info)
    # Data: 13 verified Lemma 1 instances + the 3 exceptions
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
        label=r'\$\\\\beta_0 = 1/(2F+1)\$ (Lemma 1)')

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
           label='Exceptions (F=1: \$T_1\$ irred., F=2/5: no Schur singlet)')

# Labels for exception F values
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

base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #4 FIG-2: σ/μ vs N (1/√N breakdown)
# ────────────────────────────────────────────────────────────────
function build_paper4_fig2(paper::String, fig::String, info)
    # Data from Round-5 GPU + Round-6 Sinatra runs (see Ch.5 §5.6-5.9)
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
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #4 FIG-3: Species universality
# ────────────────────────────────────────────────────────────────
function build_paper4_fig3(paper::String, fig::String, info)
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

# Bar chart with species labels
colors = ['C0', 'C3', 'C2', 'C1']  # Cr, Eu, Er, Dy
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
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #1 FIG-1: F=2 cyclic Majorana tetrahedron
# ────────────────────────────────────────────────────────────────
function build_paper1_fig1(paper::String, fig::String, info)
    # 4 vertices of regular tetrahedron inscribed in unit sphere
    # Standard tetrahedral vertices: (1,1,1), (1,-1,-1), (-1,1,-1), (-1,-1,1) normalized
    s = 1.0 / sqrt(3)
    csv = """
label,x,y,z
v1,$s,$s,$s
v2,$s,-$s,-$s
v3,-$s,$s,-$s
v4,-$s,-$s,$s
"""
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #1 FIG-1: F=2 cyclic Majorana tetrahedron (4 stars on Bloch sphere).
\"\"\"
import csv
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)
xs = [float(r['x']) for r in rows]
ys = [float(r['y']) for r in rows]
zs = [float(r['z']) for r in rows]

fig = plt.figure(figsize=(5.0, 5.0))
ax = fig.add_subplot(111, projection='3d')

# Bloch sphere
u, v = np.linspace(0, 2*np.pi, 60), np.linspace(0, np.pi, 30)
xu = np.outer(np.cos(u), np.sin(v))
yu = np.outer(np.sin(u), np.sin(v))
zu = np.outer(np.ones_like(u), np.cos(v))
ax.plot_surface(xu, yu, zu, alpha=0.10, color='gray', linewidth=0)

# Tetrahedron edges
edges = [(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]
for i, j in edges:
    ax.plot([xs[i], xs[j]], [ys[i], ys[j]], [zs[i], zs[j]],
            'k-', lw=1.2, alpha=0.6)

# Majorana points
ax.scatter(xs, ys, zs, color='C3', s=160, edgecolor='black',
           linewidths=1.2, zorder=10)
for i, r in enumerate(rows):
    ax.text(xs[i]*1.20, ys[i]*1.20, zs[i]*1.20, r['label'],
            fontsize=11, ha='center', fontweight='bold')

ax.set_box_aspect((1, 1, 1))
ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
ax.set_title('F=2 cyclic Majorana configuration\\n(regular tetrahedron, T_d symmetry)',
             fontsize=10)
plt.tight_layout()
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #2 FIG-1: F=6 icosahedron Majorana
# ────────────────────────────────────────────────────────────────
function build_paper2_fig1(paper::String, fig::String, info)
    # 12 vertices of regular icosahedron on unit sphere
    # Vertices: (0, ±1, ±φ), (±1, ±φ, 0), (±φ, 0, ±1) (12 total), normalized
    φ = (1 + sqrt(5)) / 2
    norm = sqrt(1 + φ^2)
    pts = [
        (0, 1, φ), (0, -1, φ), (0, 1, -φ), (0, -1, -φ),
        (1, φ, 0), (-1, φ, 0), (1, -φ, 0), (-1, -φ, 0),
        (φ, 0, 1), (φ, 0, -1), (-φ, 0, 1), (-φ, 0, -1),
    ]
    csv_lines = ["label,x,y,z"]
    for (i, p) in enumerate(pts)
        push!(csv_lines, "v$i,$(p[1]/norm),$(p[2]/norm),$(p[3]/norm)")
    end
    csv = join(csv_lines, "\n") * "\n"
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #2 FIG-1: F=6 icosahedron Majorana (12 stars on Bloch sphere).
\"\"\"
import csv
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D  # noqa

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)
xs = [float(r['x']) for r in rows]
ys = [float(r['y']) for r in rows]
zs = [float(r['z']) for r in rows]

fig = plt.figure(figsize=(5.0, 5.0))
ax = fig.add_subplot(111, projection='3d')

# Bloch sphere
u, v = np.linspace(0, 2*np.pi, 60), np.linspace(0, np.pi, 30)
xu = np.outer(np.cos(u), np.sin(v))
yu = np.outer(np.sin(u), np.sin(v))
zu = np.outer(np.ones_like(u), np.cos(v))
ax.plot_surface(xu, yu, zu, alpha=0.08, color='gray', linewidth=0)

# Icosahedron edges (30 edges; connect by nearest-neighbor distance)
import itertools
pts = list(zip(xs, ys, zs))
dist = lambda a, b: np.sqrt(sum((a[i]-b[i])**2 for i in range(3)))
min_d = min(dist(pts[i], pts[j]) for i, j in itertools.combinations(range(12), 2))
for i, j in itertools.combinations(range(12), 2):
    if abs(dist(pts[i], pts[j]) - min_d) < 0.01:
        ax.plot([xs[i], xs[j]], [ys[i], ys[j]], [zs[i], zs[j]],
                'k-', lw=0.7, alpha=0.4)

# Majorana points
ax.scatter(xs, ys, zs, color='C3', s=120, edgecolor='black',
           linewidths=1.0, zorder=10)
ax.set_box_aspect((1, 1, 1))
ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([])
ax.set_title('F=6 icosahedral Majorana configuration\\n(12 vertices, I_h symmetry)',
             fontsize=10)
plt.tight_layout()
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #3 FIG-2: Sign Pattern β_S^(λ) vs S for 6 F-cases
# ────────────────────────────────────────────────────────────────
function build_paper3_fig2(paper::String, fig::String, info)
    # Lemma 1 General-S: β_S^(λ) = [S(S+1) - 2F(F+1)] / (2 F(F+1)) · β_S^(c0)
    # Sign change at S_bd = sqrt(2F(F+1))
    # Generate the prefactor curve for each F (β_S^(λ)/β_S^(c0)) and S_bd line.
    lines = ["F,S,prefactor_lambda_over_c0,sign_boundary_S_bd"]
    for F in (3, 4, 6, 8, 10, 12)
        S_bd = sqrt(2.0 * F * (F + 1))
        for S in 0:2:(2F)
            prefactor = (S * (S + 1) - 2 * F * (F + 1)) / (2 * F * (F + 1))
            push!(lines, "$F,$S,$prefactor,$S_bd")
        end
    end
    csv = join(lines, "\n") * "\n"
    py = """
#!/usr/bin/env python3
\"\"\"
Paper #3 FIG-2: Sign Pattern prefactor β_S^(λ_spin) / β_S^(c0) vs S
across F = 3, 4, 6, 8, 10, 12. Vertical lines mark S_bd = sqrt(2F(F+1))
where the prefactor changes sign (Sign Pattern Lemma 2).
\"\"\"
import csv
import matplotlib.pyplot as plt
import numpy as np

rows = []
with open(__file__.replace('.py', '.csv')) as f:
    for r in csv.DictReader(f):
        rows.append(r)

# Group by F
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
ax.set_ylabel(r'\$\\beta_S^{(\\lambda_{\\rm spin})} / \\beta_S^{(c_0)}\$',
              fontsize=11)
ax.set_title('Sign Pattern Lemma 2: single sign change at \$S_{\\rm bd} = \\sqrt{2F(F+1)}\$',
             fontsize=11)
ax.legend(loc='best', fontsize=8, ncol=2)
ax.grid(alpha=0.3)
plt.tight_layout()
base = __file__.replace('.py', '')
plt.savefig(base + '.pdf', bbox_inches='tight')
plt.savefig(base + '.svg', bbox_inches='tight')
print(f'Wrote {base}.pdf and .svg')
"""
    _emit_data_and_renderer(paper, fig, info, csv, py)
end

# ────────────────────────────────────────────────────────────────
# Paper #3 FIG-1: Schur-pipeline TikZ schematic
# ────────────────────────────────────────────────────────────────
function build_paper3_fig1(paper::String, fig::String, info)
    dir = _ensure_figures_dir(paper)
    tex_path = joinpath(dir, lowercase(fig) * "_" * paper * ".tex")
    tikz = raw"""
% Paper #3 FIG-1: Schur-pipeline schematic
% Build standalone:
%   pdflatex paper3_fig1.tex
\documentclass[border=4pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,shapes,backgrounds}
\begin{document}
\begin{tikzpicture}[
    node distance=10mm,
    box/.style={draw, rounded corners=2pt, minimum width=42mm,
                minimum height=12mm, align=center, font=\small},
    arrow/.style={-{Latex[length=2.5mm]}, thick},
]
% Step 1
\node[box, fill=blue!10] (group) {Polyhedral $H \subset SO(3)$\\
    \scriptsize $T, O, I$ or their double covers};
% Step 2
\node[box, fill=blue!20, right=12mm of group] (irrep) {3-dim irrep $T_1|_H$\\
    \scriptsize spin Goldstone space};
% Step 3
\node[box, fill=blue!30, right=12mm of irrep] (schur) {Schur isotropy\\
    \scriptsize $\langle F_a^2\rangle = \frac{F(F+1)}{3}$};
% Step 4
\node[box, fill=blue!40, below=10mm of schur] (eom) {Spin-mass matrix\\
    $= \lambda_{\rm spin}^{(H)} \cdot \mathbf{I}_3$};
% Step 5
\node[box, fill=green!30, below=10mm of irrep] (closed) {Universal closed form\\
    $\varepsilon_{\rm LHY} \propto c_0^{5/2} + 3|\lambda_{\rm spin}|^{5/2}$};

% Arrows
\draw[arrow] (group) -- (irrep);
\draw[arrow] (irrep) -- (schur);
\draw[arrow] (schur) -- (eom);
\draw[arrow] (eom) -- (closed);
\draw[arrow] (irrep) -- (closed) node[midway,fill=white,font=\scriptsize]
    {3 degenerate};

\end{tikzpicture}
\end{document}
"""
    open(tex_path, "w") do io
        write(io, tikz)
    end
    @printf("OK: %s %s\n", paper, fig)
    @printf("  TikZ source: %s\n", tex_path)
    @printf("  Build: cd %s && pdflatex %s\n", dir, basename(tex_path))
end

# ────────────────────────────────────────────────────────────────
# Paper #3 FIG-4: Three-exception classification TikZ
# ────────────────────────────────────────────────────────────────
function build_paper3_fig4(paper::String, fig::String, info)
    dir = _ensure_figures_dir(paper)
    tex_path = joinpath(dir, lowercase(fig) * "_" * paper * ".tex")
    tikz = raw"""
% Paper #3 FIG-4: Three-exception classification
\documentclass[border=4pt]{standalone}
\usepackage{tikz}
\usetikzlibrary{shapes,positioning}
\begin{document}
\begin{tikzpicture}[
    F/.style={draw, rounded corners=2pt, minimum width=20mm,
              minimum height=10mm, align=center, font=\small},
    ex/.style={F, fill=red!15},
    ok/.style={F, fill=green!15},
    skip/.style={F, dashed, draw=gray!50, text=gray!70},
]
% Header
\node[font=\bfseries] at (3.5, 1.5) {Universal Theorem applies for
    polyhedral inert states with a Schur-singlet 1-dim real irrep.};

% F values
\foreach \F/\style/\note in {
    1/ex/{$T_1$ irred.}, 2/ex/{phase-eq.\\T:E_1},
    3/ok/{T:A, O:A_2}, 4/ok/{T:A, O:A_1},
    5/ex/{algebraic\\no real}, 6/ok/{all families},
    7/ok/{T:A, O:A_2}, 8/ok/{T:A, O:A_1},
    9/ok/{O:A_1, O:A_2}, 10/ok/{all families},
    11/ok/{T:A, O:A_2}, 12/ok/{all families},
    13/ok/{T:A, O:A_1, O:A_2}
} {
    \node[\style] at ({(\F-1)*22mm}, 0) {$F{=}\F$\\\scriptsize\note};
}

% Legend
\node[ok, anchor=west] at (0, -1.5) {ok};
\node[anchor=west, font=\small] at (1.5, -1.5) {Schur-singlet applies};
\node[ex, anchor=west] at (6, -1.5) {ex};
\node[anchor=west, font=\small] at (7.5, -1.5) {Exception (no real 1-dim irrep)};

\end{tikzpicture}
\end{document}
"""
    open(tex_path, "w") do io
        write(io, tikz)
    end
    @printf("OK: %s %s\n", paper, fig)
    @printf("  TikZ source: %s\n", tex_path)
    @printf("  Build: cd %s && pdflatex %s\n", dir, basename(tex_path))
end

# ────────────────────────────────────────────────────────────────
# Paper #3 FIG-6: Polyhedral inert state Majorana configurations
# ────────────────────────────────────────────────────────────────
# Canonical Paper #3 §V state spinors. Component order: index k+1
# corresponds to m = F-k, so the first index is m=+F and the last
# is m=-F. F=0 components live at the centre index F+1.
function _paper3_canonical_states()
    states = Tuple{Int, String, String, Vector{ComplexF64}}[]

    # §V.A  F=2  T_d cyclic: ζ = (1, 0, i√2, 0, 1) / 2
    let z = ComplexF64[1.0, 0.0, im * sqrt(2.0), 0.0, 1.0] ./ 2.0
        push!(states, (2, "F=2 cyclic", "T_d (§V.A)", z))
    end
    # §V.B  F=3  O:A_2:  ζ = (|+2⟩ − |−2⟩) / √2
    let z = zeros(ComplexF64, 7)
        z[2] = 1.0 / sqrt(2.0);
        z[6] = -1.0 / sqrt(2.0)
        push!(states, (3, "F=3 octa", "O:A_2 (§V.B)", z))
    end
    # §V.C  F=4  O:A_1 cube: ζ = √(5/24)|+4⟩ + √(7/12)|0⟩ + √(5/24)|−4⟩
    let z = zeros(ComplexF64, 9)
        z[1] = sqrt(5 / 24);
        z[5] = sqrt(7 / 12);
        z[9] = sqrt(5 / 24)
        push!(states, (4, "F=4 cube", "O:A_1 (§V.C)", z))
    end
    # §V.D  F=6  I:A canonical (ZETA_F6_IH): ζ = √7/5(|+5⟩−|−5⟩)+√11/5|0⟩
    let z = ComplexF64[
            0, sqrt(7.0) / 5, 0, 0, 0, 0, sqrt(11.0) / 5,
            0, 0, 0, 0, -sqrt(7.0) / 5, 0,
        ]
        push!(states, (6, "F=6 icosa", "I:A (§V.D)", z))
    end
    # F=7 O:A_2 (supplementary — m ∈ {±6, ±2}).
    let z = ComplexF64[
            0,
            -0.3635626373 + 0.3114303701im,  # m=+6
            0, 0, 0,
            -0.3952342557 + 0.3385605063im,  # m=+2
            0, 0, 0,
            0.3952342557 - 0.3385605063im,  # m=-2
            0, 0, 0,
            0.3635626373 - 0.3114303701im,  # m=-6
            0,
        ]
        push!(states, (7, "F=7 octa", "O:A_2 (supp)", z))
    end
    # §V.E  F=8  O:A_1 cube-octa: √390/48|±8⟩+√42/24|±4⟩+√33/8|0⟩
    let z = zeros(ComplexF64, 17)
        z[1] = sqrt(390) / 48;
        z[5] = sqrt(42) / 24;
        z[9] = sqrt(33) / 8
        z[13] = sqrt(42) / 24;
        z[17] = sqrt(390) / 48
        push!(states, (8, "F=8 cube-octa", "O:A_1 (§V.E)", z))
    end
    # F=9 O:A_1 (supplementary — m ∈ {±8, ±4}).
    let z = ComplexF64[
            0,
            0.1779105488 + 0.3379070434im,  # m=+8
            0, 0, 0,
            -0.2772535655 - 0.526590094im,  # m=+4
            0, 0, 0, 0, 0, 0, 0,
            0.2772535655 + 0.526590094im,  # m=-4
            0, 0, 0,
            -0.1779105488 - 0.3379070434im,  # m=-8
            0,
        ]
        push!(states, (9, "F=9 octa", "O:A_1 (supp)", z))
    end
    # §V.F  F=10 I:A dodec: √561/75|±10⟩+√209/25(|+5⟩−|−5⟩)+√741/75|0⟩
    let z = zeros(ComplexF64, 21)
        z[1] = sqrt(561) / 75;
        z[6] = sqrt(209) / 25;
        z[11] = sqrt(741) / 75
        z[16] = -sqrt(209) / 25;
        z[21] = sqrt(561) / 75
        push!(states, (10, "F=10 dodec", "I:A (§V.F)", z))
    end
    # F=11 O:A_2 (supplementary — m ∈ {±10, ±6, ±2}).
    let z = ComplexF64[
            0,
            -0.2933098261 + 0.2952057405im,  # m=+10
            0, 0, 0,
            -0.2288986869 + 0.2303782566im,  # m=+6
            0, 0, 0,
            -0.3316081934 + 0.3337516632im,  # m=+2
            0, 0, 0,
            0.3316081934 - 0.3337516632im,  # m=-2
            0, 0, 0,
            0.2288986869 - 0.2303782566im,  # m=-6
            0, 0, 0,
            0.2933098261 - 0.2952057405im,  # m=-10
            0,
        ]
        push!(states, (11, "F=11 octa", "O:A_2 (supp)", z))
    end
    # §V.G  F=12 I:A icosa (C_5^z-invariant), U(1)-rotated to real form
    let z = zeros(ComplexF64, 25)
        z[3] = 0.4871;
        z[8] = -0.3024;
        z[13] = 0.5853
        z[18] = 0.3024;
        z[23] = 0.4871
        z ./= sqrt(sum(abs2, z))
        push!(states, (12, "F=12 I:A", "I:A (§V.G)", z))
    end
    states
end

function build_paper3_fig6(paper::String, fig::String, info)
    # Output preserves the existing on-disk filename `fig-7_paper3_majorana`
    # (matching the committed matplotlib renderer in docs/manuscript/...
    # /figures/fig-7_paper3_majorana.py). The registry FIG-6 ↔ disk fig-7
    # offset is historical; the renderer side is the load-bearing contract.
    dir = _ensure_figures_dir(paper)
    csv_path = joinpath(dir, "fig-7_paper3_majorana.csv")

    # `_stereo_to_sphere` is internal but stable since the U2 z=∞ → north
    # pole fix (commit a9a3d95).
    stereo = SpinorBEC._stereo_to_sphere

    open(csv_path, "w") do io
        println(io, "panel_idx,F,label,ref,point_idx,x,y,z")
        for (panel_idx, (F, label, ref, spinor)) in
            enumerate(_paper3_canonical_states())
            stars = SpinorBEC.majorana_stars(spinor, F)
            for (i, z) in enumerate(stars)
                p = stereo(z)
                println(io, "$panel_idx,$F,$label,$ref,$i,$(p[1]),$(p[2]),$(p[3])")
            end
        end
    end

    py_path = joinpath(dir, "fig-7_paper3_majorana.py")
    @printf("OK: %s %s\n", paper, fig)
    @printf("  CSV: %s\n", csv_path)
    @printf("  renderer: %s (committed)\n", py_path)
    @printf("  Build: python3 %s\n", py_path)
end

# Default for all other figures → stub
for ((paper, fig), info) in FIGURE_REGISTRY
    builder_name = info.builder
    if !isdefined(@__MODULE__, builder_name)
        @eval function $(builder_name)(paper::String, fig::String, info)
            build_stub(paper, fig, info)
        end
    end
end

# ────────────────────────────────────────────────────────────────
# CLI
# ────────────────────────────────────────────────────────────────

function parse_args(args)
    paper = nothing
    fig = nothing
    list = false
    i = 1
    while i <= length(args)
        if args[i] == "--paper" && i + 1 <= length(args)
            paper = args[i + 1];
            i += 2
        elseif args[i] == "--fig" && i + 1 <= length(args)
            fig = args[i + 1];
            i += 2
        elseif args[i] == "--list"
            list = true;
            i += 1
        else
            i += 1
        end
    end
    (paper=paper, fig=fig, list=list)
end

function list_figures()
    @printf("%-8s %-7s %-50s %s\n", "paper", "fig", "title", "data_source")
    @printf("%s\n", "-"^110)
    keys_sorted = sort(collect(keys(FIGURE_REGISTRY)))
    for k in keys_sorted
        info = FIGURE_REGISTRY[k]
        @printf("%-8s %-7s %-50s %s\n", k[1], k[2], info.title, info.data_source)
    end
end

function main()
    opts = parse_args(ARGS)
    if opts.list
        list_figures()
        return nothing
    end
    if opts.paper === nothing || opts.fig === nothing
        @printf("Usage: julia render_figures.jl [--list | --paper <paper> --fig <FIG-N>]\n")
        @printf("\nAvailable figures:\n")
        list_figures()
        return nothing
    end
    fig_normalized = uppercase(opts.fig)
    if !haskey(FIGURE_REGISTRY, (opts.paper, fig_normalized))
        @printf("ERROR: figure (%s, %s) not in registry\n", opts.paper, fig_normalized)
        @printf("\nAvailable figures:\n")
        list_figures()
        return nothing
    end
    info = FIGURE_REGISTRY[(opts.paper, fig_normalized)]
    builder_func = getfield(@__MODULE__, info.builder)
    builder_func(opts.paper, fig_normalized, info)
end

main()
