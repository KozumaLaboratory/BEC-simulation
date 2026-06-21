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
# HISTORICAL NOTE — there used to be a separate `RotatingBasisWS` (16 type params)
# for the magnetostir path, deliberately kept out of `Workspace` to avoid a
# combined-inference JIT blowup. It was RETIRED 2026-06-21
# (docs/design/rotating_basis_unification.md): the magnetostir now runs on the
# standard `Workspace` split-step path (field-axis eigen-exact Zeeman +
# split_step_midpoint! reproduce the rotating yoshida6 at equal cost), so there
# is one workspace type again.
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
    # The unified Zeeman field B(r,t). One field for every case — uniform /
    # spatial × static / time-dependent — as a closed concrete 3-arm Union
    # (parameterised only on N, mirroring `magnetic_gradient` below): the
    # uniform arm `ZeemanField{Nothing}` hits the diagonal-exp + uniform-rotation
    # fast path (GPU); the spatial arms (`B(r,t)` profiles / functions) hit the
    # per-voxel Euler path (CPU). Replaces the former `zeeman` + `spatial_zeeman`
    # fields. Hot-path accessors (linear_p / quadratic_q / transverse_b /
    # zeeman_at) and `field_arrays_at` dispatch on the arm via Union splitting.
    zeeman::Union{
        ZeemanField{Nothing},
        ZeemanField{NTuple{4, Array{Float64, N}}},
        ZeemanField{<:SpatioTemporalProfiles{N}},
    }
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
end

"""
Real eltype carried by a Workspace's ψ. For mixed-precision audits:
`workspace_T(ws)` returns `Float32` for an F32 build, `Float64` for the
default. Equivalent to `real(eltype(ws.state.psi))` but documented +
exported so callers don't reach into internals.
"""
@inline workspace_T(ws::Workspace{N, A}) where {N, A} = real(eltype(A))
