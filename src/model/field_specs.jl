# --- What is DONE to the gas: externally applied fields ---
#
# Zeeman, Raman, light shift and the magnetic gradient. Shared rules and the
# `_pad3` helper are in `specs.jl`.

export ZeemanSpec, RamanSpec, LightShiftSpec, GradientSpec

# ---------------------------------------------------------------------------
# zeeman
# ---------------------------------------------------------------------------

"The spatial `B(r)` shapes a model may name. `foundation/types/spatial_zeeman.jl` builds them."
const SPATIAL_ZEEMAN_KINDS = (:uniform, :quadrupole, :ioffe_pritchard)

"""
    ZeemanSpec(; p=0.0, q=0.0, bx=0.0, by=0.0, spatial_kind=:uniform, …)

`H = -(b·F) + q F_z²` with `b = (bx, by, p)`, in internal units.

**Inactive value: `ZeemanSpec()`** — all four knobs zero, `spatial_kind`
`:uniform`, all spatial parameters zero.

Sign source of truth: `p ≡ -g_F μ_B B_z` (Kawaguchi-Ueda), declared once in
`Units.bfield_to_p`. This spec stores the RESOLVED `p`; it does not restate the
conversion, and a builder that starts from lab Gauss must go through that
function.

**The spatial arm is folded in rather than a separate `spatial_zeeman` slot.**
`make_workspace` already folds both kwargs into one `ZeemanField`
(`make_workspace.jl:106`) and *forbids* setting both (`:566-572`). Two slots
could encode the state that throw exists to reject; one slot cannot. The
constructor enforces the same exclusion by requiring the uniform knobs to be
zero when a spatial shape is selected.

Stored as a named shape plus numbers, not as a field. `SpatialZeemanField{N}`
(`spatial_zeeman.jl:24`) holds four grid-sized `Array{Float64,N}` — megabytes of
build product, and parameterised on `N`. `ZeemanField{P}`'s functional arm
`SpatioTemporalProfiles{N,FBX,FBY,FBZ,FQ}` (`:252`) carries four closures in its
type parameters and is unrepresentable here by construction, which is the point:
`quadrupole_field` / `ioffe_pritchard_field` are the named shapes a model may
select, and a hand-written `B(r,t)` closure is not.

`spatial_curvature` is read only by `:ioffe_pritchard`; `:quadrupole` uses
`spatial_gradient` and `spatial_bias`.
"""
struct ZeemanSpec <: ModelValue
    p::ModelWaveform
    q::ModelWaveform
    bx::ModelWaveform
    by::ModelWaveform
    spatial_kind::Symbol
    spatial_gradient::Float64
    spatial_curvature::Float64
    spatial_bias::Float64
    spatial_center::NTuple{3, Float64}

    function ZeemanSpec(p::ModelWaveform, q::ModelWaveform, bx::ModelWaveform,
        by::ModelWaveform, spatial_kind::Symbol, spatial_gradient::Float64,
        spatial_curvature::Float64, spatial_bias::Float64,
        spatial_center::NTuple{3, Float64})
        spatial_kind in SPATIAL_ZEEMAN_KINDS || throw(
            ArgumentError(
                "spatial_kind must be one of $SPATIAL_ZEEMAN_KINDS; got :$spatial_kind"),
        )
        for (w, n) in ((p, "p"), (q, "q"), (bx, "bx"), (by, "by"))
            _finite_or_throw(w, "zeeman.$n")
        end
        for (x, n) in ((spatial_gradient, "spatial_gradient"),
            (spatial_curvature, "spatial_curvature"), (spatial_bias, "spatial_bias"))
            _finite_or_throw(x, "zeeman.$n")
        end
        # Both named shapes reduce to B ≡ 0 when gradient, curvature and bias
        # all vanish (`quadrupole_field` / `ioffe_pritchard_field`), so a
        # zero-strength shape is a second spelling of "no field". Invariant 3
        # allows exactly one.
        if spatial_kind !== :uniform &&
            !any(is_active, (spatial_gradient, spatial_curvature, spatial_bias))
            spatial_kind = :uniform
        end
        if spatial_kind === :uniform
            spatial_gradient = 0.0
            spatial_curvature = 0.0
            spatial_bias = 0.0
            spatial_center = (0.0, 0.0, 0.0)
        else
            all(w -> waveform_magnitude(w) == 0.0, (p, q, bx, by)) || throw(
                ArgumentError(
                    "a spatial Zeeman shape and a uniform Zeeman field cannot both be set " *
                    "(make_workspace refuses the same pair); fold the uniform part into " *
                    "spatial_bias"),
            )
        end
        new(canonical_waveform(p), canonical_waveform(q), canonical_waveform(bx),
            canonical_waveform(by), spatial_kind, spatial_gradient, spatial_curvature,
            spatial_bias, spatial_center)
    end
