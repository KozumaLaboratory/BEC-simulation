# --- TDHFB subsystem umbrella ---
#
# Time-Dependent Hartree-Fock-Bogoliubov local-approximation engine. Tracks
# coupled (φ, ρ, κ) on a spatial grid via a voxel-local Bogoliubov-de Gennes
# matrix exponential inside a Strang split-step integrator.
#
# Files load in dependency order. The TDHFBState struct lives in
# foundation/types/tdhfb_state.jl (included by src/foundation.jl).
#
#   channel_kernel.jl              — rank-4 channel tensor Σ_S g_S Σ_M CG·CG
#                                    (shared by HF self-energy and Δ)
#   hartree_fock_matrix.jl         — F=1 c0/c1 GP-form kernel (legacy + GP
#                                    reduction reference for conservation tests)
#   hartree_fock_matrix_generic.jl — generic-F BdG self-energy U via channels
#   pair_potential.jl              — anomalous pair potential Δ from (φφ + κ)
#   strang_step.jl                 — voxel-local BdG Strang step (full coupled
#                                    (φ, ρ, κ) evolution with anomalous coupling)
#   y4_midpoint_step.jl            — Yoshida-4 + endpoint Picard wrapper around
#                                    the Strang sub-step (Phase 4, formal order 4)
#   energy.jl                      — total energy functional E[φ, ρ, κ]
#                                    (conserved by tdhfb_strang_step!)
#
# Out of scope (deferred to future sessions per
# docs/design/tdhfb_pilot_design.md Phase 4-6):
#   - YAML pipeline integration (`dynamics.tdhfb` block, run_yaml dispatch)
#   - Non-local TDHFB (ρ(r, r'), κ(r, r'))
#   - DDI / Zeeman / Raman terms in the TDHFB step
#   - GPU port + Workspace integration
#   - Thermal initial state (init_tdhfb_thermal!)
#   - Eu post-quench production runs (Phase 6)

include("tdhfb/channel_kernel.jl")
include("tdhfb/hartree_fock_matrix.jl")
include("tdhfb/hartree_fock_matrix_generic.jl")
include("tdhfb/pair_potential.jl")
include("tdhfb/strang_step.jl")
include("tdhfb/y4_midpoint_step.jl")
include("tdhfb/energy.jl")
