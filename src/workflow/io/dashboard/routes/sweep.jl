# GET /api/sweep/<run_name>
#
# Returns the resolved Vega-Lite viewspec for a sweep run. Looks for
# `<base_dir>/<run_name>/viewspec.json` (produced by
# `scripts/m1_sweep_golden_export.jl` or the runtime equivalent). 404
# when the file is absent so the frontend can show "no viewspec yet"
# rather than spinning forever.

function _route_sweep(path::String, base_dir::String)
    p = _parse_run_only(path, "/api/sweep/")
    p === nothing && return (400, "text/plain", "Expected /api/sweep/<run>")
    viewspec_path = joinpath(base_dir, p.name, "viewspec.json")
    isfile(viewspec_path) || return (
        404,
        "application/json",
        "{\"error\":\"No viewspec for $(p.name); run scripts/m1_sweep_golden_export.jl or equivalent\"}",
    )
    body = read(viewspec_path, String)
    return (200, "application/json", body)
end
