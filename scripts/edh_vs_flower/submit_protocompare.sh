#!/bin/bash
# CPU analysis: extract populations + <Fz> + <Lz> for several runs into one JSON.
#   qsub -g tga-kozuma-kouhi -l node_o=1 -l h_rt=0:40:00 -v OUT=...,RUNS="tag=dir tag=dir" \
#        scripts/edh_vs_flower/submit_protocompare.sh
#$ -cwd
#$ -N edh_pcmp
#$ -j y
#$ -o edh_pcmp_uge.log
set -euo pipefail
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=$(printf '%s' "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -vi 'cuda' | paste -sd: -)
fi
OUT=${OUT:?set OUT}
# UGE -v treats BOTH spaces and commas as separators, so runs are passed as
# individual RUN1..RUN4 variables rather than one delimited string.
RUNS_SP=""
for v in "${RUN1:-}" "${RUN2:-}" "${RUN3:-}" "${RUN4:-}"; do
  [ -n "$v" ] && RUNS_SP="$RUNS_SP $v"
done
[ -n "$RUNS_SP" ] || { echo "set RUN1=tag=dir [RUN2=...]"; exit 2; }
echo "[pcmp] host=$(hostname) out=$OUT runs=$RUNS_SP"
# Pin the OWN Julia depot. The Kozuma shared depot holds precompile caches built by
# uk07267 referencing /home/7/uk07267/... which we cannot stat -> EACCES at `using`.
export JULIA_DEPOT_PATH=/home/6/ue06186/.julia
unset JULIAUP_DEPOT_PATH || true
/home/6/ue06186/.local/bin/julia --project=. --startup-file=no \
    scripts/edh_vs_flower/precession_fit/extract_protocol_compare.jl "$OUT" $RUNS_SP
echo "[pcmp] done rc=$?"
