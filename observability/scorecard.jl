# Scorecard renderer — a DERIVATIVE VIEW over observability/history.jsonl.
# Reads the append-only history + metrics.toml registry, and emits:
#   - docs/design/scorecard.md   (best-so-far + headroom-to-bound table)
#   - observability/scorecard.csv (flat, for external plotting)
#   - figs/scorecard.png         (best-so-far trend vs hardware bound, if a
#                                 Makie backend is available)
#
# No composite score. Per the design: ratchet metrics show best-so-far and the
# gap to a physical/hardware bound (never an arbitrary target); threshold gates
# show pass/fail. Records are grouped by env_class so H100 and WSL2 never mix.
#
#   julia --project=. observability/scorecard.jl

using JSON, TOML, Printf, Dates

const ROOT = normpath(joinpath(@__DIR__, ".."))
const HIST = joinpath(@__DIR__, "history.jsonl")
const REG  = TOML.parsefile(joinpath(@__DIR__, "metrics.toml"))

records = isfile(HIST) ? [JSON.parse(l) for l in eachline(HIST) if !isempty(strip(l))] : Dict[]
gpu = filter(r -> get(r, "metric_ns", "") == "gpu_ratchet", records)
bud = filter(r -> get(r, "metric_ns", "") == "tsubame_budget", records)

better(direction, a, b) = direction == "maximize" ? a > b : a < b   # a strictly better than b

"""best-so-far value + its timestamp for a flat metric path across gpu records."""
function best_of(getter, direction)
    best = nothing; ts = ""
    for r in gpu
        v = getter(r)
        v === nothing && continue
        if best === nothing || better(direction, v, best)
            best = v; ts = get(r, "ts", "")
        end
    end
    (best, ts)
end

g(r, path...) = begin
    x = r
    for k in path
        x isa AbstractDict || return nothing
        haskey(x, k) || return nothing
        x = x[k]
    end
    x
end

# ------------------------------------------------------------------ table rows
rows = Tuple{String,String,Any,Float64,String,String}[]  # name, dir, best, bound, headroom, ts
function push_ratchet!(name, path, dir)
    bound = get(get(REG["metrics"], name, Dict()), "bound", NaN)
    best, ts = best_of(r -> g(r, path...), dir)
    best === nothing && return
    hr = dir == "maximize" ? @sprintf("%.1f to %.0f", bound - best, bound) :
                             (isfinite(bound) && bound == 0 ? "→0" : @sprintf("%.3g", best - bound))
    push!(rows, (name, dir, best, Float64(bound), hr, ts))
end

push_ratchet!("gpu_busy_pct",        ("metrics", "gpu_busy_pct"),               "maximize")
push_ratchet!("gpu_step_us",         ("metrics", "gpu_step_us"),                "minimize")
push_ratchet!("gpu_ddi_rotation_us", ("metrics", "kernels", "ddi_rotation_us"), "minimize")

# ------------------------------------------------------------------ markdown
open(joinpath(ROOT, "docs", "design", "scorecard.md"), "w") do io
    println(io, "# Perf / Accuracy Scorecard\n")
    println(io, "_Generated ", now(), " from `observability/history.jsonl` (", length(records), " records). ",
                "No composite score, no arbitrary targets — ratchet metrics track best-so-far vs a physical/hardware bound._\n")
    println(io, "## Ratchet metrics (optimise forever · env_class = tsubame_h100_node_q)\n")
    println(io, "| metric | dir | best-so-far | bound | headroom | since |")
    println(io, "|---|---|--:|--:|--|---|")
    for (name, dir, best, bound, hr, ts) in rows
        bs = best isa AbstractFloat ? @sprintf("%.2f", best) : string(best)
        println(io, "| `$name` | $dir | $bs | $(bound) | $hr | $(first(ts, 10)) |")
    end
    if isempty(rows)
        println(io, "| _(no GPU records yet — run `observability/collect_h100.sh`)_ | | | | | |")
    end
    println(io, "\n## Threshold gates (correctness · machine-eps floor · enforced in CI)\n")
    println(io, "| metric | gate | source |")
    println(io, "|---|--:|---|")
    for (name, m) in REG["metrics"]
        get(m, "kind", "") == "threshold" || continue
        println(io, "| `$name` | $(get(m, "gate", "?")) | `$(get(m, "source", ""))` |")
    end
    if !isempty(bud)
        last_b = bud[end]
        println(io, "\n## TSUBAME budget (campaign cap = ", get(REG["budget"], "cap_points", 30),
                    " points)\n")
        println(io, "- balance: **", get(last_b, "balance", "?"), "** points  ",
                    "· campaign spent: **", get(last_b, "spent", 0), "** / ", get(last_b, "cap", 30),
                    "  · /gs/fs disk: ", get(last_b, "disk_gs_gb", "?"), " GB")
    end
end

# ------------------------------------------------------------------ csv
open(joinpath(@__DIR__, "scorecard.csv"), "w") do io
    println(io, "ts,N,dtype,gpu_step_us,gpu_busy_pct,ddi_rotation_us,allocs_bytes")
    for r in gpu
        println(io, join((get(r, "ts", ""), get(r, "N", ""), get(r, "dtype", ""),
            g(r, "metrics", "gpu_step_us"), g(r, "metrics", "gpu_busy_pct"),
            g(r, "metrics", "kernels", "ddi_rotation_us"), g(r, "metrics", "allocs_bytes")), ","))
    end
end

# ------------------------------------------------------------------ figure (optional)
try
    @eval using CairoMakie
    if !isempty(gpu)
        ts_idx = 1:length(gpu)
        busy = Float64[something(g(r, "metrics", "gpu_busy_pct"), NaN) for r in gpu]
        fig = CairoMakie.Figure(size = (720, 420))
        ax = CairoMakie.Axis(fig[1, 1], xlabel = "snapshot #", ylabel = "GPU busy %",
                             title = "GPU utilisation — best-so-far vs 100% (roofline of no idle)")
        CairoMakie.hlines!(ax, [100.0], color = :red, linestyle = :dash, label = "hardware bound")
        CairoMakie.scatterlines!(ax, collect(ts_idx), busy, label = "measured")
        CairoMakie.axislegend(ax, position = :rb)
        mkpath(joinpath(ROOT, "figs"))
        CairoMakie.save(joinpath(ROOT, "figs", "scorecard.png"), fig)
        println("figs/scorecard.png written")
    end
catch e
    println("(figure skipped — no Makie backend: ", e, ")")
end

println("docs/design/scorecard.md + observability/scorecard.csv written (", length(gpu), " GPU records)")
