# --- PotentialSpec: the trap as a SUM of typed terms ---
#
# `AbstractPotential` has 16 subtypes and 15 of them are parameterised on `N`,
# so none can be a field of a non-parameterised `Model`; typing the field
# `AbstractPotential` (or even `HarmonicTrap`, which without `{N}` is a
# `UnionAll`) is an abstract field and boxes. Three of those subtypes are also
# the exact shapes the shape gate exists to reject:
# `CompositePotential.components::Vector{AbstractPotential}`,
# `TimeDependentTrap.base::AbstractPotential` + `NTuple{N,Waveform}`, and
# `ShakenLatticePotential.shake_wf::NTuple{N,Waveform}`.
#
# The alternative to a 16-arm union or a `kind::Symbol` + positional payload
# (which is the free-form slot wearing a costume) is to take the physics
# literally: V(r) is a SUM of terms, so the spec is one vector per term type and
# the field name IS the tag. Composition is then free — `CompositePotential`
# stops being a special case and becomes the only case, with the single-trap
# form as a one-element vector — and the taxonomy is closed by the compiler
# rather than by a `Symbol` that a typo can widen.
#
# Adding a trap kind therefore means adding a field here: a reviewed diff, which
# is the whole point of a ratcheted shape.
#
# Two existing kinds are deliberately unified, because their evaluators already
# compute the same function:
#   - QuarticPotential is HarmonicSpec with a non-zero `lambda`
#     (`evaluate_potential` computes `½ω²x² + λx⁴` per axis; `λ=0` is exactly
#     HarmonicTrap).
#   - ShakenLatticePotential is LatticeSpec with a time-dependent `phase`
#     (`evaluate_potential` computes `depth·sin²(kx + phase(t))`, and the static
#     OpticalLatticePotential is the same expression with a constant phase).
#
# NOT covered: `LaserBeamPotential` (`terms/trap/laser_potential.jl:9`), the
# full Gaussian-beam form with Rayleigh divergence. No parser reaches it — it is
# direct-Julia only — so it gets a field when a model needs one, not before.

export PotentialSpec, HarmonicSpec, LatticeSpec, RingSpec, BoxSpec
export GravitySpec, DoubleWellSpec, BeamSpec, DipoleTrapSpec

"""
    HarmonicSpec(; omega, lambda=(0.0,0.0,0.0))

`V = Σ_d [½ ω_d(t)² x_d² + λ_d x_d⁴]`.

`omega` is waveform-valued, which is what makes `TimeDependentTrap` unnecessary:
a trap ramp is `ω(t)`, and `TimeDependentTrap` exists only to carry `omega_wf`
beside a base potential — which the sum-of-terms shape already provides.
"""
struct HarmonicSpec <: ModelValue
    omega::NTuple{3, ModelWaveform}
    lambda::NTuple{3, Float64}

    function HarmonicSpec(omega::NTuple{3, ModelWaveform}, lambda::NTuple{3, Float64})
        all(isfinite, lambda) || throw(ArgumentError("quartic lambda must be finite"))
        new(map(canonical_waveform, omega), lambda)
    end
end

HarmonicSpec(; omega, lambda=(0.0, 0.0, 0.0)) = HarmonicSpec(
    _pad3_wf(omega), _pad3(lambda, 0.0, Float64))

"""
    LatticeSpec(; depth, period, phase=(0.0,0.0,0.0))

`V = Σ_d depth_d · sin²(2π x_d / period_d + phase_d(t))`.

A time-dependent `phase` is lattice shaking. Axes with `depth = 0` contribute
nothing, so a 1-D lattice on a 3-D grid is `depth = (V₀, 0, 0)`.
"""
struct LatticeSpec <: ModelValue
    depth::NTuple{3, Float64}
    period::NTuple{3, Float64}
    phase::NTuple{3, ModelWaveform}

    function LatticeSpec(depth::NTuple{3, Float64}, period::NTuple{3, Float64},
        phase::NTuple{3, ModelWaveform})
        for d in 1:3
            depth[d] == 0.0 || period[d] > 0 ||
                throw(
                    ArgumentError(
                        "lattice axis $d has depth $(depth[d]) but period $(period[d]); a lattice " *
                        "needs a positive period"),
                )
        end
        new(depth, period, map(canonical_waveform, phase))
    end
end

LatticeSpec(; depth, period, phase=(0.0, 0.0, 0.0)) = LatticeSpec(
    _pad3(depth, 0.0, Float64), _pad3(period, 0.0, Float64), _pad3_wf(phase))

