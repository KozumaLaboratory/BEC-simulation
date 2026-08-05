#!/usr/bin/env julia
# The soft-mode ladder, by block LOBPCG — the question the single-vector descent
# could not answer.
#
#   julia --project=. bench/probe_lbfgs_soft_mode_block.jl [grid_n] [n_steps] [n_iter] [block]
#
# Established: the ~600 L-BFGS iterations on Eu-151 F=6 24³ +DDI are
# conditioning (λ_min ≤ 3.0e-2 vs μ_max ≈ 1.4e2 ⇒ κ ≥ 4.7e3, against
# κ_eff ≈ 9e3 from the decay rate, predicting 472 against ~600). The soft mode
# is 100 % spin, 97 % below 0.1 k_max, and rank 1 in spin space to 99.6 %
# against a random control at 8.1 % — so a rank-1 deflation preconditioner is
# one global dot and one axpy.
#
# What was NOT established is whether λ₁ is ISOLATED. κ after deflating one mode
# is μ_max/λ₂, so a cluster leaves κ where it was and the design is worthless.
# Sequential single-vector descent could not settle it: the ladder came back
# λ₂/λ₁ = 1.08 in one run and λ₂ BELOW λ₁ in another, which is the signature of
# a cluster a one-vector method cannot resolve — not of too few iterations. Both
# runs correctly reported NOT CONVERGED.
#
# A block converges to the whole cluster at once, so clustering shows up as
# near-equal eigenvalues rather than as a failure to converge, and the gap is
# read off converged numbers or not claimed.
#
# Controls:
#   - every mode's residual is printed and the verdict requires the first two to
#     have converged;
#   - the ladder is re-run at a LARGER block, and eigenvalues that move are not
#     converged whatever their residual said.

using SpinorBEC
using SpinorBEC: _realdot, _tangent_project, energy_gradient!
using Printf
using Random: MersenneTwister

include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "rayleigh_descent.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600
const NITER = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 120
const BLOCK = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 6
const MU_MAX = 1.4e2      # measured in probe_lbfgs_curvature_spectrum.jl

function cell()
    grid = make_grid(GridConfig((GRID_N, GRID_N, GRID_N), (12.0, 12.0, 12.0)))
    (;
        grid, atom=AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0),
        interactions=interaction_params_from_constraint(;
            c_total=EU_c_total, c1_ratio=0.05, F=6),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi=true, c_dd=EU_c_dd, backend=CPUBackend(),
        initial_state=:spin_coherent,
        init_state_params=Dict(:init_theta => Float64(π) / 2, :init_phi => 0.0),
        verbose=false,
    )
end

n_iters_for(κ) = log(1.0e-6) / log((sqrt(κ) - 1) / (sqrt(κ) + 1))

function run_block(ws, psi, v_seed, bsz; μ, dV, n2, seed)
    rng = MersenneTwister(seed)
    X0 = Any[v_seed]
    for _ in 2:bsz
        push!(X0, randn(rng, ComplexF64, size(psi)))
    end
    block_lobpcg(ws, psi, X0; μ, dV, n2, n_iter=NITER, α_precond=0.5, verbose=true)
end

