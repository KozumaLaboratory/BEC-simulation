# --- foundation/types entry point (split 2026-05-02) ---
#
# This file used to be a 714-line monolith holding every shared
# struct (Grid, AtomSpecies, InteractionParams, ZeemanParams,
# DDIParams, Workspace …). It is now a placeholder: the actual types
# live in topical files under foundation/types/, included from
# SpinorBEC.jl in dependency order:
#
#   types/grid.jl                 ← AbstractBackend, GridConfig, Grid, GridF64
#   types/potentials.jl           ← AbstractPotential + 12 trap/beam/lattice/gradient subtypes
#   types/spin_atom.jl            ← SpinSystem, SpinMatrices, AtomSpecies
#   types/interactions_zeeman.jl  ← InteractionParams, ZeemanParams, TimeDependent*, Raman, get_cn,
#                                   linear_p / quadratic_q / transverse_b / interactions_at
#   types/sim_fft.jl              ← SimParams, SimState, FFTPlans, RFFTPlans, BatchedKineticCache,
#                                   CoriolisCache, AbsorbingBoundary
#   types/ddi_loss.jl             ← DDIParams, DDIBuffers, DDIPaddedContext, LossParams,
#                                   LightShift, TensorInteractionCache
#   types/integrator.jl           ← AdaptiveDtParams, IntegratorConfig, SimulationResult,
#                                   TWAConfig, EnsembleResult
#   types/workspace.jl            ← Workspace + workspace_T (depends on everything above)
#   types/results.jl              ← TOFParams, BdGResult, InstabilityMap, RotonParams, etc.
#   types/scan.jl                 ← OverrideScan, ConstrainedJzScan, ITPCheckpoint
#
# Per CLAUDE.md the rule "all structs in types.jl, included first"
# remains: this file is still included near the top of the module,
# right after the topical sub-files. New shared structs go into
# whichever sub-file fits semantically.

using StaticArrays
using LinearAlgebra
using FFTW
