#!/usr/bin/env bash
# GPU re-run scripts for Eu151 simulations
# Usage: bash scripts/rerun_gpu.sh [a2|a4|a5|b1|all]
#
# Requires: WSL2 with CUDA, LD_LIBRARY_PATH=/usr/lib/wsl/lib

set -euo pipefail

JULIA="LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=."
PREAMBLE="import CUDA; using SpinorBEC"

run_a2() {
    echo "=== A-2: p_continuation (continuous log ramp) ==="
    echo "Config: runs/eu151_p_continuation/config.yaml"
    echo "Ramp: p from 100 -> 0, log scale, 64³ + DDI"
    eval "$JULIA" -e "$PREAMBLE; run_yaml(\"runs/eu151_p_continuation/config.yaml\")"
}

run_a4() {
    echo "=== A-4: c_dd continuation (discrete scan) ==="
    echo "Config: runs/eu151_gs_continuation/config.yaml"
    echo "Ramp: c_dd from 0 -> 7647 in 8 steps, 64³"
    eval "$JULIA" -e "$PREAMBLE; run_yaml(\"runs/eu151_gs_continuation/config.yaml\")"
}

run_a5() {
    echo "=== A-5: c1_scan_comparison ==="
    echo "Config: runs/eu151_c1_scan_comparison/config.yaml"
    echo "Scan: c1_ratio [-0.020 ... 0.000], uniform_polarized vs fl_vortex"
    echo "Cleaning old results..."
    rm -f runs/eu151_c1_scan_comparison/point_*.jld2
    eval "$JULIA" -e "$PREAMBLE; run_yaml(\"runs/eu151_c1_scan_comparison/config.yaml\")"
}

run_b1() {
    echo "=== B-1: EdH dynamics (requires good GS from A-2/A-4) ==="
    echo "Config: runs/eu151_edh/config.yaml"
    eval "$JULIA" -e "$PREAMBLE; run_yaml(\"runs/eu151_edh/config.yaml\")"
}

case "${1:-all}" in
    a2)  run_a2 ;;
    a4)  run_a4 ;;
    a5)  run_a5 ;;
    b1)  run_b1 ;;
    all)
        run_a2
        run_a4
        run_a5
        run_b1
        ;;
    *)
        echo "Usage: $0 [a2|a4|a5|b1|all]"
        exit 1
        ;;
esac

echo "Done."
