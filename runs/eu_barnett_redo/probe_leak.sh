#!/bin/bash
# What controls the J_z leak? One variable at a time, everything else fixed.
#
# The 2026-07-28 production batch closed its ledger to only 216% of the signal
# (leak 1.63 against a conversion of 0.75). The run's own `edge_frac` said
# 1.2e-5, but it only scanned x and y; the frames carry 1.3e-3 of the density in
# the outermost 0.5 of z, where the box was tightest. Two candidate channels:
#
#   z box    — density wrapping through the tightest axis
#   xy box   — the periodic images and the aliased DDI kernel are only C4
#              symmetric in the xy-plane, so they break the U(1) that makes
#              J_z = L_z + <F_z> conserved in the first place
#   DDI pad  — zero-padded convolution removes the images without touching dx
#   dt       — pinned by test/oracles/test_jz_conservation_ddi.jl as NOT the
#              cause; re-checked here at the probe's own resolution
#
# dx is held at ~0.435 on every axis of every variant, so only the named knob
# moves. Results append to data/leak_scan.csv.
#
# Usage: bash runs/eu_barnett_redo/probe_leak.sh [variant ...]     (default: all)
set -euo pipefail
cd "$(dirname "$0")/../.."

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}:/usr/lib/wsl/lib"
export BR_CELL=plus BR_FRAMES=0
export BR_T_STIR=10.0 BR_T_QUENCH=20.0 BR_GS_STEPS=4000

mkdir -p runs/eu_barnett_redo/logs

run_variant() {
  local tag=$1 n=$2 box=$3 pad=$4 dt=$5
  echo "=== $tag  n=$n box=$box pad=$pad dt=$dt  $(date +%H:%M:%S)"
  BR_TAG="_probe_$tag" BR_N="$n" BR_BOX="$box" BR_PAD="$pad" BR_DT="$dt" BR_TRUNC="${BR_TRUNC:-NaN}" \
    julia --project=. runs/eu_barnett_redo/run_core.jl \
    >"runs/eu_barnett_redo/logs/probe_$tag.log" 2>&1
  tail -8 "runs/eu_barnett_redo/logs/probe_$tag.log"
}

source runs/eu_barnett_redo/variants.sh

TAGS=("$@")
[[ ${#TAGS[@]} -eq 0 ]] && TAGS=(base pad zbox xybox dtx)

for tag in "${TAGS[@]}"; do
  br_select_variant "$tag"
  run_variant "$tag" "$BR_N" "$BR_BOX" "$BR_PAD" "$BR_DT"
done

echo
echo "=== data/leak_scan.csv ==="
cat runs/eu_barnett_redo/data/leak_scan.csv
