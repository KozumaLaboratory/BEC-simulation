# --- Foundation subsystem umbrella ---
#
# Type definitions + mathematical foundation. Files load in dependency
# order: Waveform → Grid → AbstractPotential → spin/atom →
# interactions+Zeeman → SimParams/SimState/FFT → DDI/Loss → integrator →
# Workspace → results/scan; then math primitives (grid factory, FFT
# utils, backend dispatch, spin matrices, spinor utils, Clebsch-Gordan,
# spherical harmonics).

# Type definitions (must come first; Workspace depends on everything above).
include("foundation/waveform.jl")
include("foundation/noise_waveform.jl")           # seeded analytic field-noise waveform
include("foundation/types/grid.jl")              # AbstractBackend, GridConfig, Grid
include("foundation/types/potentials.jl")        # AbstractPotential + 12 trap / beam / lattice / gradient subtypes
include("foundation/types/spin_atom.jl")         # SpinSystem, SpinMatrices, AtomSpecies
include("foundation/types/interactions_zeeman.jl") # InteractionParams, ZeemanParams, TimeDependent*, Raman, accessors
include("foundation/types/spatial_zeeman.jl")    # SpatialZeemanField + builders + per-voxel kernel (arbitrary B(r))
include("foundation/types/sim_fft.jl")           # SimParams, SimState, FFTPlans, RFFT, BatchedKineticCache, CoriolisCache, AbsorbingBoundary
include("foundation/types/ddi_loss.jl")          # DDIParams, DDIBuffers, DDIPaddedContext, LossParams, LightShift, TensorInteractionCache
include("foundation/types/integrator.jl")        # AdaptiveDtParams, IntegratorConfig, SimulationResult, TWAConfig, EnsembleResult
include("foundation/types/workspace.jl")         # Workspace + workspace_T (depends on everything above)
include("foundation/types/results.jl")           # TOFParams, BdGResult, InstabilityMap, RotonParams, etc
include("foundation/types/scan.jl")              # OverrideScan, ConstrainedJzScan, ITPCheckpoint
include("foundation/types/tdhfb_state.jl")        # TDHFBState (Phase 1 scaffold; kernels live in hamiltonian/tdhfb/)
include("foundation/types/preset.jl")             # Preset (frozen atom/grid/interactions bundle for sweep scripts)

# Mathematical foundation.
include("foundation/grid.jl")
include("foundation/fft_utils.jl")
include("foundation/backend.jl")
include("foundation/scratch.jl")
include("foundation/voxel_index.jl")   # _voxel_index: contiguous vs zero-padded-corner field access
include("foundation/fft_planning.jl")   # default_fft_flags: MEASURE is not reproducible
include("foundation/elapsed.jl")   # elapsed_s: durations come from the MONOTONIC clock
include("foundation/thresholds.jl")
include("foundation/spin_matrices.jl")
include("foundation/spinor_utils.jl")
include("foundation/clebsch_gordan.jl")
include("foundation/spherical_harmonics.jl")
include("foundation/optical_pumping_rate_eq.jl")  # F→F+1 cycling rate eq, σ_eff(m) for absorption imaging
include("foundation/optics.jl")                   # Gaussian-beam model (OpticalBeam + ABCD + fiber coupling); shared by trap potentials, evaporation, unitful
