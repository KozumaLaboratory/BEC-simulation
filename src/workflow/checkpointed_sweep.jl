# --- CheckpointedSweep: per-cell cache + resume + extend ---
#
# Sequential parameter sweep with per-cell JLD2 caching, automatic
# skip-if-cached, and warm-restart extension for cells that don't
# pass a convergence gate.
#
# Lifted from `scripts/sprint5_M1_ITP_omega_sweep_converged.jl` +
# `scripts/sprint5_M1_extend.jl` (2026-06-04 M1 post-fix sweep). The
# per-cell-cache pattern was added ad-hoc when 30-cell sweeps started
# taking hours and partial progress was getting lost on every restart;
# this is the standard primitive that future multi-cell experiments
# (M2 perturbative Barnett, c1 calibration grid, future phase
# diagrams) should use instead of re-implementing the pattern.
#
# Design:
#   - `cell_key(params)` → String — defines the cell file basename.
#     Filenames are `cell_<key>.jld2` in `cache_dir`.
#   - `runner(params)` → NamedTuple — produces the cell result. MUST
#     include `:psi` (the wavefunction) if extension is enabled.
#   - `extender(params, prev_result; n_extend)` → NamedTuple — warm-
#     restart pass for cells that didn't pass `gate`. Loads `prev.psi`
#     from cache and runs additional iterations.
#   - `gate(result)` → Bool — true ⇒ converged, false ⇒ extend candidate.
#
# All three callbacks are user-supplied; the standard feature only
# handles the orchestration (cache, skip, log, extend pass).

export CheckpointedSweep, run_cell!, run_sweep!, extend_unconverged!,
    load_cell, collect_results

using JLD2
using Printf

"""
    CheckpointedSweep

Sequential parameter sweep with per-cell JLD2 caching, automatic
skip-if-cached, and warm-restart extension for cells that don't pass
a convergence gate.

# Fields
- `cache_dir::String` — directory where `cell_<key>.jld2` files live.
- `cell_key::Function` — `params -> String`, the cell filename key.
- `runner::Function` — `params -> NamedTuple`. The result is `jldsave`'d
  under key `:result`. If extension is enabled, the result MUST contain
  the keys the extender needs (typically `:psi`).
- `extender::Union{Nothing,Function}` — `(params, prev_result; n_extend) ->
  NamedTuple`. Set to `nothing` to disable extension.
- `gate::Function` — `result -> Bool`. Cells where `gate(result)` is true
  are considered converged.

# Examples

```julia
sweep = CheckpointedSweep(
    cache_dir = "runs/my_sweep",
    cell_key  = p -> @sprintf("B%.1f_Om%.2f", p.B, p.Ω),
    runner    = p -> my_runner(p.B, p.Ω),
    extender  = (p, prev; n_extend) -> my_extender(p, prev, n_extend),
    gate      = r -> r.grad_norm < 1e-5,
)

cells = [(B=B, Ω=Ω) for B in 0.0:1.0:10.0 for Ω in 0.1:0.1:0.6]
run_sweep!(sweep, cells)
extend_unconverged!(sweep, cells; n_extend=10_000)
results = collect_results(sweep, cells)
```
"""
struct CheckpointedSweep{R, E, G, K}
    cache_dir::String
    cell_key::K
    runner::R
    extender::E
    gate::G
end

function CheckpointedSweep(;
    cache_dir::AbstractString,
    cell_key::Function,
    runner::Function,
    extender::Union{Nothing, Function}=nothing,
    gate::Function,
)
    return CheckpointedSweep(
        String(cache_dir), cell_key, runner, extender, gate
    )
end

"""
    cell_path(sweep, params) → String

Resolve the JLD2 cache path for one cell.
"""
function cell_path(sweep::CheckpointedSweep, params)
    joinpath(sweep.cache_dir, "cell_" * sweep.cell_key(params) * ".jld2")
end

