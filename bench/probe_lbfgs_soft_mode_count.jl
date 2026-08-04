#!/usr/bin/env julia
# Is the soft mode ISOLATED, or one of a cluster?
#
#   julia --project=. bench/probe_lbfgs_soft_mode_count.jl [grid_n] [n_steps] [n_iter] [n_modes]
#
# The soft mode is rank 1 in spin space to 99.6 % (against 8.1 % for a random
# control, which is 1/13 exactly), so it is `f(x)·u` for a single fixed spinor.
# That makes the natural preconditioner a rank-1 deflation,
#
#     P = I + (1/λ₁ − 1)·v₁v₁†
#
# — one global dot and one axpy, free against a 25 ms iteration.
#
# Free only if it WORKS, and it works only if λ₁ is isolated. κ after deflating
# one mode is μ_max/λ₂, so a cluster at λ₁ leaves κ where it was and the whole
# design collapses. That is the sizing question, and it is the one I have twice
# skipped and twice been wrong about by ~4×.
#
# Deflate and re-descend. λ₂ ≫ λ₁ ⇒ rank 1 is enough and κ drops by λ₂/λ₁.
# λ₂ ≈ λ₁ ⇒ count how many before the gap, which is the rank the preconditioner
# needs.
#
# Deflation is inside the projector, not applied after each step: a descent that
# drifts back into the deflated subspace between iterations returns λ₁ again and
# would read as a cluster. The overlap of each new mode with all previous ones
# is printed as the check on exactly that.

using SpinorBEC
using SpinorBEC: _realdot, _tangent_project, energy_gradient!
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "rayleigh_descent.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600
const NITER = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 300
const NMODES = length(ARGS) >= 4 ? parse(Int, ARGS[4]) : 4

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

    println("soft-mode count — Eu151 F=6 $(GRID_N)^3 +DDI, after $NSTEPS steps")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    @printf("  |grad| = %.3e   μ = %.6f   %d modes, %d descent iterations each\n\n",
        r.grad_norm, μ, NMODES, NITER)

    v0, λ0 = softest_history_direction(r.lbfgs_history, dV)
    v0 === nothing && (println("  no usable history pair"); return)
    @printf("  softest history direction: λ = %.4e\n\n", λ0)

    modes = Any[]
    λs = Float64[]
    convs = Bool[]
    for k in 1:NMODES
        start = k == 1 ? ComplexF64.(v0) : ComplexF64.(v0) .+ 0.1 .* randn(ComplexF64, size(psi))
        res = rayleigh_descent(ws, psi, start; μ, dV, n2, n_iter=NITER,
            verbose=false, deflate=Tuple(modes))
        ovs = [abs(_realdot(u, res.v) * dV) /
               sqrt(_realdot(u, u) * dV * _realdot(res.v, res.v) * dV) for u in modes]
        push!(modes, res.v)
        push!(λs, res.q)
        push!(convs, res.converged)
        @printf("  mode %d:  λ ≤ %.6e   resid %.2e (%3.0f %% of λ)  converged=%-5s  max overlap with earlier %.1e\n",
            k, res.q, res.resid, 100 * res.resid / abs(res.q), res.converged,
            isempty(ovs) ? 0.0 : maximum(ovs))
        flush(stdout)
    end

    println()
    @printf("  λ ladder: %s\n", join([@sprintf("%.3e", x) for x in λs], "  "))
    if length(λs) >= 2
        gaps = [λs[i + 1] / λs[i] for i in 1:(length(λs) - 1)]
        @printf("  ratios:   %s\n", join([@sprintf("%.2f", x) for x in gaps], "        "))
        println()
        μ_max = 1.4e2   # measured in probe_lbfgs_curvature_spectrum.jl
        for (i, λ) in enumerate(λs)
            @printf("  deflating %d mode(s) leaves κ ≈ %.2e  ⇒  n ≈ %.0f\n",
                i - 1, μ_max / λ,
                log(1.0e-6) / log((sqrt(μ_max / λ) - 1) / (sqrt(μ_max / λ) + 1)))
        end
        println()
        # The verdict consults `converged`. The first run printed ISOLATED off a
        # 6.08 ratio between two bounds at 150-200 % residual -- both are UPPER
        # bounds, so the ratio can move either way and establishes nothing. A
        # verdict that ignores its own convergence flag is the third of these I
        # have written on this task.
        if !all(convs[1:2])
            println("  => NOT CONVERGED (modes 1-2). The ratio is between two upper")
            println("     bounds that are still moving, so it establishes nothing.")
        elseif gaps[1] > 3
            println("  => ISOLATED. A rank-1 deflation is enough and κ drops by that ratio.")
        else
            println("  => a CLUSTER. Rank 1 buys almost nothing; the preconditioner needs")
            println("     as many directions as it takes to reach the first real gap above.")
        end
    end
end

main()
