#!/usr/bin/env julia
# scripts/fisher_sprint4_item1_polar_static.jl
#
# Sprint-4 item 1 (v2): STATIC polar GS Fisher. The dynamic-evolution v1 of
# this protocol (`fisher_sprint4_item1_polar_prep.jl`) returned rank 0 — not
# a code bug but the physics of GP mean-field: polar (m=0 product state) has
# ⟨F⟩ = 0, so the c_1 spin-mixing step is identically zero on polar, and the
# MDDI step preserves ⟨F⟩ = 0. Polar is an exact dynamical fixed point of
# the GP+MDDI evolution we use here, so f_m(T) ≡ f_m(0) and Fisher of
# populations is identically zero.
#
# Beyond-GP (Bogoliubov / TWA / TDHFB) would break the polar fixed point via
# quantum fluctuations, but those live outside the linear-Fisher utility
# stack of Sprint 2.
#
# Within GP, the polar configuration is c-sensitive through the STATIC
# ground-state energy and density profile — different c_n change the
# effective polar self-interaction g_eff(polar) = Σ_S g_S |⟨S,0|F,0;F,0⟩|².
# For F=6 polar this picks up contributions from S = 0, 2, 4, 6, 8, 10, 12.
# c_1 is exempt at GP because the spin-mixing step uses ⟨F⟩² which vanishes;
# c_0, c_2, c_4, c_6 all contribute via different channel weights.
#
# Expected: rank ≥ 3 (c_0 + c_2 + tensor combination), with c_1 in the null.
#
# Run:   julia --project=. scripts/fisher_sprint4_item1_polar_static.jl
# Expected wall-clock: ~ 1 minute on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN_PIN = ZeemanParams(0.0, -2.0)   # q<0 pins polar (m=0) as GS
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8

const A_HO = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
const C_TOTAL = 4π * (ATOM.a_s / A_HO) * N_ATOMS
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL

const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]

"""Polar-pinned ITP at given c. Returns (workspace, energy, converged)."""
function forward_polar_gs(c::AbstractVector{<:Real})
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
    (workspace=ws, energy=E, converged=conv)
end

"""Summary: E and per-m populations (length 1 + 2F+1 = 14, ascending m)."""
function summary_observables(out)
    ws = out.workspace
    psi = ws.state.psi
    F_loc = ws.atom.F
    dV = SpinorBEC.cell_volume(ws.grid)
    # psi[:, c=1] = m=+F per CLAUDE.md
    n_by_c = Float64[sum(abs2, view(psi, :, c)) * dV for c in 1:(2F_loc + 1)]
    n_asc = reverse(n_by_c)
    [out.energy; n_asc]
end

function main()
    println("=== Sprint-4 item 1 v2: STATIC polar GS Fisher ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS, ω_ref=$OMEGA_REF")
    println("Grid: 24-pt 1D harmonic trap (fast). Polar pinned by q=$(ZEEMAN_PIN.q) (<0).")
    println("p=$(ZEEMAN_PIN.p), q=$(ZEEMAN_PIN.q): Zeeman gives polar (m=0) as GS.")
    @printf "Nominal (c_0..c_6) = (%.3e, %.3e, %.3e, %.3e, %.3e)\n" C0_NOMINAL C1_NOMINAL C2_NOMINAL C4_NOMINAL C6_NOMINAL
    println("Observables: y = (E, n_{-6}, ..., n_{+6})  (length 14)")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    print("Computing nominal forward (1 ITP) ... ")
    t0 = time()
    out0 = forward_polar_gs(c_nominal)
    y0 = summary_observables(out0)
    nominal_time = time() - t0
    @printf "%.1f s  (E=%.4e, conv=%s)\n" nominal_time out0.energy out0.converged
    println()

    # Sanity: confirm polar held (f[m=0] dominant)
    polar_frac = y0[1 + F + 1]   # E is y[1]; populations start at y[2]; m=0 at idx F+1 in ascending pop array
    @printf "Polar fraction f[m=0] = %.4f  (target: ≈ 1 under q<0 pinning)\n" polar_frac
    if polar_frac < 0.9
        println("  WARNING: polar pin did not hold — ITP wandered. Lower q (more negative).")
    end
    println()

    @printf "Fisher FD (5 params × 2 sides), ETA %.1f s ... " (10 * nominal_time)
    t0 = time()
    J = fisher_jacobian(forward_polar_gs, c_nominal, summary_observables;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    println("Jacobian (cols = c_0, c_1, c_2, c_4, c_6):")
    obs_names = ["E"; ["n[$m]" for m in (-F):F]]
    for i in 1:size(J, 1)
        sig = maximum(abs, view(J, i, :))
        flag = sig > 1e-8 ? "  " : " ·"
        @printf "  %5s%s  %+.3e  %+.3e  %+.3e  %+.3e  %+.3e\n" obs_names[i] flag J[i, 1] J[i, 2] J[
            i, 3
        ] J[i, 4] J[i, 5]
    end
    println()

    sigma_y = Float64[max(0.01 * abs(y0[1]), 1e-6); fill(1e-3, length(y0) - 1)]
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
    println("Polar GS energy = Σ_S g_S · |⟨S,0|6,0;6,0⟩|² · n² (channel-weighted contact).")
    println("c_n enter via 6j transform; c_0, c_2, c_4, c_6 contribute; c_1 is null at GP")
    println("(spin_mixing step uses ⟨F⟩²=0 for polar; channel S=2 contribution from c_1")
    println("is dropped by the codebase's hybrid basis routing).")
    println()
    println("Compare with stretched gate (Sprint 3): MEAS=g_{2F}=(0.028,1,0,0,0).")
    println("Polar MEAS directions orthogonal to that are GENUINELY NEW c info.")
    println()
    println("=== Sprint-4 item 1 v2 complete ===")
end

main()
