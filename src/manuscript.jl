# --- Manuscript subsystem umbrella ---
#
# Loads the figure-rendering subsystem (CSV/Python/TikZ emitters keyed by
# (paper, FIG-N)). Public entry points: `render_manuscript_figure`,
# `list_manuscript_figures`. CLI access via `scripts/cli.jl figure ...`.

include("manuscript/figures.jl")
