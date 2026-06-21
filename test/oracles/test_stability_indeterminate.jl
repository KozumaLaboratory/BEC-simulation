# StabilitySpec — the three-valued gate must REFUSE rather than over-claim.
#
# Replays the failure class of
# `mistake_stability_verdict_from_nonstationary_point`: a confident λ_min
# read off a ψ that was not stationary / not eigensolver-converged. The
# gate now returns :indeterminate (not a false PASS/FAIL) in exactly those
# cases, and abstains overall while the trapped dynamical BdG axis is
# unbuilt — a half-built verifier does not over-claim.
#
#   1. non-stationary ψ        ⇒ stationarity axis :indeterminate
#   2. converged GS, full iters ⇒ stationary + energetic min, overall
#                                 :indeterminate (dynamical axis abstains)
#   3. too few Lanczos iters    ⇒ energetic :indeterminate (Ritz residual)

using Test
using SpinorBEC
using Random: MersenneTwister

@testset "StabilitySpec — three-valued gate refuses to over-claim" begin
    n = 24
    box = 12.0
    grid = make_grid(GridConfig((n,), (box,)))
    atom = Rb87
    interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.1))
    potential = HarmonicTrap((1.0,))
    zeeman = ZeemanParams(0.0, 0.5)        # q>0 gaps spin modes ⇒ clean minimum
    ws = make_workspace(;
        grid, atom, interactions, zeeman, potential,
        sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
    )

    @testset "non-stationary ψ ⇒ :indeterminate (no false verdict)" begin
        ψ = zeros(ComplexF64, n, 3)
        for i in 1:n
            ψ[i, 2] = exp(-grid.x[1][i]^2 / (2 * 3.0^2))   # wrong width
        end
        ψ ./= sqrt(sum(abs2, ψ) * cell_volume(grid))
        res = check(StabilitySpec(), ws, ψ; rng=MersenneTwister(1))
        @test res.status === :indeterminate
        @test res.status !== :pass
        stat = first(p.second for p in res.details if p.first === :stationarity)
        @test stat.status === :indeterminate
        @test stat.got > StabilitySpec().ε_stat
    end

    # Converged GS via a SHARED ws (solved in-place) ⇒ the gate sees the
    # exact same Hamiltonian the optimiser minimised.
    seed = zeros(ComplexF64, n, 3)
    for i in 1:n
        seed[i, 2] = exp(-grid.x[1][i]^2 / 2)
    end
    seed ./= sqrt(sum(abs2, seed) * cell_volume(grid))
    find_ground_state_lbfgs(;
        ws_init=ws, psi_init=seed, n_steps=600, tol=1e-10, verbose=false)
    ψ_gs = copy(ws.state.psi)        # atomic return sets ws.state.psi = GS

    @testset "converged GS ⇒ stationary + energetic min, ABSTAINS overall" begin
        res = check(StabilitySpec(), ws, ψ_gs; rng=MersenneTwister(1))
        stat = first(p.second for p in res.details if p.first === :stationarity)
        ener = first(p.second for p in res.details if p.first === :energetic)
        dyn = first(p.second for p in res.details if p.first === :dynamical)
        @test stat.status === :pass
        @test ener.status === :pass
        @test ener.converged
        @test ener.λ_min > -StabilitySpec().λ_tol
        @test dyn.status === :indeterminate       # trapped dynamical BdG unbuilt
        @test res.status === :indeterminate       # abstains, does not over-claim
    end

    @testset "too few Lanczos iters ⇒ energetic :indeterminate (self-cert)" begin
        res = check(StabilitySpec(; niter=1), ws, ψ_gs; rng=MersenneTwister(1))
        ener = first(p.second for p in res.details if p.first === :energetic)
        @test !ener.converged                     # Ritz residual ≫ tol at niter=1
        @test ener.status === :indeterminate
    end
end
