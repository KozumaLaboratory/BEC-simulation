#!/usr/bin/env julia
# scripts/sprint5_A1_v3_complete.jl
#
# Completes the v3 scan — runs only the 2 inits that crashed/were unreached
# in the first attempt: ksu_circulation and icosahedral_explicit.
# Uses the SAME 16² quasi-2D + MDDI envelope as v3 so results are
# directly mergeable with the v3 log.
#
# Run:  julia --project=. scripts/sprint5_A1_v3_complete.jl

using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((16, 16), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 8000
const TOL_ITP = 1e-10
const L_Z_DDI = 1.0

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const MISSING_INITS = [:ksu_circulation, :icosahedral_explicit]
const NOISE_SEEDS = [1, 2]

function build_psi(state::Symbol, sys)
    if state === :ksu_circulation
        psi = init_psi(GRID, sys; state=:m_plus_F)
        xs = GRID.x[1]
        ys = GRID.x[2]
        for j in eachindex(ys), i in eachindex(xs)
            θ = atan(ys[j], xs[i])
            psi[i, j, 1] *= exp(im * θ)
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        psi ./= n
        return psi
    elseif state === :icosahedral_explicit
        ζ = SpinorBEC.IcosahedralMod.ZETA_F6_IH
        psi = init_psi(GRID, sys; state=:polar)
        for j in 1:size(psi, 2), i in 1:size(psi, 1)
            spatial_amp = sqrt(sum(abs2, view(psi, i, j, :)))
            for c in 1:size(psi, 3)
                psi[i, j, c] = spatial_amp * ζ[c]
            end
        end
        n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
        n > 0 && (psi ./= n)
        return psi
    else
        return init_psi(GRID, sys; state=state)
    end
end

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
    psi ./= n
end

function run_one(init_state::Symbol, seed::Int)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    sys = SpinSystem(F)
    psi_init = build_psi(init_state, sys)
    apply_noise!(psi_init, 0.01, seed)
    initial_state_for_fgs = if init_state === :ksu_circulation
        :m_plus_F
    elseif init_state === :icosahedral_explicit
        :polar
    else
        init_state
    end
    ws, conv, E, _, _ = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
        initial_state=initial_state_for_fgs, verbose=false,
        psi_init=psi_init,
        enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
        quasi_2d=true, l_z=L_Z_DDI)
    return ws, E, conv
end

function spin_density_max(ws)
    sm = ws.spin_matrices
    psi = ws.state.psi
    fx, fy, fz = spin_density_vector(psi, sm, 2)
    maximum(sqrt.(abs2.(fx) .+ abs2.(fy) .+ abs2.(fz)))
end

function main()
    println("=== A1 v3 completion — ksu_circulation + icosahedral_explicit ===\n")
    for init in MISSING_INITS, seed in NOISE_SEEDS
        print("  init=$init seed=$seed ... ")
        flush(stdout)
        try
            ws, E, conv = run_one(init, seed)
            b = energy_decomposition(ws)
            f_max = spin_density_max(ws)
            @printf "E=%.6f conv=%s E_ddi=%+.4e f_max=%.4f\n" E (conv ? "✓" : "✗") b.ddi f_max
        catch err
            println("FAILED: $err")
        end
    end
    println("=== Done ===")
end

main()