"""
    load_cell(sweep, params) → Union{Nothing,NamedTuple}

Load a cached cell result, or `nothing` if the cell has not run yet.
"""
function load_cell(sweep::CheckpointedSweep, params)
    path = cell_path(sweep, params)
    isfile(path) || return nothing
    return JLD2.load(path, "result")
end

"""
    run_cell!(sweep, params; force=false) → NamedTuple

Run one cell. Skip and return the cached result if `cell_<key>.jld2`
exists and `force` is `false`. Otherwise call `sweep.runner(params)`,
persist the result, and return it.
"""
function run_cell!(sweep::CheckpointedSweep, params; force::Bool=false)
    path = cell_path(sweep, params)
    if !force && isfile(path)
        return JLD2.load(path, "result")
    end
    result = sweep.runner(params)
    mkpath(sweep.cache_dir)
    JLD2.jldsave(path; result=result, params=params)
    return result
end

"""
    run_sweep!(sweep, cells; force=false, verbose=true) → Vector{NamedTuple}

Run all cells sequentially with caching. Returns results in `cells`
order. Cached cells are skipped (printed as `cached`) unless `force`.
"""
function run_sweep!(
    sweep::CheckpointedSweep, cells; force::Bool=false, verbose::Bool=true
)
    results = Vector{Any}(undef, length(cells))
    n_total = length(cells)
    for (i, params) in enumerate(cells)
        path = cell_path(sweep, params)
        if !force && isfile(path)
            verbose && @printf("[%d/%d] %s  cached\n", i, n_total, basename(path))
            results[i] = JLD2.load(path, "result")
            continue
        end
        verbose && @printf("[%d/%d] %s  running …\n", i, n_total, basename(path))
        t0 = time()
        result = sweep.runner(params)
        mkpath(sweep.cache_dir)
        JLD2.jldsave(path; result=result, params=params)
        verbose && @printf("[%d/%d] %s  done in %.1fs\n",
            i, n_total, basename(path), time() - t0)
        results[i] = result
    end
    return results
end

"""
    extend_unconverged!(sweep, cells; n_extend=10_000, verbose=true) → Vector

For each cell, if `gate(result) === false`, run `sweep.extender(params,
prev_result; n_extend)` and overwrite the cell file with the extended
result. Cells that pass the gate (or that have no cached result yet)
are skipped.

Throws `ArgumentError` if `sweep.extender === nothing`.
"""
function extend_unconverged!(
    sweep::CheckpointedSweep, cells; n_extend::Int=10_000, verbose::Bool=true
)
    sweep.extender === nothing &&
        throw(ArgumentError("CheckpointedSweep has no extender configured"))
    results = Vector{Any}(undef, length(cells))
    n_total = length(cells)
    for (i, params) in enumerate(cells)
        path = cell_path(sweep, params)
        if !isfile(path)
            verbose && @printf("[%d/%d] %s  no cache → skipping\n",
                i, n_total, basename(path))
            results[i] = nothing
            continue
        end
        prev = JLD2.load(path, "result")
        if sweep.gate(prev)
            verbose && @printf("[%d/%d] %s  converged → skipping\n",
                i, n_total, basename(path))
            results[i] = prev
            continue
        end
        verbose && @printf("[%d/%d] %s  extending (n=%d) …\n",
            i, n_total, basename(path), n_extend)
        t0 = time()
        result = sweep.extender(params, prev; n_extend=n_extend)
        JLD2.jldsave(path; result=result, params=params)
        verbose && @printf("[%d/%d] %s  extended in %.1fs (gate=%s)\n",
            i, n_total, basename(path), time() - t0, string(sweep.gate(result)))
        results[i] = result
    end
    return results
end

"""
    collect_results(sweep, cells) → Vector{Union{Nothing,NamedTuple}}

Load all cell results in `cells` order. Cells without a cache file
return `nothing` for that slot.
"""
function collect_results(sweep::CheckpointedSweep, cells)
    [load_cell(sweep, p) for p in cells]
end
