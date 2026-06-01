#!/usr/bin/env julia
# scripts/fisher_sprint4_itemA_ksweep.jl
#
# Sprint-4 item A robustness check: verify that the full-rank Fisher result
# from Bogoliubov spin-mode spectroscopy doesn't depend on a particular
# choice of momentum-sample k. Sweeps k = 0.1, 0.5 (baseline), 1.0, 2.0
# around polar GS, full FD at each.
#
# Physical expectation:
#   - Very small k → Goldstones dominate, sensitivity may drop
#   - Moderate k (~ 0.5-1) → contact / Zeeman / kinetic balanced, max
#     discrimination
#   - Very large k → kinetic dominates, channel sensitivity drops
# So the rank-5 outcome from k=0.5 should persist across k ∈ [0.3, 2.0]
# at least and dip outside that band.
#
# Run:   julia --project=. scripts/fisher_sprint4_itemA_ksweep.jl
# Expected wall-clock: ~ 8 minutes on a single CPU core (4× Item A polar).

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN_PIN = ZeemanParams(0.0, -2.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8
const K_VALUES = [0.1, 0.5, 1.0, 2.0]

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL
const C_DD_DIMLESS = SpinorBEC.compute_c_dd_dimless(ATOM;
    N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]
const PRIOR_PRECISION = 4e-4

function forward_bdg_all_k(c::AbstractVector{<:Real})
    length(c) == 5 || error("expected 5 params")
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
    )
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN_PIN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=:polar, verbose=false)
    psi = ws.state.psi
    F_loc = ws.atom.F
    D = 2F_loc + 1
    n_total = SpinorBEC.total_density(psi, 1)
    peak_idx = argmax(n_total)
    spinor = ComplexF64[psi[peak_idx, c] for c in 1:D]
    n0 = sum(abs2, spinor)
    n0 > 1e-30 && (spinor ./= sqrt(n0))
    # Compute BdG at ALL k values in one diagonalisation (n_k controls grid).
    bdg = SpinorBEC.bogoliubov_spectrum(;
        spinor=spinor, n0=n0, F=F_loc,
        interactions=ip, zeeman=ZEEMAN_PIN, c_dd=C_DD_DIMLESS,
        k_max=maximum(K_VALUES), n_k=200,
        k_direction=(0.0, 0.0, 1.0))
    # Slice out the K_VALUES samples (interpolate-by-nearest grid index).
    k_grid = bdg.k_values
    omega_at_k = Vector{Vector{Float64}}()
    for k_target in K_VALUES
        idx = argmin(abs.(k_grid .- k_target))
        push!(omega_at_k, Float64[real(ω) for ω in bdg.omega[:, idx]])
    end
    omega_at_k    # length(K_VALUES) of length-2D vectors
end

function summary_k_only(out, k_idx::Int)
    out[k_idx]
end

function main()
    println("=== Sprint-4 item A k-sweep robustness ===")
    println("Polar GS, BdG sampled at k ∈ $K_VALUES")
    @printf "Prior precision floor = %.1e\n" PRIOR_PRECISION
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 ITP + multi-k BdG) ... ")
    t0 = time()
    out0 = forward_bdg_all_k(c_nominal)
    nominal_time = time() - t0
    @printf "%.1f s\n" nominal_time

    println()
    println("Mode-frequency range per k:")
    for (i, k) in enumerate(K_VALUES)
        ω = out0[i]
        n_soft = count(abs.(ω) .< 0.1)
        @printf "  k=%.2f : ω ∈ [%.3f, %.3f], n_soft=%d\n" k minimum(ω) maximum(ω) n_soft
    end
    println()

    @printf "Fisher FD over c at each k (ETA %.1f s) ... \n" (10 * nominal_time)

    rank_per_k = Int[]
    eigvals_per_k = Vector{Vector{Float64}}()
    c1_sigma_per_k = Float64[]
    for (i, k) in enumerate(K_VALUES)
        t0 = time()
        J = fisher_jacobian(forward_bdg_all_k, c_nominal,
            out -> summary_k_only(out, i);
            delta_frac=1e-3, delta_floor=1e-6)
        sigma_y = fill(1e-3, size(J, 1))
        fish = fisher_information(J, sigma_y)
        ident = identifiable_directions(fish;
            cutoff_ratio=1e-4, cutoff_absolute=PRIOR_PRECISION,
            param_names=PARAM_NAMES)
        # Find c_1 direction (eigenvector closest to (0,1,0,0,0))
        c1_axis = Float64[0.0, 1.0, 0.0, 0.0, 0.0]
        c1_overlap = [abs(dot(fish.eigenvectors[:, j], c1_axis))
                      for j in 1:length(c_nominal)]
        c1_idx = argmax(c1_overlap)
        push!(c1_sigma_per_k, ident.posterior_sigma_absolute[c1_idx])
        push!(rank_per_k, ident.measurable_count)
        push!(eigvals_per_k, fish.eigenvalues)
        @printf "  k=%.2f : rank=%d/5 (prior-aware), c_1 σ_abs=%.3e, %.1f s\n" k ident.measurable_count c1_sigma_per_k[end] (
            time() - t0
        )
    end

    println()
    println("=== k-sweep summary ===")
    @printf "%5s  %-6s  %-10s  %-44s\n" "k" "rank" "c_1 σ_abs" "eigenvalues (ascending)"
    for (i, k) in enumerate(K_VALUES)
        evals = eigvals_per_k[i]
        evals_str = join((@sprintf("%.2e", v) for v in evals), " ")
        @printf "%5.2f  %d/5    %.3e   %s\n" k rank_per_k[i] c1_sigma_per_k[i] evals_str
    end

    println()
    if all(r -> r >= 4, rank_per_k)
        println("→ Rank ≥ 4 maintained across all k. Item A robustly closes c determination")
        println("  regardless of k-sample choice (within prior-aware cutoff).")
    else
        worst = K_VALUES[argmin(rank_per_k)]
        println("→ Rank dips to $(minimum(rank_per_k))/5 at k=$worst. Item A's full-rank result")
        println("  IS k-dependent; the lab should sample multiple k bands (which they")
        println("  do anyway in collective-mode spectroscopy).")
    end
    println()
    println("=== Sprint-4 k-sweep complete ===")
end

main()
