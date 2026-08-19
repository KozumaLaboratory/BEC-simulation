#!/usr/bin/env bash
# Baseline torus cell (#336) + the grid/box convergence arms required by the
# issue's acceptance criteria. Records its own exit status: a PID vanishing
# says nothing about success, which is what an OOM kill looks like.
set -uo pipefail
cd /home/suzume/workspace/BEC-simulation/.claude/worktrees/rippling-forging-hammock
mkdir -p runs/saito_li_torus/out

run () {
  local tag="$1"; shift
  echo "=== $tag :: $* ==="
  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
    -e 'import CUDA' \
    -e "include(\"runs/saito_li_torus/b_cells.jl\"); main(String[$*])"
  echo "--- $tag rc=$? ---"
}

# baseline
run baseline '"T","n=64","nz=64","box_xy=6.5","box_z=3.5","iters=4000"'
# grid convergence at fixed box (dx 0.1016 -> 0.0677 a_ho)
run grid96   '"T","n=96","nz=96","box_xy=6.5","box_z=3.5","iters=4000"'
# box convergence at (near) fixed dx: 1.25x box, 1.25x points
run box125   '"T","n=80","nz=80","box_xy=8.125","box_z=4.375","iters=4000"'

echo ALL_DONE
