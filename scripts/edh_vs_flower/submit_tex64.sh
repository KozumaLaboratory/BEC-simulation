#!/bin/bash
# CPU analysis job: 64^3 texture diagnostics (clean-mode vs turbulence) on a saved run.
# Pure JLD2+FFTW (no CUDA). Reads point_001.jld2 in-place on /gs/bs/work, writes a small JSON.
#   qsub -g tga-kozuma-kouhi -l node_o=1 -l h_rt=0:30:00 \
#        -v IN=/gs/bs/work/.../point_001.jld2,OUT=/gs/bs/work/.../tex64.json \
#        scripts/edh_vs_flower/submit_tex64.sh
#$ -cwd
#$ -N edh_tex64
#$ -j y
#$ -o edh_tex64_uge.log
set -euo pipefail
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=$(printf '%s' "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -vi 'cuda' | paste -sd: -)
fi
JULIA=/home/6/ue06186/.local/bin/julia
IN=${IN:?set IN=path/to/point_001.jld2}
OUT=${OUT:?set OUT=path/to/out.json}
echo "[tex64] host=$(hostname) in=$IN out=$OUT"
"$JULIA" --project=. --startup-file=no \
    scripts/edh_vs_flower/precession_fit/texture64_diag.jl "$IN" "$OUT"
echo "[tex64] done rc=$?"
