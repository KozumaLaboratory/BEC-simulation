#!/usr/bin/env julia
# scripts/fisher_sprint4_itemA_bogoliubov.jl
#
# Sprint-4 item A (lever for tensor channels): Bogoliubov spin-mode spectrum
# Fisher around the polar (m=0) ground state.
#
# Why this is the right tensor-channel probe (anko correction 2026-06-01):
# Bogoliubov spin modes (magnons) around a single-component GS have
# frequencies ω_n that depend DIRECTLY on the spin-dependent contact
# couplings g_S through the BdG mean-field matrix h_mf. Different Δm
# branches (Δm = 0, ±1, ±2, …, ±2F) carry DIFFERENT linear combinations
# of g_S (via the Clebsch-Gordan weights for each (m, m') transition).
# So a multi-branch frequency vector is a NATURALLY rich observable —
# rank > 1 in c-space is physically allowed at linear order, with
# c_2 / c_4 / c_6 separable.
#
# Companion to item 4 v0 spatial: item 4 v0 showed null-filling
# (eigenvalues 1e-5 to 1e-3 in directions that were 1e-17 structural
# zeros in the linear cascade) but the relative-cutoff "rank=1" verdict
# missed that c-information is present, just precision-thin. Item A
# uses observables with multi-mode discrimination so the post-prior
# precision lifts the tensor channels into clean MEAS status without
# leaving GP linear Fisher.
#
# Caveat: avoid mode-softening points (ω_n → 0, non-analytic Fisher);
# choose nominal c well inside a single phase region.
#
# Run:   julia --project=. scripts/fisher_sprint4_itemA_bogoliubov.jl
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
const ZEEMAN_PIN = ZeemanParams(0.0, -2.0)
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8

# Single-point k-mode sample. Small but non-zero so Goldstone is well-defined
# but the kinetic gap is small relative to spin-dep contact.
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

"""Polar GS → peak-density spinor → Bogoliubov spectrum at K_SAMPLE."""
function forward_bogoliubov(c::AbstractVector{<:Real})
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
        initial_state=:polar,
        verbose=false,
    )
    psi = ws.state.psi
    F_loc = ws.atom.F
    D = 2F_loc + 1
    n_total = SpinorBEC.total_density(psi, 1)   # 1D ndim
    peak_idx = argmax(n_total)
    spinor = ComplexF64[psi[peak_idx, c] for c in 1:D]
    n0 = sum(abs2, spinor)
    n0 > 1e-30 && (spinor ./= sqrt(n0))
    bdg = SpinorBEC.bogoliubov_spectrum(;
        spinor=spinor, n0=n0, F=F_loc,
        interactions=ip, zeeman=ZEEMAN_PIN, c_dd=C_DD_DIMLESS,
        k_max=K_SAMPLE, n_k=2,   # two k values: 0 and K_SAMPLE
        k_direction=(0.0, 0.0, 1.0),
    )
    (workspace=ws, bdg=bdg, energy=E, converged=conv)
end

"""Summary: real-part frequencies of all 2D BdG bands at the non-zero k.

Length 2D = 26 modes. Bands at k=0 contain Goldstones (ω=0) which are
not informative; we use only the k=K_SAMPLE column.
"""
function summary_bogoliubov(out)
    omega_k1 = out.bdg.omega[:, 2]    # second k value (= K_SAMPLE)
    Float64[real(ω) for ω in omega_k1]
end

function main()
    println("=== Sprint-4 item A: Bogoliubov spin-mode Fisher around polar GS ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS")
    println("Polar pinned by Zeeman q=$(ZEEMAN_PIN.q), 1D 24-pt trap")
    n_bands = 2 * (2 * F + 1)
    @printf "Bogoliubov sample at k=%.2f, %d bands\n" K_SAMPLE n_bands
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 ITP + 1 BdG diagonalisation) ... ")
    t0 = time()
    out0 = forward_bogoliubov(c_nominal)
    y0 = summary_bogoliubov(out0)
    nominal_time = time() - t0
    @printf "%.1f s  (E=%.4e, conv=%s)\n" nominal_time out0.energy out0.converged

    println()
    println("Bogoliubov mode frequencies at k=$(K_SAMPLE) ($(length(y0)) bands):")
    for (i, ω) in enumerate(y0)
        soft = abs(ω) < 0.1 ? "  ← soft" : ""
        @printf "  mode %2d:  ω = %+.4e%s\n" i ω soft
    end
    println()
    n_soft = count(ω -> abs(ω) < 0.1, y0)
    if n_soft > 4
        println("  WARNING: $n_soft soft modes — near a phase boundary, linear Fisher")
        println("  may be non-analytic. Consider tuning c_nominal away from boundary.")
    end
    println()

    @printf "Fisher FD ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_bogoliubov, c_nominal, summary_bogoliubov;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    println("Mode-by-mode sensitivities (max |∂ω/∂c|):")
    for i in 1:size(J, 1)
        sig = maximum(abs, view(J, i, :))
        sig > 1e-8 && @printf "  mode %2d  max|∂/∂c| = %.3e\n" i sig
    end
    println()

    sigma_y = fill(1e-3, length(y0))   # 1e-3 ω_ref⁻¹ resolution on mode freq
    fish = fisher_information(J, sigma_y)
    println("Fisher eigenvalues (ascending):")
    for (i, v) in enumerate(fish.eigenvalues)
        @printf "  λ_%d = %.4e\n" i v
    end
    println()

    ident = identifiable_directions(fish; cutoff_ratio=1e-4, param_names=PARAM_NAMES)
    println(ident.summary)
    println()
    println("Direction breakdown:")
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        σstr =
            isfinite(ident.posterior_sigma[i]) ?
            @sprintf("%.3e", ident.posterior_sigma[i]) : "Inf"
        @printf "  Dir %d [%s] σ_post=%s :  %s\n" i tag σstr join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    println("--- Interpretation ---")
    println("BdG spin modes around polar carry distinct channel-weight signatures")
    println("per Δm branch. If rank ≥ 2, tensor c_2/c_4/c_6 are linearly separable")
    println("from c_0 (since polar's static-EOS lever already gave c_0 alone).")
    println()
    println("Cumulative rank tally after this script:")
    println("  Sprint 3 stretched ⇒ g_{2F} = c_0 + 36·c_1")
    println("  Item 1 v2 polar    ⇒ c_0    (gives c_1 by subtraction with g_{2F})")
    println("  Item A (this)      ⇒ ??     (target: c_2, c_4, c_6 via multi-mode)")
    println()
    println("=== Sprint-4 item A complete ===")
end

main()
