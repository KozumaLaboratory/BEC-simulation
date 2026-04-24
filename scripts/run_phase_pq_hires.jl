# Long-running driver for runs/eu151_phase_pq_hires/config.yaml
#
# Invoked by the detached launcher (see logs/eu151_phase_pq_hires.log).
# A background task flushes stdout every 10 s so `tail -f` is useful when
# the process is detached (default block-buffering on non-TTY fds would
# otherwise hide ~5000 chars of output at a time).

import CUDA
using SpinorBEC
using Dates

# Periodic flusher — runs for the life of the process.
@async while true
    flush(stdout)
    flush(stderr)
    sleep(10)
end

println("[$(Dates.now())] starting eu151_phase_pq_hires")
flush(stdout)

t0 = time()
run_dir = run_yaml("runs/eu151_phase_pq_hires/config.yaml";
                    base_dir = "runs",
                    verbose = true)
dt = time() - t0

println("\n[$(Dates.now())] done in $(round(dt/3600; digits=2)) h → $(run_dir)")
flush(stdout)