end

ZeemanSpec(; p::ModelWaveform=0.0, q::ModelWaveform=0.0, bx::ModelWaveform=0.0,
    by::ModelWaveform=0.0, spatial_kind::Symbol=:uniform, spatial_gradient::Real=0.0,
    spatial_curvature::Real=0.0, spatial_bias::Real=0.0,
    spatial_center=(0.0, 0.0, 0.0)) = ZeemanSpec(
    p, q, bx, by, spatial_kind, Float64(spatial_gradient), Float64(spatial_curvature),
    Float64(spatial_bias), _pad3(spatial_center, 0.0, Float64))

# ---------------------------------------------------------------------------
# raman
# ---------------------------------------------------------------------------

"""
    RamanSpec(; omega_r=0.0, delta=0.0, k_eff=(0.0,0.0,0.0))

Two-photon Raman coupling: Rabi frequency, detuning, momentum transfer.

**Inactive value: `RamanSpec()`** — `omega_r = 0`, which is what
`make_workspace` itself tests before building the term.

Cannot embed `RamanCoupling{N}` / `TimeDependentRaman{N}`
(`interactions_zeeman.jl:180,186`): both are parameterised on `N` (only because
of `k_eff`), and the time-dependent one types its two waveform fields with the
abstract `Waveform` alias.
"""
struct RamanSpec <: ModelValue
    omega_r::ModelWaveform
    delta::ModelWaveform
    k_eff::NTuple{3, Float64}

    function RamanSpec(omega_r::ModelWaveform, delta::ModelWaveform, k_eff::NTuple{3, Float64})
        _finite_or_throw(omega_r, "raman.omega_r")
        _finite_or_throw(delta, "raman.delta")
        all(isfinite, k_eff) || throw(ArgumentError("raman.k_eff must be finite; got $k_eff"))
        is_active(waveform_magnitude(omega_r)) || return new(0.0, 0.0, (0.0, 0.0, 0.0))
        new(canonical_waveform(omega_r), canonical_waveform(delta), k_eff)
    end
end

RamanSpec(; omega_r::ModelWaveform=0.0, delta::ModelWaveform=0.0,
    k_eff=(0.0, 0.0, 0.0)) = RamanSpec(omega_r, delta, _pad3(k_eff, 0.0, Float64))

# ---------------------------------------------------------------------------
# light_shift
# ---------------------------------------------------------------------------

const LIGHT_SHIFT_PROFILE_SOURCES = (:trap,)

