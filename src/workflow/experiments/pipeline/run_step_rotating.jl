# --- Option γ rotating-basis step dispatch + chirp helpers ---
#
# YAML schema (unified `B:` block; magnitude + direction in one mapping):
#
#   ground_state:
#     kind: rotating_basis
#     atom: Eu151                      # name; pulled to populate F via atom DB
#     grid: {n: [16, 16, 16], box: [12, 12, 12]}
#     potential: {type: harmonic, omega: [1, 1, 1]}
#     interactions: {c0: 100, c1: 0, c_dd: 5, gamma_lhy: 0}
#     B:                               # unified magnetic-field block (mag + dir)
#       Bz: 5000                       # magnitude; alternates: B_mag, p (internal)
#       theta: 0                       # rad; constant B̂ during ITP
#       phi: 0                         # rad
#       # q auto-derived from |B|² (override with explicit q: <value> if needed)
#     gauge_fix: false                 # default true; set false to recover ψ_lab=Û_B ψ̃
#     n_steps: 200
#     dt: 0.005
#     init_m_idx: 1                    # start in m=+F (default 1)
#
#   dynamics:
#     kind: rotating_basis
#     duration: 1.0
#     dt: 0.005
#     B:                               # time-dep field; same block as ground_state
#       theta: 0.611                   # rad (constant during this step)
#       phi:
#         rate: 4.524                  # rad/dimless. φ(t) = phi_rate * t (= ω_stir)
#     save_every: 10                   # for trajectory observables (norm, per_m, L_z)
#
# Future-extensible: full waveform spec for theta(t), theta_dot(t),
# phi(t), phi_dot(t) (deferred this session — constant tilt + linear
# rotation covers rotating-B magnetostir).
#
# 557-line monolith split into 4 sub-files (2026-05-11 refactor):
#
#   run_step_rotating/waveforms.jl    — Concrete callable types
#                                        (_ConstAngle, _ConstZero,
#                                        _LinearRamp(+Dot), _LinearPhi,
#                                        _LinearChirpPhi(+Dot)) used to
#                                        avoid closure-type pollution per
#                                        memory pitfall_pipeline_inference
#   run_step_rotating/ground_state.jl — _run_rotating_basis_ground_state_step
#                                        (grid + V_trap + interactions auto-
#                                        derive + Gaussian seed + ITP)
#   run_step_rotating/dynamics.jl     — _run_rotating_basis_dynamics_inner
#                                        (ε→dt resolution, Larmor regime
#                                        guard, B̂(t) waveform wiring,
#                                        integrator dispatch, observable
#                                        history accumulation)
#   run_step_rotating/dispatch.jl     — _run_step methods for
#                                        RotatingBasisGroundStateStep and
#                                        RotatingBasisDynamicsStep
#                                        (@noinline boundary preserved)
#
# Include order matters: waveforms supply callables used by the GS step;
# both step bodies must be defined before the _run_step dispatchers
# reference them. Public API unchanged.

include("run_step_rotating/waveforms.jl")
include("run_step_rotating/ground_state.jl")
include("run_step_rotating/dynamics.jl")
include("run_step_rotating/dispatch.jl")
