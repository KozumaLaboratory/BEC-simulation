#!/usr/bin/env julia
# scripts/fisher_sprint4_itemA_stretched.jl
#
# Sprint-4 item A — stretched-GS Bogoliubov Fisher (companion to the polar
# variant `fisher_sprint4_itemA_bogoliubov.jl`). Tests whether the polar
# variant's full-rank-in-absolute-terms result was a polar-specific outcome
# or a generic feature of GS-Bogoliubov Fisher.
#
# Stretched GS pinned by strong linear Zeeman p=2.0 (m=+F as GS), same as
# Sprint 3 static gate. BdG diagonalisation around the stretched configuration
# at a single k mode sample, 5-param FD over (c_0, c_1, c_2, c_4, c_6).
#
# Compare to polar variant:
#   polar    (q=−2): eigvals [93.9, 2740, 12400, 15300, 5.4e7], full-rank abs.
#   stretched (p=2): this script
#
# Run:   julia --project=. scripts/fisher_sprint4_itemA_stretched.jl
# Expected wall-clock: ~ 2 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN_PIN = ZeemanParams(2.0, 0.0)   # strong p+, m=+F stretched as GS
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

# Prior precision for absolute cutoff (naturalness σ_prior ~ 50 on
# dimensionless c_n; 1/σ_prior^2 ~ 4e-4).
const PRIOR_PRECISION = 4e-4

function forward_bogoliubov_stretched(c::AbstractVector{<:Real})
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
        initial_state=:m_plus_F,
        verbose=false,
    )
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
        interactions=ip, zeeman=ZEEMAN_PIN, c_dd=C_DD_DIMLESS,
        k_max=K_SAMPLE, n_k=2,
        k_direction=(0.0, 0.0, 1.0),
    )
    (workspace=ws, bdg=bdg, energy=E, converged=conv)
end

function summary_bogoliubov(out)
    omega_k1 = out.bdg.omega[:, 2]
    Float64[real(ω) for ω in omega_k1]
end

function main()
    println("=== Sprint-4 item A (stretched): Bogoliubov Fisher around m=+F ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS")
    println("Stretched (m=+F) pinned by linear Zeeman p=$(ZEEMAN_PIN.p)")
    n_bands = 2 * (2 * F + 1)
    @printf "Bogoliubov sample at k=%.2f, %d bands\n" K_SAMPLE n_bands
    @printf "Prior precision floor (cutoff_absolute) = %.1e\n" PRIOR_PRECISION
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 ITP + 1 BdG) ... ")
    t0 = time()
    out0 = forward_bogoliubov_stretched(c_nominal)
    y0 = summary_bogoliubov(out0)
    nominal_time = time() - t0
    @printf "%.1f s  (E=%.4e, conv=%s)\n" nominal_time out0.energy out0.converged

    @printf "Mode frequencies (range): min=%.3f, max=%.3f, n_soft(|ω|<0.1)=%d\n" minimum(y0) maximum(
        y0
    ) count(ω -> abs(ω) < 0.1, y0)
    println()

    @printf "Fisher FD ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_bogoliubov_stretched, c_nominal, summary_bogoliubov;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)

    sigma_y = fill(1e-3, length(y0))
    fish = fisher_information(J, sigma_y)
    println()
    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        @printf "  λ_%d = %.4e   σ_abs = %.4e\n" i v (v > 0 ? 1 / sqrt(v) : Inf)
    end
    println()

    # Both classifications side-by-side
    ident_rel = identifiable_directions(fish; cutoff_ratio=1e-4,
        param_names=PARAM_NAMES)
    ident_abs = identifiable_directions(fish; cutoff_ratio=1e-4,
        cutoff_absolute=PRIOR_PRECISION,
        param_names=PARAM_NAMES)

    println("Verdict (relative cutoff only, the 'trap'):")
    println(ident_rel.summary)
    println()
    println("Verdict (prior-aware: relative OR absolute > 1/σ_prior²):")
    println(ident_abs.summary)
    println()

    println("Direction breakdown (with prior-aware cutoff):")
    for i in 1:length(c_nominal)
        v = ident_abs.eigenvectors[:, i]
        tag = ident_abs.is_identifiable[i] ? "MEAS" : "NULL"
        @printf "  Dir %d [%s] σ_abs=%.3e :  %s\n" i tag ident_abs.posterior_sigma_absolute[i] join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    println("--- Comparison with polar variant ---")
    println("Polar (q=-2):     eigvals [93.9, 2740, 12400, 15300, 5.4e7]")
    @printf "Stretched (p=+2): eigvals [%.1f, %.1f, %.1f, %.1f, %.2e]\n" (
        fish.eigenvalues[1]) (fish.eigenvalues[2]) (fish.eigenvalues[3]) (fish.eigenvalues[4]) (
        fish.eigenvalues[5])
    println()
    println("If stretched also full-rank under prior-aware cutoff: Item A is generic")
    println("(any single-component GS Bogoliubov closes c determination). If sparser,")
    println("stretched has fewer independent spin-modes (m=+F has no m=+F+1 partner)")
    println("and polar is the unique full-discrimination configuration.")
    println()
    println("=== Sprint-4 item A stretched complete ===")
end

main()
