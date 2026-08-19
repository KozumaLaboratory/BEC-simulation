# --- Solvers subsystem umbrella ---
#
# Ground state finders + real-time evolution drivers. Each file exports
# its public surface at definition site:
#
#   ground_state*          — ITP entry, loop kernel, checkpointing,
#                            adaptive ITP, multistart + Jz-constrained
#   simulation             — RTP entry + SimulationCallbacks
#   adaptive               — adaptive-dt (step_change + richardson modes)
#   lbfgs/{energy_gradient,helpers,driver}
#                          — energy + gradient + Sobolev pre + line search
#                            + find_ground_state_lbfgs entry
#   continuation/{scan_1d,scan_2d,boundary,pseudo_arclength,triple_point}
#                          — 1D/2D parameter sweeps + boundary tracing
#   twa                    — Truncated Wigner Approximation driver
#   binary_simulation      — two-component GP real-time propagation

include("solvers/convergence_metrics.jl")
include("solvers/ground_state.jl")
include("solvers/ground_state/itp_loop.jl")
include("solvers/ground_state/checkpoint.jl")
include("solvers/ground_state/adaptive.jl")
include("solvers/ground_state/advanced.jl")
include("solvers/simulation.jl")
include("solvers/adaptive.jl")
include("solvers/preconditioner.jl")
include("solvers/lbfgs/energy_gradient.jl")
include("solvers/lbfgs/helpers.jl")
include("solvers/lbfgs/atomic.jl")
include("solvers/lbfgs/driver.jl")
include("solvers/ground_state/pinned.jl")  # symmetry-breaking pin + ε→0 extrapolation (soft manifold)
include("solvers/hessian.jl")  # second-variation HvP + trapped-BdG λ_min
include("solvers/trapped_bdg.jl")  # dense non-Hermitian trapped BdG (dynamical axis)
include("solvers/newton_cg.jl")  # trust-region Newton-CG on the gate-2 operator
include("solvers/ground_state/polished.jl")  # ITP+LBFGS chain over a Preset
include("solvers/continuation/scan_1d.jl")
include("solvers/continuation/scan_2d.jl")
include("solvers/continuation/boundary.jl")
include("solvers/continuation/pseudo_arclength.jl")
include("solvers/continuation/triple_point.jl")
include("solvers/twa.jl")
include("solvers/binary_simulation.jl")
include("solvers/scalar_egpe.jl")  # adiabatic-elimination scalar GPE (fast-Larmor alt)
# 0-D truncated-Boltzmann evaporative-cooling model (thermal-cloud → BEC ramp
# optimization). Parallel to GP: scalar N(t)/T(t) kinetics, not a wavefunction.
include("solvers/evaporation/trap_geometry.jl")
include("solvers/evaporation/evaporation_model.jl")
include("solvers/evaporation/evaporation_solve.jl")
include("solvers/evaporation/condensate.jl")  # two-component thermal+condensate (BEC transition)
include("solvers/evaporation/evaporation_optimize.jl")
include("solvers/evaporation/euv3.jl")  # lab FORT calibration + the euv3 evaporation ramp
include("solvers/evaporation/evaporation_handoff.jl")  # evaporation endpoint → GP trap config
include("solvers/evaporation/cloud_profile.jl")  # thermal-cloud spatial profile during evaporation
include("solvers/evaporation/spgpe_reservoir.jl")  # 0-D evaporation trajectory → SPGPE (T(t), μ(t))
