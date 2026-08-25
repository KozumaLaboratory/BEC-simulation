# Running locally without losing the machine

Heavy production belongs on TSUBAME. But audits, smoke tests, figure passes and
the test suite all have to run on whatever is in front of you — and on an
interactive box the failure mode is not a wrong answer, it is a machine that
stops responding while 16 GiB of ground state pages out to disk.

This is the local path:

```bash
scripts/run_local.sh --print                      # the budget, and where each term came from
scripts/run_local.sh julia --project=. …          # run under it
```

The run gets a cgroup that **cannot touch swap**, a memory ceiling derived from
this host, and a CPU weight that makes it yield to anything you type. If it
outgrows the ceiling it is killed — cleanly, with exit status 137 and a message
saying so — rather than dragging the desktop into swap.

## There are no tuning constants

Every limit is read from the host. `--print` names the file or environment
variable behind each one, so a number that cannot be justified cannot be
emitted. The ladder, per quantity, most authoritative first:

| Rung | Source | Applies to |
|---|---|---|
| 1 | the batch allocation — `SLURM_*`, `NSLOTS` (UGE/TSUBAME), `PBS_*` | compute nodes: the grant *is* the answer, and the node's totals describe other people's jobs |
| 2 | cgroup v2 `memory.max` / `cpu.max` on our own chain | containers, systemd slices, WSL2 |
| 3 | the CPU **affinity mask** and `MemAvailable` | an ordinary interactive host |

`MemAvailable` is doing real work at rung 3: it is the kernel's own estimate of
how much can be allocated *without swapping*. That is precisely the quantity
wanted, already computed by the party that knows, and measured rather than
guessed.

Rung 3 also carries one subtraction, and only on a host that has an interactive
session:

```
interactive reserve = memory.peak − memory.current   of user@<uid>.service/{app,session}.slice
```

That is how much more the desktop has historically needed than it holds right
now — a measured growth headroom, not a chosen margin. On a compute node the
login-session cgroup does not exist, so the term is zero **by observation**.

Runs are placed in `spinorbec.slice`, a sibling of the slices being measured, so
a run's own memory never inflates the reserve. Without that the ceiling would
ratchet downward with every launch.

### Where it refuses

If the login session exists but its counters will not read (cgroup v1, a kernel
without `memory.peak`), `detect_host_budget` throws `BlindBudget` instead of
substituting zero. An unreadable reserve must not be spelled the same way as a
reserve of zero — that is the difference between "there is no desktop to
protect" and "I could not look". Same for a scheduler variable that is set but
unparseable.

State a value deliberately with `SPINORBEC_HOST_CPUS` /
`SPINORBEC_HOST_MEMORY_BYTES`; the budget then reports its source as
`:override`, so a stated number can never be presented as a measured one.

## Two knobs that are deliberately not used

**`MemoryHigh`.** Measured on this tree, 2026-08-24: a cgroup with `MemoryHigh`
below `MemoryMax` and swap forbidden does not die, it **livelocks** in reclaim.
`memory.events` read `high 2560, max 0, oom_kill 0` with the process pinned at
the cap making no progress. A job that hangs forever is worse than one that
dies, so enforcement is `MemoryMax` alone. That was measured to give a clean
`CONSTRAINT_MEMCG` kill at exit 137 with the global swap unchanged to the byte.

**`CPUQuota`.** The goal is that your typing stays responsive, and a quota buys
that by leaving the machine idle when you are not typing. `CPUWeight` at the
cgroup interface's own documented minimum buys the same responsiveness without
the waste: the job yields to anything that runs, and still takes the whole
machine when nothing else wants it.

## The FFT planner follows the thread count

`#407`: FFTW's `MEASURE` planner blows up on a mixed-radix length **only** when
threaded — 48³ at 16 threads took 1.66 GB against 0.35 GB at 64³, and 98³ took
11.97 GB. Threads are derived above, so the planner is derived with them:
`SPINORBEC_FFT_PLAN=estimate` whenever the budget grants more than one. Prefer
power-of-two grid edges anyway; the smoke grid is where this bites, because
128³ production is safe and `48³ --smoke` is not.

## What is verified, and what is not

Verified by execution on a WSL2 host, 2026-08-24:

- swap untouched under a binding cap (`memory.swap.current` 0; host swap
  unchanged at 804 MB across both canaries)
- overrun kills cleanly and distinguishably (exit 137, `CONSTRAINT_MEMCG`)
- the kill is scoped to the job — the system OOM killer never ran
- runs land in `spinorbec.slice`, outside the measured slices

**Not** verified by execution: the scheduler rungs. `SLURM_*`, `NSLOTS` and
`PBS_*` are unit-tested in `test/test_host_budget.jl` by setting the variables,
which proves the parsing and the precedence, and does **not** prove the values a
real scheduler exports on a real node. Treat the first cluster run as the
measurement. `scripts/run_local.sh` itself is not for cluster use: there the
scheduler is the thing enforcing the budget.

## Related

- `src/workflow/io/host_budget.jl` — the derivation; depends on Base alone so
  the launcher can include it without loading SpinorBEC
- `src/workflow/io/budget.jl` — the **demand** side (`estimate_run_budget`
  forecasts what a config will want); the two meet at launch
- `test/test_host_budget.jl` — the gate that keeps `Sys.CPU_THREADS` (the
  *machine's* core count, wrong by 24× inside a TSUBAME allotment) out of every
  site but its declaration
- `docs/guides/tsubame.md` — where heavy runs actually go
