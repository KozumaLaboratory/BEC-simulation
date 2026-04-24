# Overnight batch — runs a sequence of diverse scenarios in one Julia process
# to amortize JIT / package load. Each run's high-level progress and timing
# is logged to stdout (the detached launcher redirects to logs/batch_overnight.log).
# Per-run ITP traces still appear in the same log, prefixed by the run banner.

import CUDA
using SpinorBEC
using Dates
using Printf

# Periodic stdout flush so `tail -f logs/batch_overnight.log` stays live
@async while true
    flush(stdout); flush(stderr)
    sleep(10)
end

const RUNS = [
    "klaus2022_full",        # Klaus 2022 Dy164 vortex-stripe reproduction
    "eu151_sgpe_thermal",    # SGPE finite-T ensemble (validates Phase 4.3)
    "eu151_kibble_zurek",    # KZ quench scaling (defect_density × τ_Q)
    "eu151_phase_pq_hires",  # (p, q) phase diagram — runs only if prior finish early
]

println("=" ^ 72)
println("[$(now())] Overnight batch — $(length(RUNS)) runs")
println("=" ^ 72)
flush(stdout)

batch_start = time()
results = Dict{String,Any}()

for name in RUNS
    println()
    println("─" ^ 72)
    println("[$(now())] ▶ $name  start")
    println("─" ^ 72)
    flush(stdout)

    t0 = time()
    try
        run_yaml("runs/$(name)/config.yaml"; base_dir = "runs", verbose = true)
        dt = time() - t0
        results[name] = (status = :ok, seconds = dt)
        println("[$(now())] ✓ $name completed in $(round(dt/3600; digits=2)) h")
    catch e
        dt = time() - t0
        results[name] = (status = :error, seconds = dt,
                         error = sprint(showerror, e))
        println("[$(now())] ✗ $name FAILED after $(round(dt/60; digits=1)) min")
        @error "Run $name failed" exception=(e, catch_backtrace())
    end
    flush(stdout)
end

total = time() - batch_start
println()
println("=" ^ 72)
println("[$(now())] Batch finished in $(round(total/3600; digits=2)) h")
println("=" ^ 72)
for (name, r) in results
    status = r.status == :ok ? "✓" : "✗"
    @printf("  %s %-28s  %6.2f h\n", status, name, r.seconds / 3600)
end
flush(stdout)