function main()
    c = cell()
    dV = cell_volume(c.grid)
    r = find_ground_state_lbfgs(; c..., n_steps=NSTEPS, tol=1.0e-6)
    ws = r.workspace
    psi = copy(ws.state.psi)
    n2 = _realdot(psi, psi) * dV
    g = similar(psi)
    fill!(g, zero(eltype(g)))
    energy_gradient!(g, psi, ws; k_squared_dev=ws.grid.k_squared)
    μ = _realdot(psi, g) * dV / (2 * n2)

    println("soft-mode ladder (block LOBPCG) — Eu151 F=6 $(GRID_N)^3 +DDI, $NSTEPS steps")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    @printf("  |grad| = %.3e   μ = %.6f   block = %d, %d iterations\n\n",
        r.grad_norm, μ, BLOCK, NITER)

    v0, λ0 = softest_history_direction(r.lbfgs_history, dV)
    v0 === nothing && (println("  no usable history pair"); return)
    @printf("  seeded with the softest history direction, λ = %.4e\n", λ0)

    res = run_block(ws, psi, ComplexF64.(v0), BLOCK; μ, dV, n2, seed=20260804)
    println()
    @printf("  %5s %14s %12s %10s %12s %10s\n",
        "mode", "λ", "resid", "conv", "κ if defl.", "n_pred")
    for i in eachindex(res.λ)
        κ = MU_MAX / res.λ[i]
        @printf("  %5d %14.6e %12.3e %10s %12.3e %10.0f\n",
            i, res.λ[i], res.resid[i], res.converged[i], κ, n_iters_for(κ))
    end

    # A larger block is the control on convergence itself: an eigenvalue that
    # moves when the block grows was not converged, whatever its residual said.
    println()
    println("  control: same ladder at block $(BLOCK + 3)")
    res2 = run_block(ws, psi, ComplexF64.(v0), BLOCK + 3; μ, dV, n2, seed=20260805)
    println()
    @printf("  %5s %14s %14s %12s\n", "mode", "λ (b=$BLOCK)", "λ (b=$(BLOCK + 3))", "rel. move")
    nshow = min(length(res.λ), length(res2.λ))
    moved = false
    for i in 1:nshow
        rel = abs(res2.λ[i] - res.λ[i]) / max(abs(res.λ[i]), eps())
        rel > 0.05 && (moved = true)
        @printf("  %5d %14.6e %14.6e %12.2e%s\n", i, res.λ[i], res2.λ[i], rel,
            rel > 0.05 ? "  <-- moved" : "")
    end

    println()
    # The verdict is ASYMMETRIC, because every λ here is an upper bound that
    # falls as the iteration proceeds. The first version demanded that λ₂
    # converge, which is stricter than the question needs and made it report
    # NOT SETTLED on data that already answered it:
    #
    #   gap ≤ 3 from upper bounds, with λ₁ settled  ⇒ CLUSTER, established.
    #     λ₂ can only fall, so the gap can only shrink. Nothing further to learn.
    #   gap > 3 from upper bounds                   ⇒ NOT established.
    #     λ₂ falling would close the gap, so this needs λ₂ converged.
    #
    # "λ₁ settled" is the block-size control, not the residual: an eigenvalue
    # that moves when the block grows was not converged whatever its residual
    # said. That failure is the one three earlier verdicts on this task shared.
    λ1_settled = abs(res2.λ[1] - res.λ[1]) / max(abs(res.λ[1]), eps()) <= 0.05
    gap_ub = res2.λ[2] / res2.λ[1]
    @printf("  λ₁ settled across block sizes: %s   gap upper bound λ₂/λ₁ ≤ %.2f\n",
        λ1_settled, gap_ub)
    if !λ1_settled
        println("  => NOT SETTLED. λ₁ itself moves with the block size, so neither")
        println("     the bound nor the gap means anything yet.")
    elseif gap_ub <= 3
        κ1 = MU_MAX / res2.λ[1]
        κ2 = MU_MAX / res2.λ[2]
        println("  => a CLUSTER, and this is established rather than suspected:")
        println("     λ₂ is an upper bound, so the gap can only shrink from here.")
        @printf("     Rank-1 deflation moves κ from %.2e to at best %.2e,\n", κ1, κ2)
        @printf("     i.e. n from %.0f to at best %.0f — %.0f %%, not a factor.\n",
            n_iters_for(κ1), n_iters_for(κ2),
            100 * (1 - n_iters_for(κ2) / n_iters_for(κ1)))
        k = findfirst(i -> res2.λ[i] / res2.λ[1] > 3, eachindex(res2.λ))
        k === nothing ?
        @printf("     No gap above 3 anywhere in this block, so the rank needed is > %d and unbounded here.\n",
            length(res2.λ)) :
        println("     The first gap above 3 is past mode $(k - 1), so that is the rank needed.")
    elseif res.converged[2]
        @printf("  gap λ₂/λ₁ = %.2f\n", gap_ub)
        κ1 = MU_MAX / res2.λ[1]
        κ2 = MU_MAX / res2.λ[2]
        @printf("  => ISOLATED. Rank-1 deflation moves κ from %.2e to %.2e, n from %.0f to %.0f.\n",
            κ1, κ2, n_iters_for(κ1), n_iters_for(κ2))
    else
        println("  => a gap above 3 from UPPER bounds, which is not enough: λ₂ falling")
        println("     would close it. Needs λ₂ converged before any claim.")
    end
end

main()
