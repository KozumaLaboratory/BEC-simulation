# Manuscript figure subsystem.
#
# Each `build_paperX_figY(io, paper, fig)` emits CSV + companion matplotlib
# script (or TikZ source) under `docs/manuscript/papers/<paper>/figures/`.
# The dispatch table is `MANUSCRIPT_FIGURE_REGISTRY`; `render_manuscript_figure`
# and `list_manuscript_figures` are the public entry points.

export MANUSCRIPT_FIGURE_REGISTRY,
    render_manuscript_figure,
    list_manuscript_figures,
    manuscript_figure_dir,
    manuscript_figure_path

using Printf

include("figures/paths.jl")
include("figures/emitters.jl")
include("figures/canonical_states.jl")
include("figures/paper1_fig1.jl")
include("figures/paper1_fig2.jl")
include("figures/paper2_fig1.jl")
include("figures/paper2_fig2.jl")
include("figures/paper3_fig1.jl")
include("figures/paper3_fig2.jl")
include("figures/paper3_fig3.jl")
include("figures/paper3_fig4.jl")
include("figures/paper3_fig6.jl")
include("figures/paper4_fig2.jl")
include("figures/paper4_fig3.jl")

# Dispatch table: (paper, FIG-N) → (title, data_source, kind, builder)
const MANUSCRIPT_FIGURE_REGISTRY = Dict{Tuple{String, String}, NamedTuple}(
    ("paper1", "FIG-1") => (
        title="F=2 cyclic Majorana tetrahedron",
        data_source="analytical",
        kind=:majorana_3d,
        builder=build_paper1_fig1,
    ),
    ("paper1", "FIG-2") => (
        title="F=2 BdG block decomposition schematic",
        data_source="symbolic",
        kind=:tikz_diagram,
        builder=build_paper1_fig2,
    ),
    ("paper1", "FIG-3") => (
        title="F=2 mode dispersion ω(k)",
        data_source="runs/paper1_dispersion_verify/",
        kind=:dispersion_plot,
        builder=nothing,
    ),
    ("paper2", "FIG-1") => (
        title="F=6 icosahedron Majorana",
        data_source="analytical",
        kind=:majorana_3d,
        builder=build_paper2_fig1,
    ),
    ("paper2", "FIG-2") => (
        title="F=6 mod-5 block structure (26-dim BdG → 5 blocks)",
        data_source="symbolic",
        kind=:tikz_diagram,
        builder=build_paper2_fig2,
    ),
    ("paper2", "FIG-3") => (
        title="¹⁵¹Eu LHY/MF ratio vs trap omega",
        data_source="runs/paper2_Eu_predictions/",
        kind=:line_plot,
        builder=nothing,
    ),
    ("paper3", "FIG-1") => (
        title="Schur-pipeline schematic (H ⊂ SO(3) → T₁ → isotropy → universal form)",
        data_source="conceptual",
        kind=:tikz_diagram,
        builder=build_paper3_fig1,
    ),
    ("paper3", "FIG-2") => (
        title="Sign Pattern β_S^(λ_spin) vs S for 6 F-cases",
        data_source="scripts/manuscript/lemma1_general_S_verification.jl",
        kind=:scatter_grid,
        builder=build_paper3_fig2,
    ),
    ("paper3", "FIG-3") => (
        title="F-systematic 13-instance verification (β_0 = 1/(2F+1))",
        data_source="scripts/manuscript/f_systematic_lemma1_predictions.jl",
        kind=:verification_table,
        builder=build_paper3_fig3,
    ),
    ("paper3", "FIG-4") => (
        title="Three-exception classification {F=1, F=2, F=5}",
        data_source="conceptual",
        kind=:tikz_diagram,
        builder=build_paper3_fig4,
    ),
    ("paper3", "FIG-6") => (
        title="Polyhedral inert state Majorana configurations",
        data_source="rendered 2026-05-11 (existing)",
        kind=:majorana_3d_grid,
        builder=build_paper3_fig6,
    ),
    ("paper4", "FIG-1") => (
        title="Mean-field GP-LHY post-quench snapshot at t=5",
        data_source="runs/paper4_meanfield/",
        kind=:density_2d,
        builder=nothing,
    ),
    ("paper4", "FIG-2") => (
        title="σ/μ vs N showing 1/√N breakdown",
        data_source="runs/sigma_mu_scan_round5/",
        kind=:loglog_plot,
        builder=build_paper4_fig2,
    ),
    ("paper4", "FIG-3") => (
        title="Species universality: σ/μ vs ε_dd",
        data_source="runs/species_scan_round6/",
        kind=:scatter_plot,
        builder=build_paper4_fig3,
    ),
    ("paper4", "FIG-4") => (
        title="Lyapunov trajectory divergence",
        data_source="runs/lyapunov_diagnostic_round6/",
        kind=:semilog_plot,
        builder=nothing,
    ),
    ("paper4", "FIG-5") => (
        title="50-trajectory ensemble traces at Eu",
        data_source="runs/ensemble_traces_round5/",
        kind=:trace_overlay,
        builder=nothing,
    ),
)

"""
    render_manuscript_figure(paper, fig; io=stdout)

Dispatch to the registered builder for `(paper, fig)` (case-insensitive on
`fig`). Stubs report NOT IMPLEMENTED — they remain as placeholders for
figures whose data sources are not yet populated.
"""
function render_manuscript_figure(paper::AbstractString, fig::AbstractString;
    io::IO=stdout)
    fig_up = uppercase(String(fig))
    key = (String(paper), fig_up)
    if !haskey(MANUSCRIPT_FIGURE_REGISTRY, key)
        @printf(io, "ERROR: figure (%s, %s) not in registry\n", paper, fig_up)
        list_manuscript_figures(io)
        return false
    end
    info = MANUSCRIPT_FIGURE_REGISTRY[key]
    if info.builder === nothing
        @printf(io, "[NOT IMPLEMENTED] %s %s: %s\n", paper, fig_up, info.title)
        @printf(io, "  data source: %s\n", info.data_source)
        @printf(io, "  kind: %s\n", info.kind)
        @printf(io, "  output target: %s\n",
            manuscript_figure_path(paper, fig_up, "pdf"))
        return false
    end
    info.builder(io, String(paper), fig_up)
    return true
end

"""
    list_manuscript_figures(io=stdout)

Print the registry as a table.
"""
function list_manuscript_figures(io::IO=stdout)
    @printf(io, "%-8s %-7s %-50s %s\n", "paper", "fig", "title", "data_source")
    @printf(io, "%s\n", "-"^110)
    for k in sort(collect(keys(MANUSCRIPT_FIGURE_REGISTRY)))
        info = MANUSCRIPT_FIGURE_REGISTRY[k]
        status = info.builder === nothing ? "(stub)" : ""
        @printf(io, "%-8s %-7s %-50s %s %s\n",
            k[1], k[2], info.title, info.data_source, status)
    end
end
