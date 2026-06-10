# Workspace has 20 type parameters (down from 25 as of 2026-05-23):
#   Phase 1 (5a8bced): dropped LOSS / TDI / MG
#   Phase 2 (242fb3b): dropped TC (TensorInteractionCache; non-parametric)
#   Phase 3 (this commit): dropped ZEE (2-way Union of non-parametric structs)
#
# `RAM` was a Phase 2 candidate but reverted after measurement
# (`scripts/diag/workspace_jit_baseline.jl`): the 3-way Union
# `Union{Nothing, RamanCoupling{N}, TimeDependentRaman{N}}` triggered
# a +20-40 % cold-JIT regression on F=1/3/6 combos vs the parametric
# form. Keep RAM as a type parameter.
#
# Each dropped parameter fronts a `Union{Nothing, ConcreteStruct}`
# field where the concrete arm has no further parametric subtypes
# (LossParams, TimeDependentInteractions, TensorInteractionCache;
# MagneticGradient{N} / TimeDependentMagneticGradient{N} share the
# Workspace's `N`). Post-`!== nothing` narrowing gives the call site
# a concrete type. Measured: cold combos 12-32 % faster across
# F=0/1/3/6, swap-only combos (loss=nothing ↔ LossParams) become free
# since both produce the same Workspace type (hash matches).
#
# Keep these AS PARAMETERS (collapsing has measurable cost):
# - `LS` (light_shift): LightShift{A} where A depends on backend (CPU
#   Array vs CuArray) — collapsing breaks hot-path dispatch.
# - `ABM` (absorbing_mask): the broadcast `psi_view .*= mask` in
#   `apply_absorbing_boundary!` dispatches on the concrete array type.
# - `DDI / DDIB / DDIP`: hot-path DDI step needs concrete FFT buffer
#   types; collapsing breaks the rFFT plan dispatch.
# - `CC` (coriolis_cache): CoriolisCache{P1,IP1,P2,IP2} carries 4 FFT
#   plan type params; abstract-Union would lose them all.
# - `LHY`: 10+ concrete subtypes of AbstractLHY; Julia's Union splitting
#   degrades past ~4 alternatives.
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
# `Workspace{N, A, P, IP, SM, DDI, DDIB, RAM, DDIP, BK, CC, KPA, VPA,
# DBA, BACK, LHY, ABM, LS, T, B}` — 20 type parameters. CLAUDE.md's
# "Type stability boundaries" section explains why these parameters
# are load-bearing: every field that might be `Nothing` vs. a concrete
# struct gets a parameter so the compiler can specialise. Helper
# functions that take a workspace field must dispatch on a concrete
# type, never on `Any`-typed locals.
#
# Five parameters were dropped 2026-05-23 (LOSS / TDI / MG / TC / ZEE);
# see the file-header comment above for the rationale + measurement.
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
    DDI,
    DDIB,
    RAM,
    DDIP,
    BK,
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
    # `zeeman::Union{ZeemanParams, TimeDependentZeeman}` — 2-way Union of
    # two non-parametric structs. Phase 3 drop (TC pattern). Hot-path
    # accessors (linear_p / quadratic_q / transverse_b) dispatch on the
    # concrete type via Julia's Union splitting; the parametric form
    # carried no additional information.
    zeeman::Union{ZeemanParams, TimeDependentZeeman}
    potential::AbstractPotential
    sim_params::SimParams
    ddi::DDI
    ddi_bufs::DDIB
    raman::RAM
    # `loss::Union{Nothing, LossParams}` — concrete LossParams has no
    # parametric subtypes, so Union splitting at `if ws.loss !== nothing`
    # narrows to the concrete type at the call site. Phase 1 drop —
    # saves ~150ms of cold JIT on a swap-loss-only combo with no
    # hot-path measurable regression.
    loss::Union{Nothing, LossParams}
    ddi_padded::DDIP
    batched_kinetic::BK
    # `tensor_cache::Union{Nothing, TensorInteractionCache}` —
    # TensorInteractionCache is a plain parameter-less struct (Int + Dict
    # + Vector fields), so dropping the TC parameter has no inference
    # impact. Phase 2 drop.
    tensor_cache::Union{Nothing, TensorInteractionCache}
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
    # `spatial_zeeman::Union{Nothing, SpatialZeemanField{N}}` — arbitrary B(r)
    # Zeeman field (SpatialZeemanTerm). Concrete arm is parameterised on N
    # (already a Workspace param), so Union splitting narrows to concrete.
    # CPU-only propagator; make_workspace rejects GPU / spin-rotating frame.
    spatial_zeeman::Union{Nothing, SpatialZeemanField{N}}
end

"""
Real eltype carried by a Workspace's ψ. For mixed-precision audits:
`workspace_T(ws)` returns `Float32` for an F32 build, `Float64` for the
default. Equivalent to `real(eltype(ws.state.psi))` but documented +
exported so callers don't reach into internals.
"""
@inline workspace_T(ws::Workspace{N, A}) where {N, A} = real(eltype(A))
