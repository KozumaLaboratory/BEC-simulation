# GET /api/index — the navigable flat catalog over the CAS run store.
#
# One sparse row per run (summary.json observables + state.toml status +
# mtime/family), most-recently-touched first. Cheap read path: never opens
# jld2, so it's safe to serve synchronously. The browser does faceting +
# parallel-coordinates over this array (zero round-trip filtering). Runs
# lacking a summary appear as partial rows — visible, not hidden — until
# `cli.jl catalog reindex` backfills them.

using ..SpinorBEC: run_catalog_index

function _route_catalog_index(base_dir)
    rows = try
        run_catalog_index(; runs_root=base_dir)
    catch e
        return (500, "application/json",
            "{\"error\":\"$(_jsonesc(string(e)))\"}")
    end
    io = IOBuffer()
    JSON.print(io, rows)
    return (200, "application/json", String(take!(io)))
end
