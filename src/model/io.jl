# --- TOML round-trip for Model ---
#
# TOML rather than JLD2/YAML/JSON: it is Julia stdlib (no dependency to break),
# it is readable with `cat`, it will still parse in 2031, and — with
# `sorted=true` — it is byte-deterministic, which is what a content-addressed
# store needs. YAML is what this layer exists to stop being.
#
# Two properties the codec is built to have:
#
# 1. **Lossless.** `model_from_toml(to_toml(m)) == m` for every constructible
#    `m`. `==` here is the structural comparison in `model.jl`, not object
#    identity. Losslessness is what lets a `Record` carry the model verbatim
#    instead of a summary that drifts from it.
#
# 2. **Closed.** A key that no field reads is an ERROR, not something quietly
#    ignored. The 45-key `metadata:` block that nothing reads is the failure
#    this whole layer removes; permitting unknown keys in the serialised form
#    would re-open it one level down.
#
# A slot is omitted exactly when it already EQUALS its own inactive value
# `T()` (invariant 3), because that is the condition under which the decoder's
# `T()` reproduces it. The obvious-looking rule — omit when `active(s)` is false
# — is not the same statement and is lossy: `active` asks whether the slot
# contributes to the computation, and a `PotentialSpec` holding a zero-ω
# harmonic term contributes nothing while still being a different value from
# `PotentialSpec()`. See `_is_inactive_value` in `model.jl`.

using TOML

export to_toml, model_from_toml, write_model_toml, read_model_toml
export model_toml_dict, model_from_toml_dict, MODEL_TOML_FORMAT

"Serialised-model format version. Bump when the on-disk shape changes; readers dispatch on it."
const MODEL_TOML_FORMAT = 1

# ---------------------------------------------------------------------------
# encode
# ---------------------------------------------------------------------------

_enc(x::Bool) = x
_enc(x::Integer) = Int(x)
_enc(x::AbstractFloat) = Float64(x)
_enc(x::Symbol) = String(x)
_enc(x::AbstractString) = String(x)

# A static knob is a bare number and a schedule is a table, so the two arms of
# `ModelWaveform` are distinguishable on read without a discriminator field, and
# the common (static) case still reads as `p = 1.5`.
_enc(w::PiecewiseLinearWaveform) = Dict{String, Any}(
    "times" => copy(w.times), "values" => copy(w.values))

_enc(t::Tuple) = _enc_seq(t)
_enc(v::AbstractVector) = _enc_seq(v)

function _enc_seq(xs)
    out = Any[_enc(x) for x in xs]
    all(x -> x isa Float64, out) && return Float64[out...]
    all(x -> x isa Int, out) && return Int[out...]
    out
end

# The generic arm reflects a struct into its fields — and a FIELDLESS type
# reflects into `Dict()`, so `_enc(nothing)` and `_enc(sin)` used to encode as an
# empty table. That silently defeats the enforcement invariant 1 rests on
# (`_canonical_bytes!` errors on anything it cannot canonicalise): an
# unencodable value would arrive at the hasher already laundered into `{}`.
function _enc(x::T) where {T}
    (isstructtype(T) && fieldcount(T) > 0) || throw(
        ArgumentError(
            "_enc has no encoding for $T — a value with no fields would serialise as an " *
            "empty table, which is indistinguishable from an empty struct"),
    )
    Dict{String, Any}(
        String(f) => _enc_field(fieldtype(T, f), getfield(x, f))
        for f in fieldnames(T)
    )
end

