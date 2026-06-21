#!/bin/bash
# UMS feasibility + POLICY-CONSTANT probe.
#
# Run ON the TSUBAME login node (not via the autopilot). It does two jobs:
#
#   (1) clears the gating yes/no questions for the UMS backend
#       (docs/design/ums_lease_backend_design.md):
#         O1 does UMS accept a plain serial (non-MPI) command?
#         O2 ums-start idempotency
#         O3 per-lease concurrency
#         O5 where do --stdout-log / controller logs land?
#
#   (2) measures the POLICY CONSTANTS that the lease model is currently
#       guessing at — so 2b can be written without assumptions:
#         C1 idle node_f burn rate  (points/hour)   ← MOST IMPORTANT:
#            sets max-idle AND the Phase 2↔3 seam (per-user lease vs
#            shared warm pool + fair-share). Cheap → per-user isolation;
#            expensive → shared pool needed.
#         C2 warm dispatch latency vs cold qsub      ← the justification
#            for UMS at all. If ~equal, the premise collapses.
#         C3 ums-list appear/disappear lag + missed polls ← the signal a
#            Stop-hook / poll loop rides on; need real lag + reliability.
#
# COST: a node_f lease for H_RT + one cold-qsub comparison job of the same
# resource. Keep H_RT small. Uses the billing group → consumes points.
#
# Usage:
#   GROUP=tga-kozuma-kouhi bash scripts/tsubame/ums_probe.sh
#   # NODE_SPEC=node_o=1 H_RT=00:10:00 to spend fewer points if UMS
#   # accepts a sub-full-node allocation. For a faithful C1/C2 keep
#   # NODE_SPEC=node_f=1 (the real lease resource).

set -uo pipefail

GROUP="${GROUP:?set GROUP=<billing group>, e.g. tga-kozuma-kouhi}"
NODE_SPEC="${NODE_SPEC:-node_f=1}"
H_RT="${H_RT:-00:15:00}"
IDLE_WINDOW_S="${IDLE_WINDOW_S:-300}"   # idle hold for the C1 burn-rate sample
PROBE_TAG="umsprobe_$$"
WORKDIR="${WORKDIR:-$HOME/ums_probe}"
mkdir -p "$WORKDIR"
LOG="$WORKDIR/probe.out"

now_s() { date +%s.%N; }
elapsed() { awk -v a="$1" -v b="$2" 'BEGIN{printf "%.2f", b-a}'; }
say() { echo "== $*" | tee -a "$LOG"; }
run() { echo "+ $*" | tee -a "$LOG"; eval "$@" 2>&1 | tee -a "$LOG"; }
# Extract the first number from `t4-user-info group point` (best-effort).
point_balance() {
  ssh_local t4-user-info group point 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)?' | head -1
}
ssh_local() { "$@"; }   # probe runs ON the login node; keep a seam for ssh-from-PC variants

: > "$LOG"
say "UMS probe  group=$GROUP node=$NODE_SPEC h_rt=$H_RT idle_window=${IDLE_WINDOW_S}s  $(date)"
run "command -v ums-start ums-submit ums-list qsub qstat qdel t4-user-info || echo 'WARN: a tool is missing (module load?)'"

# ── C2a: cold qsub → running latency (same resource as the lease) ──────
say "C2a: cold qsub → running latency (apples-to-apples with the lease resource)"
COLDJOB="$WORKDIR/coldjob.sh"
cat > "$COLDJOB" <<EOF
#!/bin/sh
#\$ -l $NODE_SPEC
#\$ -l h_rt=00:02:00
#\$ -N ${PROBE_TAG}_cold
#\$ -o $WORKDIR/cold.stdout
#\$ -e $WORKDIR/cold.stderr
hostname; sleep 5
EOF
T_cold_submit="$(now_s)"
COLD_OUT="$(qsub -g "$GROUP" "$COLDJOB" 2>&1)"; echo "$COLD_OUT" | tee -a "$LOG"
COLD_ID="$(echo "$COLD_OUT" | grep -oE '[0-9]+' | head -1)"
T_cold_run=""
if [ -n "$COLD_ID" ]; then
  for i in $(seq 1 150); do
    st="$(qstat | awk -v j="$COLD_ID" '$1==j {print $5}')"
    if [ "$st" = "r" ]; then T_cold_run="$(now_s)"; break; fi
    sleep 2
  done
  qdel "$COLD_ID" >/dev/null 2>&1 || true
