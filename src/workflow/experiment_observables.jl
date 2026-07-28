# Experiment observables — plain functions over an `Experiment`, reading
# the result jld2 (via the memoised RunResult / direct jldopen) on first
# call. Convention: function name == observable name; trajectories carry
# the `_t` suffix, drift summaries `_drift` / `_rel_drift`. Split out of
# experiment.jl; all symbols are exported from there.

# ---------------------------------------------------------------------------
# Observables (plain functions)
# ---------------------------------------------------------------------------
#
# Convention: function name == observable name. Trajectory observables
# have `_t` suffix (e.g. `Fz_t`); drift summaries `_drift` /
# `_rel_drift`; classification `classify`; meta `n_trajectories`,
# `integrator_meta`; parametrised `density(exp, t)`, `psi(exp, t)`,
# `density_stats_at(exp, t)`.
#
# For terminal scalar from a trajectory: `last(Fz_t(exp))` etc.

# --- trajectories from RunResult dispatch ---

for (name, src) in (
    (:Fz_t, :Fz_t), (:Lz_t, :Lz_t), (:Jz_t, :Jz_t),
    (:norm_t, :norm_t), (:energy_t, :energy_t),
)
    @eval $name(exp::Experiment) =
        _memoize(exp, $(QuoteNode(name))) do
            getproperty(_runresult(exp), $(QuoteNode(src)))
        end
end

times(exp::Experiment) =
    _memoize(exp, :times) do
        dyn = _runresult(exp).dynamics
        dyn === nothing && throw(ArgumentError(
            "times(exp): this run has no dynamics block"
        ))
        Float64.(dyn.times)
    end

# --- drift summaries ---

for (fn, base) in (
    (:Fz_drift, :Fz_t), (:Lz_drift, :Lz_t),
    (:energy_drift, :energy_t), (:norm_drift, :norm_t),
)
    @eval $fn(exp::Experiment) =
        _memoize(exp, $(QuoteNode(fn))) do
            ts = $base(exp)
            maximum(abs.(ts .- ts[1]))
        end
end

for (fn, base) in (
    (:Fz_rel_drift, :Fz_t),
    (:energy_rel_drift, :energy_t),
    (:norm_rel_drift, :norm_t),
)
    @eval $fn(exp::Experiment) =
        _memoize(exp, $(QuoteNode(fn))) do
            ts = $base(exp)
            maximum(abs.(ts .- ts[1])) / max(abs(ts[1]), 1e-30)
        end
end

# --- derived trajectories ---

"""
    peaks(exp) -> Vector{Float64}

Maximum total density per snapshot. For ensemble runs, peaks of the
ensemble-mean density.
"""
peaks(exp::Experiment) =
    _memoize(exp, :peaks) do
        _is_ensemble(exp) ? _ensemble_peaks(exp) :
        peak_density_trajectory(_result_path(exp))
    end

"""
    populations_t(exp) -> Vector{Vector{Float64}}

Per-frame `|ψ_m|²` integrated over space, length-`D` per frame.
Errors for ensemble runs (no per-trajectory psi available).
"""
populations_t(exp::Experiment) =
    _memoize(exp, :populations_t) do
        _is_ensemble(exp) && throw(
            ArgumentError(
                "populations_t(exp): undefined for ensemble (no per-trajectory psi)"
            ),
        )
        spin_populations_trajectory(_result_path(exp))
    end

"""
    per_m_t(exp) -> Vector{Vector{Float64}}

Rotating-basis save layout: `dynamics/per_m_history` D×T matrix
surfaced as a D-vector per frame.
"""
per_m_t(exp::Experiment) =
    _memoize(exp, :per_m_t) do
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            haskey(f, "dynamics/per_m_history") || throw(
                ArgumentError(
                    "per_m_t(exp): dynamics/per_m_history missing (this run did " *
                    "not use save_rotating_basis_result!)",
                ),
            )
            pm = f["dynamics/per_m_history"]
            T = size(pm, 2)
            [Vector{Float64}(view(pm, :, t)) for t in 1:T]
        end
    end

"""
    integrator_meta(exp) -> Dict{String,Any}

Rotating-basis save layout: contents of `dynamics/integrator_meta/`.
Empty Dict if the group is missing.
"""
integrator_meta(exp::Experiment) =
    _memoize(exp, :integrator_meta) do
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            meta = Dict{String, Any}()
            haskey(f, "dynamics/integrator_meta") || return meta
            for k in keys(f["dynamics/integrator_meta"])
                meta[String(k)] = f["dynamics/integrator_meta/$k"]
            end
            meta
        end
    end

# --- classification + ensemble meta ---

"""
    classify(exp) -> Symbol

5-category collapse classifier on the peaks trajectory + final norm
ratio. Categories: `:collapse / :delay / :marginal_arrest /
:sacrificial_arrest / :stable_arrest`.
"""
classify(exp::Experiment) =
    _memoize(exp, :classify) do
        ps = peaks(exp)
        ns = norm_t(exp)
        classify_collapse(ps, ns[end] / ns[1])
    end

