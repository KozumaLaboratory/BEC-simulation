# --- Contact interactions, Zeeman, Raman ---
#
# `InteractionParams` holds c0/c1/c_lhy + arbitrary even-rank c_extra
# couplings. `ZeemanParams` is the constant-in-time form; the
# time-dependent counterpart `TimeDependentZeeman` carries waveforms
# for p, q, and (optionally) transverse Bx/By. `linear_p` /
# `quadratic_q` / `transverse_b` are the unified accessors so call
# sites don't have to dispatch on which Zeeman flavour they got.
# `RamanCoupling` + `TimeDependentRaman` are the corresponding
# Raman-laser parameters; `TimeDependentInteractions` swaps c0/c1 in
# time with `interactions_at(td, t)`.

export InteractionParams, ZeemanParams, TimeDependentZeeman, c_dict
export RamanCoupling, TimeDependentRaman, TimeDependentInteractions
export linear_p, quadratic_q, transverse_b, interactions_at

# --- Interaction Parameters ---

"""
    InteractionParams(c0, c1, [c_lhy], [c_extra])

Contact interaction parameters. `c0` is the density coupling, `c1` the spin coupling.

`c_extra` stores higher-rank couplings: `c_extra[n-1]` = cₙ for n ≥ 2.
Access via `get_cn(ip, n)`. When any even-rank c_extra entry with k ≥ 4 is nonzero,
`make_workspace` builds a `TensorInteractionCache` and zeros c0/c1 (all contact
interactions are then handled by the tensor step).
"""
struct InteractionParams
    c0::Float64
    c1::Float64
    c_lhy::Float64
    c_extra::Vector{Float64}

    InteractionParams(c0::Float64, c1::Float64) = new(c0, c1, 0.0, Float64[])
    InteractionParams(c0::Float64, c1::Float64, c_extra::Vector{Float64}) = new(
        c0, c1, 0.0, c_extra
    )
    InteractionParams(c0::Float64, c1::Float64, c_lhy::Float64) = new(c0, c1, c_lhy, Float64[])
    InteractionParams(c0::Float64, c1::Float64, c_lhy::Float64, c_extra::Vector{Float64}) = new(
        c0, c1, c_lhy, c_extra
    )
end

"""
    InteractionParams(c_dict::Dict{Int,Float64}; c_lhy=0.0)

Dict-keyed constructor — addresses the `c_0, c_1` (struct field) vs
`c_extra` (positional Vector) asymmetry by letting the user write all
`c_n` as a single Dict keyed by rank n:

    InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
    InteractionParams(Dict(0 => 2.0, 1 => 0.1, 2 => 0.3, 4 => 0.5); c_lhy=10.0)

Equivalent to the positional Vector form but eliminates two footguns:
  (i)  hand-writing `c_extra = [c_2, c_4, c_6]` silently misindexes
       (c_4 → c_3 slot, c_6 → c_4 slot)
  (ii) odd-rank slots (c_3, c_5, ...) must be explicit zeros in the
       Vector form; the Dict form omits them naturally.

Rejects:
  - negative keys (n < 0)
  - odd keys with n ≥ 3 (Kawaguchi-Ueda's c_3 is the S=2 pair channel,
    NOT a rank-3 tensor — use `_make_tensor_cache_from_channels` for that)
"""
function InteractionParams(c_dict::Dict{Int, Float64}; c_lhy::Real=0.0)
    for (k, _) in c_dict
        k >= 0 || throw(ArgumentError(
            "InteractionParams: c_n key must be ≥ 0 (got n=$k)"))
        if k >= 3 && isodd(k)
            throw(
                ArgumentError(
                    "InteractionParams: c_$k is odd-rank and not a physical " *
                    "single-particle tensor coupling. For Kawaguchi-Ueda " *
                    "pair-channel couplings (c_3 = S=2 pair, etc.), use " *
                    "_make_tensor_cache_from_channels(F, Dict(S => g_S)) directly."),
            )
        end
    end
    c0 = Float64(get(c_dict, 0, 0.0))
    c1 = Float64(get(c_dict, 1, 0.0))
    max_n = isempty(c_dict) ? 1 : maximum(keys(c_dict))
    extra = if max_n >= 2
        vec = zeros(Float64, max_n - 1)
        for (k, v) in c_dict
            k >= 2 && (vec[k - 1] = Float64(v))
        end
        vec
    else
        Float64[]
    end
    InteractionParams(c0, c1, Float64(c_lhy), extra)
end

"""
    get_cn(ip::InteractionParams, n::Int) -> Float64

Unified accessor for any c_n. Returns 0 for n outside the populated range.
"""
function get_cn(ip::InteractionParams, n::Int)
    n == 0 && return ip.c0
    n == 1 && return ip.c1
    idx = n - 1
    idx <= length(ip.c_extra) ? ip.c_extra[idx] : 0.0
