# --- Potential types ---
#
# Trap potentials and exotic Hamiltonian add-ons (light-shift profiles,
# magnetic gradients, Laguerre-Gauss beams, optical lattices, etc.).
# All inherit from `AbstractPotential`. Pure type definitions; the
# evaluators live in `src/hamiltonian/potentials/`.

export AbstractPotential
export HarmonicTrap, NoPotential, GravityPotential, CompositePotential
export RingPotential, BoxPotential, OpticalLatticePotential, DoubleWellPotential, QuarticPotential
export AbstractLHY, NoLHY, ScalarLHY, Quasi2DLHY
export TabulatedLHY
export TwoChannelLHY, FullBdGLHY, PolarContactLHY, PolarDipolarLHY
export FMContactLHY, FMDipolarLHY, IcosahedralLHY
export MagneticGradient, TimeDependentMagneticGradient
export LaguerreGaussBeam, PlugBeam, ShakenLatticePotential, TimeDependentTrap

# --- Potential ---

abstract type AbstractPotential end

struct HarmonicTrap{N} <: AbstractPotential
    omega::NTuple{N, Float64}
end

HarmonicTrap(omega::Float64) = HarmonicTrap((omega,))
HarmonicTrap(ox::Float64, oy::Float64) = HarmonicTrap((ox, oy))
HarmonicTrap(ox::Float64, oy::Float64, oz::Float64) = HarmonicTrap((ox, oy, oz))

struct NoPotential <: AbstractPotential end

struct GravityPotential{N} <: AbstractPotential
    g::Float64
    axis::Int

    function GravityPotential{N}(g::Float64, axis::Int) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(g, axis)
    end
end

GravityPotential(g::Float64, axis::Int, ndim::Int) = GravityPotential{ndim}(g, axis)

struct CompositePotential{N} <: AbstractPotential
    components::Vector{AbstractPotential}
end

struct RingPotential{N} <: AbstractPotential
    radius::Float64
    strength::Float64
    width::Float64
end

RingPotential(; radius=5.0, strength=50.0, width=1.0, ndim::Int=2) = RingPotential{ndim}(
    radius, strength, width
)

struct BoxPotential{N} <: AbstractPotential
    size::NTuple{N, Float64}
    wall_strength::Float64
    wall_width::Float64
end

BoxPotential(size::NTuple{N, Float64}; wall_strength=1000.0, wall_width=0.5) where {N} = BoxPotential{
    N
}(
    size, wall_strength, wall_width
)

struct OpticalLatticePotential{N} <: AbstractPotential
    depth::NTuple{N, Float64}
    period::NTuple{N, Float64}
    phase::NTuple{N, Float64}
end

OpticalLatticePotential(depth::NTuple{N, Float64}, period::NTuple{N, Float64};
phase::NTuple{N, Float64}=ntuple(_ -> 0.0, N)) where {N} = OpticalLatticePotential{N}(
    depth, period, phase
)

struct DoubleWellPotential{N} <: AbstractPotential
    separation::Float64
    barrier::Float64
    omega::NTuple{N, Float64}
    axis::Int
end

DoubleWellPotential(; separation=4.0, barrier=10.0, omega=(1.0,), axis=1) = DoubleWellPotential{
    length(omega)
}(
    separation, barrier, omega, axis
)

struct QuarticPotential{N} <: AbstractPotential
    omega::NTuple{N, Float64}
    lambda::NTuple{N, Float64}
end

# --- LHY Abstraction ---
#
# Hierarchy:
#   AbstractLHY
#     ├── NoLHY                      explicit "no correction"
#     ├── ScalarLHY                  n^(3/2) contact (1D/2D/3D)
#     ├── Quasi2DLHY                 logarithmic 2D correction
#     └── TabulatedLHY  (abstract)   density → potential lookup
#           ├── TwoChannelLHY        F ≤ 2 two-channel reduction
#           ├── FullBdGLHY           F-generic BdG-diagonalised
#           ├── PolarContactLHY      F-generic polar contact closed form
#           ├── PolarDipolarLHY      polar contact + DDI closed form
#           ├── FMContactLHY         FM contact closed form
#           ├── FMDipolarLHY         FM contact + DDI Lima-Pelster
#           └── IcosahedralLHY       F = 6 icosahedral closed form
#
# All `TabulatedLHY` subtypes carry the same shape (`densities` +
# `potential_values`); shared eval methods live in propagators / energy.

