# Sweep-view system: the data side of parameter-sweep visualisation.
#
# Umbrella over the sweep subsystem (split out of the former 2192-line monolith).
# Sub-files, included in dependency order:
#
#   * sweep/types.jl        — SweepResult contract + axes / observables + hypothesis
#                             apparatus + dominant-m margin extraction.
#   * sweep/colormaps.jl    — frozen reference LUTs + per-cell hex resolution.
#   * sweep/golden_table.jl — golden per-cell table emitter + VSUP alpha-fade.
#   * sweep/viewspec.jl     — SweepResult → Vega-Lite spec dispatcher.
#
# `SweepResult` is the single source of truth that both the dashboard `to_viewspec`
# pipeline and Makie `plot_sweep` consume. The dispatcher picks the view_shape and
# emits a Vega-Lite spec; renderers paint the spec, they do not decide.

using JSON

include("sweep/types.jl")
include("sweep/colormaps.jl")
include("sweep/golden_table.jl")
include("sweep/viewspec.jl")
