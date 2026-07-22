# Deterministic round-verdict primitive for /goal + /loop driven optimisation.
#
#   julia --project=. observability/round.jl <metric> [N] [dtype]
#
# Reads observability/history.jsonl (measurements) + observability/best.json
# (persistent ratchet state) and decides — WITHOUT any fuzzy judgment — whether
# the newest measurement beats best-so-far beyond the noise band and whether the
# accuracy gates still hold. Writes observability/round_verdict.json.
#
# The /goal evaluator (a fast fuzzy model) must read ONLY `accepted` from that
# file — never re-derive the numeric comparison. This is the sneaky-prover
# discipline (don't trust a fuzzy judge with numbers) applied to /goal.
#
# accepted == true  => a REAL improvement, gates verified, best.json advanced.
# On first-ever measurement of a metric: baseline recorded, accepted=false.

using JSON, TOML

const HERE = @__DIR__
const HIST = joinpath(HERE, "history.jsonl")
const BEST = joinpath(HERE, "best.json")
const GATES = joinpath(HERE, "gates_status.json")   # written by the gate-runner turn
const VERDICT = joinpath(HERE, "round_verdict.json")
const REG = TOML.parsefile(joinpath(HERE, "metrics.toml"))

metric = length(ARGS) >= 1 ? ARGS[1] : error("usage: round.jl <metric> [N] [dtype]")
N      = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 128
dtype  = length(ARGS) >= 3 ? ARGS[3] : "Float64"

# metric name -> (metric_ns, path into the record's "metrics" tree)
const MAP = Dict(
    "gpu_busy_pct"        => ("gpu_ratchet", ["gpu_busy_pct"]),
    "gpu_step_us"         => ("gpu_ratchet", ["gpu_step_us"]),
    "gpu_ddi_rotation_us" => ("gpu_ratchet", ["kernels", "ddi_rotation_us"]),
    "gpu_ddi_convolve_us" => ("gpu_ratchet", ["kernels", "ddi_convolve_us"]),
    "gpu_kinetic_us"      => ("gpu_ratchet", ["kernels", "kinetic_us"]),
    "gpu_diagonal_us"     => ("gpu_ratchet", ["kernels", "diagonal_us"]),
    "gpu_spin_mixing_us"  => ("gpu_ratchet", ["kernels", "spin_mixing_us"]),
    "gpu_energy_us"       => ("gpu_ratchet", ["gpu_energy_us"]),
    "gpu_gradient_us"     => ("gpu_ratchet", ["gpu_gradient_us"]),
    "gpu_allocs_bytes"    => ("gpu_ratchet", ["allocs_bytes"]),
    "cpu_split_step_ns"     => ("cpu_ratchet", ["split_step_ns"]),
    "cpu_split_step_allocs" => ("cpu_ratchet", ["split_step_allocs"]),
)
haskey(MAP, metric) || error("unknown metric '$metric'. known: $(join(sort(collect(keys(MAP))), ", "))")
metric_ns, path = MAP[metric]

reg = get(REG["metrics"], metric, Dict())
direction   = get(reg, "direction", "minimize")
confidence  = get(reg, "confidence", "noisy")
env_class   = get(REG["env"], "ratchet_env_class", "tsubame_h100_node_q")
noise_band  = Float64(get(REG["env"], "noise_band_pct", 5.0))

dig(x, ks) = (for k in ks; (x isa AbstractDict && haskey(x, k)) || return nothing; x = x[k]; end; x)

# ---- newest matching measurement --------------------------------------------
records = isfile(HIST) ? [JSON.parse(l) for l in eachline(HIST) if !isempty(strip(l))] : Dict[]
matches = filter(records) do r
    get(r, "metric_ns", "") == metric_ns &&
        get(r, "N", nothing) == N && get(r, "dtype", "") == dtype &&
        dig(get(r, "env", Dict()), ["env_class"]) == env_class
end
isempty(matches) && error("no $metric_ns record for N=$N dtype=$dtype env=$env_class in history.jsonl")
latest = matches[end]
new_val = dig(get(latest, "metrics", Dict()), path)
new_val === nothing && error("metric path $(path) absent in newest record")
new_val = Float64(new_val)

