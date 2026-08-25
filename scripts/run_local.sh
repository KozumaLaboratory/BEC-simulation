#!/usr/bin/env bash
# Run a command under the budget this host derived for itself.
#
# All of the derivation lives in src/workflow/io/host_budget.jl and NONE of it
# lives here — this script reads what that file emits and applies it. There is
# one statement of "how big may a run be on this host", and it is testable Julia
# rather than shell arithmetic. host_budget.jl depends on Base alone precisely so
# this launcher can include it without paying to load SpinorBEC.
#
# What it buys, measured on this tree 2026-08-24:
#   - the job cannot touch swap        (MemorySwapMax=0; global swap stayed put
#                                       to the byte while the cap was exercised)
#   - overrunning KILLS, never hangs   (exit 137, constraint=CONSTRAINT_MEMCG;
#                                       MemoryHigh was measured to livelock and
#                                       is deliberately not used)
#   - the kill is scoped to the job    (the system OOM killer never ran, so
#                                       nothing else on the desktop was at risk)
#   - typing stays responsive          (CPUWeight at the cgroup minimum: the job
#                                       yields to anything, and still uses an
#                                       otherwise idle machine in full)
#
# Usage:
#   scripts/run_local.sh --print                 # show the budget and its provenance
#   scripts/run_local.sh julia --project=. …     # run under it
#   scripts/run_local.sh -- julia --project=. …  # same, explicit end of options
#
# This is for LOCAL work. Heavy production belongs on TSUBAME, where the
# scheduler is the thing enforcing the budget; there host_budget.jl reads the
# grant out of the batch environment instead and this wrapper is not used.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
julia_bin="${SPINORBEC_LOCAL_JULIA:-julia}"

print_only=0
allow_uncontained=0
while [ $# -gt 0 ]; do
    case "$1" in
        --print|-n) print_only=1; shift ;;
        --allow-uncontained) allow_uncontained=1; shift ;;
        --) shift; break ;;
        -*) echo "run_local.sh: unknown option $1" >&2; exit 2 ;;
        *) break ;;
    esac
done

if [ "$print_only" -eq 1 ]; then
    exec "$julia_bin" --startup-file=no -e '
        include(joinpath(ARGS[1], "src", "workflow", "io", "host_budget.jl"))
        budget_report(detect_host_budget())
    ' "$root"
fi

if [ $# -eq 0 ]; then
    echo "run_local.sh: nothing to run. Try --print, or pass a command." >&2
    exit 2
fi

# One call, three answers: the env the run wants, the cgroup properties that
# contain it, and whether containment is possible at all. Tab-separated so the
# shell never has to eval anything the derivation printed.
emitted="$("$julia_bin" --startup-file=no -e '
    include(joinpath(ARGS[1], "src", "workflow", "io", "host_budget.jl"))
    b = detect_host_budget()
    for e in budget_env(b);              println("env\t", e);  end
    for p in budget_scope_properties(b); println("prop\t", p); end
    println("contained\t", b.swap_containable)
    println("ceiling\t", b.memory_bytes)
' "$root")"

env_args=()
scope_args=()
contained=false
ceiling=0
while IFS=$'\t' read -r kind value; do
    case "$kind" in
        env)       env_args+=("$value") ;;
        prop)      scope_args+=(-p "$value") ;;
        contained) contained="$value" ;;
        ceiling)   ceiling="$value" ;;
    esac
done <<< "$emitted"

if [ "$contained" != "true" ]; then
    # Fail closed. The whole point of running here rather than on TSUBAME is
    # that the machine stays usable, and without a swap-proof cgroup this
    # wrapper cannot promise that — so it must not pretend to.
    echo "run_local.sh: this host cannot forbid swap for a child cgroup." >&2
    "$julia_bin" --startup-file=no -e '
        include(joinpath(ARGS[1], "src", "workflow", "io", "host_budget.jl"))
        budget_report(detect_host_budget(); io = stderr)
    ' "$root" >&2 || true
    if [ "$allow_uncontained" -ne 1 ]; then
        echo "Refusing to launch: the run could push this machine into swap." >&2
        echo "Pass --allow-uncontained to run anyway, deliberately." >&2
        exit 3
    fi
    echo "--allow-uncontained given; launching WITHOUT a swap guarantee." >&2
fi

# A slice of our own, so a run's own memory never lands in the app/session
# slices whose historical peak is what sizes the interactive reserve. Without
# this the ceiling would ratchet downward with every run.
if [ "${#scope_args[@]}" -gt 0 ]; then
    # --collect: a scope that dies at the cap is left registered as `failed`
    # otherwise, so a week of hitting the ceiling silts up `systemctl --user`
    # with units nobody will read and the real failure gets harder to see.
    set -- systemd-run --user --scope --quiet --collect --slice=spinorbec.slice \
        --description="spinorbec run under derived host budget" \
        "${scope_args[@]}" -- "$@"
fi

set +e
env "${env_args[@]}" "$@"
rc=$?
set -e

if [ "$rc" -eq 137 ]; then
    echo "" >&2
    echo "run_local.sh: the job was KILLED at the derived memory ceiling" \
         "($(( ceiling / 1024 / 1024 )) MiB) — it did not crash, and it did not swap." >&2
    echo "Either shrink the run, or take it to TSUBAME where the budget is the" \
         "scheduler's to grant. 'scripts/run_local.sh --print' shows how the" \
         "ceiling was derived." >&2
fi
exit "$rc"
