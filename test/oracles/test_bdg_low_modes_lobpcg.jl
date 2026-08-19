using Test
using SpinorBEC
using SpinorBEC: trapped_bdg_lowest_eigenvalue, trapped_bdg_low_modes,
    constrained_hessian_params
using Random

# gate-2 eigensolver: the preconditioned block LOBPCG (`trapped_bdg_low_modes`)
# must agree with the bare Lanczos (`trapped_bdg_lowest_eigenvalue`) on the
# lowest constrained-Hessian eigenvalue — two independent eigensolvers on the
# SAME operator. Also pins the Kato–Temple two-sided certificate: the lower
# bound never exceeds the Ritz value, and (when converged) brackets it.
#
# NOTE: this gates CORRECTNESS (agreement), not speed. The kinetic-Fourier
# preconditioner's convergence advantage shows on stiff / soft-mode spectra
# (fine 3D grid, λ_min→0), which this small gapped anchor does not exercise;
# tuning the preconditioner + the shift-invert (MINRES) variant for soft
# points is done against a real soft-mode case, not here.

@testset "gate-2 eigensolver: LOBPCG ≡ Lanczos + Kato–Temple bracket" begin
    grid = make_grid(GridConfig(16, 10.0))
    interactions = InteractionParams(Dict(0 => 4.0, 1 => 0.3))
    r = find_ground_state_lbfgs(;
        grid, atom=Rb87, interactions, potential=HarmonicTrap(1.0),
        n_steps=400, tol=1e-11, initial_state=:polar, verbose=false,
    )
    ws = r.workspace
    ψ = copy(ws.state.psi)
    prm = constrained_hessian_params(ws, ψ)

    lanczos = trapped_bdg_lowest_eigenvalue(ws, ψ; niter=80, params=prm,
        rng=MersenneTwister(1))
    lobpcg = trapped_bdg_low_modes(ws, ψ; nev=1, block=6, max_iter=40, tol=1e-8,
        params=prm, rng=MersenneTwister(1))

    # Two independent eigensolvers, same operator → same λ_min.
    @test isapprox(lobpcg.λ[1], lanczos.λ_min; atol=5e-3)

    # Kato–Temple: lower bound ≤ Ritz value (upper bound), and the interval
    # is finite / sane.
    @test lanczos.λ_lower ≤ lanczos.λ_min + 1e-12
    @test isfinite(lanczos.λ_lower)
    @test lanczos.gap ≥ 0
    # LOBPCG per-mode lower bound also ≤ its Ritz value.
    @test lobpcg.λ_lower[1] ≤ lobpcg.λ[1] + 1e-12
end

# Regression for the convergence-flag fix. The OLD flag was purely RELATIVE
# (`ρ < tol_ritz·(|λ_min|+1e-10)`), so it false-negatived as λ_min→0 — exactly
# the soft / Goldstone modes the gate-2 verdict cares about. The flag is now
# width-based (`width < max(atol, tol_ritz·|λ_min|)`) with adaptive early-stop.
# A polar (c₁>0, q=0) GS breaks spin-rotation symmetry ⇒ a spin-Goldstone zero
# mode at λ_min≈0 — the case that used to misreport converged=false.
@testset "gate-2 convergence flag: width-based + adaptive + Goldstone" begin
    grid = make_grid(GridConfig(16, 10.0))
    interactions = InteractionParams(Dict(0 => 4.0, 1 => 0.3))
    r = find_ground_state_lbfgs(;
        grid, atom=Rb87, interactions, potential=HarmonicTrap(1.0),
        n_steps=500, tol=1e-10, initial_state=:polar, verbose=false,
    )
    ws = r.workspace
    ψ = copy(ws.state.psi)

    res = trapped_bdg_lowest_eigenvalue(ws, ψ; niter=300, atol=1e-6, rng=MersenneTwister(1))

    # Adaptive early-stop: a tiny 16-pt problem converges well before the cap.
    @test res.converged
    @test res.niter_used < 300
    # Kato–Temple bracket internal consistency.
    @test res.width ≥ 0
    @test res.λ_lower ≤ res.λ_min + 1e-12
    @test isapprox(res.λ_lower, res.λ_min - res.width; atol=1e-12)
    # converged ⇒ width under the absolute/relative threshold.
    @test res.width < max(1e-6, 1e-2 * abs(res.λ_min)) + 1e-12
    # goldstone flag is exactly "converged & |λ_min| < atol".
    @test res.goldstone == (res.converged && abs(res.λ_min) < 1e-6)
    # Polar GS spin Goldstone ⇒ λ_min≈0, tightly bracketed, flagged (the case
    # the pre-fix relative-only flag would have called converged=false).
    @test abs(res.λ_min) < 1e-5
    @test res.width < 1e-6
    @test res.goldstone
end

# A PRECONDITIONER CHANGES THE ITERATION, NEVER THE SPECTRUM. `precond=:combined`
# wires in `P_C = P_V^½ P_K P_V^½` (`solvers/preconditioner.jl`), which adds the
# real-space stiffness `V_trap + c₀n` that the kinetic-only inverse leaves alone —
# the stiffness that matters on the weak-field Eu manifold, where the block
# solver was measured returning λ_min = 1.68 with a Kato–Temple width of 5.7.
#
# The sharpest available correctness statement is that the two arms must return
# the SAME eigenvalues. If they disagree, one of them is not solving the problem
# it claims to: a metric cannot move an eigenvalue. Speed is NOT asserted here —
# it is a property of the state, and this small gapped fixture is not the state
# the option exists for.
@testset "preconditioner is a metric: :combined ≡ :kinetic on the spectrum" begin
    grid = make_grid(GridConfig(16, 10.0))
    interactions = InteractionParams(Dict(0 => 4.0, 1 => 0.3))
    r = find_ground_state_lbfgs(;
        grid, atom=Rb87, interactions, potential=HarmonicTrap(1.0),
        n_steps=400, tol=1e-11, initial_state=:polar, verbose=false,
    )
    ws = r.workspace
    ψ = copy(ws.state.psi)
    prm = constrained_hessian_params(ws, ψ)

    kin = trapped_bdg_low_modes(ws, ψ; nev=3, block=8, max_iter=60, tol=1e-9,
        params=prm, rng=MersenneTwister(3))
    comb = trapped_bdg_low_modes(ws, ψ; nev=3, block=8, max_iter=60, tol=1e-9,
        precond=:combined, params=prm, rng=MersenneTwister(3))

    @test all(kin.converged_modes)
    @test all(comb.converged_modes)
    for k in 1:3
        # Same eigenvalue, to well inside each arm's own certified width.
        @test isapprox(comb.λ[k], kin.λ[k];
            atol=max(1e-6, 2 * max(kin.widths[k], comb.widths[k])))
    end
    # …and the vectors span the same subspace: each combined Ritz vector is
    # inside the kinetic block's span. Eigenvalues agreeing while the vectors
    # differ would mean the two solved different problems and coincided.
    dV = prm.dV
    ipR(a, b) = real(sum(conj.(a) .* b)) * dV
    for v in comb.vectors
        proj2 = sum(ipR(v, u)^2 for u in kin.vectors)
        @test proj2 > 0.99 * ipR(v, v)
    end

    @test_throws ArgumentError trapped_bdg_low_modes(ws, ψ; precond=:bogus,
        params=prm, max_iter=1)
end
