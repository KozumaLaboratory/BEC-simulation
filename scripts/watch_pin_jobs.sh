#!/usr/bin/env bash
# Watch the TSUBAME pinning-extrapolation jobs: queue state + live progress/ETA.
#   ./scripts/watch_pin_jobs.sh           # one snapshot
#   watch -n 30 ./scripts/watch_pin_jobs.sh   # auto-refresh every 30s
HOST=uk07267@login1.t4.gsic.titech.ac.jp
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267/BEC-opt
ssh -o ConnectTimeout=20 "$HOST" "
  cd $ROOT
  echo '===== queue (qw=waiting, r=running) ====='
  qstat
  for f in logs/eu_pin_fast.o* logs/eu_pin_bx.o* logs/eu_pin_trap.o*; do
    [ -f \"\$f\" ] || continue
    echo
    echo \"===== \$f =====\"
    # last eps-progress + last LBFGS per-step ETA line + any RESULT/extrapolation
    grep -E 'eps [0-9]+/|progress|CUDA OK|FATAL|RESULT|extrapolation|ALLDONE' \"\$f\" | tail -8
    echo '--- latest LBFGS step (ETA) ---'
    grep -E 'LBFGS|ITP|BdG' \"\$f\" | tail -3
  done
"