# ---- ratchet state ----------------------------------------------------------
best = isfile(BEST) ? JSON.parsefile(BEST) : Dict()
key = "$metric/N$N/$dtype"
prior = get(best, key, nothing)

better(a, b) = direction == "maximize" ? a > b : a < b   # a strictly better than b

# ---- accuracy gates (deterministic: read status file, never guess) ----------
gates = isfile(GATES) ? JSON.parsefile(GATES) : nothing
gates_ok = gates === nothing ? nothing : all(v -> v == true || v == "pass",
                                              values(get(gates, "gates", Dict())))

# ---- verdict ----------------------------------------------------------------
local improved, delta_pct, beyond_noise, accepted, reason
if prior === nothing
    old_best = nothing
    delta_pct = NaN; beyond_noise = false; improved = false; accepted = false
    reason = "baseline recorded for $key = $(round(new_val; digits=3)) (no prior best)"
    best[key] = Dict("best" => new_val, "ts" => get(latest, "ts", ""),
                     "commit" => dig(get(latest, "env", Dict()), ["commit"]),
                     "N" => N, "dtype" => dtype)
else
    old_best = Float64(prior["best"])
    delta_pct = 100.0 * (new_val - old_best) / abs(old_best)
    beyond_noise = confidence == "deterministic" ? new_val != old_best : abs(delta_pct) > noise_band
    improved = better(new_val, old_best) && beyond_noise
    if improved && gates_ok === true
        accepted = true
        reason = "$metric $(round(old_best;digits=3))→$(round(new_val;digits=3)) " *
                 "($(round(delta_pct;digits=1))%, beyond $(noise_band)% band); no gate regressed"
        best[key] = Dict("best" => new_val, "ts" => get(latest, "ts", ""),
                         "commit" => dig(get(latest, "env", Dict()), ["commit"]),
                         "N" => N, "dtype" => dtype)
    elseif improved && gates_ok === nothing
        accepted = false
        reason = "measurement improved ($(round(delta_pct;digits=1))%) but gates NOT verified — " *
                 "run threshold tests and write observability/gates_status.json"
    elseif improved
        accepted = false
        reason = "measurement improved but an accuracy gate REGRESSED — reject"
    else
        accepted = false
        reason = better(new_val, old_best) ?
            "change $(round(delta_pct;digits=1))% within $(noise_band)% noise band — not a real win" :
            "no improvement ($(round(new_val;digits=3)) vs best $(round(old_best;digits=3)))"
    end
end

verdict = Dict(
    "metric" => metric, "key" => key, "env_class" => env_class,
    "old_best" => prior === nothing ? nothing : Float64(prior["best"]),
    "new" => new_val, "delta_pct" => delta_pct,
    "direction" => direction, "confidence" => confidence,
    "beyond_noise_band" => beyond_noise, "improved" => improved,
    "gates_ok" => gates_ok, "accepted" => accepted, "reason" => reason,
    "ts" => get(latest, "ts", ""),
)

# Monotonic progress counter — lets a CONSTANT, metric-agnostic /goal drive
# many rounds: "accepted_count reaches N" is satisfied one win at a time,
# whatever kernel each round targeted.
PROGRESS = joinpath(HERE, "progress.json")
prog = isfile(PROGRESS) ? JSON.parsefile(PROGRESS) : Dict("accepted_count" => 0, "wins" => Any[])
if accepted
    prog["accepted_count"] = get(prog, "accepted_count", 0) + 1
    push!(get!(prog, "wins", Any[]),
          Dict("metric" => metric, "delta_pct" => delta_pct, "new" => new_val,
               "old" => old_best, "ts" => get(latest, "ts", "")))
    open(PROGRESS, "w") do io; JSON.print(io, prog, 2); end
end

open(VERDICT, "w") do io; JSON.print(io, verdict, 2); end
open(BEST, "w") do io; JSON.print(io, best, 2); end

println("="^70)
println("ROUND VERDICT  ", metric, "  (", key, ")")
println("="^70)
for k in ("old_best", "new", "delta_pct", "beyond_noise_band", "improved", "gates_ok", "accepted")
    println("  ", rpad(k, 18), " ", verdict[k])
end
println("  reason             ", reason)
println("\naccepted=", accepted, "  -> ", VERDICT)
