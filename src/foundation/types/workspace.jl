# --- Workspace: the master per-simulation state container ---
#
# `Workspace{N, A, P, IP, SM, ZEE, DDI, DDIB, RAM, LOSS, DDIP, BK, TC,
# CC, KPA, VPA, DBA, BACK, LHY, ABM, LS, TDI, MG}` — 23 type
# parameters. CLAUDE.md's "Type stability boundaries" section
# explains why this many parameters is load-bearing: every field that
# might be `Nothing` vs. a concrete struct gets a parameter so the
# compiler can specialise. Helper functions that take a workspace
# field must dispatch on a concrete type, never on `Any`-typed locals.
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
    LOSS,
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
    TDI,
    MG,
    T <: AbstractFloat,
}
    state::SimState{N, A}
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
    loss::LOSS
    ddi_padded::DDIP
    batched_kinetic::BK
    tensor_cache::TC
    coriolis_cache::CC
    backend::BACK
    lhy::LHY
    absorbing_mask::ABM
    light_shift::LS
    time_dep_interactions::TDI
    magnetic_gradient::MG
end

"""
Real eltype carried by a Workspace's ψ. For mixed-precision audits:
`workspace_T(ws)` returns `Float32` for an F32 build, `Float64` for the
default. Equivalent to `real(eltype(ws.state.psi))` but documented +
exported so callers don't reach into internals.
"""
@inline workspace_T(ws::Workspace{N, A}) where {N, A} = real(eltype(A))
