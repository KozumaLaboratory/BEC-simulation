#!/bin/bash
#$ -cwd
#$ -N v7_fable
#$ -l cpu_40=1
#$ -l h_rt=6:00:00
#$ -j y
#$ -o /gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data/v7_fable.log
# v7_EdH_Fable — full pipeline on the 96^3/f64 EdH v6 data, CPU node (no GPU).
# forward (raw SG pixel data) -> truth -> recon (pixels only) -> audit -> viz.
# Compute grid == analysis grid == display grid; no density floor.
set -uo pipefail   # NOT -e: viz panels must not abort the chain; stages gate manually
PROJECT_ROOT=/gs/fs/tga-kozuma-kouhi/ue06186/BEC-simulation
DATA=/gs/fs/tga-kozuma-kouhi/ue06186/runs/edh_vs_flower_data
VIZPY=/gs/fs/tga-kozuma-kouhi/ue06186/conda_viz/bin/python
V7=$PROJECT_ROOT/scripts/edh_vs_flower/v7_fable
cd "$PROJECT_ROOT"

EDIR=$(ls -dt "$DATA"/edh_quench_v6_*/ 2>/dev/null | head -1)
PSI13=$DATA/edh_v6_psi13.jld2
GOTO=$EDIR/goto.h5
OUTD=$DATA/v7_fable
FIGS=$OUTD/figures_v7
mkdir -p "$FIGS"
echo "EDIR=$EDIR PSI13=$PSI13 OUTD=$OUTD"
[ -f "$PSI13" ] || { echo "FATAL: psi13 missing"; exit 1; }
[ -f "$GOTO" ] || { echo "FATAL: goto.h5 missing (times source)"; exit 1; }

# default protocol id,y+-16,x+-16; override by qsub -v V7_TILT_SPEC=...
export V7_TILT_SPEC="${V7_TILT_SPEC:-id,y+16,y-16,x+16,x-16}"
export V7_HELDOUT_SPEC="${V7_HELDOUT_SPEC:-y+30,x-30}"
echo "protocol: $V7_TILT_SPEC  heldout: $V7_HELDOUT_SPEC"

echo "=== 1/5 forward model (raw SG pixel data) ==="
PSI13=$PSI13 GOTO=$GOTO OUT=$OUTD/sg_raw_v7.h5 OUTDIR=$FIGS \
  "$VIZPY" "$V7/sg_forward.py" || { echo "FATAL: forward failed"; exit 1; }

echo "=== 2/5 truth reference ==="
PSI13=$PSI13 RAW=$OUTD/sg_raw_v7.h5 OUT=$OUTD/truth_v7.h5 \
  "$VIZPY" "$V7/truth_reference.py" || { echo "FATAL: truth failed"; exit 1; }

echo "=== 3/5 reconstruction from pixels only ==="
RAW=$OUTD/sg_raw_v7.h5 OUT=$OUTD/recon_v7.h5 \
  "$VIZPY" "$V7/recon_from_pixels.py" || { echo "FATAL: recon failed"; exit 1; }

echo "=== 4/5 adversarial audit ==="
RAW=$OUTD/sg_raw_v7.h5 RECON=$OUTD/recon_v7.h5 \
  "$VIZPY" "$V7/audit_v7.py"
AUDIT_RC=$?
echo "audit exit code: $AUDIT_RC (0 = ALL PASS)"

echo "=== 5/5 visualization suite ==="
RAW=$OUTD/sg_raw_v7.h5 RECON=$OUTD/recon_v7.h5 TRUTH=$OUTD/truth_v7.h5 OUTDIR=$FIGS \
  "$VIZPY" "$V7/viz_v7.py" || echo "(viz FAILED)"

echo "=== done ==="; ls -la "$OUTD" "$FIGS"
exit $AUDIT_RC
