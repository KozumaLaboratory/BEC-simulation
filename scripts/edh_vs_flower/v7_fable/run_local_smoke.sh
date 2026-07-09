#!/bin/bash
# v7_EdH_Fable — local end-to-end smoke on synthetic 16^3 data.
# Renders EVERY code path (forward -> truth -> recon -> audit -> viz) in ~1 min.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SMOKE="${SMOKE_DIR:-${TMPDIR:-/tmp}/v7_smoke}"
PY="${PYTHON:-python3}"
mkdir -p "$SMOKE"
echo "=== smoke dir: $SMOKE ==="

OUTDIR="$SMOKE" "$PY" "$HERE/make_smoke_data.py" || exit 1

PSI13="$SMOKE/smoke_psi13.jld2" GOTO="$SMOKE/smoke_goto.h5" \
  OUT="$SMOKE/sg_raw_v7.h5" OUTDIR="$SMOKE/figs" \
  "$PY" "$HERE/sg_forward.py" || exit 1

PSI13="$SMOKE/smoke_psi13.jld2" RAW="$SMOKE/sg_raw_v7.h5" \
  OUT="$SMOKE/truth_v7.h5" "$PY" "$HERE/truth_reference.py" || exit 1

RAW="$SMOKE/sg_raw_v7.h5" OUT="$SMOKE/recon_v7.h5" \
  "$PY" "$HERE/recon_from_pixels.py" || exit 1

RAW="$SMOKE/sg_raw_v7.h5" RECON="$SMOKE/recon_v7.h5" \
  "$PY" "$HERE/audit_v7.py"
AUDIT_RC=$?

RAW="$SMOKE/sg_raw_v7.h5" RECON="$SMOKE/recon_v7.h5" TRUTH="$SMOKE/truth_v7.h5" \
  OUTDIR="$SMOKE/figs" "$PY" "$HERE/viz_v7.py" || exit 1

echo "=== smoke outputs ==="
ls -la "$SMOKE" "$SMOKE/figs"
echo "=== audit exit code: $AUDIT_RC (0 = ALL PASS) ==="
exit $AUDIT_RC
