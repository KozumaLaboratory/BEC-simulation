# --- Two-component (binary) BEC scaffold ---
#
# Scalar binary ITP + types/observables. NOT YET wired into make_workspace /
# split_step / pipeline_runner — see `docs/design/two_component_gp_design.md`
# for the multi-session integration plan.
#
#   binary_state/types_observables.jl — BinaryCouplings, BinaryState,
#                                       is_immiscible, droplet_regime_petrov,
#                                       binary_overlap, binary_separation_radius
#   binary_state/scalar_itp.jl        — find_binary_ground_state + _binary_energy
#
# Note: SpinorBinaryCouplings/State + find_spinor_binary_ground_state removed
# 2026-06-06 (unwired scaffold; see git history of binary_state/spinor_itp.jl).
#
# Use cases:
#   - Cr-Sr immiscibility studies
#   - ⁸⁷Rb |F=1⟩ × |F=2⟩ Ramsey
#   - Boson-boson droplet (Petrov)

include("binary_state/types_observables.jl")
include("binary_state/scalar_itp.jl")
