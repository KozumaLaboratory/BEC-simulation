#!/usr/bin/env julia
# scripts/fisher_sprint3_eu_f6_gate.jl
#
# Sprint-3 judgment gate: F=6 ¹⁵¹Eu ground-state Fisher analysis on the
# textbook 5-parameter spinor basis (c_0, c_1, c_2, c_4, c_6).
#
# Why this is the gate: under the EdH protocol Matsui used, the system spends
# the prep phase in a strongly-stretched state (m = ±F). For a fully stretched
# ground state, ALL channel contributions reduce to the single S = 2F
# scattering length g_{2F} (Vandermonde with one eigenvalue F² at S=2F).
# The Fisher matrix should therefore reveal **measurable rank = 1** with the
# identifiable direction being the g_{S=2F} combination, and 4 null directions
# orthogonal to it. Verifying this in the codebase confirms:
#   (a) the {c_n} parameterization is consistent at F=6
#   (b) ring-stage stretched observables cannot determine the 7 a_S
#       individually — additional protocols (microwave Feshbach, non-stretched
#       polarisation prep, or interferometric phase) are required
#   (c) sets the data-driven bar for the 3D vortex stage investment decision
#       (Sprint-4 SBI cost-benefit: covered in note next to this script)
#
# Run:   julia --project=. scripts/fisher_sprint3_eu_f6_gate.jl
# Expected wall-clock: ~ 5-10 minutes on a single CPU core.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const ATOM = SpinorBEC.Eu151
const N_ATOMS = 2000      # smaller cloud → faster ITP without changing physics
const OMEGA_REF = 691.15
const GRID = make_grid(GridConfig((24,), (10.0,)))
const POT = HarmonicTrap{1}((1.0,))
const ZEEMAN = ZeemanParams(2.0, 0.0)   # strong negative-µ Zeeman → m = +F stretched
const DT_ITP = 0.005
const N_STEPS_ITP = 6000
const TOL = 1e-8

# c_total ≈ 4π(a_s/a_ho)·N_atoms (matches Matsui scale at this N)
const C_TOTAL = let a_ho = sqrt(SpinorBEC.Units.HBAR / (ATOM.mass * OMEGA_REF))
    4π * (ATOM.a_s / a_ho) * N_ATOMS
end
const C0_NOMINAL = C_TOTAL / (1 + F^2 / 36.0)   # c_1/c_0 = 1/36 textbook
const C1_NOMINAL = C0_NOMINAL / 36.0
const C2_NOMINAL = 0.05 * C0_NOMINAL            # naturalness toy
const C4_NOMINAL = 0.02 * C0_NOMINAL
const C6_NOMINAL = 0.005 * C0_NOMINAL

const PARAM_NAMES = ["c_0", "c_1", "c_2", "c_4", "c_6"]

"""Build interactions from 5-vector and run ITP."""
function forward_ground_state(c::AbstractVector{<:Real})
    length(c) == 5 || error("expected 5 params (c_0, c_1, c_2, c_4, c_6)")
    ip = InteractionParams(
        Dict{Int, Float64}(
            0 => Float64(c[1]), 1 => Float64(c[2]),
            2 => Float64(c[3]), 4 => Float64(c[4]), 6 => Float64(c[5])),
    )
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=:m_plus_F,
        verbose=false,
    )
    (workspace=ws, energy=E, converged=conv)
end

"""Reduce ws → (E, n_m for m = -F..+F)."""
function summary_observables(out)
    ws = out.workspace
    psi = ws.state.psi
    F_loc = ws.atom.F
    dV = SpinorBEC.cell_volume(ws.grid)
    n_per_m = Float64[sum(abs2, view(psi, :, c)) * dV for c in 1:(2F_loc + 1)]
    [out.energy; n_per_m]
end

function main()
    println("=== Sprint-3 Fisher gate: ¹⁵¹Eu F=$F stretched GS ===")
    println("Atom: $(ATOM.name), N=$N_ATOMS, ω_ref=$OMEGA_REF rad/s")
    @printf "Nominal (c_0, c_1, c_2, c_4, c_6) = (%.3e, %.3e, %.3e, %.3e, %.3e)\n" C0_NOMINAL C1_NOMINAL C2_NOMINAL C4_NOMINAL C6_NOMINAL
    println("c_total = $C_TOTAL    (4π·a_s/a_ho·N)")
    println(
        "Forward: 1D 24-pt harmonic trap, p=$(ZEEMAN.p) (strong linear Zeeman → m=+F stretched)"
    )
    println("Observables: y = (E, n_{-6}, n_{-5}, ..., n_{+6})  (length $(1 + 2F + 1))")
    println()

    c_nominal = [C0_NOMINAL, C1_NOMINAL, C2_NOMINAL, C4_NOMINAL, C6_NOMINAL]

    t0 = time()
    print("Computing ∂y/∂c via central FD (5 params × 2 sides = 10 GS solves + nominal) ... ")
    J = fisher_jacobian(forward_ground_state, c_nominal, summary_observables;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    println("Jacobian J (rows = observables, cols = c_0, c_1, c_2, c_4, c_6):")
    obs_names = ["E"; ["n[$m]" for m in (-F):F]]
    for i in 1:size(J, 1)
        sig = maximum(abs, view(J, i, :))
        flag = sig > 1e-8 ? "  " : " ·"   # mark trivially-zero rows
        @printf "  %5s%s  %+.3e  %+.3e  %+.3e  %+.3e  %+.3e\n" obs_names[i] flag J[i, 1] J[i, 2] J[
            i, 3
        ] J[i, 4] J[i, 5]
    end
    println()

    # Noise model: 1% relative on E, absolute 1e-3 on each population.
    y0 = summary_observables(forward_ground_state(c_nominal))
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
    println("Direction breakdown (eigenvectors in c-basis):")
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        σstr =
            isfinite(ident.posterior_sigma[i]) ? @sprintf("%.3e", ident.posterior_sigma[i]) : "Inf"
        @printf "  Dir %d [%s] σ_post=%s :  %s\n" i tag σstr join(
            (@sprintf("%+.3f·%s", v[k], PARAM_NAMES[k]) for k in 1:5), "  ")
    end

    println()
    if ident.measurable_count == 1
        println("→ Confirms the physical expectation: ring-stage stretched GS")
        println("  constrains only a single linear combination of the 5 c_n.")
        println("  This is the g_{S=2F} ≈ c_0 + F²·c_1 + ... textbook combination.")
        println("  For SBI Phase 4 to determine all 7 a_S individually, additional")
        println("  protocols (non-stretched prep, microwave Feshbach, interferometer)")
        println("  must be added to break the 4 null directions.")
    else
        println(
            "→ Measurable rank = $(ident.measurable_count) (unexpected if ≠ 1 for stretched GS)"
        )
        println("  Inspect the Jacobian above — non-stretched contamination likely.")
    end
    println()
    println("=== Sprint-3 gate complete ===")
end

main()
