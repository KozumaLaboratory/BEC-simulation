#!/usr/bin/env bash
#
# Stop / SubagentStop hook — the INTEGRITY FLOOR of the Loop Engineering loop
# (docs/design/loop_engineering_architecture.md). On a stop attempt for a
# campaign ($BEC_LOOP_DIRECTION = path to the candidate TOML) it FRESH-RERUNS
# the isolated verifier (scripts/loop/verify.jl) on that candidate. The decision
# depends ONLY on this rerun, NEVER on the transcript: a `VERIFY: ACCEPT` line
# the agent echoed is advisory and cannot end the loop. This is the structural
# defense — the research shows an agent that can touch / self-report a verifier
# games it 49–76% of the time; here the verdict is the hook's own subprocess run.
#
# Composes with any per-task hooks: this one no-ops unless $BEC_LOOP_DIRECTION
# is set, and Stop is blocked if EITHER hook exits 2.
#
# Budget (progress-relative policy cap): a per-direction tick counter under
# .loop/ (survives --resume). K consecutive non-ACCEPT stop attempts →
# BUDGET_EXHAUSTED, allow stop — the loop terminates with a logged non-success,
# never unbounded. A terminal verdict is sealed in a .done sentinel so a resumed
# campaign stays terminated. `--max-turns` on `claude -p` is the silent hard
# backstop above this.
#
# Gate re-certification (F2/F9, the in-tree substitute for out-of-tree verifier
# isolation): set BEC_LOOP_RECERT=1 to additionally run the frozen adversarial
# suite (the sneaky-prover + three-valued replay) before trusting the gate, so a
# silently-weakened gate turns the suite red. Heavy (Julia) — run periodically,
# not every tick.
#
# exit 0 = allow stop (ACCEPT or budget exhausted) · exit 2 = block, keep going.

set -uo pipefail

[ -z "${BEC_LOOP_DIRECTION:-}" ] && exit 0     # not a campaign run → no-op

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CAND="$BEC_LOOP_DIRECTION"
NAME="$(basename "${CAND%.toml}")"
CAP="${BEC_LOOP_MAX_TICKS:-12}"
LDIR="$ROOT/.loop"
mkdir -p "$LDIR"
DONE="$LDIR/${NAME}.done"
TICK="$LDIR/${NAME}.ticks"

# Already terminal (sealed) → stay terminated.
if [ -f "$DONE" ]; then
    cat "$DONE"
    exit 0
fi

# Optional gate re-certification before trusting the verdict.
if [ "${BEC_LOOP_RECERT:-0}" = "1" ]; then
    if ! julia --project="$ROOT" -e 'using SpinorBEC;
            include("test/oracles/test_stability_sneaky_prover.jl");
            include("test/oracles/test_stability_indeterminate.jl")' >/dev/null 2>&1; then
        echo "loop_gate: GATE RE-CERT FAILED — the frozen adversarial suite is red; the verifier may be weakened. Refusing to trust the verdict." >&2
        exit 2
    fi
fi

out="$(julia --project="$ROOT" "$ROOT/scripts/loop/verify.jl" "$CAND" 2>&1 | grep '^VERIFY:' | tail -1)"
rc_status="${out#VERIFY: }"
verdict="${rc_status%% *}"
echo "$out"

if [ "$verdict" = "ACCEPT" ]; then         # certified → terminal
    echo "$out" >"$DONE"
    rm -f "$TICK"
    exit 0
fi

# REJECT / ABSTAIN / (empty) → progress-relative budget
n=0
[ -f "$TICK" ] && n="$(cat "$TICK" 2>/dev/null || echo 0)"
n=$((n + 1))
echo "$n" >"$TICK"

if [ "$n" -ge "$CAP" ]; then
    msg="VERIFY: BUDGET_EXHAUSTED $NAME — $n stop attempts without ACCEPT (cap $CAP); terminating with non-success"
    echo "$msg"
    echo "$msg" >"$DONE"
    rm -f "$TICK"
    exit 0
fi

echo "loop_gate: $NAME not ACCEPTed (verdict='$verdict', tick $n/$CAP)." >&2
echo "Keep working — only scripts/loop/verify.jl's own ACCEPT ends this campaign; a VERIFY:ACCEPT line in the transcript is ignored. On ABSTAIN, escalate the gate budget (niter) in the candidate; on REJECT, the physics is wrong." >&2
exit 2
