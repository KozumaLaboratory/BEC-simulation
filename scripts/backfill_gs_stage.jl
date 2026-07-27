#!/usr/bin/env julia
# Backfill the content-addressed GS stage store from EXISTING run directories, so
# ground states already computed under the old (per-config, per-scan-index) layout
# are reused by future SPINORBEC_STAGE_CACHE runs instead of recomputed.
#
#   julia --project=. scripts/backfill_gs_stage.jl <run_dir>...           # dry-run
#   BACKFILL_WRITE=1 julia --project=. scripts/backfill_gs_stage.jl <dir>...  # ingest
#
# For each point_*.jld2 it reconstructs the SAME gs_hash a live run would produce
# (apply_overrides → parse_pipeline → the exact GS resolution path → _gs_cache_key)
# and copies psi/energy/converged into <stage>/<gs_hash>.jld2 if absent. It only
# ingests from-scratch cells (no seed_from / no explicit cache: / not a continuation
# scan) — the same cells the auto-cache is valid for. Existing point files are never
# modified. Stage dir = SPINORBEC_STAGE_DIR or <SPINORBEC_STORE|runs>/_stage/gs.

using SpinorBEC, JLD2, YAML
using SpinorBEC: apply_overrides, parse_pipeline, GroundStateStep,
    _resolve_gs_atom, _resolve_gs_grid, _resolve_gs_interactions,
    _resolve_gs_ddi_inheritance, _gs_cache_key, _gs_stage_dir

const WRITE = get(ENV, "BACKFILL_WRITE", "0") in ("1", "true", "on", "yes")

# Reproduce the live gs_hash for one cell; nothing if the cell is not auto-cacheable.
function _gs_hash_for_cell(data::Dict, override, is_continuation::Bool)
    is_continuation && return nothing
    patched = apply_overrides(data, override)
    delete!(patched, "scan")
    cfg = parse_pipeline(patched)
    gs = nothing
    for s in cfg.steps
        s isa GroundStateStep && (gs = s; break)
    end
    gs === nothing && return nothing
    p = gs.params
    (haskey(p, "seed_from") || haskey(p, "cache")) && return nothing
    method = Symbol(get(p, "method", "itp"))
    atom = _resolve_gs_atom(p, nothing; verbose=false)
    grid, _ = _resolve_gs_grid(p, nothing)
    inter = _resolve_gs_interactions(p, nothing, atom)
    ddi = _resolve_gs_ddi_inheritance(p, nothing, atom)
    tol = Float64(get(p, "tol", 1e-8))
    n_steps = Int(get(p, "n_steps", method === :lbfgs ? 500 : 100000))
    dt = Float64(get(p, "dt", 0.001))
    _gs_cache_key(method, atom, grid, inter, ddi, tol, n_steps, dt, p)
end

function backfill_dir(rundir::String, stagedir::String)
    cfgpath = joinpath(rundir, "config.yaml")
    isfile(cfgpath) || (println("  skip (no config.yaml): $rundir"); return (0, 0, 0))
    data = YAML.load_file(cfgpath)
    scan = get(data, "scan", nothing)
    is_cont = scan isa AbstractDict && get(scan, "continuation", false) == true
    ingest = 0; present = 0; skip = 0
    for f in sort(readdir(rundir))
        (startswith(f, "point_") && endswith(f, ".jld2")) || continue
        path = joinpath(rundir, f)
        local override, psi, energy, converged
        try
            jldopen(path, "r") do d
                override = d["override"]
                psi = d["psi"]
                energy = haskey(d, "energy") ? d["energy"] : NaN
                converged = haskey(d, "converged") ? d["converged"] : true
            end
        catch
            skip += 1; continue
        end
        h = try
            _gs_hash_for_cell(data, override, is_cont)
        catch err
            @warn "hash failed" file=f exception=err
            nothing
        end
        h === nothing && (skip += 1; continue)
        dest = joinpath(stagedir, h * ".jld2")
        if isfile(dest)
            present += 1; continue
        end
        if WRITE
            mkpath(stagedir)
            tmp = dest * ".tmp." * string(getpid())
            jldopen(tmp, "w") do g
                g["psi"] = psi; g["energy"] = energy; g["converged"] = converged
            end
            mv(tmp, dest; force=true)
        end
        ingest += 1
    end
    println("  $rundir: ingest=$ingest present=$present skip=$skip")
    (ingest, present, skip)
end

function main()
    isempty(ARGS) && (println("usage: backfill_gs_stage.jl <run_dir>..."); return)
    stagedir = _gs_stage_dir()
    println("stage dir: $stagedir   mode: ", WRITE ? "WRITE" : "DRY-RUN")
    tot = [0, 0, 0]
    for d in ARGS
        (i, p, s) = backfill_dir(d, stagedir)
        tot .+= (i, p, s)
    end
    println("TOTAL ingest=$(tot[1]) present=$(tot[2]) skip=$(tot[3]) ",
        WRITE ? "(written)" : "(dry-run — set BACKFILL_WRITE=1 to ingest)")
end

main()
