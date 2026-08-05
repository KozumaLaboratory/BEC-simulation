#!/usr/bin/env bash
#
# Watch one job until it finishes, then say what happened. Exists because the two
# halves of "I'll report when it's done" both fail on their own:
#
#   1. An agent has no clock. A promise to report later is empty unless a process
#      is left running that EXITS when the thing finishes -- that exit is the
#      notification. Polling inside one turn does not survive the turn.
#   2. A classifier that is partial reports a verdict at the moment it has no
#      information. Five incidents in this project: a probe that folded a missing
#      marker into FAIL and so credited a dead worker with a catch; a CI watcher
#      that read the gap between two runs as GREEN; a job watcher that read
#      `qstat`'s 10-character name truncation as completion after one minute of a
#      one-hour job; and the fix for THAT, `qstat -j`, which exits 0 for IDs that
#      do not exist.
#
# So: four verdicts, absence is its own verdict, and `--canary` proves the
# classifier can reach RED and UNKNOWN before anyone trusts a GREEN from it.
#
#   scripts/watch_until_done.sh gh-run       <run-id>              # GitHub Actions
#   scripts/watch_until_done.sh tsubame-job  <job-id>              # TSUBAME (UGE), over ssh
#   scripts/watch_until_done.sh local-pid    <pid> --rc-file PATH  # a local background job
#   scripts/watch_until_done.sh --canary                           # self-test
#
# Options: --timeout SEC (default 1800), --interval SEC (default 30).
#
#   exit 0  GREEN    every unit finished and succeeded (names and count printed)
#   exit 1  RED      at least one unit failed (each named)
#   exit 2  TIMEOUT  deadline hit with units unfinished -- NOT green, result unknown
#   exit 3  UNKNOWN  the subject could not be observed, or finished without recording
#
# Run it backgrounded. Foregrounding it defeats point 1.
#
# `local-pid` needs `--rc-file` because **a PID disappearing says nothing about
# success**. Launch the job so it records its own status:
#
#   setsid nohup bash -c 'julia --project=. x.jl > logs/x.log 2>&1; echo $? > logs/x.rc' \
#       < /dev/null & disown
#   echo $!   # <- the pid
#
# Without --rc-file only TIMEOUT and UNKNOWN are reachable, and the script says so
# rather than calling a vanished process a success.

set -uo pipefail

SUBJECT=${1:-}
ID=${2:-}
TIMEOUT=1800
INTERVAL=30
RC_FILE=""
if [ "$SUBJECT" = "--canary" ] || [ -z "$SUBJECT" ]; then shift 2>/dev/null || true
else shift 2 2>/dev/null || true; fi
while [ $# -gt 0 ]; do
    case "$1" in
        --timeout)  TIMEOUT=$2; shift 2 ;;
        --interval) INTERVAL=$2; shift 2 ;;
        --rc-file)  RC_FILE=$2; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 64 ;;
    esac
done

# Each poller prints one line per unit: "status|conclusion|name". `status` is
# `completed` or anything else; `conclusion` is `success`, `skipped`, or a failure
# word. Printing NOTHING means "could not observe", which the caller turns into
# UNKNOWN -- never into "nothing pending, therefore done".

# --- GitHub Actions ---------------------------------------------------------
poll_gh_run() {
    gh run view "$1" --json jobs \
        -q '.jobs[] | "\(.status)|\(.conclusion // "")|\(.name)"' 2>/dev/null
}

