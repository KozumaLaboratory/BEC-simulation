#!/bin/bash
# Exact on-demand point charge for a finished TSUBAME job — from the job id alone.
#
#   bash observability/job_cost.sh <jobid>
#   (run on the login node, or it will ssh tsubame for qacct)
#
# Everything the formula needs is already in the job record, so nothing is typed
# by hand and nothing defaults:
#
#   resource type, node count  <- qacct `hard_resources` (e.g. "cpu_4=1,h_rt=300")
#   reserved time h_rt         <- qacct `hard_resources`
#   actual time                <- qacct `ru_wallclock`
#   priority                   <- qacct `priority`
#   type / priority coefficient<- refs/tsubame4_points.toml (別表3 / 別表4)
#
# The previous version took the coefficient as an argument defaulting to 0.200,
# which meant costing a cpu_4 job required the operator to already know 0.015
# and to type it right — and a wrong coefficient produces a plausible number, so
# there was nothing to notice. It now REFUSES when a value cannot be read: an
# unknown resource type must not be spelled the same way as gpu_1.
#
# Formula and rounding are 別表2 / 第4条 of docs/refs/TSUBAME4_Terms_2024-02.pdf,
# transcribed in refs/tsubame4_points.toml:
#
#   points = nodes * type_coef * prio_coef
#            * (0.7 * max(actual_s, 300) + 0.1 * h_rt_s) / 3600
#
# and the result is TRUNCATED to 1/10000 pt — not rounded. `printf "%.4f"`
# rounds half away from zero, which is the wrong direction and was what this
# script did before.
set -uo pipefail

JID=${1:?usage: job_cost.sh <jobid>}
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOML="$ROOT/refs/tsubame4_points.toml"
[ -r "$TOML" ] || { echo "job_cost.sh: cannot read $TOML" >&2; exit 1; }

QACCT=$( qacct -j "$JID" 2>/dev/null || ssh tsubame "qacct -j $JID" 2>/dev/null )
[ -n "$QACCT" ] || { echo "job_cost.sh: no qacct record for $JID (still running?)" >&2; exit 1; }

HARD=$(  echo "$QACCT" | awk '/^hard_resources/{print $2; exit}')
ACTUAL=$(echo "$QACCT" | awk '/^ru_wallclock/ {print $2; exit}')
PRIO=$(  echo "$QACCT" | awk '/^priority/     {print $2; exit}')

[ -n "$HARD"   ] || { echo "job_cost.sh: $JID has no hard_resources line; the resource type cannot be read and must not be guessed." >&2; exit 2; }
[ -n "$ACTUAL" ] || { echo "job_cost.sh: $JID has no ru_wallclock." >&2; exit 2; }
[ -n "$PRIO"   ] || { echo "job_cost.sh: $JID has no priority field; 別表4's coefficient must not be assumed." >&2; exit 2; }

awk -v hard="$HARD" -v actual="$ACTUAL" -v prio="$PRIO" -v jid="$JID" -v toml="$TOML" '
BEGIN {
    # --- read 別表3 and 別表4 out of the transcription -----------------------
    section = ""
    while ((getline line < toml) > 0) {
        sub(/#.*$/, "", line)
        gsub(/^[ \t]+|[ \t]+$/, "", line)
        if (line ~ /^\[/) { section = line; continue }
        if (line !~ /=/)  continue
        key = line; val = line
        sub(/=.*$/, "", key); sub(/^[^=]*=/, "", val)
        gsub(/^[ \t]+|[ \t]+$|"/, "", key)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        if (section == "[resource_type]") type_coef[key] = val + 0
        else if (section == "[priority]")  prio_coef[key] = val + 0
        else if (section == "[rounding]" && key == "unit_points") { unit = val + 0; unit_str = val }
    }
    close(toml)
    if (unit <= 0) { print "job_cost.sh: [rounding].unit_points missing from " toml > "/dev/stderr"; exit 2 }
    # Decimal places the unit implies, taken from the TEXT of the unit rather
    # than from log10 of the float, so the truncation below is decimal and exact.
    places = (index(unit_str, ".") > 0) ? length(unit_str) - index(unit_str, ".") : 0

    # --- which resource type did this job hold? -----------------------------
    n = split(hard, parts, ",")
    rtype = ""; nodes = 0; hrt = -1
    for (i = 1; i <= n; i++) {
        k = parts[i]; v = parts[i]
        sub(/=.*$/, "", k); sub(/^[^=]*=/, "", v)
        if (k == "h_rt") { hrt = v + 0; continue }
        if (k in type_coef) { rtype = k; nodes = v + 0 }
    }
    if (rtype == "") {
        print "job_cost.sh: none of " jid "\047s hard_resources (" hard ") names a type in 別表3." > "/dev/stderr"
        print "  Refusing to price it — a guessed coefficient produces a plausible wrong number." > "/dev/stderr"
        exit 2
    }
    if (hrt < 0) {
        print "job_cost.sh: " jid " requested no h_rt; the 0.1*reserved term is unknown." > "/dev/stderr"
        exit 2
    }
    if (!(prio in prio_coef)) {
        print "job_cost.sh: priority " prio " is not in 別表4 (" toml ")." > "/dev/stderr"
        exit 2
    }

    # --- 別表2, on-demand ----------------------------------------------------
    af  = (actual + 0 > 300) ? actual + 0 : 300           # max(actual, 300)
    raw = nodes * type_coef[rtype] * prio_coef[prio] * (0.7 * af + 0.1 * hrt) / 3600
    # 第4条: truncate below one unit. Done on the DECIMAL STRING, because
    # `int(raw / unit)` is a trap: 0.001 / 0.0001 is 9.999999... in binary, so
    # the first version of this line turned an exact 0.0010 pt into 0.0009.
    # Cutting the digits after `places` cannot do that, and needs no epsilon.
    s = sprintf("%.*f", places + 6, raw)
    pts = substr(s, 1, index(s, ".") + places) + 0

    printf "job %s: %s x%d  prio=%s(%.2f)  actual=%ss (floored %.0fs)  h_rt=%ss  coef=%.3f\n",
        jid, rtype, nodes, prio, prio_coef[prio], actual, af, hrt, type_coef[rtype]
    printf "  raw       = %.8f pt\n", raw
    printf "  truncated = %.4f pt   (1/%d pt units, 第4条)\n", pts, int(1 / unit)
    printf "POINTS=%.4f\n", pts
}'
