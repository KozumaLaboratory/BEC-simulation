#!/bin/bash
# UGE submission: Goto Ch.6 Flower protocol RTP with three-body loss
# K_3 = 1.0×10⁻⁴⁰ m⁶/s (Matsui-aligned, Issue #26).
#
#   variant A — full_descend: 10 mG → 0 G (smooth corner at t=50 ms) + 100 ms hold
#
# Uses FPE_REUSE_LBFGS_ONLY=true so only Phase 3 (RTP) runs — ITP+LBFGS ψ
# comes from the cached jld2 anchor (K_3 is RT-only / non-Hermitian, GS cache
# is bit-identical to the K_3=0 case).
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_goto_protocol_10mG_k3.sh
#$ -cwd
#$ -N goto_10mG_k3
#$ -l gpu_h=1
#$ -l h_rt=4:00:00
#$ -j n
#$ -o /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/
#$ -e /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/

set -euo pipefail
PROJECT_ROOT=$HOME/bec-simulation
mkdir -p /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs
cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
HOME_DEPOT=$HOME/.julia
export JULIA_DEPOT_PATH="$JULIA_DEPOT_PATH:$HOME_DEPOT"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "[goto_10mG_k3] on $(hostname)"
export FPE_REUSE_LBFGS_ONLY=true
export GOTO_K3_PER_M_SI=1.0e-40

run_plots () {
    local mode="$1"
    local h5_name="$2"
    local fig_subdir="$3"
    local h5_path="/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/${h5_name}"
    local fig_dir="runs/eu151_flower_protocol_edh/figures/${fig_subdir}"
    mkdir -p "$fig_dir"
    echo "[goto_10mG_k3] [$mode] generating plots"
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_tilted_diff.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_GIF="${fig_dir}/volume_density_phase.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_spin.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_GIF="${fig_dir}/isosurface_peak30_m6.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        ISO_PEAK_RATIO_M6=0.30 \
        OUT_GIF="${fig_dir}/isosurface_peak30_m6m5m4_secondhalf.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_GIF="${fig_dir}/isosurface_peak70m6_30m5m4_secondhalf.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6m5m4_second_half.py
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_PNG="${fig_dir}/vortex_analysis_m6m5m4.png" \
        OUT_CSV="${fig_dir}/vortex_analysis_m6m5m4.csv" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_vortex_analysis.py
    echo "[goto_10mG_k3] [$mode] plots done"
}

# Variant A only (per Issue #26 scope)
echo "[goto_10mG_k3] === variant A: full_descend  K_3=${GOTO_K3_PER_M_SI} m^6/s ==="
GOTO_MODE=full_descend "$JULIA" --project=. scripts/flower_protocol_edh/goto_protocol_10mG.jl
run_plots full_descend rtp_10mG_goto_k3_1.0e-40.h5 goto_protocol_10mG_k3_1e-40

echo "[goto_10mG_k3] all done"
