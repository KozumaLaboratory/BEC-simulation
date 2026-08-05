#!/bin/bash
# Interleaved, SHA-pinned A/B driver. One JSON line per measurement.
#
#   bench/ab_driver.sh <worktree> <sha_a> <sha_b> <rounds> <out.jsonl> <body.jl>
#
# `body.jl` runs under `julia --project=.` inside the checked-out worktree and
# prints one `{"metric":"...","value":...}` object per line; everything else it
# prints stays in the raw log beside `out.jsonl`.
#
# Four invariants. Each was violated by a hand-rolled script during the
# 2026-08-02 L-BFGS work, and each cost a wrong or unattributable answer:
#
#   1. ATTRIBUTION. Refuse a dirty tree; stamp every row with the SHA. A job
#      that ran another session's uncommitted work while printing a clean
#      `git log -1` produced two withdrawn tables. A failed checkout kills the
#      run rather than degrading it.
#   2. PINNED REFS. Full SHAs, never branch names. Re-resolving `origin/main`
#      each round compared two DIFFERENT mains for an hour unnoticed.
#   3. INTERLEAVE. Alternate arms every round. A-then-B cannot separate the
#      change from a node that got busier, and once reported 15 % that way.
#   4. RAW OUTPUT. No `grep | tail` at generation; rows are harvested from the
#      raw log afterwards, so the rows and the log cannot disagree. The
#      diagnosis is in the part that gets cut — that happened four times in one
#      day.
#
# The decision rule is NOT here. `bench/ab_report.jl` reads the rows and
# refuses to state a delta smaller than the within-arm spread.
set -uo pipefail

[ $# -eq 6 ] || { sed -n '2,6p' "$0"; exit 2; }
W=$1 SHA_A=$2 SHA_B=$3 ROUNDS=$4 OUT=$5 BODY=$6
RAW="${OUT%.jsonl}.raw.log"

cd "$W" || { echo "no worktree: $W" >&2; exit 1; }
: > "$RAW"

for sha in "$SHA_A" "$SHA_B"; do
    [ ${#sha} -ge 40 ] || { echo "pass a full SHA, not '$sha'" >&2; exit 1; }
    git rev-parse --verify --quiet "$sha^{commit}" > /dev/null \
        || { echo "not a commit: $sha" >&2; exit 1; }
done

for round in $(seq 1 "$ROUNDS"); do
    for sha in "$SHA_A" "$SHA_B"; do
        git reset -q --hard && git clean -qfd && git checkout -q --detach "$sha" \
            || { echo "CHECKOUT FAILED at $sha" >&2; exit 1; }
        dirty=$(git status --porcelain -- src test | wc -l)
        if [ "$dirty" -ne 0 ]; then
            echo "REFUSING: src/test dirty in $W after checkout — not attributable" >&2
            git status --porcelain -- src test >&2
            exit 1
        fi
        echo "##### round=$round sha=$sha $(git log --oneline -1 | cut -c1-60)" | tee -a "$RAW"
        if ! julia --project=. "$BODY" >> "$RAW" 2>&1; then
            echo "BODY FAILED round=$round sha=$sha — see $RAW" >&2
            exit 1
        fi
    done
done

awk '
  /^##### / { for (i = 1; i <= NF; i++) {
                 if ($i ~ /^sha=/)   sha = substr($i, 5)
                 if ($i ~ /^round=/) rnd = substr($i, 7) }
              next }
  /^\{"metric"/ { sub(/}[ \t]*$/, ",\"sha\":\"" sha "\",\"round\":" rnd "}"); print }
' "$RAW" > "$OUT"

echo "wrote $(wc -l < "$OUT") rows to $OUT (raw: $RAW)"