end

"""
    Base.getindex(ip::InteractionParams, n::Int)

Index syntax for `c_n`: write `ip[0]` instead of `ip.c0`, `ip[4]` instead
of `ip.c_extra[3]`. Symmetric across all ranks — addresses the
`ip.c0 / ip.c1 / ip.c_extra[3]` asymmetry by giving one indexing rule.
"""
Base.getindex(ip::InteractionParams, n::Int) = get_cn(ip, n)

"""
    c_dict(ip::InteractionParams) -> Dict{Int,Float64}

Round-trip back to the Dict form. Only nonzero c_n entries appear.
"""
function c_dict(ip::InteractionParams)
    d = Dict{Int, Float64}()
    abs(ip.c0) > 0 && (d[0] = ip.c0)
    abs(ip.c1) > 0 && (d[1] = ip.c1)
    for (idx, v) in enumerate(ip.c_extra)
        abs(v) > 0 && (d[idx + 1] = v)
    end
    d
end

# --- Zeeman Parameters ---

struct ZeemanParams
    p::Float64      # linear Zeeman (energy)
    q::Float64      # quadratic Zeeman (energy)
end

ZeemanParams() = ZeemanParams(0.0, 0.0)

struct TimeDependentZeeman
    p_wf::Waveform
    q_wf::Waveform
    bx_wf::Union{Nothing, Waveform}
    by_wf::Union{Nothing, Waveform}
end

TimeDependentZeeman(p_wf::Waveform, q_wf::Waveform) = TimeDependentZeeman(
    p_wf, q_wf, nothing, nothing
)

TimeDependentZeeman(f::Function) = TimeDependentZeeman(
    FunctionWaveform(t -> f(t).p),
    FunctionWaveform(t -> f(t).q),
    nothing, nothing,
)

# --- Uniform Zeeman accessors -------------------------------------------
#
# Both ZeemanParams (constant) and TimeDependentZeeman (waveforms) are
# valid arguments to the solver, but they expose different field names
# (`.p` vs `.p_wf`). Without a unified accessor every call site that
# wants the linear-Zeeman scalar at a given time has to dispatch via
# `if zeeman isa TimeDependentZeeman`. This caused a `FieldError` in
# `make_workspace`'s Larmor-regime advisory when the EdH config switched
# to time-dependent Bz; rather than patching that one site we provide
# `linear_p` / `quadratic_q` / `transverse_b` for everyone.

"""Linear Zeeman coefficient at time `t`. For ZeemanParams this is the
constant `p`; for TimeDependentZeeman it samples `p_wf` at `t`."""
linear_p(z::ZeemanParams, (::Real)=0.0) = z.p
linear_p(z::TimeDependentZeeman, t::Real=0.0) = evaluate(z.p_wf, Float64(t))

"""Quadratic Zeeman coefficient at time `t`."""
quadratic_q(z::ZeemanParams, (::Real)=0.0) = z.q
quadratic_q(z::TimeDependentZeeman, t::Real=0.0) = evaluate(z.q_wf, Float64(t))

"""Transverse field components `(Bx, By)` at time `t`. Both are zero for
plain ZeemanParams (purely longitudinal)."""
transverse_b(::ZeemanParams, (::Real)=0.0) = (0.0, 0.0)
function transverse_b(z::TimeDependentZeeman, t::Real=0.0)
    bx = z.bx_wf === nothing ? 0.0 : evaluate(z.bx_wf, Float64(t))
    by = z.by_wf === nothing ? 0.0 : evaluate(z.by_wf, Float64(t))
    (bx, by)
end

# --- Raman Coupling ---

struct RamanCoupling{N}
    Omega_R::Float64          # Rabi frequency
    delta::Float64            # two-photon detuning
    k_eff::NTuple{N, Float64}  # effective wave vector (difference of two beams)
end

struct TimeDependentRaman{N}
    omega_wf::Waveform
    delta_wf::Waveform
    k_eff::NTuple{N, Float64}
end

# --- Time-dependent extensions ---
#
# `TimeDependentTrap` lives in src/foundation/types/potentials.jl (it's an
# AbstractPotential); only the non-potential time-dep types stay here.

struct TimeDependentInteractions
    c0_wf::Waveform
    c1_wf::Waveform
end

TimeDependentInteractions(; c0=0.0, c1=0.0) = TimeDependentInteractions(
    ConstantWaveform(Float64(c0)), ConstantWaveform(Float64(c1))
)

function interactions_at(ip::InteractionParams, ::Float64)
    ip
end

function interactions_at(td::TimeDependentInteractions, t::Float64)
    InteractionParams(evaluate(td.c0_wf, t), evaluate(td.c1_wf, t))
end
