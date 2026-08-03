#!/usr/bin/env julia
# An UPPER bound on λ_min of the constrained GP Hessian, by minimising the
# Rayleigh quotient directly.
#
#   julia --project=. bench/probe_lbfgs_lambda_min_bound.jl [grid_n] [n_steps] [n_iter]
#
# The question this closes. Eu-151 F=6 24³ +DDI takes ~600 L-BFGS iterations;
# its decay rate implies κ_eff ≈ 9e3 while the curvature the method has sampled
# spans κ ≈ 6e2. Those differ by 15×, and nothing so far separates
#
#   (a) the true spectrum IS that wide — κ_sampled is only a lower bound, since
#       L-BFGS samples curvature along the 20 directions it happens to hold — so
#       conditioning explains the count and a preconditioner is the lever;
#   (b) the spectrum is κ ≈ 6e2 and the METHOD loses 15×, in which case no
#       preconditioner will help and the cause is in the two-loop, the line
#       search or the history handling.
#
# Comparing κ_eff against κ_sampled cannot separate them, because κ_sampled is a
# bound. Guessing soft directions did not either: spin rotations about x and y
# come back at 0.23, level with the sampled λ_min of 0.18, and the exact axial
# generator at 1.3e-4 ≈ 0 as it must (`probe_lbfgs_soft_modes.jl`). But five
# guesses failing is weak evidence that nothing is there.
#
# So stop guessing. `λ_min ≤ ⟨v,Hv⟩/⟨v,v⟩` for ANY v in the constrained tangent
# space, so minimising that quotient gives a genuine upper bound whatever the
# eigenvector looks like. This needs no eigensolver — the previously recorded
# block on λ_min certification was about converging a whole spectrum, and one
# bound does not need that.
#
#   drops toward ~1e-2  ⇒ the soft mode is real, (a) holds, and the minimiser
#                          itself says what it is.
#   stalls near ~1.8e-1 ⇒ the spectrum really is κ ≈ 6e2 and (b) holds.
#
# Controls, because a descent that goes nowhere and a descent that has converged
# look identical from the last value alone:
#   - the quotient is printed every iteration, so a stall is visible as a stall;
#   - the run starts from a RANDOM v (bulk, ~60) so the descent has to travel;
#   - the exact axial generator is evaluated at the end and must still be ~0,
#     confirming the projection did not drift during the descent.

using SpinorBEC
using SpinorBEC: constrained_hessian_action, _realdot, _tangent_project,
    energy_gradient!, CoriolisTerm, apply_operator!
using Printf
using Random: MersenneTwister

