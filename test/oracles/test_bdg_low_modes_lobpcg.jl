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
