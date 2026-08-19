# --- CheckpointedSweep: thin sweep wrapper over Checkpoint ---
#
# Multi-cell parameter sweep with per-cell checkpointing. Built as a
# thin wrapper over the general `Checkpoint` primitive
# (`src/workflow/checkpoint.jl`). The Checkpoint primitive is what
# any deterministic checkpointable computation should use directly;
# this file adds the loop-over-cells convenience and convergence-gate
# extension pass that come up repeatedly in parameter sweeps.
#
# Lifted from `sprint5_M1_ITP_omega_sweep_converged.jl (archived)` +
# `sprint5_M1_extend.jl (archived)` (2026-06-04 M1 post-fix sweep). The
# per-cell pattern was ad-hoc until the 30-cell sweep started taking
# hours and partial progress was getting lost on every restart.

export CheckpointedSweep, run_cell!, run_sweep!, extend_unconverged!,
    load_cell, collect_results

using Printf

"""
    CheckpointedSweep

Parameter sweep that delegates per-cell caching to a `Checkpoint`.
Three user-supplied callbacks drive the loop:

  - `cell_key(params) → String` — the checkpoint key for one cell
  - `runner(params) → result::NamedTuple` — produce the cell result
  - `extender(params, prev; n_extend) → result` — warm-restart pass
    (set to `nothing` to disable `extend_unconverged!`)
  - `gate(result) → Bool` — convergence predicate

# Examples

```julia
sweep = CheckpointedSweep(
    checkpoint = Checkpoint("runs/my_sweep"),
    cell_key   = p -> @sprintf("B%.1f_Om%.2f", p.B, p.Ω),
    runner     = p -> my_runner(p.B, p.Ω),
    extender   = (p, prev; n_extend) -> my_extender(p, prev, n_extend),
    gate       = r -> r.grad_norm < 1e-5,
)

cells = [(B=B, Ω=Ω) for B in 0.0:1.0:10.0 for Ω in 0.1:0.1:0.6]
run_sweep!(sweep, cells)
extend_unconverged!(sweep, cells; n_extend=10_000)
results = collect_results(sweep, cells)
```
"""
struct CheckpointedSweep{R, E, G, K}
    checkpoint::Checkpoint
    cell_key::K
    runner::R
    extender::E
    gate::G
end

function CheckpointedSweep(;
    checkpoint::Union{Checkpoint, Nothing}=nothing,
    cache_dir::Union{AbstractString, Nothing}=nothing,
    cell_key::Function,
    runner::Function,
    extender::Union{Nothing, Function}=nothing,
    gate::Function,
)
    cp = if checkpoint !== nothing
        checkpoint
    elseif cache_dir !== nothing
        Checkpoint(String(cache_dir))
    else
        throw(ArgumentError("CheckpointedSweep: pass either `checkpoint=` or `cache_dir=`"))
    end
    return CheckpointedSweep(cp, cell_key, runner, extender, gate)
end

"""
    run_cell!(sweep, params; force=false) → result

Run one cell. Thin wrapper over `get_or_compute!(sweep.checkpoint,
sweep.cell_key(params), () -> sweep.runner(params))`. Skip and
return the cached result if cached and `force=false`.
"""
function run_cell!(sweep::CheckpointedSweep, params; force::Bool=false)
    key = sweep.cell_key(params)
    return get_or_compute!(
        sweep.checkpoint, key, () -> sweep.runner(params); force=force
    )
end

"""
    load_cell(sweep, params) → Union{Nothing, NamedTuple}

Load a cached cell result by params, or `nothing` if not yet run.
"""
load_cell(sweep::CheckpointedSweep, params) =
    load_checkpoint(sweep.checkpoint, sweep.cell_key(params))

"""
    run_sweep!(sweep, cells; force=false, verbose=true) → Vector

Run all cells sequentially. Each cell either loads its cached result
or calls `runner(params)` via `get_or_compute!`. Returns results in
`cells` order.
"""
function run_sweep!(
    sweep::CheckpointedSweep, cells; force::Bool=false, verbose::Bool=true
)
    n_total = length(cells)
    results = Vector{Any}(undef, n_total)
    for (i, params) in enumerate(cells)
        key = sweep.cell_key(params)
        if !force && has_checkpoint(sweep.checkpoint, key)
            verbose && @printf("[%d/%d] %s  cached\n", i, n_total, key)
            results[i] = load_checkpoint(sweep.checkpoint, key)
            continue
        end
        verbose && @printf("[%d/%d] %s  running …\n", i, n_total, key)
        t0 = time_ns()
        results[i] = get_or_compute!(
            sweep.checkpoint, key, () -> sweep.runner(params); force=force
        )
        verbose && @printf("[%d/%d] %s  done in %.1fs\n",
            i, n_total, key, elapsed_s(t0))
    end
    return results
end

"""
    extend_unconverged!(sweep, cells; n_extend=10_000, verbose=true) → Vector

For each cell, if `gate(result) === false`, call
`sweep.extender(params, prev; n_extend)` via `refine!` and overwrite
the checkpoint. Cells without a cached result OR cells that pass the
gate are skipped.

Throws `ArgumentError` if `sweep.extender === nothing`.
"""
function extend_unconverged!(
    sweep::CheckpointedSweep, cells; n_extend::Int=10_000, verbose::Bool=true
)
    sweep.extender === nothing &&
        throw(ArgumentError("CheckpointedSweep has no extender configured"))
    n_total = length(cells)
    results = Vector{Any}(undef, n_total)
    for (i, params) in enumerate(cells)
        key = sweep.cell_key(params)
        if !has_checkpoint(sweep.checkpoint, key)
            verbose && @printf("[%d/%d] %s  no cache → skipping\n", i, n_total, key)
            results[i] = nothing
            continue
        end
        prev = load_checkpoint(sweep.checkpoint, key)
        if sweep.gate(prev)
            verbose && @printf("[%d/%d] %s  converged → skipping\n", i, n_total, key)
            results[i] = prev
            continue
        end
        verbose && @printf("[%d/%d] %s  extending (n=%d) …\n",
            i, n_total, key, n_extend)
        t0 = time_ns()
        # In-place fork! (same source/target key) = advance the
        # checkpoint. The predicate short-circuits already-converged
        # cells (no transform call); we've already filtered above so
        # it's belt-and-braces here.
        results[i] = fork!(
            sweep.checkpoint, key, key,
            prev -> sweep.extender(params, prev; n_extend=n_extend);
            predicate=sweep.gate,
        )
        verbose && @printf("[%d/%d] %s  extended in %.1fs (gate=%s)\n",
            i, n_total, key, elapsed_s(t0), string(sweep.gate(results[i])))
    end
    return results
end

"""
    collect_results(sweep, cells) → Vector{Union{Nothing, Any}}

Load all cell results in `cells` order. Cells without a cache file
return `nothing`.
"""
function collect_results(sweep::CheckpointedSweep, cells)
    [load_checkpoint(sweep.checkpoint, sweep.cell_key(p)) for p in cells]
end
