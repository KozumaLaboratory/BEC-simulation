# --- Dashboard subsystem (live HTTP/WS dashboard for SpinorBEC runs) ---
#
# 21 source files split by concern:
#
#   encoding/cache/snapshots/route_helpers — shared infrastructure
#   compute/{helpers,density,phase,binary}  — number-crunch helpers
#   routes/{density,phase,vortex,scan,
#           snapshots,lab_live,misc}        — HTTP endpoint handlers
#   server/{json,data_export,router,static} — HTTP/WS server core
#   pack3d, websocket                       — binary packers + WS frames
#
# Wrapped in `module Dashboard` so dashboard internals (cache structs,
# private helpers like `_load_psi_cached`) stay isolated from the rest of
# SpinorBEC. Public surface is re-exported back to SpinorBEC at the
# include site (see SpinorBEC.jl).

module Dashboard

using JLD2
using JSON
using YAML
using Sockets
using Base64: base64encode
using FFTW
using CodecZlib: GzipCompressor
using Base: transcode
using CodecZstd: ZstdCompressor
using SHA: sha1
using Printf
using Dates
using LinearAlgebra
using Random

# Pull the SpinorBEC types and free functions used inside dashboard
# handlers. All of these must be exported at definition site by the time
# this module is included (dashboard is loaded near the bottom of the
# umbrella, after analysis + experiments).
using ..SpinorBEC: Grid, GridConfig, FFTPlans
using ..SpinorBEC: make_grid, make_fft_plans, spin_matrices
using ..SpinorBEC: spin_density_vector
using ..SpinorBEC: probability_current, superfluid_velocity, superfluid_vorticity
using ..SpinorBEC: synthetic_dim_dispersion
using ..SpinorBEC: list_runs, run_status
# Dashboard internals (pack3d.jl + compute/phase.jl) call _component_slice
# directly. It's a private helper from foundation/spinor_utils/slice_helpers.jl;
# named import here makes the cross-module reference explicit.
using ..SpinorBEC: _component_slice
# `_read_box_size` falls back to parsing config.yaml; mixin expansion is
# needed so configs whose GS step pulls `grid:` via `use: [some_mixin]`
# (e.g. eu151_edh_k3_compare via eu151_edh_phys) still resolve. Imported
# unexported.
using ..SpinorBEC: apply_templates_and_mixins!
using ..SpinorBEC: QueueEntry, autopilot_queue_root, list_queue,
    is_autopilot_dry_run, is_autopilot_paused, autopilot_set_dry_run!,
    enqueue!, Experiment, CASStore, content_id, default_store,
    inspect_config_string, inspect_config, budget_gate, refresh_budget!,
    next_profile, PROFILE_DIRECTIVES

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
include("dashboard/routes/inspect.jl")    # /api/effective_config — depends on _json_string
include("dashboard/routes/autopilot_queue.jl")  # /api/queue — autopilot state
include("dashboard/routes/autopilot_enqueue.jl") # /api/queue/enqueue — POST
include("dashboard/routes/autopilot_action.jl")  # /api/queue/action — POST
include("dashboard/server/data_export.jl")  # generate_dashboard_data + export_dashboard
include("dashboard/server/router.jl")     # serve_dashboard + _route_dashboard
include("dashboard/server/static.jl")     # static asset + HTTP response helpers
include("dashboard/websocket.jl")         # WS handshake + frames + serve
include("dashboard/compute/helpers.jl")   # trilinear upsample + run metadata
include("dashboard/compute/density.jl")   # 3D + column density compute
include("dashboard/compute/phase.jl")     # phase slice compute
include("dashboard/compute/binary.jl")    # binary packers (density/atlas/phase)
include("dashboard/pack3d.jl")            # 3D density/vortex/phase/vector binary packers

end # module Dashboard
