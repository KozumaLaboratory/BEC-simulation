# --- What the gas IS, and how it interacts with itself ---
#
# grid / interactions / ddi / lhy. The applied fields are in `field_specs.jl`
# and the frame, boundary and bath in `environment_specs.jl`; the trap is in
# `potential_spec.jl`. The rules below hold for all four files.
#
# Every field is concrete, or a fixed-arity tuple / typed vector of concrete
# things, or the two-member `ModelWaveform` union. Nothing here is `Any`,
# `Function`, `Dict{Symbol,Any}`, mutable, or type-parameterised.
#
# Two rules run through all four files and are the reason several existing
# structs could not simply be embedded:
#
# 1. **Activity is derived from the coupling, never stored beside it.** There is
#    no `enabled::Bool` next to `c_dd`. `enable_ddi=false, c_dd=5.0` is not a
#    state a resolved model can be in, so the pair cannot disagree — and the
#    long-standing disagreement between the library default (`enable_ddi=false`,
#    `make_workspace.jl:67`) and the YAML default (`enabled: true`,
#    `schema.jl:234`) has nothing left to disagree about.
#
# 2. **An inactive spec has exactly ONE representation.** Constructors normalise
#    the secondary fields of an inactive spec to their zero values. That is what
#    makes invariant 3 ("inactive slots are omitted") lossless: a slot can be
#    left out of the serialised form and reconstructed exactly, because there was
#    only one thing it could have been.
#
# There are no `NaN` sentinels anywhere in a `Model`. `NaN != NaN`, so a single
# sentinel would make two identical models compare unequal and hash apart,
# silently defeating both `==` and any content-addressed dedup built on it. The
# three existing sentinels (`c_dd=NaN` "derive from atom", `trunc_radius=NaN`
# "off", `LHYTableOpts.n_max=NaN` "derive from psi_init") are therefore all
# resolved *before* a Model exists; see each spec's docstring for what replaced
# them.
#
# The one place a sentinel is replaced by a UNION rather than by a resolved
# number is `DDISpec.trunc_radius`, and the reason is that its "auto" state is
# not resolvable to one number: `make_workspace` derives TWO radii from it, one
# for the unpadded kernel and one for the padded one. `Union{Nothing, Float64}`
# says that in the type instead of encoding it as `-1.0`. That is not a sentinel
# by another name — `nothing` is outside the value domain, so it cannot collide
# with a radius, and `==`/`hash` treat it as its own value rather than as a
# number that fails to equal itself.

export GridSpec, InteractionSpec, DDISpec, LHYSpec

# Trailing entries of the fixed-arity 3-tuples, for axes the grid does not have.
# Pinned so that two models of the same 2-D physics cannot differ in slots that
# no operator ever reads. `Model`'s constructor enforces them against `ndim`.
const _UNUSED_AXIS_POINTS = 1
const _UNUSED_AXIS_LENGTH = 0.0

_axes_ok(t::NTuple{3, <:Real}, ndim::Int, unused) =
    all(d -> t[d] == unused, (ndim + 1):3)

# Accept the natural `[32, 32]` form and pad to the fixed arity the struct needs.
function _pad3(v, unused, ::Type{T}) where {T}
    n = length(v)
    n <= 3 || throw(ArgumentError("at most 3 axes; got $n"))
    ntuple(d -> d <= n ? T(v[d]) : T(unused), 3)
end
_pad3(v::NTuple{3, T}, _, ::Type{T}) where {T} = v

# ---------------------------------------------------------------------------
# grid
# ---------------------------------------------------------------------------

