# Workspace has 22 type parameters (down from 25 as of 2026-05-23 Phase 1
# refactor). Each `Union{Nothing, ConcreteStruct}` field originally had
# its own parameter so the compiler could specialise through it. Three
# were dropped — `LOSS`, `TDI`, `MG` — because each Union arm is a
# single concrete struct (or two siblings whose other type params are
# already pinned via `N`), so post-`!== nothing` narrowing gives the
# compiler a concrete type at the call site. Measured with
# `scripts/diag/workspace_jit_baseline.jl`: cold combos unchanged, loss-
# only cold swap dropped from ~150ms to ~0ms.
#
# Keep these AS PARAMETERS (collapsing has measurable cost):
# - `LS` (light_shift): LightShift{A} where A depends on backend (CPU
#   Array vs CuArray) — collapsing breaks hot-path dispatch.
# - `ABM` (absorbing_mask): the broadcast `psi_view .*= mask` in
#   `apply_absorbing_boundary!` dispatches on the concrete array type.
# - `DDI / DDIB / DDIP`: hot-path DDI step needs concrete FFT buffer
#   types; collapsing breaks the rFFT plan dispatch.
# - Anything with array eltype/backend dependence.
#
# Re-introducing parameters is fine; collapsing the wrong one has hit
# the inference cascade (observed 2026-03 as a 30-min JIT hang with
# `Grid{N}`). Run `scripts/diag/workspace_jit_baseline.jl` before/after
# any future refactor.
# See: CLAUDE.md §"Type stability boundaries", MEMORY pitfall_partial_type_params_in_struct_fields
#
# DESIGN NOTE — why Workspace and RotatingBasisWS are NOT a shared AbstractWorkspace
# (re-evaluated 2026-05-13; permanent decision):
# (1) Tiny common surface — only grid::Grid{N,T}, spin_matrices, backend overlap.
#     The other ~13/~10 fields are mutually exclusive (Workspace: tensor_cache,
#     coriolis_cache, time_dep_interactions, magnetic_gradient, absorbing_mask,
#     loss, light_shift, raman; RotatingBasisWS: theta/phi_func + their dots,
#     psi_tilde + psi_lab + rotation_scratch + kspace/xspace phase buffers).
# (2) Pipeline inference firewall — `run_step_rotating/ground_state.jl:197`
#     deliberately keeps RotatingBasisWS OUT of the returned pipeline tuple
#     because the combined inference space (Workspace ∪ RotatingBasisWS
#     through an AbstractWorkspace-typed local) is the textbook trigger for
#     the 30-min JIT hang documented in CLAUDE.md.
# (3) No call-site demand — propagators already dispatch on the concrete
#     struct (`split_step!(::Workspace{N})` vs `apply_local_spin_step!(::RotatingBasisWS)`).
# Trait dispatch (HasGauge/NoGauge) was considered and rejected on the same
# grounds: functionally equivalent to concrete dispatch but adds a layer the
# compiler must resolve, with no measurable benefit.
#
# --- Workspace: the master per-simulation state container ---
#
# `Workspace{N, A, P, IP, SM, ZEE, DDI, DDIB, RAM, DDIP, BK, TC, CC,
# KPA, VPA, DBA, BACK, LHY, ABM, LS, T, B}` — 22 type parameters.
# CLAUDE.md's "Type stability boundaries" section explains why this
# many parameters is load-bearing: every field that might be `Nothing`
# vs. a concrete struct gets a parameter so the compiler can
# specialise. Helper functions that take a workspace field must
# dispatch on a concrete type, never on `Any`-typed locals.
#
# Three parameters were dropped 2026-05-23 (LOSS / TDI / MG); see the
# file-header comment above for the rationale and the measurement.
#
# This struct lives in its own file (rather than the main types.jl)
# so the include order can stay legible: every type Workspace depends
# on (Grid, AtomSpecies, InteractionParams, AbstractPotential,
# SimParams, SpinMatrices, FFTPlans, etc) is already defined by the
# time we get here.

export Workspace, workspace_T

struct Workspace{
    N,
    A,
    P,
    IP,
    SM <: SpinMatrices,
    ZEE,
    DDI,
    DDIB,
    RAM,
    DDIP,
    BK,
    TC,
    CC,
    KPA <: AbstractArray,
    VPA <: AbstractArray,
    DBA <: AbstractArray,
    BACK <: AbstractBackend,
    LHY,
    ABM,
    LS,
    T <: AbstractFloat,
    B <: AbstractArray,
}
    # SimState has parameters `{N, A, B, T}`. Declaring `::SimState{N, A}`
    # leaves B (fft_buf type) and T (float type) abstract — same boxing
    # pitfall as the Grid issue. `ws.state.fft_buf[i]` in a hot loop
    # measured 19,460 allocs / 508 KB without the B/T pinning.
    state::SimState{N, A, B, T}
    fft_plans::FFTPlans{P, IP}
    kinetic_phase::KPA
    potential_values::VPA
    density_buf::DBA
    spin_matrices::SM
    # Grid has two parameters `Grid{N, T}` — declaring `::Grid{N}` here
    # leaves T abstract. Reading `ws.grid.k_squared[i]` then routes
    # through dynamic dispatch (~3 boxing allocs per element in a loop;
    # measured 11.7K allocs / 188 KB on a 16³ k_squared traversal).
    # Pin T as a workspace type parameter so the float type propagates.
    grid::Grid{N, T}
    atom::AtomSpecies
    interactions::InteractionParams
    zeeman::ZEE
    potential::AbstractPotential
    sim_params::SimParams
    ddi::DDI
    ddi_bufs::DDIB
    raman::RAM
    # `loss::Union{Nothing, LossParams}` — concrete LossParams has no
    # parametric subtypes, so Union splitting at `if ws.loss !== nothing`
    # narrows to the concrete type at the call site. Dropping the LOSS
    # parameter (was 10th) saves ~150ms of cold JIT on a swap-loss-only
    # combo with no hot-path measurable regression.
    loss::Union{Nothing, LossParams}
    ddi_padded::DDIP
    batched_kinetic::BK
    tensor_cache::TC
    coriolis_cache::CC
    backend::BACK
    lhy::LHY
    absorbing_mask::ABM
    light_shift::LS
    # `time_dep_interactions::Union{Nothing, TimeDependentInteractions}` —
    # concrete `TimeDependentInteractions` carries Waveform fields with
    # abstract type already, so the workspace-level parameter added no
    # specialisation. Dropped in the same Phase 1 refactor.
    time_dep_interactions::Union{Nothing, TimeDependentInteractions}
    # `magnetic_gradient::Union{Nothing, MagneticGradient{N},
    # TimeDependentMagneticGradient{N}}` — both concrete arms are
    # parameterised on N which is already a Workspace type parameter,
    # so Union splitting gives the call site a concrete narrowed type.
    magnetic_gradient::Union{Nothing, MagneticGradient{N}, TimeDependentMagneticGradient{N}}
end

"""
Real eltype carried by a Workspace's ψ. For mixed-precision audits:
`workspace_T(ws)` returns `Float32` for an F32 build, `Float64` for the
default. Equivalent to `real(eltype(ws.state.psi))` but documented +
exported so callers don't reach into internals.
"""
@inline workspace_T(ws::Workspace{N, A}) where {N, A} = real(eltype(A))
