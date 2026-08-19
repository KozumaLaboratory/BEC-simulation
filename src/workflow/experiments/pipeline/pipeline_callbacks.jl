# --- Dynamics-step callback builders ---
#
# Parse a `dynamics:` block's optional callback knobs (sgpe / projected_gp /
# photon_scattering / live_monitor) into the typed `on_step` callbacks the
# simulator consumes. Each accepts `nothing | false | Dict` so the YAML
# author can disable a callback without dropping the key.

"""
    _build_pgp_callback(node) -> Union{Nothing,Function}

Parse a `dynamics.projected_gp:` block into a Projected-GP on-step
callback. Accepts:

    projected_gp: false | null
    projected_gp: {k_cut: 6.0, smooth: false, every: 1}
"""
function _build_pgp_callback(node)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(ArgumentError(
        "dynamics.projected_gp must be a Dict or `false`, got $(typeof(node))"))
    haskey(node, "k_cut") || throw(ArgumentError("dynamics.projected_gp requires `k_cut`"))
    k_cut = Float64(node["k_cut"])
    smooth = Bool(get(node, "smooth", false))
    every = Int(get(node, "every", 1))
    projected_gp_callback(k_cut; smooth=smooth, every=every)
end

"""
    _build_photon_callback(node, dt) -> Union{Nothing,Function}

Parse a `dynamics.photon_scattering:` block into a phase-diffusion
on-step callback. Accepts:

    photon_scattering: false | null
    photon_scattering: {Gamma_sc: 0.01, seed: 42}
"""
function _build_photon_callback(node, dt::Float64)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(
        ArgumentError(
            "dynamics.photon_scattering must be a Dict or `false`, got $(typeof(node))"),
    )
    haskey(node, "gamma_sc") && throw(
        ArgumentError(
            "dynamics.photon_scattering: `gamma_sc` (lowercase) was removed " *
            "2026-05-24 — use canonical `Gamma_sc`."),
    )
    haskey(node, "Gamma_sc") ||
        throw(ArgumentError("dynamics.photon_scattering requires `Gamma_sc`"))
    Γ_sc = Float64(node["Gamma_sc"])
    seed = let v = get(node, "seed", nothing)
        v === nothing ? nothing : Int(v)
    end
    photon_scattering_callback(Γ_sc, dt; seed=seed)
end

"""
    _build_live_callback(node, status_path) -> Union{Nothing,Function}

Build an on_step callback that periodically writes a JSON status snapshot
to `status_path` for the dashboard's `/api/live/*` endpoints. Accepts:

    live_monitor: false | null   → off
    live_monitor: true           → defaults (every=50)
    live_monitor: {every: 100}   → custom cadence

If `status_path === nothing` we silently skip even when YAML asks for it
(useful for ad-hoc `run_config` calls that have no run dir).
"""
function _build_live_callback(node, status_path::Union{Nothing, String})
    node === nothing && return nothing
    if node isa Bool
        node || return nothing
        every = 50
    else
        node isa Dict || throw(ArgumentError(
            "dynamics.live_monitor must be Bool or Dict, got $(typeof(node))"))
        every = Int(get(node, "every", 50))
    end
    status_path === nothing && return nothing
    every >= 1 || throw(ArgumentError("live_monitor.every must be >= 1"))
    status_dir = dirname(status_path)
    isempty(status_dir) || mkpath(status_dir)
    # The two quantities the DIVERGENCE KILL reads, held across calls because
    # both are differences. Until 2026-08-04 this callback wrote none of them,
    # and `is_divergent_status` (`autopilot/monitor.jl:56-68`) defaults every one
    # of its three inputs to a healthy value when the key is absent — `0.0` for
    # `norm_drift`, `nothing` for `classify`, `0.0` for `fz_jump`. The writer's
    # keys and the reader's keys had an EMPTY intersection, so the predicate
    # returned `false` for every run that has ever been monitored, however far
    # it had diverged.
    #
    # Both suites were green throughout, because each drives its own side with
    # synthetic input: `test_autopilot.jl:75-79` hands the reader a dict
    # containing the reader's own keys. A gate that builds its input from the
    # thing under test never crosses the producer/consumer boundary, which is
    # the only place this defect lives.
    norm_0 = Ref(NaN)
    fz_prev = Ref(NaN)
    function (ws, step, times, energies)
        step % every == 0 || return nothing
        psi = ws.state.psi
        D = size(psi, ndims(psi))
        ndim = ndims(psi) - 1
        n_total = sum(abs2, psi)
        pops = Float64[]
        for c in 1:D
            push!(pops, Float64(sum(abs2, selectdim(psi, ndim + 1, c))) / n_total)
        end
        e_now = isempty(energies) ? NaN : Float64(energies[end])
        t_now = isempty(times) ? Float64(ws.state.t) : Float64(times[end])
        norm_now = Float64(n_total) * Float64(cell_volume(ws.grid))
        isnan(norm_0[]) && (norm_0[] = norm_now)
        # Relative to this run's FIRST observed norm, not to 1.0: a run may be
        # normalised to something else, and the kill is about drift, not about
        # the absolute value.
        norm_drift = norm_0[] == 0 ? 0.0 : abs(norm_now / norm_0[] - 1)
        # <F_z> from the populations already computed above — m runs F, F-1, …,
        # -F over c = 1..D (CLAUDE.md: `c=1 -> m=F`), so no spin matrices and no
        # second pass over psi.
        F = (D - 1) / 2
        fz_now = sum((F - (c - 1)) * pops[c] for c in 1:D)
        fz_jump = isnan(fz_prev[]) ? 0.0 : abs(fz_now - fz_prev[])
        fz_prev[] = fz_now
        _emit_live_status(status_path; step, t=t_now, energy=e_now,
            norm=norm_now, populations=pops, norm_drift, fz_jump)
    end
