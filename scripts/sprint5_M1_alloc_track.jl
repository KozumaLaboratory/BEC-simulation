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

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 50000
const OMEGA_REF = 691.15
const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C_DD = SpinorBEC.compute_c_dd_dimless(ATOM; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)
const GRID = make_grid(GridConfig((24, 24, 24), (30.0, 30.0, 26.0)))
const POT = HarmonicTrap{3}((1.0, 1.0, 1.1818))

# M1-ITP-style helper functions (the suspects)
function build_seed(state::Symbol, grid)
    sys = SpinSystem(F)
    return init_psi(grid, sys; state=state)
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(grid))
    psi ./= n
end

function run_cell(omega::Float64, B_nT::Float64, seed_state::Symbol)
    ip = InteractionParams(Dict{Int, Float64}(0 => C0, 1 => C1))
    p_lab = B_nT * 0.148
    zeeman = ZeemanParams(p_lab, 0.0)
    psi_init = build_seed(seed_state, GRID)
    apply_noise!(psi_init, 0.01, 1, GRID)
    initial_state_for_fgs = seed_state == :fl_vortex ? :fl_vortex : :polar
    mark("about to call find_ground_state inside run_cell")
    ws_itp, conv_itp, E_itp, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=zeeman, potential=POT,
        dt=0.005, n_steps=500, tol=1e-7,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
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