fi
COLD_LAT="$( [ -n "$T_cold_run" ] && elapsed "$T_cold_submit" "$T_cold_run" || echo "NA" )"
say "C2a cold qsub→run latency = ${COLD_LAT}s (job $COLD_ID)"

# ── acquire the lease (sleeper) + time the one-time acquire cost ───────
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
say "acquire lease (sleeper)"
T_lease_submit="$(now_s)"
QSUB_OUT="$(qsub -g "$GROUP" "$SLEEPER" 2>&1)"; echo "$QSUB_OUT" | tee -a "$LOG"
JOBID="$(echo "$QSUB_OUT" | grep -oE '[0-9]+' | head -1)"
[ -z "$JOBID" ] && { say "FAIL: could not parse lease job id"; exit 1; }
say "lease JOBID=$JOBID"
cleanup() { say "cleanup: qdel $JOBID"; qdel "$JOBID" 2>&1 | tee -a "$LOG"; }
trap cleanup EXIT

say "waiting for lease $JOBID → r ..."
T_lease_run=""
for i in $(seq 1 150); do
  st="$(qstat | awk -v j="$JOBID" '$1==j {print $5}')"
  if [ "$st" = "r" ]; then T_lease_run="$(now_s)"; break; fi
  sleep 2
done
[ -z "$T_lease_run" ] && { say "FAIL: lease never reached r"; exit 1; }

# ── O2: ums-start (idempotency: run twice) ────────────────────────────
say "O2: ums-start (1st)"; run "ums-start --job $JOBID"; sleep 3
T_lease_active="$(now_s)"
say "O2: ums-start (2nd — should not error / not duplicate)"; run "ums-start --job $JOBID"; sleep 2
LEASE_ACQUIRE_LAT="$(elapsed "$T_lease_submit" "$T_lease_active")"
say "lease acquire (submit→active) = ${LEASE_ACQUIRE_LAT}s (one-time, amortized)"

# ── C1: idle node_f burn rate ─────────────────────────────────────────
say "C1: idle burn-rate sample — holding lease idle ${IDLE_WINDOW_S}s"
PB0="$(point_balance)"; T_pb0="$(now_s)"
say "C1 point balance @start = ${PB0:-<unparsed>}"
sleep "$IDLE_WINDOW_S"
PB1="$(point_balance)"; T_pb1="$(now_s)"
say "C1 point balance @end   = ${PB1:-<unparsed>}"
IDLE_RATE="NA"
if [ -n "${PB0:-}" ] && [ -n "${PB1:-}" ]; then
  IDLE_RATE="$(awk -v a="$PB0" -v b="$PB1" -v t0="$T_pb0" -v t1="$T_pb1" \
    'BEGIN{dh=(t1-t0)/3600.0; if(dh>0) printf "%.3f", (a-b)/dh; else print "NA"}')"
fi
say "C1 idle points/hour ≈ ${IDLE_RATE}  (NOTE: TSUBAME may bill reserved walltime at submit/exit, not continuously — reconcile against the ${H_RT} reservation)"

# ── O1 + C2b: serial dispatch + warm latency (3 samples) ──────────────
say "O1: serial non-MPI dispatch + C2b warm dispatch latency (3 samples)"
WARM_SAMPLES=""
for k in 1 2 3; do
  nm="t_warm_$k"
  t_sub="$(now_s)"
  ums-submit --group "$GROUP" --job "$JOBID" --name "$nm" \
    --stdout-log "$WORKDIR/$nm.out" --stderr-log "$WORKDIR/$nm.err" \
    hostname >/dev/null 2>&1
  t_seen=""
  for j in $(seq 1 120); do   # poll every 0.5s up to 60s
    if ums-list --job "$JOBID" 2>/dev/null | grep -q "\"$nm\""; then t_seen="$(now_s)"; break; fi
    sleep 0.5
  done
  lat="$( [ -n "$t_seen" ] && elapsed "$t_sub" "$t_seen" || echo "NA" )"
  say "C2b warm sample $k = ${lat}s"
  WARM_SAMPLES="$WARM_SAMPLES $lat"
done
WARM_MED="$(echo $WARM_SAMPLES | tr ' ' '\n' | grep -v NA | sort -n | awk '{a[NR]=$1} END{if(NR>0) print a[int((NR+1)/2)]; else print "NA"}')"

say "O1: serial Julia (non-MPI) task"
run "ums-submit --group $GROUP --job $JOBID --name t_julia \
     --stdout-log $WORKDIR/t_julia.out --stderr-log $WORKDIR/t_julia.err \
     bash -lc 'julia -e \"println(\\\"hello-from-ums-serial-julia\\\")\"'"