"""
    GridSpec(; ndim, n_points, box, dealias_two_thirds=false, dealias_k_cut=0.0)

The spectral representation: which points the field lives on, and which `k`
modes are kept.

**Inactive value: none.** Every computation has a grid.

Cannot embed `GridConfig{N}` (`foundation/types/grid.jl:14`): it is parameterised
on `N`, and `Model` has no type parameters to supply one. Leaving the field
typed `GridConfig` (the `UnionAll`) is an abstract field — the boxing that
`workspace.jl:100` measured at 11.7 K allocations on a single 16³ traversal.
`Grid{N,T}` is doubly unusable: it also carries the materialised `x`, `k` and
`k_squared` arrays, which are a build product, not a value. `ndim` + fixed
3-tuples reproduce `GridConfig`'s content; its even/positive validation is
reproduced below.

**`dtype` is deliberately absent.** F32 and F64 give different numbers, so the
choice must enter an identity — but it is a *precision* decision, not a physics
one: an F32 audit of an F64 result is auditing the same model. It belongs in
the method digest, so the two cannot collide in the store while still naming
the same physics. `make_workspace.jl:98-103` already refuses a `dtype` that
disagrees with the grid eltype, i.e. it is a grid-*construction* argument.

**`dealias_*` is here because it is physics and had no home at all.** The 2/3
rule and the explicit `k` cutoff currently live in the global `Ref`s
`DEALIAS_2_3_ENABLED` / `DEALIAS_K_CUTOFF` (`dealias.jl:95,120`), popped off the
top of the YAML and written into no step dict, recoverable only post hoc by an
analyzer. Dealiasing is an exact spectral projector: two runs that differ in it
differ in their answer, so a model that omits it is not a complete statement of
the computation and any fingerprint over it collides. It sits in `GridSpec`
rather than a slot of its own because `dealias_k_cut` is in physical `k` units
and is only interpretable against `box` — `DDIParams` already carries `box_size`
for exactly that reason (`ddi_loss.jl:25`).

`dealias_k_cut = 0.0` means "no explicit cutoff"; combined with
`dealias_two_thirds = true` it selects the plain 2/3 rule.
"""
struct GridSpec <: ModelValue
    ndim::Int
    n_points::NTuple{3, Int}
    box::NTuple{3, Float64}
    dealias_two_thirds::Bool
    dealias_k_cut::Float64

    function GridSpec(ndim::Int, n_points::NTuple{3, Int}, box::NTuple{3, Float64},
        dealias_two_thirds::Bool, dealias_k_cut::Float64)
        1 <= ndim <= 3 || throw(ArgumentError("ndim must be 1, 2 or 3; got $ndim"))
        for d in 1:ndim
            n_points[d] > 0 && iseven(n_points[d]) ||
                throw(
                    ArgumentError(
                        "n_points[$d] must be positive and even (FFT grid); got $(n_points[d])"
                    ),
                )
            box[d] > 0 || throw(ArgumentError("box[$d] must be positive; got $(box[d])"))
        end
        _axes_ok(n_points, ndim, _UNUSED_AXIS_POINTS) ||
            throw(
                ArgumentError(
                    "n_points beyond ndim=$ndim must be $_UNUSED_AXIS_POINTS; got $n_points"
                ),
            )
        _axes_ok(box, ndim, _UNUSED_AXIS_LENGTH) ||
            throw(ArgumentError("box beyond ndim=$ndim must be $_UNUSED_AXIS_LENGTH; got $box"))
        dealias_k_cut >= 0 ||
            throw(
                ArgumentError(
                    "dealias_k_cut must be >= 0 (0 = no explicit cutoff); got $dealias_k_cut"
                ),
            )
        new(ndim, n_points, box, dealias_two_thirds, dealias_k_cut)
    end
end

GridSpec(; ndim::Integer, n_points, box,
    dealias_two_thirds::Bool=false, dealias_k_cut::Real=0.0) = GridSpec(
    Int(ndim), _pad3(n_points, _UNUSED_AXIS_POINTS, Int),
    _pad3(box, _UNUSED_AXIS_LENGTH, Float64), dealias_two_thirds, Float64(dealias_k_cut))

# ---------------------------------------------------------------------------
# interactions
# ---------------------------------------------------------------------------