# --- optional scalars ---------------------------------------------------------
#
# TOML has no null (`TOML.print` errors on `nothing`), and `_enc(nothing)` is
# refused above for a load-bearing reason: `Nothing` is fieldless, so the generic
# struct arm would launder it into `{}` and past `_canonical_bytes!`. That
# refusal must stay, so an optional field is encoded by its DECLARED type rather
# than by its value — `_enc_field` is the only place in the codec that looks at
# `fieldtype`, and it exists so a `Union{Nothing, Float64}` field can pick a
# spelling for its `nothing` arm without weakening the value-directed encoder.
#
# The spelling is a String, discriminated from a radius by TOML type exactly as
# `ModelWaveform`'s two arms are discriminated by number-vs-table. It cannot
# collide with any radius, and `_canonical_bytes!` hashes it distinctly, so
# auto / off / explicit take three different `artifact_id`s.
"How `nothing` is written for a `Union{Nothing, Float64}` field. Outside the numeric domain, so it cannot collide with a value."
const OPTIONAL_FLOAT_NOTHING = "auto"

const _OPTIONAL_FLOAT = Union{Nothing, Float64}

_enc_field(::Type{FT}, v) where {FT} = _enc(v)
_enc_field(::Type{_OPTIONAL_FLOAT}, ::Nothing) = OPTIONAL_FLOAT_NOTHING
_enc_field(::Type{_OPTIONAL_FLOAT}, v::Float64) = _enc(v)

# Explicit rather than via the struct arm: `Stage.params` with no entries is an
# EMPTY NamedTuple, which has no fields and would hit the refusal above. An
# empty parameter set is a legitimate declaration ("this method takes none").
_enc(nt::NamedTuple) = Dict{String, Any}(String(k) => _enc(v) for (k, v) in pairs(nt))

_enc(f::Function) = throw(
    ArgumentError(
        "_enc refuses a Function ($(typeof(f))): a closure's captures are not a value, " *
        "and every closure site is its own type — the specialisation class CLAUDE.md's " *
        "type-stability rule 2 exists to close"),
)

# `AtomSpecies` needs a hand-written codec for two reasons the generic encoder
# cannot handle: it has no all-positional constructor (`a_s` and `q_geometry`
# are DERIVED from the primitives inside it), and `scattering_lengths` is a
# `Dict{Int,Float64}` whose iteration order is unspecified — a serialised model
# whose byte order depends on hash insertion order is not content-addressable.
# Sorted parallel channel arrays fix both.
#
# The derived fields are deliberately NOT written. Writing a value the reader
# recomputes and ignores is a drift surface: the file would be able to disagree
# with the constructor and nothing would notice.
# Recomputed by the constructor from the fields above, so they are skipped for
# the reason in the comment above this block. Declaring them here rather than by
# omission is what lets the gate below tell "deliberately derived" apart from
# "forgotten", which a hand-written key list cannot.
const _ATOM_DERIVED = (:a_s, :q_geometry)

# Enumerated from `fieldnames`, not listed. A 15th `AtomSpecies` field is either
# encoded here or declared derived; it cannot be silently dropped from the
# digest. The hand-written 13-key version of this function did exactly that —
# removing "g_F" from it left the discrimination gate fully green.
function _enc_atom(a::AtomSpecies)
    d = Dict{String, Any}()
    for f in fieldnames(AtomSpecies)
        f in _ATOM_DERIVED && continue
        v = getfield(a, f)
        if f === :scattering_lengths
            # One field, two keys: a Dict has no canonical order, so the channel
            # list is sorted and the amplitudes ride in that order.
            ch = sort!(collect(keys(v)))
            d["channel_S"] = ch
            d["channel_a"] = Float64[v[k] for k in ch]
        else
            d[String(f)] = v
        end
    end
    d
end

# Derived from the same two declarations, at the TYPE level — no atom instance
# and no registry lookup, so it cannot depend on load order.
const _ATOM_KEYS = Tuple(
    sort!(
        vcat(
            String[
                String(f) for f in fieldnames(AtomSpecies)
                if !(f in _ATOM_DERIVED) && f !== :scattering_lengths
            ],
            String["channel_S", "channel_a"]),
    ),
)

