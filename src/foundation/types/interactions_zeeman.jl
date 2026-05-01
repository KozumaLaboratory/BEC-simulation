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

function get_cn(ip::InteractionParams, n::Int)
    n == 0 && return ip.c0
    n == 1 && return ip.c1
    idx = n - 1
    idx <= length(ip.c_extra) ? ip.c_extra[idx] : 0.0
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
linear_p(z::ZeemanParams, ::Real=0.0) = z.p
linear_p(z::TimeDependentZeeman, t::Real=0.0) = evaluate(z.p_wf, Float64(t))

"""Quadratic Zeeman coefficient at time `t`."""
quadratic_q(z::ZeemanParams, ::Real=0.0) = z.q
quadratic_q(z::TimeDependentZeeman, t::Real=0.0) = evaluate(z.q_wf, Float64(t))

"""Transverse field components `(Bx, By)` at time `t`. Both are zero for
plain ZeemanParams (purely longitudinal)."""
transverse_b(::ZeemanParams, ::Real=0.0) = (0.0, 0.0)
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