"""
    InteractionSpec(; n_atoms, omega_ref, c0=0.0, c1=0.0, c_extra_ranks=Int[], c_extra_values=Float64[])

Contact interaction channels plus the two numbers that fix the unit system.

**Inactive value: none.** `n_atoms` and `omega_ref` are required by every
computation — `omega_ref` in particular is the anchor for every conversion in
the layer (Gauss→p, Hz→dimensionless, SI K₃→dimensionless), so nothing below is
interpretable without it. A non-interacting gas is `c0 = c1 = 0` with empty
extra ranks, not an absent slot.

Cannot embed `InteractionParams` (`interactions_zeeman.jl:37`): its `c` field is
a `Dict{Int,Float64}`, and it has no room for `n_atoms`, `omega_ref`, or a
time-dependent `c0`/`c1`.

**`c0`/`c1` are waveform-valued, which deletes `TimeDependentInteractions`.**
The doc's 14 slots have no home for the `time_dep_interactions` kwarg
(`make_workspace.jl:93`), and it is not separate physics — it is `c0(t)`,
`c1(t)`, i.e. a Feshbach ramp. Absorbing it here means one fewer type and one
fewer place the static and ramped paths can drift.

`c_extra_ranks` holds the higher contact channels `S = 2, 4, …, 2F` in strictly
increasing order (rank 2 is the singlet pair `c₂`; ranks ≥ 4 route to the tensor
cache). Odd ranks ≥ 3 are rejected, matching `InteractionParams`' own inner
constructor. Parallel sorted vectors rather than a `Dict{Int,Float64}` because a
`Dict` has no canonical iteration order, and a serialised model whose byte order
depends on hash insertion order is not content-addressable. Sorted rank vectors
also make `even_c_extra`'s documented misindexing footgun for F ≥ 3
(a bare `[c2, c4, c6]` list) unrepresentable: the rank is written next to its
value.
"""
struct InteractionSpec <: ModelValue
    n_atoms::Int
    omega_ref::Float64
    c0::ModelWaveform
    c1::ModelWaveform
    c_extra_ranks::Vector{Int}
    c_extra_values::Vector{Float64}

    function InteractionSpec(n_atoms::Int, omega_ref::Float64, c0::ModelWaveform,
        c1::ModelWaveform, c_extra_ranks::Vector{Int}, c_extra_values::Vector{Float64})
        n_atoms >= 1 || throw(ArgumentError("n_atoms must be >= 1; got $n_atoms"))
        omega_ref > 0 || throw(ArgumentError("omega_ref must be > 0 rad/s; got $omega_ref"))
        length(c_extra_ranks) == length(c_extra_values) || throw(ArgumentError(
            "c_extra_ranks and c_extra_values must have equal length"))
        issorted(c_extra_ranks; lt=<=) ||
            throw(ArgumentError("c_extra_ranks must be strictly increasing; got $c_extra_ranks"))
        for k in c_extra_ranks
            k >= 2 && iseven(k) || throw(
                ArgumentError(
                    "c_extra rank $k is invalid: only even ranks >= 2 carry a contact channel"),
            )
        end
        new(n_atoms, omega_ref, canonical_waveform(c0), canonical_waveform(c1),
            copy(c_extra_ranks), copy(c_extra_values))
    end
end

InteractionSpec(; n_atoms::Integer, omega_ref::Real, c0::ModelWaveform=0.0,
    c1::ModelWaveform=0.0, c_extra_ranks::AbstractVector{<:Integer}=Int[],
    c_extra_values::AbstractVector{<:Real}=Float64[]) = InteractionSpec(
    Int(n_atoms), Float64(omega_ref), c0, c1,
    Vector{Int}(c_extra_ranks), Vector{Float64}(c_extra_values))

# ---------------------------------------------------------------------------
# ddi
# ---------------------------------------------------------------------------

