#!/bin/bash
# Exact on-demand point charge for a finished TSUBAME job (別表2 formula) —
# authoritative, deterministic, independent of the noisy balance-delta.
#
#   bash observability/job_cost.sh <jobid> [type_coef] [prio_coef]
#   (run on the login node, or it will ssh tsubame for qacct)
#
#   points = nodes × typeCoef × prioCoef × (0.7·max(actual_s,300) + 0.1·h_rt_s)/3600
#
# type_coef: gpu_1=0.200 (default) · node_q=0.250 · node_h=0.500 · node_f=1.000
#            node_o=0.125 · gpu_h=0.100 (MIG) · cpu_160=0.600 …
JID=${1:?usage: job_cost.sh <jobid> [type_coef=0.200] [prio_coef=1.0]}
COEF=${2:-0.200}
PRIO=${3:-1.0}

QACCT=$( qacct -j "$JID" 2>/dev/null || ssh tsubame "qacct -j $JID" 2>/dev/null )
ACTUAL=$(echo "$QACCT" | awk '/^ru_wallclock/{print $2; exit}')
HRT=$(echo "$QACCT"   | grep -m1 hard_resources | grep -oE 'h_rt=[0-9]+' | cut -d= -f2)
[ -z "$ACTUAL" ] && { echo "no qacct for $JID (still running?)"; exit 1; }
[ -z "$HRT" ] && HRT=0

awk -v a="$ACTUAL" -v h="$HRT" -v c="$COEF" -v p="$PRIO" -v j="$JID" 'BEGIN{
  af = (a+0>300)?a+0:300;
  pts = c*p*(0.7*af + 0.1*h)/3600;
  printf "job %s: actual=%.0fs (floored %.0fs) h_rt=%ss coef=%s prio=%s  ->  %.4f pt\n", j,a,af,h,c,p,pts;
  # machine-readable last token:
  printf "POINTS=%.4f\n", pts;
}'
