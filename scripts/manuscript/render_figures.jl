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

# ────────────────────────────────────────────────────────────────
# Figure dispatch table
# ────────────────────────────────────────────────────────────────

const FIGURE_REGISTRY = Dict{Tuple{String, String}, NamedTuple}(
    # Paper #1
    ("paper1", "FIG-1") => (
        title = "F=2 cyclic Majorana tetrahedron",
        data_source = "analytical",
        kind = :majorana_3d,
        builder = :build_paper1_fig1,
    ),
    ("paper1", "FIG-2") => (
        title = "F=2 BdG block decomposition schematic",
        data_source = "symbolic",
        kind = :tikz_diagram,
        builder = :build_paper1_fig2,
    ),
    ("paper1", "FIG-3") => (
        title = "F=2 mode dispersion ω(k)",
        data_source = "runs/paper1_dispersion_verify/",
        kind = :dispersion_plot,
        builder = :build_paper1_fig3,
    ),

    # Paper #2
    ("paper2", "FIG-1") => (
        title = "F=6 icosahedron Majorana",
        data_source = "analytical",
        kind = :majorana_3d,
        builder = :build_paper2_fig1,
    ),
    ("paper2", "FIG-2") => (
        title = "F=6 mod-5 block structure (26-dim BdG → 5 blocks)",
        data_source = "symbolic",
        kind = :tikz_diagram,
        builder = :build_paper2_fig2,
    ),
    ("paper2", "FIG-3") => (
        title = "¹⁵¹Eu LHY/MF ratio vs trap omega",
        data_source = "runs/paper2_Eu_predictions/",
        kind = :line_plot,
        builder = :build_paper2_fig3,
    ),

    # Paper #3
    ("paper3", "FIG-1") => (
        title = "Schur-pipeline schematic (H ⊂ SO(3) → T₁ → isotropy → universal form)",
        data_source = "conceptual",
        kind = :tikz_diagram,
        builder = :build_paper3_fig1,
    ),
    ("paper3", "FIG-2") => (
        title = "Sign Pattern β_S^(λ_spin) vs S for 6 F-cases",
        data_source = "scripts/manuscript/lemma1_general_S_verification.jl",
        kind = :scatter_grid,
        builder = :build_paper3_fig2,
    ),
    ("paper3", "FIG-3") => (
        title = "F-systematic 13-instance verification (β_0 = 1/(2F+1))",
        data_source = "scripts/manuscript/f_systematic_lemma1_predictions.jl",
        kind = :verification_table,
        builder = :build_paper3_fig3,
    ),
    ("paper3", "FIG-4") => (
        title = "Three-exception classification {F=1, F=2, F=5}",
        data_source = "conceptual",
        kind = :tikz_diagram,
        builder = :build_paper3_fig4,
    ),
    ("paper3", "FIG-6") => (
        title = "Polyhedral inert state Majorana configurations",
        data_source = "rendered 2026-05-11 (existing)",
        kind = :majorana_3d_grid,
        builder = :build_paper3_fig6,
    ),

    # Paper #4
    ("paper4", "FIG-1") => (
        title = "Mean-field GP-LHY post-quench snapshot at t=5",
        data_source = "runs/paper4_meanfield/",
        kind = :density_2d,
        builder = :build_paper4_fig1,
    ),
    ("paper4", "FIG-2") => (
        title = "σ/μ vs N showing 1/√N breakdown",
        data_source = "runs/sigma_mu_scan_round5/",
        kind = :loglog_plot,
        builder = :build_paper4_fig2,
    ),
    ("paper4", "FIG-3") => (
        title = "Species universality: σ/μ vs ε_dd",
        data_source = "runs/species_scan_round6/",
        kind = :scatter_plot,
        builder = :build_paper4_fig3,
    ),
    ("paper4", "FIG-4") => (
        title = "Lyapunov trajectory divergence",
        data_source = "runs/lyapunov_diagnostic_round6/",
        kind = :semilog_plot,
        builder = :build_paper4_fig4,
    ),
    ("paper4", "FIG-5") => (
        title = "50-trajectory ensemble traces at Eu",
        data_source = "runs/ensemble_traces_round5/",
        kind = :trace_overlay,
        builder = :build_paper4_fig5,
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

# All builders take (paper::String, fig::String) and write PDF + SVG to
# output_path(paper, fig, "pdf"/"svg"). They are currently stubs that
# error with a NotImplemented message — implementation pending the
# data sources being populated in `runs/`.

function build_stub(paper, fig, info)
    @printf("[NOT IMPLEMENTED] %s %s: %s\n", paper, fig, info.title)
    @printf("  data source: %s\n", info.data_source)
    @printf("  kind: %s\n", info.kind)
    @printf("  output target: %s\n", output_path(paper, fig, "pdf"))
    @printf("  → run the data-generating job first if data_source is a runs/ dir,\n")
    @printf("    or write the TikZ source if conceptual\n")
end

# Dispatch all builders to the stub for now. Real implementations
# follow the same `build_*(paper, fig)` signature.
for ((paper, fig), info) in FIGURE_REGISTRY
    @eval function $(info.builder)(paper::String, fig::String, info)
        build_stub(paper, fig, info)
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
            paper = args[i + 1]; i += 2
        elseif args[i] == "--fig" && i + 1 <= length(args)
            fig = args[i + 1]; i += 2
        elseif args[i] == "--list"
            list = true; i += 1
        else
            i += 1
        end
    end
    (paper = paper, fig = fig, list = list)
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
        return
    end
    if opts.paper === nothing || opts.fig === nothing
        @printf("Usage: julia render_figures.jl [--list | --paper <paper> --fig <FIG-N>]\n")
        @printf("\nAvailable figures:\n")
        list_figures()
        return
    end
    fig_normalized = uppercase(opts.fig)
    if !haskey(FIGURE_REGISTRY, (opts.paper, fig_normalized))
        @printf("ERROR: figure (%s, %s) not in registry\n", opts.paper, fig_normalized)
        @printf("\nAvailable figures:\n")
        list_figures()
        return
    end
    info = FIGURE_REGISTRY[(opts.paper, fig_normalized)]
    builder_func = getfield(@__MODULE__, info.builder)
    builder_func(opts.paper, fig_normalized, info)
end

main()
