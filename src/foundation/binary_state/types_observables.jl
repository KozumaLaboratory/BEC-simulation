# Binary BEC types (scalar + spinor) + scalar-state observables.
# Types are declared here because the ITP files (scalar_itp.jl,
# spinor_itp.jl) need them at top-level scope when included.

export BinaryCouplings, BinaryState
export is_immiscible, droplet_regime_petrov
export binary_overlap, binary_separation_radius
export SpinorBinaryCouplings, SpinorBinaryState

struct BinaryCouplings
    g_AA::Float64       # intra-species A-A
    g_BB::Float64       # intra-species B-B
    g_AB::Float64       # inter-species (immiscibility when g_AB^2 > g_AA·g_BB)
    omega_coupling::Float64    # optional Rabi flip A ↔ B (real)
    delta_coupling::Float64    # optional detuning between species
end

BinaryCouplings(; g_AA::Real, g_BB::Real, g_AB::Real,
omega_coupling::Real=0.0, delta_coupling::Real=0.0) = BinaryCouplings(Float64(g_AA), Float64(g_BB),
    Float64(g_AB),
    Float64(omega_coupling), Float64(delta_coupling))

mutable struct BinaryState{N, A1 <: AbstractArray, A2 <: AbstractArray}
    psi_A::A1
    psi_B::A2
    t::Float64
    step::Int
end

"""
    is_immiscible(c::BinaryCouplings) -> Bool

Mean-field immiscibility criterion: g_AB^2 > g_AA * g_BB. When true,
the two species spatially separate at zero temperature.
"""
is_immiscible(c::BinaryCouplings) = c.g_AB^2 > c.g_AA * c.g_BB

"""
    droplet_regime_petrov(c::BinaryCouplings) -> Bool

Petrov-droplet sign criterion: requires g_AB < 0 and |g_AB| slightly
above √(g_AA·g_BB) so the LHY positive contribution stabilises. This
function only reports the mean-field sign condition; an LHY check is
needed to confirm the droplet is bound.
"""
droplet_regime_petrov(c::BinaryCouplings) =
    c.g_AB < 0 && c.g_AB^2 > c.g_AA * c.g_BB

# --- Binary system observables -----------------------------------------

"""
    binary_overlap(state) -> Float64

Spatial overlap integral ∫ √(n_A·n_B) dV. 0 = perfectly demixed,
1 = identical density profiles. Quick immiscibility metric for the
ground state of a binary system.

Requires the BinaryState carry the spatial grid implicitly; for
the scaffold case we accept the grid as a 2nd argument.
"""
function binary_overlap(state::BinaryState, grid)
    # Manual reduction skips the `abs2.`/`sqrt.` temporaries — the
    # overlap is just `Σ √(|ψ_A|² · |ψ_B|²)·dV = Σ |ψ_A|·|ψ_B|·dV`.
    s = 0.0
    @inbounds for i in eachindex(state.psi_A, state.psi_B)
        s += abs(state.psi_A[i]) * abs(state.psi_B[i])
    end
    s * cell_volume(grid)
end

"""
    binary_separation_radius(state, grid) -> Float64

L²-distance between the COM of species A and species B (in a_ho units).
Robust scalar measure of phase separation.
"""
function binary_separation_radius(state::BinaryState, grid::Grid{N}) where {N}
    n_A = abs2.(state.psi_A)
    n_B = abs2.(state.psi_B)
    dV = cell_volume(grid)
    n_A_tot = sum(n_A) * dV
    n_B_tot = sum(n_B) * dV
    com_A = ntuple(d -> sum(n_A .* _coord_axis_array(grid, d, N)) * dV / n_A_tot, N)
    com_B = ntuple(d -> sum(n_B .* _coord_axis_array(grid, d, N)) * dV / n_B_tot, N)
    sqrt(sum((com_A[d] - com_B[d])^2 for d in 1:N))
end

# Helper: broadcast the grid coordinate along axis d to the full N-D shape
function _coord_axis_array(grid::Grid{N}, d::Int, ::Int) where {N}
    coords = grid.x[d]
    shape = ntuple(i -> i == d ? length(coords) : 1, N)
    reshape(coords, shape)
end

# --- Spinor binary types -----------------------------------------------

"""
    SpinorBinaryCouplings(; F_A, F_B, c0_A, c1_A, c0_B, c1_B, g_AB)

Couplings for two spinor species with intra-species (c0/c1 in standard
SpinorBEC convention) and an inter-species Hartree contact term g_AB
(applied to total densities only).

Per-channel spinor-spinor coupling (e.g. spin-2 + spin-2 with separate
F_pair=0,2,4 channels) is a follow-up — for now g_AB is a single scalar.
"""
struct SpinorBinaryCouplings
    F_A::Int
    F_B::Int
    c0_A::Float64
    c1_A::Float64
    c0_B::Float64
    c1_B::Float64
    g_AB::Float64
end

SpinorBinaryCouplings(; F_A::Int, F_B::Int, c0_A::Real, c1_A::Real,
c0_B::Real, c1_B::Real, g_AB::Real) = SpinorBinaryCouplings(F_A, F_B,
    Float64(c0_A), Float64(c1_A),
    Float64(c0_B), Float64(c1_B),
    Float64(g_AB))

mutable struct SpinorBinaryState{N, A1 <: AbstractArray, A2 <: AbstractArray}
    psi_A::A1                # shape (n_pts..., 2F_A+1)
    psi_B::A2                # shape (n_pts..., 2F_B+1)
    couplings::SpinorBinaryCouplings
    t::Float64
    step::Int
end