"""
    LightShiftSpec(; eta_vector=0.0, eta_tensor=0.0, polarization=(0.0,0.0,1.0),
                     profile_source=:trap)

Vector and tensor AC Stark shifts of a far-detuned beam.

**Inactive value: `LightShiftSpec()`** — both `η` zero.

Cannot embed `LightShift{A}` (`ddi_loss.jl:133`): it holds a materialised,
grid-sized `profile::A` that may live on a GPU, plus the `D×D` eigenvector
matrix of the already-diagonalised operator. That is build output, transferred
to the device by `make_workspace.jl:454-463`, not a value.

`profile_source` names where the spatial envelope comes from. `:trap` (reuse the
trap's own `V`) is the only source any parser reaches today — the `profile:`
and bare `alpha_*` branches both throw — so naming it makes the current limit a
readable property of the value rather than an `ArgumentError` two layers down.
"""
struct LightShiftSpec <: ModelValue
    eta_vector::Float64
    eta_tensor::Float64
    polarization::NTuple{3, Float64}
    profile_source::Symbol

    function LightShiftSpec(eta_vector::Float64, eta_tensor::Float64,
        polarization::NTuple{3, Float64}, profile_source::Symbol)
        profile_source in LIGHT_SHIFT_PROFILE_SOURCES || throw(
            ArgumentError(
                "profile_source must be one of $LIGHT_SHIFT_PROFILE_SOURCES; got :$profile_source"
            ),
        )
        _finite_or_throw(eta_vector, "light_shift.eta_vector")
        _finite_or_throw(eta_tensor, "light_shift.eta_tensor")
        all(isfinite, polarization) ||
            throw(ArgumentError("light_shift.polarization must be finite; got $polarization"))
        (is_active(eta_vector) || is_active(eta_tensor)) ||
            return new(0.0, 0.0, (0.0, 0.0, 1.0), :trap)
        norm_p = sqrt(sum(abs2, polarization))
        norm_p > 0 || throw(ArgumentError("polarization must be a non-zero vector"))
        # Dividing a vector that is already unit to within a few ULP moves its
        # last bit, so the normalisation would not be a fixed point of itself and
        # `model_from_toml(to_toml(m))` would take a second content id for the
        # same physics.
        pol = abs(norm_p - 1.0) <= 4eps(1.0) ? polarization : polarization ./ norm_p
        new(eta_vector, eta_tensor, pol, profile_source)
    end
end

LightShiftSpec(; eta_vector::Real=0.0, eta_tensor::Real=0.0,
    polarization=(0.0, 0.0, 1.0), profile_source::Symbol=:trap) = LightShiftSpec(
    Float64(eta_vector), Float64(eta_tensor), _pad3(polarization, 0.0, Float64), profile_source)

# ---------------------------------------------------------------------------
# magnetic_gradient
# ---------------------------------------------------------------------------

"""
    GradientSpec(; gradient=0.0, axis=3, g_F=0.0)

Spin-INDEPENDENT linear tilt `V = g_F · gradient · x_axis`. Despite the name it
is not a Zeeman term (CLAUDE.md's HamTerm table is explicit), which is why it
keeps its own slot.

**Inactive value: `GradientSpec()`** — `gradient = 0`.

`g_F` here is a separate number from `atom.g_F` — `MagneticGradient` defaults it
to 1.0 while Eu's is ≈1.163, so today the two can silently disagree. There is no
default: an active gradient with `g_F = 0` is a term that contributes nothing
while wearing an active label, and is refused, so a builder has to say which
`g_F` it means instead of inheriting one by accident.

Cannot embed `MagneticGradient{N}` / `TimeDependentMagneticGradient{N}`
(`potentials.jl:231,246`): parameterised on `N` (only to range-check `axis`),
and the time-dependent one types `gradient_wf` with the abstract `Waveform`.
`Model` reproduces the axis check against `grid.ndim`.
"""
struct GradientSpec <: ModelValue
    gradient::ModelWaveform
    axis::Int
    g_F::Float64

    function GradientSpec(gradient::ModelWaveform, axis::Int, g_F::Float64)
        _finite_or_throw(gradient, "magnetic_gradient.gradient")
        _finite_or_throw(g_F, "magnetic_gradient.g_F")
        is_active(waveform_magnitude(gradient)) || return new(0.0, 3, 0.0)
        is_active(g_F) || throw(
            ArgumentError(
                "an active magnetic gradient needs a non-zero g_F; pass atom.g_F if that " *
                "is what you mean, rather than leaving it to a default"),
        )
        1 <= axis <= 3 || throw(ArgumentError("gradient axis must be in 1:3; got $axis"))
        new(canonical_waveform(gradient), axis, g_F)
    end
end

GradientSpec(; gradient::ModelWaveform=0.0, axis::Integer=3, g_F::Real=0.0) =
    GradientSpec(gradient, Int(axis), Float64(g_F))
