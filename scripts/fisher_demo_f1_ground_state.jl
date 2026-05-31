#!/usr/bin/env julia
# scripts/fisher_demo_f1_ground_state.jl
#
# Sprint-2 Fisher methodology demo on a minimal F=1 GPE ground state.
# Parameterises in the textbook (c_0, c_1) basis (Kawaguchi-Ueda Eq. 13.18),
# runs central-FD ∂y/∂c around a nominal point, builds the Fisher information
# matrix from a diagonal photon-shot-noise floor, and prints measurable rank
# + identifiable directions.
#
# Run:   julia --project=. scripts/fisher_demo_f1_ground_state.jl
#
# This is the Sprint-2 deliverable validation: confirms the Fisher utilities
# work end-to-end on a real PDE forward model (~60 s on a single CPU).
# Production Eu Fisher (F=6, {a_S} channel basis, 7 params, ring-stage 3D
# ground state) lives in Sprint 4 — same utilities, larger compute budget.

using SpinorBEC
using LinearAlgebra
using Printf

const F = 1
const ATOM = SpinorBEC.Rb87
const GRID = make_grid(GridConfig((32,), (12.0,)))
const ZEEMAN = ZeemanParams(0.5, 0.05)
const POT = HarmonicTrap{1}((1.0,))
const DT_ITP = 0.005
const N_STEPS_ITP = 4000
const TOL = 1e-7

"""Build interactions, run ITP, return final workspace."""
function forward_ground_state(c::AbstractVector{<:Real})
    length(c) == 2 || error("expected 2 parameters (c_0, c_1), got $(length(c))")
    ip = InteractionParams(Dict(0 => Float64(c[1]), 1 => Float64(c[2])))
    ws, conv, E, dE, last = find_ground_state(;
        grid=GRID, atom=ATOM, interactions=ip,
        zeeman=ZEEMAN, potential=POT,
        dt=DT_ITP, n_steps=N_STEPS_ITP, tol=TOL,
        initial_state=:polar,
    )
    (workspace=ws, energy=E, converged=conv)
end

"""Reduce workspace to observable vector y = [E, n_{-1}, n_0, n_{+1}]."""
function summary_observables(out)
    ws = out.workspace
    psi = ws.state.psi
    F_loc = ws.atom.F
    dV = SpinorBEC.cell_volume(ws.grid)
    n_per_m = Float64[]
    for c_idx in 1:(2F_loc + 1)
        nc = sum(abs2, view(psi, :, c_idx)) * dV
        push!(n_per_m, nc)
    end
    [out.energy; n_per_m]
end

function main()
    # Nominal Rb87 dimensionless couplings for N≈10⁴ in our harmonic units.
    c_nominal = [4.0, 0.05]
    param_names = ["c_0", "c_1"]

    println("=== Sprint-2 Fisher demo (F=1, $(ATOM.name)) ===")
    @printf "Nominal: c_0=%.3f, c_1=%.3f\n" c_nominal...
    println("Forward: 32-point 1D harmonic trap, B such that p=$(ZEEMAN.p), q=$(ZEEMAN.q)")
    println("Observables: y = (E, n_{-1}, n_0, n_{+1})")
    println()

    print("Computing ∂y/∂c via central FD (~ 4 ground-state solves) ... ")
    t0 = time()
    J = fisher_jacobian(forward_ground_state, c_nominal, summary_observables;
        delta_frac=1e-3, delta_floor=1e-6)
    @printf "%.1f s\n" (time() - t0)
    println()

    println("Jacobian J (rows = observables, cols = c_0, c_1):")
    for i in 1:size(J, 1)
        @printf "  row %d:  %+.4e  %+.4e\n" i J[i, 1] J[i, 2]
    end
    println()

    # Diagonal noise: relative 1% on energy, absolute 1e-4 on populations.
    y0 = summary_observables(forward_ground_state(c_nominal))
    sigma_y = Float64[max(0.01 * abs(y0[1]), 1e-6); fill(1e-4, length(y0) - 1)]

    fish = fisher_information(J, sigma_y)
    @printf "Fisher eigenvalues: %s\n" join((@sprintf("%.3e", v) for v in fish.eigenvalues), ", ")

    ident = identifiable_directions(fish; cutoff_ratio=1e-4, param_names=param_names)
    println()
    println(ident.summary)
    println()
    for i in 1:length(c_nominal)
        v = ident.eigenvectors[:, i]
        tag = ident.is_identifiable[i] ? "MEAS" : "NULL"
        @printf "  Direction %d [%s]: c_0 ↦ %+.4f, c_1 ↦ %+.4f  (σ_post = %s)\n" i tag v[1] v[2] (
            isfinite(ident.posterior_sigma[i]) ?
            @sprintf("%.3e", ident.posterior_sigma[i]) : "Inf"
        )
    end

    println()
    println("=== Done ===")
end

main()
