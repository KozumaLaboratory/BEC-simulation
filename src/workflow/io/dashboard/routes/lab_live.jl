# Lab image archive + live-monitor list/file route handlers
#
# Extracted from src/workflow/io/dashboard/routes.jl in the 2026-05-09
# refactor. Loaded by SpinorBEC.jl after route_helpers.jl + cache.jl.

function _route_lab_list(path::String, base_dir::String)
    # /api/lab/list/<run_name>?limit=N → JSON array of recent lab
    # images uploaded via POST /api/lab/image/<run>. Most recent
    # first, capped to `limit` (default 32 — matches the React
    # LabImageOverlay's ring buffer expectation).
    p = _parse_run_only(path, "/api/lab/list/")
    limit = _q_int(p.query, "limit", 32)
    img_dir = joinpath(base_dir, p.name, "lab_images")
    isdir(img_dir) || return (200, "application/json", "[]")
    files = sort(filter(f -> startswith(f, "shot_") && endswith(f, ".png"),
            readdir(img_dir)); rev=true)
    files = files[1:min(limit, length(files))]
    items = map(files) do f
        full = joinpath(img_dir, f)
        mt = round(Int, mtime(full) * 1000)
        sz = filesize(full)
        "{\"name\":\"$f\",\"url\":\"/runs/$(p.name)/lab_images/$(f)\",\"mtime_ms\":$mt,\"size\":$sz}"
    end
    (200, "application/json", "[" * join(items, ",") * "]")
end

function _route_live_list(base_dir::String)
    # Scan base_dir/* for runs whose _live_status.json was touched in
    # the last 5 minutes — those are presumed actively running. Return
    # a JSON array of {run, mtime_ms, age_s}.
    cutoff_s = 300.0
    active = String[]
    if isdir(base_dir)
        now_s = time()
        for entry in readdir(base_dir)
            full = joinpath(base_dir, entry, "_live_status.json")
            isfile(full) || continue
            age = now_s - mtime(full)
            age <= cutoff_s || continue
            mt = round(Int, mtime(full) * 1000)
            push!(active,
                "{\"run\":\"$entry\",\"mtime_ms\":$mt,\"age_s\":$(round(age; digits=1))}")
        end
    end
    (200, "application/json", "[" * join(active, ",") * "]")
end

function _route_live(path::String, base_dir::String)
    # /api/live/<run_name> → contents of base_dir/<run>/_live_status.json
    p = _parse_run_only(path, "/api/live/")
    status_path = joinpath(base_dir, p.name, "_live_status.json")
    isfile(status_path) ||
        return (404, "application/json", "{\"error\":\"no live status for $(p.name)\"}")
    (200, "application/json", read(status_path, String))
end
