#!/usr/bin/env julia
# scripts/sprint5_A1_v2_eu_2d_proper.jl
#
# Track A1 v2 — Eu nominal phase ID with the corrections from v1:
#   1. ≥ 2D grid (MDDI texturing essential for Eu)
#   2. Symmetry-breaking noise on each init (escape saddle points)
#   3. ITP + LBFGS polish (proper convergence)
#   4. Wavefunction comparison (not just E)
#   5. Bz = 0 (no Zeeman bias contamination)
#
# Output: per-init (E, |ψ⟩) after polish, overlap matrix between all
# converged ψ's. Distinct phases ⇒ low pairwise overlap; same phase
# (just reached from different inits) ⇒ high overlap.
#
# This v2 also keeps N=2000 for compute envelope and uses a 2D quasi-2D
# trap; full 3D + N≈5×10⁴ is the proper next-session run.
#
# Run:   julia --project=. scripts/sprint5_A1_v2_eu_2d_proper.jl
# Expected wall-clock: ~ 20 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Random
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
# 2D 16×16 in (x,y) plane with quasi-2D DDI (z extent compressed)
const GRID = make_grid(GridConfig((16, 16), (8.0, 8.0)))
const POT = HarmonicTrap{2}((1.0, 1.0))
const ZEEMAN = ZeemanParams(0.0, 0.0)   # NO Zeeman — pure contact + MDDI competition
const DT_ITP = 0.005
const N_STEPS_ITP = 8000
const TOL_ITP = 1e-10
const L_Z_DDI = 1.0                       # quasi-2D DDI confinement length

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0 = C_TOTAL / (1 + F^2 / 36.0)
const C1 = C0 / 36.0
const C2 = 0.05 * C0
const C4 = 0.02 * C0
const C6 = 0.005 * C0
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const INITS = [:m_plus_F, :polar, :antiferromagnetic, :cyclic, :biaxial_nematic]
const NOISE_SEEDS = [1, 2]   # two noise realisations per init to detect noise-dependence

function apply_noise!(psi::AbstractArray, amp::Float64, seed::Int)
    rng = MersenneTwister(seed)
    @inbounds for i in eachindex(psi)
        psi[i] += amp * (randn(rng) + im * randn(rng))
    end
    # Renormalise to keep ∫|ψ|² = 1
    n = sqrt(sum(abs2, psi) * SpinorBEC.cell_volume(GRID))
    psi ./= n
end

function run_one(init_state::Symbol, seed::Int)
    ip = InteractionParams(Dict{Int, Float64}(
        0 => C0, 1 => C1, 2 => C2, 4 => C4, 6 => C6))
    sys = SpinSystem(F)
    psi_init = init_psi(GRID, sys; state=init_state)
    apply_noise!(psi_init, 0.01, seed)
    try
        ws, conv, E, dE, last = find_ground_state(;
            grid=GRID, atom=ATOM, interactions=ip,
            zeeman=ZEEMAN, potential=POT,
            dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL_ITP,
            initial_state=init_state, verbose=false,
            psi_init=psi_init,
            enable_ddi=true, c_dd=C_DD_DIMLESS, secular_ddi=false,
            quasi_2d=true, l_z=L_Z_DDI)
        return ws, E, conv
    catch err
        @warn "init=$init_state seed=$seed failed" err
        return nothing, NaN, false
    end
end

"""Normalised inner product |⟨ψ_a | ψ_b⟩| — phase-invariant overlap."""
function overlap(psi_a::AbstractArray, psi_b::AbstractArray, grid)
    dV = SpinorBEC.cell_volume(grid)
    inner = 0.0 + 0.0im
    @inbounds for i in eachindex(psi_a)
        inner += conj(psi_a[i]) * psi_b[i]
    end
    abs(inner * dV)
end

