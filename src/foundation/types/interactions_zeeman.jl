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
    InteractionParams(c::Dict{Int,Float64}; c_lhy=0.0)

Contact interaction parameters keyed by rank n.

    ip = InteractionParams(Dict(0 => 2.0, 1 => 0.1, 4 => 0.5))
    ip[0]                # c_0 (density coupling)
    ip[1]                # c_1 (spin coupling ⟨F̂_1·F̂_2⟩)
    ip[2]                # c_2 (S=0 singlet pair, unset → 0)
    ip[4]                # c_4 (rank-4 tensor)

Rejects:
  - negative keys (n < 0)
  - odd keys with n ≥ 3 (Kawaguchi-Ueda's c_3 is the S=2 pair channel
    coupling, NOT a rank-3 single-particle tensor — use
    `_make_tensor_cache_from_channels(F, Dict(S => g_S))` for pair channels)
"""
struct InteractionParams
    c::Dict{Int, Float64}
    c_lhy::Float64

    function InteractionParams(c::Dict{Int, Float64}; c_lhy::Real=0.0)
        for (k, _) in c
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
        new(c, Float64(c_lhy))
    end
end

# Reject positional (c0, c1, ...) form — only the Dict form is supported.
function InteractionParams(::Real, ::Real, args...; kwargs...)
    throw(
        ArgumentError(
            "InteractionParams takes a Dict{Int,Float64}: " *
            "InteractionParams(Dict(0 => c0, 1 => c1, 2 => c2, ...))"),
    )
end

"""
    get_cn(ip::InteractionParams, n::Int) -> Float64

Unified accessor for any c_n. Returns 0 for n outside the populated set.
"""
get_cn(ip::InteractionParams, n::Int) = get(ip.c, n, 0.0)

"""
    Base.getindex(ip::InteractionParams, n::Int) -> Float64

Symmetric c_n indexing. `ip[0]` is c_0, `ip[1]` is c_1, `ip[4]` is c_4.
"""
Base.getindex(ip::InteractionParams, n::Int) = get_cn(ip, n)

"""
    c_dict(ip::InteractionParams) -> Dict{Int,Float64}

Return the underlying Dict (alias of `ip.c`). Only nonzero entries are
filtered out at the call site if needed.
"""
c_dict(ip::InteractionParams) = ip.c

"""
    has_higher_rank_couplings(ip::InteractionParams) -> Bool

True iff any nonzero c_k with k ≥ 4 is present (the trigger for
tensor_cache routing in `make_workspace`). c_0 and c_1 are handled by
specialized diagonal + spin_mixing steps; c_2 is handled by the
singlet_pair step; only k ≥ 4 needs the general tensor_cache.
"""
function has_higher_rank_couplings(ip::InteractionParams)
    for (k, v) in ip.c
        k >= 4 && abs(v) > 1e-30 && return true
    end
    false
end

"""
    max_rank(ip::InteractionParams) -> Int

Largest n with a stored entry (nonzero or not). Returns -1 if empty.
"""
max_rank(ip::InteractionParams) = isempty(ip.c) ? -1 : maximum(keys(ip.c))

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
    InteractionParams(Dict(0 => evaluate(td.c0_wf, t),
        1 => evaluate(td.c1_wf, t)))
end
