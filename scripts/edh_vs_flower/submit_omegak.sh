#!/bin/bash
# CPU analysis job: omega(k) magnon dispersion extraction from a saved 64^3 run.
#   qsub -g tga-kozuma-kouhi -l node_o=1 -l h_rt=0:40:00 \
#        -v IN=/gs/bs/work/.../point_001.jld2,OUT=/gs/bs/work/.../omegak.json \
#        scripts/edh_vs_flower/submit_omegak.sh
#$ -cwd
#$ -N edh_omk
#$ -j y
#$ -o edh_omk_uge.log
set -euo pipefail
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=$(printf '%s' "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -vi 'cuda' | paste -sd: -)
fi
# Pin the OWN Julia depot. The Kozuma shared depot holds precompile caches built by
# uk07267 referencing /home/7/uk07267/... which we cannot stat -> EACCES at `using`.
export JULIA_DEPOT_PATH=/home/6/ue06186/.julia
unset JULIAUP_DEPOT_PATH || true
JULIA=/home/6/ue06186/.local/bin/julia
IN=${IN:?set IN=path/to/point_001.jld2}
OUT=${OUT:?set OUT=path/to/out.json}
echo "[omk] host=$(hostname) in=$IN out=$OUT"
"$JULIA" --project=. --startup-file=no \
    scripts/edh_vs_flower/precession_fit/omega_k_export.jl "$IN" "$OUT"
echo "[omk] done rc=$?"
