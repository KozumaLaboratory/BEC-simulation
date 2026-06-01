#!/usr/bin/env julia
# scripts/fisher_sprint4_joint_all_levers.jl
#
# Joint Fisher across all Sprint 4 levers — combines the polar GS Bogoliubov
# spectrum (k=0.5, 26 modes) and the stretched GS Bogoliubov spectrum
# (k=0.5, 26 modes) into a single 52-observable Fisher analysis.
#
# Both individually gave full-rank under prior-aware cutoff with
# c_1 σ_post ~ 1e-4 and tensor σ_post ~ 1e-2. The joint analysis confirms
# whether they provide independent information (rank-5 with tightened σ)
# or redundant information (same rank, marginal tightening).
#
# Run:   julia --project=. scripts/fisher_sprint4_joint_all_levers.jl
# Expected wall-clock: ~ 5 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN_POLAR = ZeemanParams(0.0, -2.0)
const ZEEMAN_STRETCHED = ZeemanParams(2.0, 0.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8
const K_SAMPLE = 0.5

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

function bdg_around_config(c::AbstractVector{<:Real}, zeeman, init_state::Symbol)
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
    )
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=zeeman, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=init_state, verbose=false)
    psi = ws.state.psi
    F_loc = ws.atom.F
    D = 2F_loc + 1
    n_total = SpinorBEC.total_density(psi, 1)
    peak_idx = argmax(n_total)
    spinor = ComplexF64[psi[peak_idx, c] for c in 1:D]
    n0 = sum(abs2, spinor)
    n0 > 1e-30 && (spinor ./= sqrt(n0))
    bdg = SpinorBEC.bogoliubov_spectrum(;
        spinor=spinor, n0=n0, F=F_loc,
        interactions=ip, zeeman=zeeman, c_dd=C_DD_DIMLESS,
        k_max=K_SAMPLE, n_k=2,
        k_direction=(0.0, 0.0, 1.0))
    Float64[real(ω) for ω in bdg.omega[:, 2]]
end

function forward_joint(c::AbstractVector{<:Real})
    ω_polar = bdg_around_config(c, ZEEMAN_POLAR, :polar)
    ω_stretched = bdg_around_config(c, ZEEMAN_STRETCHED, :m_plus_F)
    vcat(ω_polar, ω_stretched)
end

function main()
    println("=== Joint Fisher: polar + stretched Bogoliubov ===")
    println("52 observables (26 modes × 2 configurations)")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal (2 ITPs + 2 BdGs) ... ")
    t0 = time()
    y0 = forward_joint(c_nominal)
    nominal_time = time() - t0
    @printf "%.1f s\n" nominal_time

    @printf "FD ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_joint, c_nominal, identity;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)

    sigma_y = fill(1e-3, length(y0))
    fish = fisher_information(J, sigma_y)

    println()
    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        σabs = v > 0 ? 1 / sqrt(v) : Inf
        @printf "  λ_%d = %.4e   σ_abs = %.4e\n" i v σabs
    end
    println()

    ident = identifiable_directions(fish; cutoff_ratio=1e-4,
        cutoff_absolute=PRIOR_PRECISION,
        param_names=PARAM_NAMES)
    println(ident.summary)
    println()
    println("Direction breakdown (prior-aware cutoff):")
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        @printf "  Dir %d [%s] σ_abs=%.3e :  %s\n" i tag ident.posterior_sigma_absolute[i] join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    println("--- Comparison vs single-config ---")
    println("Item A polar only: c_1 σ=1.36e-4, tensor σ=8e-3 to 2e-2, c_0 σ=0.10")
    println("Item A stretched : c_1 σ=5.88e-5, tensor σ=8e-3 to 2e-2, c_0 σ=0.058")
    println("Joint (this):   per-axis σ above. Tightening factor vs best single shown.")
    println()
    println("If joint σ ≈ single-best σ: configurations carry redundant information.")
    println("If joint σ < single-best σ: orthogonal information, real ~√2 gain or more.")
    println()
    println("=== Joint analysis complete ===")
end

main()