# --- TSUBAME 4 (UGE, not Slurm) ---------------------------------------------
# `qstat` answers "is it queued or running", and NOTHING else -- its absence is
# not success. Completion is a `qacct` record and the verdict is that record's
# exit_status/failed. qacct lags qstat, so the window between them is explicitly
# pending. One line per array task, so a 4-task array that loses one reports RED.
poll_tsubame_job() {
    ssh tsubame "
        if qstat -u \$USER 2>/dev/null | awk '{print \$1}' | grep -qx '$1'; then
            echo 'running||scheduler still lists it'; exit 0
        fi
        rec=\$(qacct -j '$1' 2>/dev/null)
        [ -n \"\$rec\" ] || { echo 'running||left the queue, no qacct record yet'; exit 0; }
        # Field order inside a record is jobnumber, taskid, failed, exit_status --
        # so emit on exit_status (the LAST of the four) and reset on jobnumber.
        # Emitting on the failed line read exit_status from the PREVIOUS task, and for
        # the first task read it as unset, which awk compares equal to 0: a
        # nonzero exit would have been reported as success.
        printf '%s\n' \"\$rec\" | awk '
            /^jobnumber/   { t=\"-\"; f=\"\" }
            /^taskid/      { t=\$2 }
            /^failed/      { f=\$2 }
            /^exit_status/ {
                if (f == \"\") { v=\"completed|no-record|\" }
                else if (f == \"0\" && \$2 == \"0\") { v=\"completed|success|\" }
                else { v=\"completed|failure|\" }
                print v \"task \" (t==\"undefined\" ? \"-\" : t) \" exit=\" \$2 \" failed=\" f }'
    " 2>/dev/null
}

# --- local background process ------------------------------------------------
# Alive -> pending. Gone WITH an rc file -> that rc is the verdict. Gone WITHOUT
# one -> UNKNOWN, because that is the shape of a job that was OOM-killed, and
# calling it success is the exact failure this script exists to prevent.
poll_local_pid() {
    if kill -0 "$1" 2>/dev/null; then
        echo "running||pid $1 alive"
        return
    fi
    if [ -z "$RC_FILE" ]; then
        echo "completed|no-rc-file|pid $1 is gone and no --rc-file was given: nothing recorded its status"
        return
    fi
    if [ ! -f "$RC_FILE" ]; then
        echo "completed|no-record|pid $1 is gone and $RC_FILE was never written (killed before it could record?)"
        return
    fi
    local rc
    rc=$(tr -dc '0-9' < "$RC_FILE")
    [ -n "$rc" ] || { echo "completed|empty-record|$RC_FILE holds no exit code"; return; }
    if [ "$rc" -eq 0 ]; then echo "completed|success|pid $1 exit=0"
    else echo "completed|failure|pid $1 exit=$rc"; fi
}

poll() {
    case "$SUBJECT" in
        gh-run)       poll_gh_run "$ID" ;;
        tsubame-job)  poll_tsubame_job "$ID" ;;
        local-pid)    poll_local_pid "$ID" ;;
        *) echo "usage: $0 {gh-run|tsubame-job|local-pid} <id> [opts] | --canary" >&2; exit 64 ;;
    esac
}

watch() {
    local start=$SECONDS
    while :; do
        local j
        j=$(poll)
        if [ -z "$j" ]; then
            echo "VERDICT=UNKNOWN  $SUBJECT $ID returned nothing -- absence is not health"
            return 3
        fi
        local pending
        pending=$(printf '%s\n' "$j" | grep -vc '^completed|')
        if [ "$pending" -eq 0 ]; then
            # A "completed" unit with no usable conclusion is UNKNOWN, not RED:
            # the job may well have succeeded and merely failed to say so.
            local unrec
            unrec=$(printf '%s\n' "$j" | awk -F'|' '$2 ~ /^(no-rc-file|no-record|empty-record)$/ {print "    "$3}')
            if [ -n "$unrec" ]; then
                echo "VERDICT=UNKNOWN  $SUBJECT $ID finished without recording its status"
                printf '%s\n' "$unrec"
                return 3
            fi
            local bad
            bad=$(printf '%s\n' "$j" | awk -F'|' '$2!="success" && $2!="skipped" {print "    "$2"  "$3}')
            if [ -n "$bad" ]; then
                echo "VERDICT=RED  $SUBJECT $ID"; printf '%s\n' "$bad"; return 1
            fi
            echo "VERDICT=GREEN  $SUBJECT $ID -- $(printf '%s\n' "$j" | wc -l) unit(s), all success/skipped"
            printf '%s\n' "$j" | awk -F'|' '{print "    "$2"  "$3}'
            return 0
        fi
        if [ $((SECONDS - start)) -ge "$TIMEOUT" ]; then
            echo "VERDICT=TIMEOUT  $SUBJECT $ID -- ${TIMEOUT}s elapsed, $pending unit(s) unfinished; result UNKNOWN, not green"
            printf '%s\n' "$j" | grep -v '^completed|' | awk -F'|' '{print "    "$1"  "$3}'
            return 2
        fi
        sleep "$INTERVAL"
    done
}

# --- canary -----------------------------------------------------------------
# A monitor that has only ever returned GREEN has not been tested. Each leg feeds
# it an input whose verdict is known independently, and asserts it gets there.
canary() {
    local rc fails=0 tmp
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' RETURN

    _leg() {  # _leg <label> <want-exit> <subject> <id> [rc-file]
        local label=$1 want=$2
        SUBJECT=$3 ID=$4 RC_FILE=${5:-} TIMEOUT=${TIMEOUT_OVERRIDE:-1800} INTERVAL=1 watch
        rc=$?
        if [ "$rc" -eq "$want" ]; then echo "  ok (exit $rc)  $label"
        else echo "  FAIL: exit $rc, wanted $want  -- $label"; fails=1; fi
    }

    echo "[gh-run] RED from a run that really failed"
    local failed
    failed=$(gh run list --limit 60 --json databaseId,conclusion \
        -q '[.[]|select(.conclusion=="failure")][0].databaseId' 2>/dev/null)
    if [ -n "$failed" ] && [ "$failed" != "null" ]; then _leg "failed CI run" 1 gh-run "$failed"
    else echo "  SKIP: no failed run in the last 60 -- this leg is UNTESTED"; fails=1; fi

    echo "[gh-run] UNKNOWN from an id that does not exist"
    _leg "nonexistent run id" 3 gh-run 999999999999

    # TIMEOUT against a live LOCAL process, not a CI run: a queued run whose jobs
    # have not materialised yet answers with an empty list, so that leg raced
    # between TIMEOUT and UNKNOWN. A sleeping pid is pending by construction.
    echo "[local-pid] TIMEOUT without waiting for one"
    ( sleep 30 ) & local p_slow=$!
    TIMEOUT_OVERRIDE=0 _leg "live pid, 0 s budget" 2 local-pid "$p_slow"
    kill "$p_slow" 2>/dev/null; wait "$p_slow" 2>/dev/null

    echo "[local-pid] GREEN from a process that exited 0 and recorded it"
    ( sleep 1; echo 0 > "$tmp/ok.rc" ) & local p_ok=$!
    _leg "exit 0 + rc file" 0 local-pid "$p_ok" "$tmp/ok.rc"

    echo "[local-pid] RED from a process that exited nonzero"
    ( sleep 1; echo 3 > "$tmp/bad.rc" ) & local p_bad=$!
    _leg "exit 3 + rc file" 1 local-pid "$p_bad" "$tmp/bad.rc"

    echo "[local-pid] UNKNOWN from a process killed before it could record"
    ( sleep 30 ) & local p_kill=$!
    kill -9 "$p_kill" 2>/dev/null; wait "$p_kill" 2>/dev/null
    _leg "killed, rc file never written" 3 local-pid "$p_kill" "$tmp/never.rc"

    # TSUBAME: no fixtures. Discover recent job ids from the scheduler's own
    # stdout files, derive each verdict INDEPENDENTLY from qacct, and assert the
    # script agrees. Requires at least one GREEN and one RED in the sample --
    # a sample of all-successes would leave RED unproven, which is the state
    # every one of the five incidents shipped in.
    echo "[tsubame-job] verdicts cross-checked against an independent qacct read"
    local ids
    ids=$(ssh tsubame \
        "ls -t /gs/fs/tga-kozuma-kouhi/\$USER/*/*.o[0-9]*.[0-9]* ~/*/*.o[0-9]*.[0-9]* 2>/dev/null \
         | sed -E 's/.*\\.o([0-9]+)\\..*/\\1/' | awk '!seen[\$0]++' | head -12" 2>/dev/null)
    if [ -z "$ids" ]; then
        echo "  SKIP: no scheduler output files found -- this subject is UNTESTED"; fails=1
    else
        local saw_g=0 saw_r=0 id want
        for id in $ids; do
            want=$(ssh tsubame "qacct -j $id 2>/dev/null | awk '
                /^failed/ {f=\$2} /^exit_status/ {if (f!=\"0\" || \$2!=\"0\") bad=1}
                END {if (NR==0) print \"none\"; else print (bad ? \"RED\" : \"GREEN\")}'" 2>/dev/null)
            [ "$want" = "none" ] && continue
            SUBJECT=tsubame-job ID=$id RC_FILE="" TIMEOUT=5 INTERVAL=2 watch >/dev/null; rc=$?
            local got; case $rc in 0) got=GREEN ;; 1) got=RED ;; *) got="exit$rc" ;; esac
            if [ "$got" = "$want" ]; then
                echo "  ok   job $id -> $got"
                [ "$want" = GREEN ] && saw_g=1 || saw_r=1
            else
                echo "  FAIL job $id -> $got, qacct says $want"; fails=1
            fi
        done
        [ "$saw_g" -eq 1 ] || { echo "  no GREEN in the sample -- that verdict is UNPROVEN"; fails=1; }
        [ "$saw_r" -eq 1 ] || { echo "  no RED in the sample -- that verdict is UNPROVEN"; fails=1; }
    fi

    echo
    [ "$fails" -eq 0 ] && echo "canary: every verdict is reachable on every subject" \
                       || echo "canary: at least one leg is unproven -- do not trust a GREEN"
    return "$fails"
}

if [ "$SUBJECT" = "--canary" ]; then canary; exit $?; fi
[ -n "$ID" ] || { echo "usage: $0 {gh-run|tsubame-job|local-pid} <id> [opts] | --canary" >&2; exit 64; }
watch