include(joinpath(@__DIR__, "eu151_params.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600
const NITER = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 60

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

function axial_generator(psi, ws)
    lz = similar(psi)
    fill!(lz, zero(eltype(lz)))
    apply_operator!(lz, CoriolisTerm(1.0), ws, psi)
    lz .*= -1
    sys = ws.spin_matrices.system
    F, D = sys.F, sys.n_components
    nd = ndims(psi)
    t = similar(psi)
    for c in 1:D
        m = Float64(F - (c - 1))
        idx = ntuple(d -> d == nd ? (c:c) : Colon(), nd)
        @views t[idx...] .= lz[idx...] .+ m .* psi[idx...]
    end
    t .*= -im
    t
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

    println("λ_min upper-bound probe — Eu151 F=6 $(GRID_N)^3 +DDI, after $NSTEPS steps")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    @printf("  |grad| = %.3e   μ = %.6f   descent iterations = %d\n\n", r.grad_norm, μ, NITER)

    H(v) = constrained_hessian_action(ws, psi, v; μ, dV, n2, ε=1.0e-5, order=4)
    proj(v) = _tangent_project(v, psi, dV, n2)
    rq(v, Hv) = _realdot(v, Hv) * dV / (_realdot(v, v) * dV)

    # Start from the SOFTEST direction L-BFGS already found, not a random one.
    # The first version started random (q ≈ 60) and after 60 iterations had
    # reached 1.45 while still falling 8 % per step — it had not even got down
    # to the sampled 0.18, so it could say nothing, and its fixed-iteration
    # verdict said "no soft mode" anyway. From the history the question becomes
    # the one that matters: can the quotient go BELOW what L-BFGS sampled?
    rng = MersenneTwister(20260803)
    v = let hist = r.lbfgs_history
        best = nothing
        bestλ = Inf
        if hist !== nothing && !isempty(hist[3])
            s_h, y_h, _ = hist
            for i in eachindex(s_h)
                ss = _realdot(s_h[i], s_h[i]) * dV
                sy = _realdot(s_h[i], y_h[i]) * dV
                (ss > 0 && sy > 0) || continue
                λi = sy / ss
                λi < bestλ && (bestλ = λi; best = s_h[i])
            end
        end
        if best === nothing
            @printf("  (no usable history pair; starting random)\n")
            proj(randn(rng, ComplexF64, size(psi)))
        else
            @printf("  starting from the softest history direction, λ = %.4e\n\n", bestλ)
            proj(ComplexF64.(best))
        end
    end
    v ./= sqrt(_realdot(v, v) * dV)

    # Steepest descent on the Rayleigh quotient: ∇q = 2(Hv − q v)/⟨v,v⟩. The
    # step is chosen by an exact 1-D minimisation over the 2-D space {v, w},
    # which is the cheapest thing that cannot stall for want of a step size —
    # a fixed step would make a stall unreadable, and reading the stall is the
    # entire point.
    @printf("  %5s %14s %12s\n", "iter", "Rayleigh q", "|resid|")
    Hv = H(v)
    qv = rq(v, Hv)
    for it in 1:NITER
        w = proj(Hv .- qv .* v)
        nw = sqrt(_realdot(w, w) * dV)
        (it % 5 == 1 || it == NITER) && @printf("  %5d %14.6e %12.3e\n", it - 1, qv, nw)
        flush(stdout)
        nw < 1.0e-12 && break
        w ./= nw
        Hw = H(w)
        # 2×2 Rayleigh-Ritz in span{v, w}: exact minimiser of the quotient in
        # that plane, so the descent cannot be limited by a step-size guess.
        a = qv
        b = _realdot(v, Hw) * dV
        d = _realdot(w, Hw) * dV
        θ = 0.5 * atan(2b, a - d)
        cs, sn = cos(θ), sin(θ)
        v1 = cs .* v .+ sn .* w
        v2 = -sn .* v .+ cs .* w
        H1 = cs .* Hv .+ sn .* Hw
        H2 = -sn .* Hv .+ cs .* Hw
        q1, q2 = rq(v1, H1), rq(v2, H2)
        if q1 <= q2
            v, Hv, qv = v1, H1, q1
        else
            v, Hv, qv = v2, H2, q2
        end
        nv = sqrt(_realdot(v, v) * dV)
        v ./= nv
        Hv ./= nv
    end

    ax = proj(axial_generator(psi, ws))
    λax = rq(ax, H(ax))
    ov = abs(_realdot(ax, v) * dV) /
         sqrt(_realdot(ax, ax) * dV * _realdot(v, v) * dV)

    println()
    @printf("  λ_min ≤ %.6e\n", qv)
    @printf("  sampled λ_min over the L-BFGS history was 1.8e-01\n")
    @printf("  exact axial generator, re-checked here: %.4e  [must stay ~0]\n", λax)
    @printf("  overlap of the minimiser with that exact generator: %.4f\n", ov)
    println()
    # The verdict requires CONVERGENCE, not a step count. The first version
    # asked only `qv < 0.05` after a fixed 60 iterations and printed
    # "no such mode found" while the quotient was still falling 8 % per step —
    # reading a non-converged state as an answer.
    resid = let w = proj(Hv .- qv .* v)
        sqrt(_realdot(w, w) * dV)
    end
    @printf("  final residual |Hv - qv| = %.3e   (%.1f %% of q)\n", resid,
        100 * resid / abs(qv))
    if resid > 0.2 * abs(qv)
        println()
        println("  => NOT CONVERGED. The descent is still moving, so this bound is")
        println("     only where it had got to, not lambda_min. No verdict.")
    elseif qv < 0.05
        println("  => a mode far softer than anything L-BFGS sampled EXISTS.")
        println("     Conditioning explains the ~600 iterations, and flattening")
        println("     this mode is the lever. Check the overlap above first: a")
        println("     minimiser that has simply found the exact symmetry is not")
        println("     a soft mode, it is the null space leaking through.")
    else
        println("  => no such mode found. The spectrum is about what the history")
        println("     already showed, so the method is losing ~15x against its own")
        println("     conditioning and a preconditioner is NOT the lever.")
    end
end

main()
