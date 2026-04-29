#!/usr/bin/env bash
# Perf Ralph loop. One pass: pick next kernel from queue, hand to
# Claude Code with the guardrails prompt, run benches + tests, decide
# commit/revert.
#
# Usage:
#   bash scripts/ralph_perf.sh                # one iteration
#   bash scripts/ralph_perf.sh --loop         # run until queue empty
#   bash scripts/ralph_perf.sh --dry-run      # don't invoke claude, just
#                                              # show what would happen
#
# Requires: claude CLI on PATH, bench/baseline.json present.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

QUEUE="bench/perf_targets.txt"
GUARDRAILS="bench/RALPH_PERF_GUARDRAILS.md"
BASELINE="bench/baseline.json"
LATEST="bench/results.json"
JULIA="${JULIA:-/home/suzume/.julia/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia}"
LD="LD_LIBRARY_PATH=/usr/lib/wsl/lib"

die() { echo "ralph_perf: $*" >&2; exit 1; }

# Pre-flight
[ -f "$QUEUE" ]       || die "missing queue $QUEUE"
[ -f "$GUARDRAILS" ]  || die "missing guardrails $GUARDRAILS"
[ -f "$BASELINE" ]    || die "missing baseline $BASELINE — run bench/bench_regression.jl and copy results.json to baseline.json first"
command -v claude >/dev/null 2>&1 || die "claude CLI not on PATH"

LOOP=false
DRY=false
for arg in "$@"; do
  case "$arg" in
    --loop)    LOOP=true ;;
    --dry-run) DRY=true ;;
    *)         die "unknown flag: $arg" ;;
  esac
done

# Pick first unmarked target
next_target() {
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /# done|# skipped/ { next }
    { print; exit }
  ' "$QUEUE"
}

mark_target() {
  local target="$1"; local marker="$2"
  local stamp="$(date -u +%Y-%m-%d)"
  # Comment out the first matching uncommented line so future iterations
  # skip it. Append-only would leave the original target line active.
  awk -v target="$target" -v marker="$marker" -v stamp="$stamp" '
    !done && $1 == target {
      print "# " marker " " stamp ": " $0
      done = 1
      next
    }
    { print }
  ' "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
}

