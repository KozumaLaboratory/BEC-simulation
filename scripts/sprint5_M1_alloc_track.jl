#!/usr/bin/env julia
# Allocation tracking test — minimum reproducer wrapping find_ground_state in
# a main()/run_cell() structure like M1-ITP. Run with --track-allocation=user
# to produce .mem files showing per-line allocation counts/sizes.
#
# Run:  julia --project=. --track-allocation=user \
#         scripts/sprint5_M1_alloc_track.jl
# Then inspect .mem files in src/ etc. (lines with non-zero counts).

import CUDA
using SpinorBEC
using LinearAlgebra
using Random
using Printf

function rss_mb()
    procfile = "/proc/self/status"
    for line in eachline(procfile)
        startswith(line, "VmRSS:") && return parse(Int, split(line)[2]) ÷ 1024
    end
    -1
end

const T0 = time()
mark(s) = @printf "[%6.1fs RSS=%5d] %s\n" (time() - T0) rss_mb() s
const TW = eu151_preset()

function build_seed(state::Symbol, grid)
    sys = SpinSystem(TW.F)
    return init_psi(grid, sys; state=state)
end

function run_cell(omega::Float64, B_nT::Float64, seed_state::Symbol)
    p_lab = B_nT * TW.p_per_nT
    zeeman = ZeemanParams(p_lab, 0.0)
    psi_init = build_seed(seed_state, TW.grid)
    add_white_noise!(psi_init, 0.01, 1, TW.grid)
    initial_state_for_fgs = seed_state == :radial_spin_vortex ? :radial_spin_vortex : :polar
    mark("about to call find_ground_state inside run_cell")
    ws_itp, conv_itp, E_itp, _, _ = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=500, tol=1e-7,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=omega,
        backend=CUDABackend())
    mark("find_ground_state DONE in run_cell")
    return E_itp
end

function main()
    mark("main start")
    E = run_cell(0.0, 0.0, :polar)
    mark("main DONE, E=$(round(E; sigdigits=8))")
end

main()
