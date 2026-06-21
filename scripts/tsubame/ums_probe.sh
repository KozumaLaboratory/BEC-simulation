#!/bin/bash
# UMS feasibility probe — answers the open questions that gate the UMS
# low-latency backend (docs/design/ums_lease_backend_design.md).
#
# Run this ON the TSUBAME login node (not via the autopilot). It acquires
# a short node_f lease, starts UMS, submits a few PLAIN SERIAL (non-MPI)
# commands, lists them, checks where logs land, exercises ums-start
# idempotency, then tears the lease down. Everything is captured so the
# output can be pasted back for the design decision.
#
# COST: a node_f lease for the h_rt below. Keep h_rt small. Uses the
# billing group, so it consumes points — set GROUP and keep it short.
#
# Usage:
#   GROUP=tga-kozuma-kouhi bash scripts/tsubame/ums_probe.sh
#   # optional: NODE_SPEC=node_o=1 H_RT=00:05:00 to spend fewer points if
#   # UMS accepts a sub-full-node allocation (O-resource question).

set -uo pipefail

GROUP="${GROUP:?set GROUP=<billing group>, e.g. tga-kozuma-kouhi}"
NODE_SPEC="${NODE_SPEC:-node_f=1}"
H_RT="${H_RT:-00:10:00}"
PROBE_TAG="umsprobe_$$"
WORKDIR="${WORKDIR:-$HOME/ums_probe}"
mkdir -p "$WORKDIR"
LOG="$WORKDIR/probe.out"

say() { echo "== $*" | tee -a "$LOG"; }
run() { echo "+ $*" | tee -a "$LOG"; eval "$@" 2>&1 | tee -a "$LOG"; }

: > "$LOG"
say "UMS probe start  group=$GROUP node=$NODE_SPEC h_rt=$H_RT  $(date)"
say "uname / which ums-*"
run "command -v ums-start ums-submit ums-list || echo 'WARN: ums-* not on PATH (module load?)'"

# --- 1. acquire the lease (sleeper job) -------------------------------
SLEEPER="$WORKDIR/sleeper.sh"
cat > "$SLEEPER" <<EOF
#!/bin/sh
#\$ -l $NODE_SPEC
#\$ -l h_rt=$H_RT
#\$ -N ${PROBE_TAG}
#\$ -o $WORKDIR/sleeper.stdout
#\$ -e $WORKDIR/sleeper.stderr
sleep infinity
EOF
say "submit sleeper"
QSUB_OUT="$(qsub -g "$GROUP" "$SLEEPER" 2>&1)"; echo "$QSUB_OUT" | tee -a "$LOG"
JOBID="$(echo "$QSUB_OUT" | grep -oE '[0-9]+' | head -1)"
[ -z "$JOBID" ] && { say "FAIL: could not parse job id from qsub"; exit 1; }
say "lease JOBID=$JOBID"

cleanup() { say "cleanup: qdel $JOBID"; qdel "$JOBID" 2>&1 | tee -a "$LOG"; }
trap cleanup EXIT

# --- 2. wait for the parent job to reach running state (r) ------------
say "waiting for job $JOBID to reach 'r' ..."
for i in $(seq 1 120); do
  STATE="$(qstat | awk -v j="$JOBID" '$1==j {print $5}')"
  [ "$STATE" = "r" ] && break
  sleep 5
done
say "qstat state = ${STATE:-<gone>}"
[ "${STATE:-}" != "r" ] && { say "FAIL: job never reached r within 10 min"; exit 1; }

# --- 3. start UMS (and test ums-start idempotency, O2) ----------------
say "ums-start (1st)"
run "ums-start --job $JOBID"
sleep 3
say "ums-start (2nd — idempotency check O2: should not error / not duplicate)"
run "ums-start --job $JOBID"
sleep 3

# --- 4. O1: submit PLAIN SERIAL non-MPI commands ---------------------
say "O1: ums-submit a plain serial shell command (hostname)"
run "ums-submit --group $GROUP --job $JOBID --name t_hostname \
     --stdout-log $WORKDIR/t_hostname.out --stderr-log $WORKDIR/t_hostname.err \
     hostname"

say "O1: ums-submit a plain serial Julia command (no MPI)"
run "ums-submit --group $GROUP --job $JOBID --name t_julia \
     --stdout-log $WORKDIR/t_julia.out --stderr-log $WORKDIR/t_julia.err \
     bash -lc 'julia -e \"println(\\\"hello-from-ums-serial-julia\\\")\"'"

say "O3: submit a few concurrent sleepers to probe per-lease concurrency"
for k in 1 2 3 4; do
  run "ums-submit --group $GROUP --job $JOBID --name t_sleep_$k \
       --stdout-log $WORKDIR/t_sleep_$k.out --stderr-log $WORKDIR/t_sleep_$k.err \
       sleep 30"
done

# --- 5. list (snapshot format the backend will parse) ----------------
sleep 5
say "ums-list (JSON {name: host} of RUNNING tasks only)"
run "ums-list --job $JOBID"

# --- 6. where did logs land? (O5) ------------------------------------
sleep 8
say "O5: --stdout-log target contents (t_hostname.out, t_julia.out)"
run "cat $WORKDIR/t_hostname.out 2>/dev/null || echo '(empty/missing)'"
run "cat $WORKDIR/t_julia.out    2>/dev/null || echo '(empty/missing)'"
say "O5: controller-side log dir per the docs (\$HOME/.ums/log/<name>-<id>/)"
run "ls -la \$HOME/.ums/log/${PROBE_TAG}-${JOBID}/ 2>/dev/null || ls -la \$HOME/.ums/log/ 2>/dev/null || echo '(no ~/.ums/log)'"

say "wait for sleepers to drain, re-list (should shrink as tasks finish)"
sleep 30
run "ums-list --job $JOBID"

say "PROBE DONE — full transcript at $LOG"
say "Decision inputs:"
say "  O1 serial accepted?  -> did t_hostname.out / t_julia.out contain output, or did ums-submit reject non-MPI?"
say "  O2 ums-start 2x       -> did the 2nd call error?"
say "  O3 concurrency        -> how many of t_sleep_* appeared in ums-list at once?"
say "  O5 logs               -> --stdout-log honored, and/or ~/.ums/log used?"
# trap fires qdel on exit