"""
    model_toml_dict(m::Model) -> Dict{String,Any}

The TOML tree for `m`, before printing. Separated from `to_toml` so the identity
layer can digest the tree without paying a round trip through a string.
"""
function model_toml_dict(m::Model)
    d = Dict{String, Any}("format" => MODEL_TOML_FORMAT)
    for f in slots(Model)
        s = getfield(m, f)
        (f in REQUIRED_SLOTS || !_is_inactive_value(s)) || continue
        d[String(f)] = f === :atom ? _enc_atom(s) : _enc(s)
    end
    d
end

"""
    to_toml(m::Model) -> String

The resolved model, verbatim. Keys are sorted at every level, so the bytes are a
function of the value alone — two processes serialising equal models produce
identical text.
"""
function to_toml(m::Model)
    io = IOBuffer()
    TOML.print(io, model_toml_dict(m); sorted=true)
    String(take!(io))
end

"""
    write_model_toml(path, m::Model) -> path
"""
function write_model_toml(path::AbstractString, m::Model)
    open(io -> write(io, to_toml(m)), path, "w")
    path
end

# ---------------------------------------------------------------------------
# decode
# ---------------------------------------------------------------------------

_dec(::Type{Bool}, v::Bool) = v
_dec(::Type{Int}, v::Integer) = Int(v)
_dec(::Type{Float64}, v::Real) = Float64(v)
_dec(::Type{Symbol}, v::AbstractString) = Symbol(v)
_dec(::Type{String}, v::AbstractString) = String(v)

function _dec(::Type{PiecewiseLinearWaveform}, v::AbstractDict)
    _closed(v, ("times", "values"), "PiecewiseLinearWaveform")
    PiecewiseLinearWaveform(Float64[x for x in v["times"]], Float64[x for x in v["values"]])
end

_dec(::Type{ModelWaveform}, v::Real) = Float64(v)
_dec(::Type{ModelWaveform}, v::AbstractDict) = _dec(PiecewiseLinearWaveform, v)

# The `Union{Nothing, Float64}` arms. Three methods rather than one plus the
# generic fallback: the fallback is `_dec(::Type{T}, v)`, which is AMBIGUOUS with
# `_dec(::Type{T}, ::AbstractDict)` for a union `T`, and without the dict arm a
# malformed file raises a `MethodError` from `fieldnames(Union{...})` instead of
# the `ArgumentError` the format's closedness is stated in.
_dec(::Type{_OPTIONAL_FLOAT}, v::Real) = Float64(v)
function _dec(::Type{_OPTIONAL_FLOAT}, v::AbstractString)
    String(v) == OPTIONAL_FLOAT_NOTHING || throw(
        ArgumentError(
            "an optional float is either a number or the string " *
            "$(repr(OPTIONAL_FLOAT_NOTHING)); got $(repr(String(v)))"),
    )
    nothing
end
_dec(::Type{_OPTIONAL_FLOAT}, v::AbstractDict) = throw(
    ArgumentError("an optional float is a number or $(repr(OPTIONAL_FLOAT_NOTHING)), not a table"))

function _dec(::Type{T}, v::AbstractVector) where {T <: Tuple}
    fts = fieldtypes(T)
    length(fts) == length(v) ||
        throw(ArgumentError("expected $(length(fts)) entries for $T, got $(length(v))"))
    Tuple(_dec(fts[i], v[i]) for i in eachindex(fts))
end

_dec(::Type{Vector{T}}, v::AbstractVector) where {T} = T[_dec(T, e) for e in v]

function _dec(::Type{T}, v::AbstractDict) where {T}
    _closed(v, String.(fieldnames(T)), String(nameof(T)))
    T((_dec(fieldtype(T, f), _fetch(v, String(f), T)) for f in fieldnames(T))...)
end

_dec(::Type{T}, v) where {T} = throw(ArgumentError(
    "cannot read a $T from $(typeof(v)) — the serialised model is malformed"))

