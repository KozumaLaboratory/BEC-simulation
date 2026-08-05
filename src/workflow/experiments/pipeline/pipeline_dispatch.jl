# --- Pipeline dispatch helpers: small parsers shared across run-step branches ---
#
# Helpers that don't fit the parsing/builders/runtime split — they're called
# only from `_run_step` branches in `pipeline/runner.jl` (this said
# `pipeline_runner.jl`, a path that has not existed since the pipeline/ split).
# Kept type-stable
# (each function returns a concrete type) so extracting them out of the
# main run-step body doesn't introduce a `Dict{Symbol,Any}` inference
# fence (see CLAUDE.md "Type stability boundaries").

# Default integrator for RTP: Yoshida6 (order 6).
function _default_rotating_integrator(duration::Float64)::String
    "yoshida6"
end

"""
    _resolve_save_every(p::Dict, duration, dt; n_steps=nothing) -> Int

Resolve frame stride from `save:` block. Priority:

  1. `save.every: 30`        — explicit step count (exact)
  2. `save.n_snapshots: 100` — N frames over the step, dt-invariant
  3. default                  — ~20-100 frames depending on context

`n_snapshots` is dt-invariant: changing `dt`/`epsilon` keeps the number
of saved frames unchanged, only their granularity changes.
"""
function _resolve_save_every(p::Dict, duration::Float64, dt::Real;
    n_steps::Union{Nothing, Int}=nothing)
    save_block = get(p, "save", Dict{Any, Any}())::AbstractDict
    if haskey(save_block, "every")
        return Int(save_block["every"])
    end
    if haskey(save_block, "n_snapshots")
        ns = Int(save_block["n_snapshots"])
        ns >= 1 || throw(ArgumentError("save.n_snapshots must be >= 1, got $ns"))
        total = n_steps !== nothing ? n_steps :
                max(1, round(Int, duration / float(dt)))
        return max(1, total ÷ ns)
    end
    total = n_steps !== nothing ? n_steps :
            max(1, round(Int, duration / float(dt)))
    # 100 frames default for rotating_basis (n_steps known), 20 otherwise.
    return max(1, total ÷ (n_steps === nothing ? 20 : 100))
end

"""
Parse `B_hat.theta` (canonical form):
  scalar → const θ
  {from, to, duration} → linear ramp
Returns (theta_func, theta_dot_func, θ_repr).
"""
function _parse_b_hat_theta(b_hat::Dict)
    if !haskey(b_hat, "theta")
        return (_ConstAngle(0.0), _ZERO_FUNC, 0.0)
    end
    v = b_hat["theta"]
    if v isa AbstractDict
        haskey(v, "from") && haskey(v, "to") && haskey(v, "duration") ||
            throw(
                ArgumentError(
                    "B_hat.theta dict form requires `from`, `to`, `duration`; " *
                    "got keys $(collect(keys(v)))"),
            )
        θ0 = Float64(v["from"])
        θ1 = Float64(v["to"])
        T_ramp = Float64(v["duration"])
        rate = (θ1 - θ0) / T_ramp
        return (_LinearRamp(θ0, θ1, T_ramp), _LinearRampDot(rate, T_ramp), θ1)
    end
    θc = Float64(v)
    (_ConstAngle(θc), _ZERO_FUNC, θc)
end

"""
Parse `B_hat.phi` (canonical form, rotation-rate semantics):
  {rate: scalar}                    → const dφ/dt
  {rate: {from, to, duration}}      → ramp dφ/dt (chirp)
Returns (phi_func, phi_dot_func, φ_omega_repr).

Hz-aware: `_ω` resolves Hz quantity strings to dimensionless ω/ω_ref.
"""
function _parse_b_hat_phi(b_hat::Dict, _ω)
    if !haskey(b_hat, "phi")
        return (_LinearPhi(0.0), _ConstAngle(0.0), 0.0)
    end
    v = b_hat["phi"]
    v isa AbstractDict || throw(
        ArgumentError(
            "B_hat.phi: expected `{rate: <waveform>}`, got scalar $v. " *
            "Use `phi: {rate: <V>}` for rotation at rate V (formerly `phi_omega`)."),
    )
    haskey(v, "rate") || throw(
        ArgumentError(
            "B_hat.phi: expected `{rate: <waveform>}`, got keys $(collect(keys(v)))"),
    )
    rate = v["rate"]
    if rate isa AbstractDict
        haskey(rate, "from") && haskey(rate, "to") && haskey(rate, "duration") ||
            throw(
                ArgumentError(
                    "B_hat.phi.rate dict form requires `from`, `to`, `duration`; " *
                    "got keys $(collect(keys(rate)))"),
            )
        ω0 = _ω(rate["from"])
        ω1 = _ω(rate["to"])
        T_chirp = Float64(rate["duration"])
        return (_LinearChirpPhi(ω0, ω1, T_chirp),
            _LinearChirpPhiDot(ω0, ω1, T_chirp), ω1)
    end
    ω = _ω(rate)
    (_LinearPhi(ω), _ConstAngle(ω), ω)