"""
    RingSpec(; radius, strength, width)

Annular wall of height `strength` at `radius`, of thickness `width`. 2-D and up.
"""
struct RingSpec <: ModelValue
    radius::Float64
    strength::Float64
    width::Float64

    function RingSpec(radius::Float64, strength::Float64, width::Float64)
        radius > 0 || throw(ArgumentError("ring radius must be > 0; got $radius"))
        width > 0 || throw(ArgumentError("ring width must be > 0; got $width"))
        new(radius, strength, width)
    end
end

RingSpec(; radius::Real, strength::Real=50.0, width::Real=1.0) = RingSpec(
    Float64(radius), Float64(strength), Float64(width))

"""
    BoxSpec(; size, wall_strength=1000.0, wall_width=0.5)

Hard-walled box of the given inner extent, with soft walls of the given height
and thickness.
"""
struct BoxSpec <: ModelValue
    size::NTuple{3, Float64}
    wall_strength::Float64
    wall_width::Float64

    function BoxSpec(size::NTuple{3, Float64}, wall_strength::Float64, wall_width::Float64)
        wall_width > 0 || throw(ArgumentError("box wall_width must be > 0; got $wall_width"))
        new(size, wall_strength, wall_width)
    end
end

BoxSpec(; size, wall_strength::Real=1000.0, wall_width::Real=0.5) = BoxSpec(
    _pad3(size, 0.0, Float64), Float64(wall_strength), Float64(wall_width))

"""
    GravitySpec(; g, axis)

`V = g · x_axis` — a spin-INDEPENDENT linear tilt.

Functionally identical to the `magnetic_gradient` slot's `g_F · gradient · x`;
they are separate because the gradient is a `HamTerm` with its own sign
declaration and oracle while gravity is a trap term, and collapsing them would
put one physics under two audit regimes.
"""
struct GravitySpec <: ModelValue
    g::Float64
    axis::Int

    function GravitySpec(g::Float64, axis::Int)
        1 <= axis <= 3 || throw(ArgumentError("gravity axis must be in 1:3; got $axis"))
        new(g, axis)
    end
end

GravitySpec(; g::Real=9.81, axis::Integer=3) = GravitySpec(Float64(g), Int(axis))

"""
    DoubleWellSpec(; separation, barrier, omega, axis=1)

Harmonic confinement plus a Gaussian barrier of height `barrier` and rms
`separation/2` on `axis`.
"""
struct DoubleWellSpec <: ModelValue
    separation::Float64
    barrier::Float64
    omega::NTuple{3, Float64}
    axis::Int

    function DoubleWellSpec(separation::Float64, barrier::Float64,
        omega::NTuple{3, Float64}, axis::Int)
        separation > 0 ||
            throw(ArgumentError("double-well separation must be > 0; got $separation"))
        1 <= axis <= 3 || throw(ArgumentError("double-well axis must be in 1:3; got $axis"))
        new(separation, barrier, omega, axis)
    end
end

DoubleWellSpec(; separation::Real=4.0, barrier::Real=10.0, omega=(1.0, 0.0, 0.0),
    axis::Integer=1) = DoubleWellSpec(Float64(separation), Float64(barrier),
    _pad3(omega, 0.0, Float64), Int(axis))

"""
    BeamSpec(; amplitude, waist, l_mode=0)

Transverse beam profile `V = amplitude · ρ^(2l) · exp(-ρ²)` with `ρ = √2 r / waist`,
`r` the radius in the `xy` plane. `amplitude > 0` is a repulsive plug;
`amplitude < 0` is an attractive dipole trap; `l_mode > 0` is a Laguerre-Gauss
doughnut.

**`waist` is the 1/e² intensity radius**, the standard optics convention and the
one `LaguerreGaussBeam` uses (`evaluate_potential.jl:117-131` computes
`ρ = √2 r / waist`, i.e. `exp(-2r²/waist²)`). `PlugBeam`'s evaluator computes
`strength · exp(-r²/2w²)` (`:133-144`), whose 1/e² point is at `r = 2w` — so its
`w` is HALF the 1/e² radius, and `BeamSpec.waist = 2 · PlugBeam.waist`. Two
definitions of "waist" live in the current tree. The conversion belongs in the
translator, once (`resolve_gs.jl`), and the spec carries the physical number;
`test/model/test_yaml_to_model.jl` gates it against the evaluator numerically
rather than against this paragraph, which said "twice" before it was measured.
"""
struct BeamSpec <: ModelValue
    amplitude::Float64
    waist::Float64
    l_mode::Int

    function BeamSpec(amplitude::Float64, waist::Float64, l_mode::Int)
        waist > 0 || throw(ArgumentError("beam waist must be > 0; got $waist"))
        l_mode >= 0 || throw(ArgumentError("beam l_mode must be >= 0; got $l_mode"))
        new(amplitude, waist, l_mode)
    end