function _fetch(v::AbstractDict, key::AbstractString, ::Type{T}) where {T}
    haskey(v, key) || throw(ArgumentError("$T is missing required key \"$key\""))
    v[key]
end

# A key nothing reads is the accretion sink, so it is refused rather than
# ignored. The message names both sides because the usual cause is a format
# version older or newer than this reader.
function _closed(v::AbstractDict, allowed, what::AbstractString)
    extra = setdiff(collect(String.(keys(v))), collect(allowed))
    isempty(extra) && return nothing
    throw(
        ArgumentError(
            "$what has no field(s) " * join(sort!(extra), ", ") *
            "; known fields are " * join(allowed, ", "),
        ),
    )
end

function _dec_atom(v::AbstractDict)
    _closed(v, _ATOM_KEYS, "AtomSpecies")
    ch = Int[Int(k) for k in _fetch(v, "channel_S", AtomSpecies)]
    av = Float64[Float64(x) for x in _fetch(v, "channel_a", AtomSpecies)]
    length(ch) == length(av) ||
        throw(ArgumentError("atom channel_S and channel_a must have equal length"))
    AtomSpecies(String(v["name"]), Float64(v["mass"]), Int(v["F"]), Float64(v["a0"]),
        Float64(v["a2"]), Float64(v["mu_mag"]), Float64(v["g_F"]),
        Dict{Int, Float64}(zip(ch, av));
        Delta_E_hf=Float64(v["Delta_E_hf"]), g_J=Float64(v["g_J"]),
        nuclear_I=Float64(v["nuclear_I"]), electronic_J=Float64(v["electronic_J"]))
end

"""
    model_from_toml_dict(d) -> Model

Rebuild a `Model` from a parsed TOML tree. An absent optional slot decodes to
that slot's inactive value; an unknown key is an error.
"""
function model_from_toml_dict(d::AbstractDict)
    fmt = get(d, "format", nothing)
    fmt == MODEL_TOML_FORMAT || throw(
        ArgumentError(
            "model TOML format $(repr(fmt)) is not $MODEL_TOML_FORMAT; " *
            "no migration path is registered for it"),
    )
    _closed(d, ("format", String.(slots(Model))...), "Model")
    slot(f, T) = _slot(d, f, T)
    Model(
        _dec(GridSpec, _fetch(d, "grid", Model)),
        _dec_atom(_fetch(d, "atom", Model)),
        _dec(InteractionSpec, _fetch(d, "interactions", Model)),
        slot(:potential, PotentialSpec),
        slot(:zeeman, ZeemanSpec),
        slot(:ddi, DDISpec),
        slot(:lhy, LHYSpec),
        slot(:raman, RamanSpec),
        slot(:light_shift, LightShiftSpec),
        slot(:magnetic_gradient, GradientSpec),
        slot(:frame, FrameSpec),
        slot(:geometry, GeometrySpec),
        slot(:reservoir, ReservoirSpec),
        slot(:loss, LossParams),
    )
end

# An absent optional slot is not a missing value — it is the statement that the
# slot took no part. `T()` is the one representation of that, which is what
# makes omission lossless.
_slot(d::AbstractDict, f::Symbol, ::Type{T}) where {T} =
    haskey(d, String(f)) ? _dec(T, d[String(f)]) : T()

"""
    model_from_toml(s::AbstractString) -> Model
"""
model_from_toml(s::AbstractString) = model_from_toml_dict(TOML.parse(s))

"""
    read_model_toml(path) -> Model
"""
read_model_toml(path::AbstractString) = model_from_toml_dict(TOML.parsefile(path))

# The struct decoder needs all-positional constructors, which every `*Spec` has
# and which the three reused foundation types have too — except `AtomSpecies`,
# handled above. `LossParams`' 7-field positional form and `AbsorbingBoundary`'s
# 3-field one are the default inner constructors, so they need no special case;
# `GaussianBeam` likewise.