iterate() {
  local target_line target_kernel target_bench target_hint
  target_line="$(next_target || true)"
  if [ -z "$target_line" ]; then
    echo "[ralph_perf] queue empty — nothing to do."
    return 1
  fi

  # Parse: first whitespace-delimited token is the kernel, second is the bench key, rest is hint.
  target_kernel="$(echo "$target_line" | awk '{print $1}')"
  target_bench="$(echo "$target_line"  | awk '{print $2}')"
  target_hint="$(echo "$target_line"   | awk '{for (i=3; i<=NF; ++i) printf "%s ", $i; print ""}')"

  echo "[ralph_perf] target: $target_kernel  bench=$target_bench"
  echo "             hint: $target_hint"

  if $DRY; then
    echo "[ralph_perf] --dry-run, skipping claude invocation"
    return 0
  fi

  # Build the per-iteration prompt. Claude reads the full guardrails
  # doc and the specific target. It must not access network. It will
  # produce edits in-tree, then we run benches + tests here.
  local prompt
  prompt=$(cat <<EOF
You are running one iteration of the perf-Ralph loop. Read
$GUARDRAILS in full and follow it strictly.

Target this iteration:
  kernel:    $target_kernel
  bench key: $target_bench
  hint:      $target_hint

Procedure:
1. Locate the kernel via grep. Confirm it matches the bench harness key.
2. Profile / inspect it (\`@code_warntype\`, \`@allocated\`, source read).
3. Apply ONE of the safe patterns from the guardrails. Do not combine
   patterns. Do not exceed 30 lines of edits across all files.
4. Run a smoke test for the kernel (see guardrails §"Constraint:
   numerical correctness").
5. Stop. Do not commit. The wrapper script will run the bench
   comparison and decide commit vs revert. Just report the kernel
   name, the pattern you applied, the files you edited, and the
   smoke-test outcome in your final message.

If you must bail out (kernel too fragile, no improvement obvious,
unfamiliar territory), report "BAIL: <one-sentence reason>" as your
final line and do not edit any files.
EOF
)

  # Snapshot current tree so we can revert if needed.
  local snapshot
  snapshot="$(git stash create "ralph_perf snapshot before $target_kernel" 2>/dev/null || echo "")"
  if [ -n "$snapshot" ]; then
    echo "[ralph_perf] snapshot: $snapshot"
  fi

  # Run claude headlessly. -p (print) runs the prompt non-interactively.
  # --dangerously-skip-permissions bypasses approval since the loop runs
  # unattended; we revert any tree changes via git below if anything
  # goes wrong.
  local claude_log="logs/ralph_perf_$(date +%s)_${target_kernel//[^a-zA-Z0-9]/_}.log"
  mkdir -p logs
  echo "[ralph_perf] invoking claude → $claude_log"
  if ! claude -p --dangerously-skip-permissions "$prompt" > "$claude_log" 2>&1; then
    echo "[ralph_perf] claude exited non-zero, reverting"
    git checkout -- . && mark_target "$target_kernel" "skipped(claude-error)"
    return 0
  fi

  # Did claude self-bail?
  if grep -q "^BAIL:" "$claude_log"; then
    local reason
    reason="$(grep "^BAIL:" "$claude_log" | head -1 | sed 's/^BAIL: //')"
    echo "[ralph_perf] BAIL: $reason"
    git checkout -- . && mark_target "$target_kernel" "skipped($reason)"
    return 0
  fi

  # Snapshot exactly which paths claude touched, before the bench
  # harness rewrites bench/results.json. We will commit only these
  # paths plus the wrapper-controlled bookkeeping files (perf_targets,
  # baseline) — never `git add -A`, which previously swept untracked
  # archive/, runs/, and figs/ into auto-perf commits.
  local claude_changes
  claude_changes="$(git status --porcelain | awk '{print $2}')"
  if [ -z "$claude_changes" ]; then
    echo "[ralph_perf] no edits applied; treating as bail"
    mark_target "$target_kernel" "skipped(no-edit)"
    return 0
  fi

  # Run bench harness.
  echo "[ralph_perf] running bench/bench_regression.jl"
  if ! eval "$LD $JULIA --project=. bench/bench_regression.jl" > "$claude_log.bench" 2>&1; then
    echo "[ralph_perf] bench failed, reverting"
    git checkout -- . && mark_target "$target_kernel" "skipped(bench-fail)"
    return 0
  fi

  # Compare bench/results.json (latest) against bench/baseline.json.
  # Accept iff target_bench improved ≥5% AND no other bench regressed >5%.
  # Wrapped in a function — Julia's soft scope eats `target_improved`
  # assignments inside top-level for-loops, returning false always.
  local verdict
  verdict="$($JULIA --project=. -e "
    using JSON
    function evaluate(base_path, new_path, target)
        base = JSON.parsefile(base_path)
        new  = JSON.parsefile(new_path)
        target_improved = false
        any_regressed = false
        regressions = String[]
        for (k, v) in new
            haskey(base, k) || continue
            old_t = base[k][\"time_ns\"]
            new_t = v[\"time_ns\"]
            ratio = new_t / old_t
            if k == target && ratio < 0.95
                target_improved = true
            end
            if ratio > 1.05
                any_regressed = true
                push!(regressions, string(k, \" +\", round((ratio-1)*100; digits=1), \"%\"))
            end
        end
        if target_improved && !any_regressed
            return \"ACCEPT\"
        elseif !target_improved
            return \"REJECT no-target-improve\"
        else
            return \"REJECT regressions: \" * join(regressions, \", \")
        end
    end
    println(evaluate(\"$BASELINE\", \"$LATEST\", \"$target_bench\"))
  ")"

  echo "[ralph_perf] $verdict"
  case "$verdict" in
    ACCEPT*)
      # Stage exactly the files claude edited + the wrapper bookkeeping
      # (perf_targets gets the # done line, baseline.json ratchets fwd).
      # Skip bench/results.json — gitignored, regenerated each iter.
      mark_target "$target_kernel" "done"
      cp "$LATEST" "$BASELINE"
      for f in $claude_changes; do
        [ "$f" = "bench/results.json" ] && continue
        git add -- "$f"
      done
      git add -- bench/perf_targets.txt bench/baseline.json
      git commit -m "perf($target_kernel): auto-perf-ralph

$target_hint

Bench: $target_bench (auto-accept by ralph_perf.sh)

Assisted-by: Claude (model: claude-opus-4-7) [perf-ralph]"
      ;;
    REJECT*)
      # Revert tracked changes (claude edits). Untracked new files
      # claude may have created are left in place for human review;
      # they are NOT swept into the next iteration's commit because
      # ACCEPT only stages files in $claude_changes captured before
      # the bench harness ran.
      for f in $claude_changes; do
        git checkout -- "$f" 2>/dev/null || rm -f "$f"
      done
      mark_target "$target_kernel" "skipped(${verdict#REJECT })"
      ;;
  esac
}

if $LOOP; then
  while iterate; do
    sleep 1
  done
else
  iterate || true
fi