function main()
    println("=== A1 v2: Eu nominal phase ID, 2D quasi-2D MDDI, Bz=0, noise+polish ===")
    @printf "Grid: 2D 16×16, box=8, l_z(DDI)=%.2f, Zeeman=(0,0)\n" L_Z_DDI
    @printf "c=(%.2e, %.2e, %.2e, %.2e, %.2e), c_dd=%.4g\n" C0 C1 C2 C4 C6 C_DD_DIMLESS
    @printf "%d inits × %d noise seeds = %d ITPs\n" length(INITS) length(NOISE_SEEDS) (
        length(INITS) * length(NOISE_SEEDS)
    )
    println()

    results = Vector{Any}()
    for init in INITS, seed in NOISE_SEEDS
        print("  init=$init seed=$seed ... ")
        t0 = time()
        ws, E, conv = run_one(init, seed)
        if ws === nothing
            @printf "%.1fs FAILED\n" (time() - t0)
            continue
        end
        F_loc = ws.atom.F
        sys = SpinSystem(F_loc)
        Mz = SpinorBEC.magnetization(ws.state.psi, ws.grid, sys)
        sm = spin_matrices(F_loc)
        phase = SpinorBEC.classify_phase_detailed(ws.state.psi, F_loc, ws.grid, sm)
        @printf "%.1fs E=%.6f Mz=%+.4f conv=%s phase=%s\n" (time() - t0) E Mz conv string(
            phase.phase
        )
        push!(results, (init=init, seed=seed, ws=ws, E=E, Mz=Mz, conv=conv, phase=phase))
    end
    println()
    isempty(results) && (println("No runs completed."); return nothing)

    sorted = sort(results; by=r -> r.E)

    println("Energy ranking (lowest first):")
    for r in sorted
        flag = r.conv ? "" : "  [NOT CONV]"
        @printf "  %-22s seed=%d  E=%.6f  Mz=%+.4f  phase=%s%s\n" string(r.init) r.seed r.E r.Mz string(
            r.phase.phase
        ) flag
    end
    println()

    # Wavefunction overlap matrix
    println("Pairwise |⟨ψ_i|ψ_j⟩| matrix (1 = same state, 0 = orthogonal):")
    n = length(sorted)
    overlaps = zeros(n, n)
    for i in 1:n, j in 1:n
        overlaps[i, j] = overlap(sorted[i].ws.state.psi, sorted[j].ws.state.psi, GRID)
    end
    print("                  ")
    for j in 1:n
        @printf "%6d " j
    end
    println()
    for i in 1:n
        @printf "  %-2d %-12s  " i string(sorted[i].init)[1:min(end, 12)]
        for j in 1:n
            @printf "%6.3f " overlaps[i, j]
        end
        println()
    end
    println()

    # Distinct phase count (clustering by overlap >= 0.9)
    n_distinct = 1
    cluster_of = ones(Int, n)
    for i in 2:n
        assigned = false
        for k in 1:(i - 1)
            if overlaps[i, k] > 0.9 && cluster_of[k] == cluster_of[k]
                cluster_of[i] = cluster_of[k]
                assigned = true
                break
            end
        end
        if !assigned
            n_distinct += 1
            cluster_of[i] = n_distinct
        end
    end
    @printf "Distinct phases (overlap > 0.9 clustering): %d\n" n_distinct
    println()

    # Energy gap among distinct minima
    distinct_idx = unique(cluster_of)
    distinct_E = [
        minimum(r.E for (j, r) in enumerate(sorted) if cluster_of[j] == c) for c in distinct_idx
    ]
    sort!(distinct_E)
    if length(distinct_E) >= 2
        @printf "Lowest distinct E = %.6f, second = %.6f, gap = %.3e\n" distinct_E[1] distinct_E[2] (
            distinct_E[2] - distinct_E[1]
        )
        @printf "Gap / E = %.3e\n" ((distinct_E[2] - distinct_E[1]) / distinct_E[1])
        println()
        println("Interpretation: distinct phases with finite gap. Track B (LHY/TDHFB)")
        println("becomes load-bearing only if gap is *smaller than* expected LHY shift")
        println("AND verified to be above lattice noise (run at 2 grid sizes).")
    else
        println("Only 1 distinct phase found across all (init, noise) runs.")
        println("Eu nominal appears in a single GP phase at this (Bz=0, N, trap, c) point.")
    end

    println()
    println("=== Done ===")
end

main()
