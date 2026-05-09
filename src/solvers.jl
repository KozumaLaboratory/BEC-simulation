# --- Solvers subsystem umbrella ---
#
# Ground state finders + real-time evolution drivers. Each file exports
# its public surface at definition site:
#
#   ground_state*          — ITP entry, loop kernel, checkpointing,
#                            adaptive ITP, multistart + Jz-constrained
#   simulation             — RTP entry + SimulationCallbacks
#   adaptive/embedded_adaptive — adaptive-dt + embedded-error variants
#   lbfgs/{energy_gradient,helpers,driver}
#                          — energy + gradient + Sobolev pre + line search
#                            + find_ground_state_lbfgs entry
#   continuation/{scan_1d,scan_2d,boundary,pseudo_arclength,triple_point}
#                          — 1D/2D parameter sweeps + boundary tracing
#   twa                    — Truncated Wigner Approximation driver
#   binary_simulation      — two-component GP real-time propagation

include("solvers/ground_state.jl")
include("solvers/ground_state/itp_loop.jl")
include("solvers/ground_state/checkpoint.jl")
include("solvers/ground_state/adaptive.jl")
include("solvers/ground_state/advanced.jl")
include("solvers/simulation.jl")
include("solvers/adaptive.jl")
include("solvers/embedded_adaptive.jl")
include("solvers/lbfgs/energy_gradient.jl")
include("solvers/lbfgs/helpers.jl")
include("solvers/lbfgs/driver.jl")
include("solvers/continuation/scan_1d.jl")
include("solvers/continuation/scan_2d.jl")
include("solvers/continuation/boundary.jl")
include("solvers/continuation/pseudo_arclength.jl")
include("solvers/continuation/triple_point.jl")
include("solvers/twa.jl")
include("solvers/binary_simulation.jl")
