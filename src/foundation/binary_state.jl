# --- Two-component (binary) BEC scaffold (Phase 4.7 / Scenario #51) ---
#
# Minimal types + ITP for the binary-condensate plumbing. NOT YET wired
# into make_workspace / split_step / pipeline_runner — see
# `docs/two_component_gp_design.md` for the multi-session integration
# plan.
#
# 438-line monolith split into 3 sub-files (2026-05-11 refactor):
#
#   binary_state/types_observables.jl — BinaryCouplings, BinaryState,
#                                       SpinorBinaryCouplings/State,
#                                       is_immiscible, droplet_regime_petrov,
#                                       binary_overlap, binary_separation_radius
#   binary_state/scalar_itp.jl        — find_binary_ground_state + _binary_energy
#                                       (placeholder scalar F=0 binary GP)
#   binary_state/spinor_itp.jl        — find_spinor_binary_ground_state +
#                                       _spinor_binary_energy (real spinor
#                                       binary with Hartree g_AB)
#
# Use cases:
#   - Cr-Sr immiscibility studies
#   - ⁸⁷Rb |F=1⟩ × |F=2⟩ Ramsey
#   - Boson-boson droplet (Petrov)
#
# Public API unchanged. Exports stay at each sub-file's definition site.

include("binary_state/types_observables.jl")
include("binary_state/scalar_itp.jl")
include("binary_state/spinor_itp.jl")