"""
    DDISpec(; c_dd=0.0, secular=false, padded=true, pad_factor=(2.0,2.0,2.0),
              trunc_radius=nothing, quasi_2d=false, l_z=0.0)

Magnetic dipole-dipole interaction. Convention `c_dd = μ₀μ²` (no 4π),
`Q_αβ = k̂_α k̂_β − δ_αβ/3`, `Q(k=0) = 0` — self-consistent, do not "fix".

**Inactive value: `DDISpec()`** — `c_dd = 0`, every other field at its zero;
`trunc_radius` normalises to `0.0` there, because a kernel that does not exist
is not truncated and has no box to derive a radius from.

**There is no `enabled` flag.** `enable_ddi` and `c_dd` are two declarations of
one fact and they already disagree by default between the library
(`enable_ddi=false`) and the YAML surface (`enabled: true`). A resolved model
says whether there is a dipole interaction by carrying its strength. `c_dd = NaN`
meaning "derive from `atom.mu_mag`" is likewise resolved away: a builder calls
`compute_c_dd`, and the model stores the number.

# `trunc_radius` is three-valued, and the three are different physics

| value | meaning |
|---|---|
| `nothing` | auto — derive the radius from the box at build time |
| `0.0` | off: the bare periodic kernel, no real-space truncation |
| `> 0.0` | that explicit radius |

`0.0` is unambiguous as the off value because a zero cutoff radius would zero
the whole kernel, so it cannot also mean a truncation someone wanted.

**Auto is `nothing` rather than a resolved number because it is not ONE
number.** `make_workspace.jl:228-241` derives two radii from the same input —
`auto_ddi_trunc_radius(box)` for the unpadded kernel and
`auto_ddi_trunc_radius(box, pad_factor)` for the padded one — and when
`padded = true` it builds BOTH objects, the padded one being what the propagator
reads. A single `Float64` cannot represent that pair, so resolving auto into the
model would have to pick one of two radii and silently discard the other.

It is nonetheless a *derivable* value, not an unknown: `box`, `padded` and
`pad_factor` are all in the model already, so the radius is a pure function of
the model at the point of use. That is what separates `nothing` here from the
`-1.0` the YAML layer uses, which is a number inside the value domain that
happens to be excluded by a range check.

**Watch the polarity when converting.** `nothing` means AUTO here and OFF two
layers down (`make_ddi_params(trunc_radius=nothing)` →
`_build_q_tensor!`'s `do_trunc = trunc_radius !== nothing`, `qtensor.jl:145`),
and `make_workspace` reads `<= 0.0` as auto — so the identity map is wrong in
both directions. The conversion is `ddi_trunc_radius_kwarg` below, and it exists
exactly once.

`pad_factor`'s negative "auto" sentinel is a sibling of the same defect, and is
still resolved by `auto_ddi_pad_factor` before the model exists; the union has
not been extended to it because nothing in the corpus writes `pad_factor: auto`.

**`quasi_2d`/`l_z` here are the DDI-kernel pair, not the contact rescale.**
The doc's sketch puts `quasi_2d_ddi`/`l_z_ddi` in `geometry`; they are arguments
to `make_ddi_params` and `make_ddi_padded` and select the quasi-2-D dipolar
kernel, so they belong to the term they parameterise. `make_workspace` *derives*
them from the geometry (`:127-130`) — that derivation is a builder convenience,
and its result is a DDI property. `GeometrySpec` keeps the confinement that
rescales the *contact* couplings.

**There is no `euler` field**, contra the doc's sketch. The Euler rotation is the
propagator's own 5-stage cache, rebuilt from the instantaneous Zeeman direction
(`terms/ddi/rotation.jl:180`); no kwarg and no YAML key corresponds to it.
"""
struct DDISpec <: ModelValue
    c_dd::Float64
    secular::Bool
    padded::Bool
    pad_factor::NTuple{3, Float64}
    trunc_radius::Union{Nothing, Float64}
    quasi_2d::Bool
    l_z::Float64

    function DDISpec(c_dd::Float64, secular::Bool, padded::Bool,
        pad_factor::NTuple{3, Float64}, trunc_radius::Union{Nothing, Float64},
        quasi_2d::Bool, l_z::Float64)
        isfinite(c_dd) || throw(ArgumentError("c_dd must be finite; got $c_dd"))
        if !is_active(c_dd)
            return new(0.0, false, false, (1.0, 1.0, 1.0), 0.0, false, 0.0)
        end
        all(>=(1.0), pad_factor) ||
            throw(ArgumentError("pad_factor must be >= 1 per axis; got $pad_factor"))
        if trunc_radius !== nothing
            # `NaN >= 0` is false, so the range check alone already rejected NaN
            # — but by a message about the range, which reads as a bound the
            # caller could satisfy rather than as "this is the YAML `none`
            # sentinel and it has a different spelling here".
            isfinite(trunc_radius) || throw(
                ArgumentError(
                    "trunc_radius must be finite; got $trunc_radius. `NaN` is the YAML " *
                    "layer's spelling of \"no truncation\" — in a model that is 0.0, and " *
                    "`nothing` is auto"),
            )
            trunc_radius >= 0 || throw(
                ArgumentError(
                    "trunc_radius must be >= 0 (0 = untruncated, nothing = auto); " *
                    "got $trunc_radius"),
            )
        end
        quasi_2d && !(l_z > 0) &&
            throw(ArgumentError("quasi-2D DDI needs l_z > 0; got $l_z"))
        new(c_dd, secular, padded, pad_factor, trunc_radius, quasi_2d, l_z)
    end