end

"""
    _emit_live_status(status_path; step, t, norm, norm_drift, energy, populations, fz_jump)

Write the run's live status. **The single writer** — every dynamics path emits
through here, so the keys the reaper reads are defined once.

`norm_drift` is the universal divergence signal and is required. `fz_jump` is
spinor-specific and omitted where it has no meaning (the binary path has two
scalar fields, not a spinor); `is_divergent_status` skips an absent key, so the
norm arm still fires. `classify` is deliberately never written — the predicate
skips a `nothing` classification, and inventing one here would be a second
classifier competing with `analysis/phases/`.

Until 2026-08-04 the writer and `is_divergent_status` had an EMPTY key
intersection and the kill had never fired for any run. Until 2026-08-07 only the
standard `dynamics:` path called a writer at all, so the other two could not
fire either. Both are why this is one function and not three.
"""
function _emit_live_status(status_path::AbstractString; step::Integer,
    t::Real, norm::Real, norm_drift::Real,
    energy::Real=NaN, populations=nothing, fz_jump=nothing)
    data = Dict{String, Any}(
        "step" => step,
        "t" => Float64(t),
        "energy" => Float64(energy),
        "norm" => Float64(norm),
        "updated_ms" => round(Int, time() * 1000),
        "norm_drift" => Float64(norm_drift),
    )
    populations === nothing || (data["populations"] = populations)
    fz_jump === nothing || (data["fz_jump"] = Float64(fz_jump))
    # Atomic write: tmp file + rename so HTTP readers never see partial JSON
    tmp_path = status_path * ".tmp"
    open(tmp_path, "w") do f
        JSON.print(f, data)
    end
    mv(tmp_path, status_path; force=true)
    nothing
end

"""
    _build_binary_live_callback(node, status_path) -> (s, step) -> nothing

Liveness for the two-component binary path, whose state is `psi_A` / `psi_B`
rather than a spinor. Emits `norm_drift` — the arm that catches a diverging run
— and the two component fractions as `populations`. No `fz_jump`: there is no
F_z here, and writing a placeholder would be a number that means nothing.
"""
function _build_binary_live_callback(node, status_path::Union{Nothing, String},
    dV::Real)
    every = _live_every(node)
    (every === nothing || status_path === nothing) && return nothing
    status_dir = dirname(status_path)
    isempty(status_dir) || mkpath(status_dir)
    norm_0 = Ref(NaN)
    function (s, step)
        step % every == 0 || return nothing
        nA = Float64(sum(abs2, s.psi_A))
        nB = Float64(sum(abs2, s.psi_B))
        n_total = nA + nB
        norm_now = n_total * Float64(dV)
        isnan(norm_0[]) && (norm_0[] = norm_now)
        norm_drift = norm_0[] == 0 ? 0.0 : abs(norm_now / norm_0[] - 1)
        _emit_live_status(status_path; step, t=Float64(s.t), norm=norm_now,
            norm_drift, populations=n_total == 0 ? [0.0, 0.0] :
                                    [nA / n_total, nB / n_total])
    end
end

"Shared `live_monitor:` parsing — `nothing` when liveness is off."
function _live_every(node)
    node === nothing && return nothing
    if node isa Bool
        node || return nothing
        return 50
    end
    node isa Dict || throw(ArgumentError(
        "dynamics.live_monitor must be Bool or Dict, got $(typeof(node))"))
    every = Int(get(node, "every", 50))
    every >= 1 || throw(ArgumentError("live_monitor.every must be >= 1"))
    every
end

"""Composed-callback wrapper: tuple-typed so each inner callback is
statically dispatched. The previous closure-based form captured a
`Vector{Any}` of callbacks and incurred dynamic dispatch on every
step × every callback (a measurable cost in long Eu151 runs)."""
struct ComposedCallbacks{T <: Tuple}
    cbs::T
end

@inline function (cc::ComposedCallbacks)(ws, step, args...)
    for cb in cc.cbs
        cb(ws, step, args...)
    end
    nothing
end

"""Compose multiple optional on_step callbacks into a single one. Each
`nothing` entry is silently skipped. Returns `nothing`, the lone callback,
or a `ComposedCallbacks{Tuple{...}}` instance for ≥ 2 callbacks — never
an anonymous closure (CLAUDE.md type-stability discipline)."""
function _compose_callbacks(cbs...)
    real_cbs = tuple((cb for cb in cbs if cb !== nothing)...)
    isempty(real_cbs) && return nothing
    length(real_cbs) == 1 && return real_cbs[1]
    ComposedCallbacks(real_cbs)
end
function _build_sgpe_callback(node, dt::Float64)
    node === nothing && return nothing
    node isa Bool && (node || return nothing)
    node isa Dict || throw(ArgumentError(
        "dynamics.sgpe must be a mapping or `false`, got $(typeof(node))"))
    haskey(node, "gamma") || throw(ArgumentError("dynamics.sgpe requires `gamma`"))
    haskey(node, "T") || throw(ArgumentError("dynamics.sgpe requires `T`"))
    γ = Float64(node["gamma"])
    T = Float64(node["T"])
    μ = Float64(get(node, "mu", 0.0))
    k_cut = Float64(get(node, "k_cut", Inf))
    every = Int(get(node, "every", 1))
    seed = let v = get(node, "seed", nothing)
        v === nothing ? nothing : Int(v)
    end
    sgpe_callback(γ, T, dt; μ=μ, k_cut=k_cut, seed=seed, every=every)
end