end

"""
Derive dt from accumulated-error target ε via global error scaling
ε ≈ C · T · dt^p where p is integrator order, C ~ O(1).

Safety factor 0.1 → conservative dt that consistently meets target across
typical Klaus / B-1 problems (verified empirically, prevents under-resolved
DDI / fast-rotation regimes).

Returns: dt = 0.1 · (ε / duration)^(1/p)
"""
function _dt_from_epsilon(epsilon::Float64, duration::Float64, integrator::String)
    p = if integrator == "strang"
        ;
        2
    elseif integrator == "yoshida4" || integrator == "cfet4"
        ;
        4
    elseif integrator == "yoshida6"
        ;
        6
    else
        ;
        2  # fallback
    end
    safety = 0.1
    safety * (epsilon / duration)^(1.0 / p)
end
function _dynamics_scratch_path()
    scratch = get(ENV, "SPINORBEC_SCRATCH_DIR", "")
    base = string(hash((time_ns(), getpid())); base=16)
    dir = isempty(scratch) ? tempdir() : scratch
    isdir(dir) || mkpath(dir)
    joinpath(dir, "spinorbec_snaps_" * base * ".jld2")
end

function _parse_twa_config(d::Dict)
    n_traj = Int(d["n_trajectories"])
    seed_base = Int(get(d, "seed_base", 42))
    cutoff_raw = get(d, "cutoff_energy", nothing)
    cutoff = cutoff_raw === nothing ? nothing : Float64(cutoff_raw)
    obs_raw = get(d, "observables", ["density", "magnetization"])
    observables = Symbol[Symbol(s) for s in obs_raw]
    TWAConfig(n_traj, seed_base, cutoff, observables)
end

function _parse_light_shift(raw, F::Int, V_trap, backend::AbstractBackend)
    raw === nothing && return nothing
    raw isa Dict || return nothing
    if haskey(raw, "eta_tensor")
        eta_t = Float64(raw["eta_tensor"])
        eta_v = Float64(get(raw, "eta_vector", 0.0))
        pol_raw = get(raw, "polarization", [0, 0, 1])
        pol = NTuple{3, Float64}(Tuple(Float64.(pol_raw)))
        V_trap === nothing &&
            throw(ArgumentError("light_shift.eta_tensor requires a trap potential (V_trap)"))
        return make_light_shift_from_trap(
            V_trap, F, eta_t; eta_vector=eta_v, polarization=pol, backend
        )
    end
    if haskey(raw, "profile")
        throw(
            ArgumentError(
                "light_shift.profile from YAML not yet supported; " *
                "use eta_tensor with trap or pass LightShift from Julia",
            ),
        )
    end
    if haskey(raw, "alpha_tensor") || haskey(raw, "alpha_vector")
        # Reading alpha_tensor / alpha_vector from YAML requires a profile
        # array, which the parser doesn't yet accept (see the explicit
        # `profile` branch above). Earlier this branch silently returned
        # nothing, dropping the user's coupling values on the floor.
        throw(
            ArgumentError(
                "light_shift.alpha_tensor/alpha_vector require a `profile:` array, " *
                "which is not yet supported via YAML. " *
                "Use `light_shift.eta_tensor` (with the trap as profile) " *
                "or pass a LightShift constructed in Julia.",
            ),
        )
    end
    nothing
end
