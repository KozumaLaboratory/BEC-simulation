# --- Large analyzer implementations extracted from _run_analyzer ---
#
# 5 of the 31 analyzer kinds had bodies > 70 lines each. Each is now a
# standalone `_analyze_<name>(psi, grid, atom, params, ws_prev) -> Any`
# helper. The dispatcher in pipeline_analyzers.jl delegates via 1-line
# `elseif` branches.
#
# 432-line monolith split into 5 topic-grouped sub-files
# (2026-05-11 refactor round):
#
#   analyzers_large/skyrmion_detect.jl       — local-maxima topo charge
#   analyzers_large/synthetic_dim.jl         — m-axis as synthetic site
#   analyzers_large/bogoliubov_mode.jl       — BdG eigenvector + weights
#   analyzers_large/rosensweig_pattern.jl    — DDI hex / stripe ring peak
#   analyzers_large/column_density_movie.jl  — JLD2 snapshot column movie
#
# Public API unchanged; each sub-file owns its own helper definition.

include("analyzers_large/skyrmion_detect.jl")
include("analyzers_large/synthetic_dim.jl")
include("analyzers_large/bogoliubov_mode.jl")
include("analyzers_large/rosensweig_pattern.jl")
include("analyzers_large/column_density_movie.jl")
