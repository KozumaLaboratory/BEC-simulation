# --- solvers/continuation entry point (split 2026-05-02) ---
#
# Split into 3 files; SpinorBEC.jl loads each separately:
#   continuation/scan_1d.jl     ← scan_continuation*
#   continuation/scan_2d.jl     ← scan_phase_diagram_2d
#   continuation/boundary.jl    ← scan_phase_boundary (bisection)