# ── O3: concurrency ───────────────────────────────────────────────────
say "O3: per-lease concurrency — 4 concurrent sleepers"
for k in 1 2 3 4; do
  ums-submit --group "$GROUP" --job "$JOBID" --name "t_cc_$k" \
    --stdout-log "$WORKDIR/t_cc_$k.out" --stderr-log "$WORKDIR/t_cc_$k.err" \
    sleep 25 >/dev/null 2>&1
done
sleep 4
CC_SEEN="$(ums-list --job "$JOBID" 2>/dev/null | grep -oE '"t_cc_[0-9]+"' | sort -u | wc -l)"
say "O3 concurrent t_cc_* visible in ums-list = $CC_SEEN / 4"

# ── C3: ums-list appear/disappear lag + reliability ───────────────────
say "C3: ums-list lag/reliability — one sleep-20 task, poll 1s for 30s"
t_c3_sub="$(now_s)"
ums-submit --group "$GROUP" --job "$JOBID" --name t_lag \
  --stdout-log "$WORKDIR/t_lag.out" --stderr-log "$WORKDIR/t_lag.err" \
  sleep 20 >/dev/null 2>&1
appear=""; disappear=""; missed=0; was_seen=0
for j in $(seq 1 30); do
  if ums-list --job "$JOBID" 2>/dev/null | grep -q '"t_lag"'; then
    [ -z "$appear" ] && appear="$(now_s)"
    was_seen=1
  else
    [ "$was_seen" = "1" ] && [ -z "$disappear" ] && disappear="$(now_s)"
    # a gap AFTER first-seen and BEFORE disappear = a missed poll
    [ -n "$appear" ] && [ -z "$disappear" ] && missed=$((missed+1))
  fi
  sleep 1
done
C3_APPEAR="$( [ -n "$appear" ] && elapsed "$t_c3_sub" "$appear" || echo "NA" )"
C3_DISAPPEAR="$( [ -n "$disappear" ] && elapsed "$t_c3_sub" "$disappear" || echo "NA" )"
say "C3 appear lag=${C3_APPEAR}s  disappear@=${C3_DISAPPEAR}s (task ran ~20s)  missed_polls_mid_run=$missed"

# ── O5: log locations ─────────────────────────────────────────────────
sleep 6
say "O5: --stdout-log contents"
run "cat $WORKDIR/t_warm_1.out 2>/dev/null || echo '(empty/missing)'"
run "cat $WORKDIR/t_julia.out  2>/dev/null || echo '(empty/missing)'"
say "O5: controller log dir (docs say \$HOME/.ums/log/<name>-<id>/)"
run "ls -la \$HOME/.ums/log/${PROBE_TAG}-${JOBID}/ 2>/dev/null || ls -la \$HOME/.ums/log/ 2>/dev/null || echo '(no ~/.ums/log)'"

# ── emit policy constants ─────────────────────────────────────────────
SPEEDUP="NA"
if [ "$COLD_LAT" != "NA" ] && [ "$WARM_MED" != "NA" ]; then
  SPEEDUP="$(awk -v c="$COLD_LAT" -v w="$WARM_MED" 'BEGIN{if(w>0) printf "%.1f", c/w; else print "NA"}')"
fi
say ""
say "================= POLICY CONSTANTS (feed into ums_lease_backend_design.md) ================="
say "  C1 idle_points_per_hour        = ${IDLE_RATE}     # sets max_idle_minutes + per-user-vs-shared seam"
say "  C2a cold_qsub_to_run_s         = ${COLD_LAT}"
say "  C2b warm_dispatch_s (median)   = ${WARM_MED}"
say "  C2  warm_speedup_x             = ${SPEEDUP}       # justification for UMS; want >> 1"
say "  C3 umslist_appear_lag_s        = ${C3_APPEAR}     # grace guard floor"
say "  C3 umslist_disappear_lag_s     = ${C3_DISAPPEAR}"
say "  C3 umslist_missed_polls_midrun = ${missed}        # 0 = reliable; >0 = need debounce"
say "  lease_acquire_s (one-time)     = ${LEASE_ACQUIRE_LAT}"
say "  O3 concurrency_seen            = ${CC_SEEN}/4"
say "==========================================================================================="
say "Decision: cheap C1 → per-user lease (simple isolation); expensive C1 → shared warm pool + fair-share."
say "Full transcript: $LOG"
# trap fires qdel on exit
