#!/bin/bash
# UGE GPU submit for the mild-parabolic EdH checkerboard-inversion run(s).
# ue06186 own julia + own depot (~/.julia) — the shared uk07267 juliaup fails
# EACCES on compute nodes, so we deliberately do NOT touch it here.
#
#   qsub -g tga-kozuma-kouhi \
#        -v CFG=runs/eu151_edh_vs_flower/ramp_sweep/ramp_par_edh_mild.yaml \
#        scripts/edh_vs_flower/submit_edh_mild.sh
#
# RESOURCE: node_q=1 (dedicated 1/4 H100 node = one full 94 GB H100). We do NOT
# request gpu_h / gpu_1 — those are MIG (GPU-split) slices from the gg_mig pool,
# which on this cluster is congested/over-constrained (`gg_mig=2(g1_m^…^g4_m)`
# placement) and leaves jobs stuck in qw indefinitely. node_q slots are free and
# schedule immediately; our short (~25 min) runs make the small point-rate
# difference (0.200→0.250 /h) negligible, and we get full H100 memory.
#
# NB: -g AND -l go on the qsub CLI, NOT as #$ directives (TSUBAME rejects #$ -g;
# putting -l on the CLI lets us pick node_q=1 for big jobs or node_o=1 (1/8,
# cheaper, more free slots) for small ≤64³ jobs per submit). Example:
#   qsub -g tga-kozuma-kouhi -l node_o=1 -l h_rt=1:00:00 \
#        -v CFG=<config.yaml> scripts/edh_vs_flower/submit_edh_mild.sh
#$ -cwd
#$ -N edh_mild
#$ -j y
#$ -o edh_mild_uge.log

set -euo pipefail

# Do NOT `module load cuda` — CUDA.jl ships its own CUDA toolkit via artifacts.
# module-loading the system toolkit puts /apps/.../cuda/12.8.0/lib64 on
# LD_LIBRARY_PATH, so CUDA.jl loads the *system* libcublas, which fails with
# CUBLAS_STATUS_NOT_SUPPORTED on the ILP64 cublasZdotc_v2_64 path used by the
# GPU energy/gradient. Only the NVIDIA driver (libcuda, always present on GPU
# nodes) is required. Strip any stray CUDA dirs the login profile may inject.
if [ -n "${LD_LIBRARY_PATH:-}" ]; then
  export LD_LIBRARY_PATH=$(printf '%s' "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -vi 'cuda' | paste -sd: -)
fi

# Pin the OWN Julia depot. The Kozuma shared depot holds precompile caches built by
# uk07267 referencing /home/7/uk07267/... which we cannot stat -> EACCES at `using`.
export JULIA_DEPOT_PATH=/home/6/ue06186/.julia
unset JULIAUP_DEPOT_PATH || true
JULIA=/home/6/ue06186/.local/bin/julia   # ue06186-owned; depot defaults to ~/.julia
CFG=${CFG:?set CFG=path/to/config.yaml via qsub -v CFG=...}
# Write run output to the group WORK area (TB-scale), NOT $HOME (25 GB quota fills
# up and jobs die with "Disk quota exceeded"). The GS cache path in the config is
# relative to cwd (~/bec-simulation, $HOME) and is small + read-only, so it stays.
OUTDIR=${OUTDIR:-/gs/bs/work/6/ue06186/bec-runs}
mkdir -p "$OUTDIR"

echo "[edh_mild] host=$(hostname) cfg=$CFG outdir=$OUTDIR cuda_dev=${CUDA_VISIBLE_DEVICES:-?}"
nvidia-smi -L 2>/dev/null || echo "[edh_mild] nvidia-smi -L unavailable"

"$JULIA" --project=. --startup-file=no -e \
    "import CUDA; using SpinorBEC; CUDA.functional() || error(\"CUDA not functional on this node\"); run_yaml(\"$CFG\"; base_dir=\"$OUTDIR\")"

echo "[edh_mild] done rc=$?"