end

# `trunc_radius = nothing` (auto) rather than `0.0` (the bare periodic kernel):
# the YAML surface defaults to auto (`DDI_TRUNC_RADIUS_DEFAULT = -1.0`,
# `schema/parsing_blocks.jl:398`), and a library default that disagreed with it
# would re-create, one layer up, exactly the split this spec's missing `enabled`
# flag was removed to close. The bare kernel carries a 2-5 % dipolar field error
# that is flat in resolution, so "the default is the cheap wrong one" is not a
# neutral choice.
DDISpec(; c_dd::Real=0.0, secular::Bool=false, padded::Bool=true,
    pad_factor=(2.0, 2.0, 2.0), trunc_radius::Union{Nothing, Real}=nothing,
    quasi_2d::Bool=false, l_z::Real=0.0) = DDISpec(Float64(c_dd), secular, padded,
    _pad3(pad_factor, 1.0, Float64),
    trunc_radius === nothing ? nothing : Float64(trunc_radius), quasi_2d, Float64(l_z))

"""
    ddi_trunc_radius_kwarg(d::DDISpec) -> Float64

`d.trunc_radius` in the spelling `make_workspace` / `find_ground_state` take.

The ONE conversion between the two vocabularies, and it is non-identity in both
directions:

| `DDISpec.trunc_radius` | kwarg | why |
|---|---|---|
| `nothing` (auto) | `-1.0` | `make_workspace` reads `<= 0` as auto |
| `0.0` (off) | `NaN` | `make_workspace` reads `NaN` as off, and `0.0` as AUTO |
| `r > 0` | `r` | the one value both layers agree on |

Mapping `0.0` through unchanged would turn every untruncated model into an
auto-truncated one; mapping `nothing` to `0.0` would do the same. Both are
silent — the run succeeds and the dipolar field is wrong by 2-5 %.
"""
ddi_trunc_radius_kwarg(d::DDISpec) =
    d.trunc_radius === nothing ? -1.0 : (d.trunc_radius == 0.0 ? NaN : d.trunc_radius)

"""
    ddi_trunc_radius_from_kwarg(x::Real) -> Union{Nothing, Float64}

Inverse of `ddi_trunc_radius_kwarg`, over the whole `Float64` the YAML layer can
produce: `NaN` ⇒ `0.0` (off), `<= 0` ⇒ `nothing` (auto — `_parse_ddi_trunc_radius`
returns `-1.0`, but a hand-written `trunc_radius: 0` reaches `make_workspace`'s
auto branch too and must resolve the same way), `> 0` ⇒ itself.
"""
ddi_trunc_radius_from_kwarg(x::Real) =
    isnan(x) ? 0.0 : (x <= 0 ? nothing : Float64(x))

export ddi_trunc_radius_kwarg, ddi_trunc_radius_from_kwarg

# Drop the padding of axes the grid does not have. `Model`'s constructor calls
# this; see the comment there for why this one tuple is normalised rather than
# rejected. `1.0` is the no-padding value, i.e. what `_validate_model` demands
# beyond `ndim`.
function _trim_pad_factor(d::DDISpec, ndim::Int)
    _axes_ok(d.pad_factor, ndim, 1.0) && return d
    DDISpec(d.c_dd, d.secular, d.padded,
        ntuple(i -> i <= ndim ? d.pad_factor[i] : 1.0, 3),
        d.trunc_radius, d.quasi_2d, d.l_z)
