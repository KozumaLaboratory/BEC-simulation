# --- Dashboard subsystem umbrella ---
#
# 21 source files implementing the static-export + live HTTP/WS dashboard
# for SpinorBEC runs. Files are split by concern:
#
#   encoding/cache/snapshots/route_helpers — shared infrastructure
#   compute/{helpers,density,phase,binary}  — number-crunch helpers
#   routes/{density,phase,vortex,scan,
#           snapshots,lab_live,misc}        — HTTP endpoint handlers
#   server/{json,data_export,router,static} — HTTP/WS server core
#   pack3d, websocket                       — binary packers + WS frames
#
# This file just `include`s each in dependency order. Public surface
# (serve_dashboard, generate_dashboard_data, export_dashboard,
# RunMetadata, load_run_metadata) is exported at definition sites.
#
# Note: this is a flat-namespace umbrella, not a `module Dashboard`. The
# subsystem is internally cohesive and could be elevated to a submodule in
# future work; the obstacle is the precompile workload reaching into
# private helpers (_load_psi_cached, _compute_column_density_binary,
# _compute_phase_slice_binary, _snapshots_metadata) and the cross-module
# imports of Grid / GridConfig / FFTPlans / total_density / spin_density_vector
# / probability_current / superfluid_velocity / superfluid_vorticity /
# synthetic_dim_dispersion / make_grid / make_fft_plans / spin_matrices /
# list_runs / run_status that would all need explicit `using ..SpinorBEC:`
# declarations.

include("dashboard/encoding.jl")          # bitshuffle + zstd
include("dashboard/cache.jl")             # PSI_CACHE, JLD handle pool, atlas disk cache
include("dashboard/snapshots.jl")         # _load_psi_cached + sibling result.jld2 redirect
include("dashboard/route_helpers.jl")     # _parse_run_file / _q_int / _q_float / _q_flag / _q_sym
include("dashboard/routes/density.jl")    # density2d/3d/_bin/_max/_atlas/_rotated handlers
include("dashboard/routes/phase.jl")      # phase2d/_bin/3d_bin handlers
include("dashboard/routes/vortex.jl")     # vortex_lines + vorticity3d_bin
include("dashboard/routes/scan.jl")       # scan_group/_status, physics_summary, synthetic_dispersion
include("dashboard/routes/snapshots.jl")  # snapshots, dynamics_series, ensemble
include("dashboard/routes/lab_live.jl")   # lab_list, live_list, live
include("dashboard/routes/misc.jl")       # data, coherence, vector3d_bin
include("dashboard/server/json.jl")       # _write_json + _json_string
include("dashboard/server/data_export.jl")  # generate_dashboard_data + export_dashboard
include("dashboard/server/router.jl")     # serve_dashboard + _route_dashboard
include("dashboard/server/static.jl")     # static asset + HTTP response helpers
include("dashboard/websocket.jl")         # WS handshake + frames + serve
include("dashboard/compute/helpers.jl")   # trilinear upsample + run metadata
include("dashboard/compute/density.jl")   # 3D + column density compute
include("dashboard/compute/phase.jl")     # phase slice compute
include("dashboard/compute/binary.jl")    # binary packers (density/atlas/phase)
include("dashboard/pack3d.jl")            # 3D density/vortex/phase/vector binary packers