abstract type AbstractLHY end

struct NoLHY <: AbstractLHY end

struct ScalarLHY <: AbstractLHY
    c_lhy::Float64
end

struct Quasi2DLHY <: AbstractLHY
    c_lhy_2d::Float64
    a_2d_sq::Float64
    log_const::Float64
end

abstract type TabulatedLHY <: AbstractLHY end

"""
    TwoChannelLHY

Two-channel LHY reduction for polar-phase spinor BEC. Captures the m=0
phonon plus 2 (m=±1) SO(3) Goldstone modes only.

**NOT generalizable beyond F ≤ 2 — this is a mathematical constraint,
not an implementation gap.** Two-channel reduction sums over S = 0 and
S = 2 only, valid up to F = 2. For F ≥ 3 the S ≥ 4 channels are
independent (Lavoine-Bourdel 2021); regression-pinned 30–70 % off at
F = 6 in `test/test_spinor_lhy.jl`. Use `PolarContactLHY` / `PolarDipolarLHY`
(F-generic polar closed form, Paper #1) or `IcosahedralLHY` (F = 6
inert state, Paper #3) instead.
"""
struct TwoChannelLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct FullBdGLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct PolarContactLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct PolarDipolarLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct FMContactLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct FMDipolarLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct IcosahedralLHY <: TabulatedLHY
    densities::Vector{Float64}
    potential_values::Vector{Float64}
end

struct MagneticGradient{N} <: AbstractPotential
    gradient::Float64
    axis::Int
    g_F::Float64

    function MagneticGradient{N}(gradient::Float64, axis::Int, g_F::Float64) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(gradient, axis, g_F)
    end
end

MagneticGradient(; gradient=0.1, axis=3, g_F=1.0, ndim::Int=3) = MagneticGradient{ndim}(
    gradient, axis, g_F
)

struct TimeDependentMagneticGradient{N}
    gradient_wf::Waveform
    axis::Int
    g_F::Float64

    function TimeDependentMagneticGradient{N}(
        gradient_wf::Waveform, axis::Int, g_F::Float64
    ) where {N}
        1 <= axis <= N || throw(ArgumentError("axis must be between 1 and $N"))
        new{N}(gradient_wf, axis, g_F)
    end
end

TimeDependentMagneticGradient(; gradient_wf::Waveform, axis::Int=3, g_F::Float64=1.0, ndim::Int=3) = TimeDependentMagneticGradient{
    ndim
}(
    gradient_wf, axis, g_F
)

struct LaguerreGaussBeam{N} <: AbstractPotential
    power::Float64
    waist::Float64
    l_mode::Int
    p_mode::Int
    polarizability::Float64
end

LaguerreGaussBeam(; power=1.0, waist=10.0, l_mode=1, p_mode=0, polarizability=1.0, ndim::Int=2) = LaguerreGaussBeam{
    ndim
}(
    power, waist, l_mode, p_mode, polarizability
)

struct PlugBeam{N} <: AbstractPotential
    strength::Float64
    waist::Float64
end

PlugBeam(; strength=50.0, waist=2.0, ndim::Int=2) = PlugBeam{ndim}(strength, waist)

struct ShakenLatticePotential{N} <: AbstractPotential
    depth::NTuple{N, Float64}
    period::NTuple{N, Float64}
    shake_wf::NTuple{N, Waveform}
end

# Time-dependent trap (kept here with other potentials despite being in
# the original "Time-dependent extensions" section of types.jl).
struct TimeDependentTrap{N} <: AbstractPotential
    base::AbstractPotential
    omega_wf::NTuple{N, Waveform}
end
