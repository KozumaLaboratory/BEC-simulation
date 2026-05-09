# --- Rotating-basis (Klaus regime) subsystem umbrella ---
#
# Klaus 2022 magnetostir / high-field rotating-basis dynamics. The
# rotating-basis path removes Larmor analytically via $|\psi⟩=\hat U_B(t)|\tilde\psi⟩$
# so dt can stay ~1e-3 even at $|p\cdot F\cdot dt| > \pi$. See
# `src/rotating_basis/README.md` for design + when to use.
#
#   workspace      — RotatingBasisWS struct, Lima-Pelster Q5, U_B transforms
#   propagators    — kinetic / spatial-diagonal / local-spin / DDI / gauge
#                    substeps in the rotating basis
#   integrators    — split_step_rotating!, Yoshida 4/6, CFET 4,
#                    find_ground_state_rotating!
#   analysis       — per-m norms, total density, L_z, coordinate buffers
#   analyzers      — pipeline-level analyzer entry points
#   scalar_egpe    — adiabatic-elimination scalar GPE alternative path

include("rotating_basis/workspace.jl")
include("rotating_basis/propagators.jl")
include("rotating_basis/integrators.jl")
include("rotating_basis/analysis.jl")
include("rotating_basis/analyzers.jl")
include("rotating_basis/scalar_egpe.jl")
