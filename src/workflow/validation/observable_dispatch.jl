# --- Base.getproperty(::RunResult, ::Symbol) — observable dispatch ---
#
# Surfaces observables as properties on RunResult so REPL workflows
# read like `r.norm`, `r.Fz_drift`, `r.energy_rel_drift` instead of
# poking into `r.dynamics.norms[end]`.
#
# Dispatch table (suffix-based, applied to dynamics columns):
#
#   * struct fields (path, psi, grid, atom, interactions, dynamics,
#     e_decomp, metadata) — passthrough via getfield
#   * `<x>_t`             — full time series Vector{Float64}
#   * `<x>`               — terminal scalar (last element of time series)
#   * `<x>_drift`         — max |x(t) - x(0)|
#   * `<x>_rel_drift`     — max |x(t) - x(0)| / max(|x(0)|, 1e-30)
#
# Where `x ∈ {norm, energy, Fz, Lz, Jz}`. `Jz = Fz + Lz` is computed
# on demand from Fz and Lz columns (with Lz defaulting to zero if
# absent — the dispatch warns when this happens).
#
# Missing observables throw informative ArgumentError so the user
# learns the dispatch table rather than getting a bare FieldError.

# Recognised time-series column accessors. Each maps a base symbol to
# the function that extracts the underlying Vector{Float64} from a
# DynamicsTimeSeries (returning `nothing` if not saved).
const _OBSERVABLE_COLUMNS = (
    :norm => d -> d.norms,
    :energy => d -> d.energies,
    :Fz => d -> d.Fz,
    :Lz => d -> d.Lz,
    :Jz => d -> begin
        Lz = d.Lz === nothing ? zeros(Float64, length(d.Fz)) : d.Lz
        d.Fz .+ Lz
    end,
)

_observable_column(name::Symbol) = findfirst(p -> p.first === name, _OBSERVABLE_COLUMNS)

function _dynamics_series(r::RunResult, base::Symbol)
    dyn = getfield(r, :dynamics)
    dyn === nothing && throw(
        ArgumentError(
            "RunResult.$base requires a dynamics time series; this run has none. " *
            "Saved struct fields: $(fieldnames(RunResult))"),
    )
    idx = _observable_column(base)
    idx === nothing && throw(
        ArgumentError(
            "RunResult: no observable `$base`. Known: $(map(first, _OBSERVABLE_COLUMNS))"),
    )
    extractor = _OBSERVABLE_COLUMNS[idx].second
    series = extractor(dyn)
    series === nothing && throw(
        ArgumentError(
            "RunResult.$base: column not present in saved dynamics " *
            "(this run did not save Lz / etc.). Recompute from psi snapshots " *
            "in Phase-3 observable layer."),
    )
    Float64.(series)
end

function Base.getproperty(r::RunResult, name::Symbol)
    # 1. Plain struct fields — passthrough.
    if name in fieldnames(RunResult)
        return getfield(r, name)
    end

    s = String(name)

    # 2. Drift dispatch (`<base>_rel_drift`, `<base>_drift`, `<base>_t`).
    if endswith(s, "_rel_drift")
        base = Symbol(s[1:(end - length("_rel_drift"))])
        ts = _dynamics_series(r, base)
        absolute = maximum(abs.(ts .- ts[1]))
        return absolute / max(abs(ts[1]), COUPLING_TOL)
    end
    if endswith(s, "_drift")
        base = Symbol(s[1:(end - length("_drift"))])
        ts = _dynamics_series(r, base)
        return maximum(abs.(ts .- ts[1]))
    end
    if endswith(s, "_t")
        base = Symbol(s[1:(end - length("_t"))])
        return _dynamics_series(r, base)
    end

    # 3. Terminal scalar — last value of the time series.
    if _observable_column(name) !== nothing
        ts = _dynamics_series(r, name)
        return ts[end]
    end

    throw(
        ArgumentError(
            "RunResult.$name not recognised. " *
            "Try: fields ($(join(fieldnames(RunResult), ", "))); " *
            "observables ($(join(map(first, _OBSERVABLE_COLUMNS), ", "))); " *
            "suffixes (_t, _drift, _rel_drift)."),
    )
end

# Tell Julia which symbols are valid for tab-completion + reflection.
function Base.propertynames(r::RunResult)
    fields = collect(fieldnames(RunResult))
    obs = collect(map(first, _OBSERVABLE_COLUMNS))
    obs_t = [Symbol(string(x, "_t")) for x in obs]
    obs_d = [Symbol(string(x, "_drift")) for x in obs]
    obs_rd = [Symbol(string(x, "_rel_drift")) for x in obs]
    Tuple(vcat(fields, obs, obs_t, obs_d, obs_rd))
end