end

BeamSpec(; amplitude::Real, waist::Real, l_mode::Integer=0) = BeamSpec(
    Float64(amplitude), Float64(waist), Int(l_mode))

"""
    DipoleTrapSpec(; beams, polarizability)

A crossed optical dipole trap in SI units: `V = -polarizability · Σ I_beam(r)`.

`GaussianBeam` (`terms/trap/optical_trap.jl:3`) is reused verbatim — it is
already concrete, non-parametric, immutable and closure-free, which makes
`Vector{GaussianBeam}` a legitimate concretely-typed container. It is the
*wrapper* `CrossedDipoleTrap{N}` that is parameterised, not the beam.
"""
struct DipoleTrapSpec <: ModelValue
    beams::Vector{GaussianBeam}
    polarizability::Float64

    function DipoleTrapSpec(beams::Vector{GaussianBeam}, polarizability::Float64)
        isempty(beams) && throw(ArgumentError("a dipole trap needs at least one beam"))
        new(copy(beams), polarizability)
    end
end

DipoleTrapSpec(; beams, polarizability::Real) = DipoleTrapSpec(
    Vector{GaussianBeam}(beams), Float64(polarizability))

"""
    PotentialSpec(; harmonic=[], lattice=[], ring=[], box=[], gravity=[],
                    double_well=[], beam=[], dipole_trap=[])

The trap: `V(r, t)` is the sum of every term in every vector.

**Inactive value: `PotentialSpec()`** — every vector empty, i.e. a free particle
(`NoPotential`).

One vector per term type rather than one tagged struct with a shared numeric
payload: the shared payload is how a spec accretes positional meaning, and the
per-type vectors let the compiler check what a `Symbol` could not.
"""
struct PotentialSpec <: ModelValue
    harmonic::Vector{HarmonicSpec}
    lattice::Vector{LatticeSpec}
    ring::Vector{RingSpec}
    box::Vector{BoxSpec}
    gravity::Vector{GravitySpec}
    double_well::Vector{DoubleWellSpec}
    beam::Vector{BeamSpec}
    dipole_trap::Vector{DipoleTrapSpec}
end

PotentialSpec(; harmonic=HarmonicSpec[], lattice=LatticeSpec[], ring=RingSpec[],
    box=BoxSpec[], gravity=GravitySpec[], double_well=DoubleWellSpec[],
    beam=BeamSpec[], dipole_trap=DipoleTrapSpec[]) = PotentialSpec(
    Vector{HarmonicSpec}(harmonic), Vector{LatticeSpec}(lattice), Vector{RingSpec}(ring),
    Vector{BoxSpec}(box), Vector{GravitySpec}(gravity), Vector{DoubleWellSpec}(double_well),
    Vector{BeamSpec}(beam), Vector{DipoleTrapSpec}(dipole_trap))

"""
    harmonic_trap(omega...) -> PotentialSpec

The overwhelmingly common case, so it gets a name: a single harmonic term.
"""
harmonic_trap(omega...) = PotentialSpec(; harmonic=[HarmonicSpec(; omega=omega)])

"Number of trap terms across every kind. Zero means `NoPotential`."
n_terms(p::PotentialSpec) = sum(f -> length(getfield(p, f)), fieldnames(PotentialSpec); init=0)

export harmonic_trap, n_terms

# Per-axis waveform tuples take the same padding as the numeric ones; an axis a
# grid does not have holds a static zero.
_pad3_wf(v::NTuple{3, ModelWaveform}) = v
function _pad3_wf(v)
    n = length(v)
    n <= 3 || throw(ArgumentError("at most 3 axes; got $n"))
    ntuple(d -> d <= n ? _as_wf(v[d]) : 0.0, 3)::NTuple{3, ModelWaveform}
end
_as_wf(x::Real) = Float64(x)
_as_wf(x::PiecewiseLinearWaveform) = x
_as_wf(x) = throw(
    ArgumentError(
        "a per-axis knob must be a number or a PiecewiseLinearWaveform; got $(typeof(x)). " *
        "Use to_model_waveform(w, duration) to sample any other AbstractWaveform."),
)