end

# ---------------------------------------------------------------------------
# lhy
# ---------------------------------------------------------------------------

"Every LHY mode. `:scalar`/`:quasi_2d` are closed forms in `c_lhy`; the rest tabulate."
const LHY_KINDS = (:none, :scalar, :quasi_2d, :polar_two_channel, :full_bdg, :polar_contact,
    :polar_dipolar, :fm_contact, :fm_dipolar, :icosahedral, :spatial)
const LHY_CLOSED_SCALAR_KINDS = (:scalar, :quasi_2d)

"""
    LHYSpec(; kind=:none, c_lhy=0.0, n_max=0.0, n_points=200, n_bins=12)

Lee-Huang-Yang beyond-mean-field correction.

**Inactive value: `LHYSpec()`** — `kind = :none`, everything else zero/default.

**One home for one concept.** The YAML layer splits LHY across two places:
`:scalar` and `:quasi_2d` land in `interactions.c_lhy`, every tabulated kind
lands in `lhy_kind` + `lhy_opts`. That split is why `:scalar` rode a different
route through all six of the 2026-07 LHY defects and stayed green throughout.
Here `kind` is the single selector and `c_lhy` is the coefficient the closed
scalar forms use; the constructor refuses the two states the split allowed:
a scalar kind with `c_lhy = 0` (a silently-inert LHY) and a tabulated kind
carrying a `c_lhy` that nothing reads.

**`n_max` must be a positive number for a tabulated kind, not `NaN`.**
`LHYTableOpts.n_max = NaN` means "3 × max|ψ_init|²", which makes the LHY
functional — and therefore the physics — a function of the *initial state*. The
same model with two different seeds would then not be the same model. Resolving
`n_max` before the model exists is what keeps the physics a property of the
value.

Cannot embed `LHYTableOpts` (`make_workspace.jl:50`) despite it being the right
shape: it carries its own `n_atoms`, a second declaration of
`InteractionSpec.n_atoms` whose default of 1 is exactly the drift that makes a
tabulated table `N_atoms`× wrong. A builder constructs `LHYTableOpts` from this
spec plus `interactions.n_atoms`.
"""
struct LHYSpec <: ModelValue
    kind::Symbol
    c_lhy::Float64
    n_max::Float64
    n_points::Int
    n_bins::Int

    function LHYSpec(kind::Symbol, c_lhy::Float64, n_max::Float64, n_points::Int, n_bins::Int)
        kind in LHY_KINDS ||
            throw(ArgumentError("lhy kind must be one of $LHY_KINDS; got :$kind"))
        kind === :none && return new(:none, 0.0, 0.0, 200, 12)
        if kind in LHY_CLOSED_SCALAR_KINDS
            is_active(c_lhy) || throw(
                ArgumentError(
                    "lhy kind :$kind is driven by c_lhy, so c_lhy = 0 is an inert LHY " *
                    "wearing an active label; either derive c_lhy or use kind = :none"),
            )
            return new(kind, c_lhy, 0.0, 200, 12)
        end
        c_lhy == 0.0 || throw(
            ArgumentError(
                "lhy kind :$kind is tabulated and never reads c_lhy; leave it at 0"),
        )
        n_max > 0 || throw(
            ArgumentError(
                "tabulated lhy needs a resolved n_max > 0; \"3x max|psi|^2\" would make the " *
                "functional depend on the initial state, so it must be resolved before the model",
            ),
        )
        n_points >= 2 || throw(ArgumentError("lhy n_points must be >= 2; got $n_points"))
        n_bins >= 1 || throw(ArgumentError("lhy n_bins must be >= 1; got $n_bins"))
        new(kind, 0.0, n_max, n_points, n_bins)
    end
end

LHYSpec(; kind::Symbol=:none, c_lhy::Real=0.0, n_max::Real=0.0, n_points::Integer=200,
    n_bins::Integer=12) = LHYSpec(kind, Float64(c_lhy), Float64(n_max), Int(n_points), Int(n_bins))