"""
    n_trajectories(exp) -> Int

1 for single-trajectory runs, the recorded ensemble size for TWA runs.
"""
n_trajectories(exp::Experiment) =
    _memoize(exp, :n_trajectories) do
        _is_ensemble(exp) || return 1
        jld = _result_path(exp)
        jldopen(jld, "r") do f
            for k in sort(collect(keys(f)))
                startswith(k, "dynamics") || continue
                haskey(f[k], "ensemble") || continue
                eg = f["$k/ensemble"]
                for pk in sort(collect(keys(eg)))
                    startswith(pk, "phase_") || continue
                    haskey(eg[pk], "n_trajectories") || continue
                    return Int(f["$k/ensemble/$pk/n_trajectories"])
                end
            end
            return 1
        end
    end

# --- parametrised observables ---

"""
    density(exp, t) -> Array{Float64,3} or (mean=…, variance=…)

Total density at the snapshot closest to time `t`. For ensemble runs,
returns a named tuple `(mean, variance)` of 3D arrays.
"""
function density(exp::Experiment, t::Real)
    t = float(t)
    if _is_ensemble(exp)
        return jldopen(_result_path(exp), "r") do f
            _ensemble_density_at(f, t)
        end
    end
    p = psi(exp, t)
    total_density(p, ndims(p) - 1)
end

"""
    psi(exp, t) -> Array{Complex,4}

Raw ψ snapshot closest to time `t` (single trajectory only).
"""
function psi(exp::Experiment, t::Real)
    t = float(t)
    _is_ensemble(exp) && throw(ArgumentError(
        "psi(exp, t): undefined for ensemble runs; use density(exp, t)"
    ))
    jldopen(_result_path(exp), "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        snap_times = _snapshot_times(f, frames)
        idx = argmin(abs.(snap_times .- t))
        g[frames[idx]]
    end
end

function _snapshot_times(f, frames::AbstractVector{<:AbstractString})
    ts = Vector{Float64}(f["dynamics/times"])
    nf = length(frames)
    length(ts) == nf + 1 && return @view ts[2:end]
    length(ts) == nf && return ts
    @view ts[1:min(nf, length(ts))]
end

"""
    density_stats_at(exp, t) -> NamedTuple

`(peak, peak_voxel, fwhm_x, fwhm_z, on_axis, sigma_over_mu)`. For
single trajectories `sigma_over_mu = NaN`; for ensembles it is
`sqrt(variance[peak_voxel]) / peak`.
"""
function density_stats_at(exp::Experiment, t::Real)
    t = float(t)
    if _is_ensemble(exp)
        snap = density(exp, t)
        return density_stats(snap.mean; variance=snap.variance)
    end
    density_stats(density(exp, t))
end

# --- ensemble internals (kept private — surfaced via density / peaks) ---

function _ensemble_density_at(f, t::Float64)
    phase_groups = String[]
    for k in collect(keys(f))
        startswith(k, "dynamics") || continue
        haskey(f[k], "ensemble") || continue
        push!(phase_groups, k)
    end
    sort!(phase_groups)
    isempty(phase_groups) && throw(ArgumentError(
        "density(exp, t): no dynamics/ensemble/ group in jld2"
    ))
    for pg in phase_groups
        eg = f["$pg/ensemble"]
        for k in keys(eg)
            startswith(k, "phase_") || continue
            tk = "$pg/ensemble/$k/times"
            haskey(f, tk) || continue
            times_arr = Vector{Float64}(f[tk])
            tmin, tmax = extrema(times_arr)
            (t < tmin - 1e-12 || t > tmax + 1e-12) && continue
            idx = argmin(abs.(times_arr .- t))
            mean_arr = f["$pg/ensemble/$k/density/mean"]
            var_arr = f["$pg/ensemble/$k/density/variance"]
            return (mean=mean_arr[:, :, :, idx],
                variance=var_arr[:, :, :, idx])
        end
    end
    throw(ArgumentError("density(exp, t): t=$t outside all phase windows"))
end

function _ensemble_peaks(exp::Experiment)
    jld = _result_path(exp)
    jldopen(jld, "r") do f
        for k in sort(collect(keys(f)))
            startswith(k, "dynamics") || continue
            haskey(f[k], "ensemble") || continue
            eg = f["$k/ensemble"]
            for pk in sort(collect(keys(eg)))
                startswith(pk, "phase_") || continue
                haskey(eg[pk], "density") || continue
                mean_arr = f["$k/ensemble/$pk/density/mean"]
                _, _, _, nt = size(mean_arr)
                return [
                    Float64(maximum(view(mean_arr,:,:,:,it))) for it in 1:nt
                ]
            end
        end
        throw(ArgumentError(
            "peaks(exp): no dynamics/ensemble/phase_*/density/mean"
        ))
    end
end

"""
    superfluid_fraction(exp; direction=1, method=:leggett) -> Float64
    superfluid_fraction(exp, t; direction=1, method=:leggett) -> Float64

Translational superfluid fraction of the run's stored state — the final ψ for
the no-`t` form, the snapshot nearest `t` otherwise. Adds the `Experiment`
faces of `superfluid_fraction(psi, grid; …)`; all keywords pass through, so
the caveats there apply unchanged (rigid density ⇒ upper bound; a cloud that
does not span the periodic box legitimately reports ≈ 0).

Grid comes from the run's own `RunResult`, so the value is reproducible from
the jld2 alone.
"""
superfluid_fraction(exp::Experiment; kwargs...) =
    let r = _runresult(exp)
        superfluid_fraction(r.psi, r.grid; kwargs...)
    end

function superfluid_fraction(exp::Experiment, t::Real; kwargs...)
    grid = _runresult(exp).grid
    superfluid_fraction(psi(exp, float(t)), grid; kwargs...)
end
