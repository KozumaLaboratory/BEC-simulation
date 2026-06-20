#!/bin/bash
# UGE submission: EdH vs Flower comparison at 63 µG (Issue #32).
#
#   variant A (Flower)  — GOTO_MODE=hold_63ug   : smooth 10 mG → 63 µG over 250 ms + hold
#   variant B (EdH)     — GOTO_MODE=quench_63ug : quench 10 mG → 63 µG in 0.2 ms + hold
#
# Both: K_3 = 1.0×10⁻⁴⁰ m⁶/s, FPE_REUSE_LBFGS_ONLY=true, full ψ saved every 8 frames.
# After each RTP finishes the mass_current_analysis.jl is run on its h5,
# then the python plot script.
#
# qsub -g tga-kozuma-kouhi runs/eu151_flower_protocol_edh/main/submit_edh_vs_flower_k3.sh
#$ -cwd
#$ -N edh_vs_flower
#$ -l gpu_h=1
#$ -l h_rt=8:00:00
#$ -j n
#$ -o /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/
#$ -e /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs/

set -euo pipefail
PROJECT_ROOT=${PROJECT_ROOT:-$HOME/bec-simulation}
mkdir -p /gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh/logs
cd "$PROJECT_ROOT"
source scripts/tsubame_setup.sh
set -euo pipefail
HOME_DEPOT=$HOME/.julia
export JULIA_DEPOT_PATH="$JULIA_DEPOT_PATH:$HOME_DEPOT"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/juliaup/julia-1.12.6+0.x64.linux.gnu/bin/julia
echo "[edh_vs_flower] on $(hostname)"

export FPE_REUSE_LBFGS_ONLY=true
export GOTO_K3_PER_M_SI=1.0e-40
export GOTO_PSI_SAVE_EVERY=8

WORK_DIR=/gs/bs/work/6/ue06186/bec-runs/flower_protocol_edh

run_one () {
    local mode="$1"        # hold_63ug or quench_63ug
    local fig_subdir="$2"  # figures subdirectory name
    local h5_basename="$3" # expected h5 file basename (without .h5)
    local h5_path="${WORK_DIR}/${h5_basename}_k3_1.0e-40.h5"
    local fig_dir="runs/eu151_flower_protocol_edh/figures/${fig_subdir}"
    mkdir -p "$fig_dir"

    echo "[edh_vs_flower] === ${mode} ==="
    # Skip RTP if h5 already has psi_full_re (i.e. a previous successful run exists).
    if [[ -f "$h5_path" ]] && python3 -c "import h5py; f=h5py.File('${h5_path}','r'); exit(0 if 'psi_full_re' in f else 1)" 2>/dev/null; then
        echo "[edh_vs_flower] [${mode}] existing h5 with psi_full_re found → skip RTP"
    else
        GOTO_MODE="${mode}" "$JULIA" --project=. scripts/flower_protocol_edh/goto_protocol_10mG.jl
    fi

    echo "[edh_vs_flower] [${mode}] mass current analysis"
    "$JULIA" --project=. scripts/flower_protocol_edh/mass_current_analysis.jl "$h5_path" || \
        echo "[edh_vs_flower] [${mode}] WARN: mass_current_analysis failed, continuing"

    echo "[edh_vs_flower] [${mode}] mass current plots → $fig_dir"
    python3 scripts/flower_protocol_edh/plot_mass_current.py "$h5_path" "$fig_dir/mass_current" || \
        echo "[edh_vs_flower] [${mode}] WARN: plot_mass_current failed, continuing"

    # Re-use existing plotting for density / vortex / spin-texture
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto.py || true
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_GIF="${fig_dir}/volume_density_phase.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_3d_density_phase.py || true
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_GIF="${fig_dir}/isosurface_peak30_m6.gif" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_isosurface_m6.py || true
    GOTO_H5="$h5_path" RTP_H5="$h5_path" \
        OUT_PNG="${fig_dir}/vortex_analysis_m6m5m4.png" \
        OUT_CSV="${fig_dir}/vortex_analysis_m6m5m4.csv" \
        python3 scripts/flower_protocol_edh/plot_rtp_10mG_goto_vortex_analysis.py || true

    echo "[edh_vs_flower] [${mode}] done"
}

# variant A: smooth ramp (Flower hypothesis)
run_one hold_63ug    flower_63uG_k3_1e-40   rtp_10mG_goto_hold_63ug

# variant B: sudden quench (EdH hypothesis)
run_one quench_63ug  edh_quench_63uG_k3_1e-40   rtp_quench_63uG

echo "[edh_vs_flower] cross-variant comparison"
FLOWER_H5=${WORK_DIR}/rtp_10mG_goto_hold_63ug_k3_1.0e-40.h5
QUENCH_H5=${WORK_DIR}/rtp_quench_63uG_k3_1.0e-40.h5
CMP_DIR=runs/eu151_flower_protocol_edh/figures/edh_vs_flower_compare_k3_1e-40
mkdir -p "$CMP_DIR"
python3 scripts/flower_protocol_edh/compare_edh_vs_flower.py \
    "$FLOWER_H5" "$QUENCH_H5" "$CMP_DIR" || \
    echo "[edh_vs_flower] WARN: cross-variant comparison plot failed"

echo "[edh_vs_flower] all done"
