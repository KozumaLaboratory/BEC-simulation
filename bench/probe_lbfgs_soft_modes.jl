#!/usr/bin/env julia
# Is there a mode softer than anything L-BFGS sampled, and is it a symmetry?
#
#   julia --project=. bench/probe_lbfgs_soft_modes.jl [grid_n] [n_steps]
#
# Where this sits. The Eu-151 F=6 24³ +DDI cell takes ~600 iterations. Its decay
# rate implies κ_eff ≈ 9e3 while the curvature L-BFGS has sampled spans only
# κ ≈ 6e2 (`probe_lbfgs_curvature_spectrum.jl`). That factor of 15 does NOT
# decide anything, because κ_sampled is a lower bound: "the true spectrum is 15×
# wider than 20 directions revealed" and "the method loses 15×" fit it equally.
#
# What separates them is an UPPER bound on λ_min — does a mode 15× softer than
# the softest sampled (0.18) actually exist? That needs no eigendecomposition,
# only the right guesses, because a soft mode of a GP ground state is almost
# always an APPROXIMATE symmetry:
#
#   exact symmetry     → eigenvalue exactly 0, and the gradient is orthogonal to
#                        it, so the iterate never moves along it. Measured:
#                        orbit fraction 2e-17 (`probe_lbfgs_orbit_fraction.jl`).
#                        Invisible to the solver, and not the problem.
#   APPROXIMATE symmetry → eigenvalue ~ the size of the breaking. NOT orthogonal
#                        to the path. This is the candidate.
#
# The axial U(1) `e^{-iθ(L_z+F_z)}` is exact here. Spin rotations about x and y
# are broken only by the DDI and the quadratic Zeeman, both small at weak field
# — so they are exactly the shape a pseudo-Goldstone takes.
#
# So: take the Rayleigh quotient of the CONSTRAINED Hessian along each candidate
# generator, and compare with the sampled λ_min. A candidate at ~0.01 gives
# κ ~ 1e4, explains the count, and also explains why P_C fails — a collective
# spin rotation is diagonal in neither real nor Fourier space, and P_C is
# diagonal in both.
#
# Controls, because a small Rayleigh quotient proves nothing on its own:
#   - a RANDOM tangent direction, which must come back near the bulk;
#   - the exact generator (L_z+F_z), which must come back ~0 and confirms the
#     projection and the operator are doing what is claimed.

using SpinorBEC
using SpinorBEC: constrained_hessian_action, _realdot, CoriolisTerm, apply_operator!,
    _tangent_project
using Printf
using Random: MersenneTwister

include(joinpath(@__DIR__, "eu151_params.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600

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

"`-i·A·ψ` for a spin operator `A` given as a D×D matrix — the tangent to
`e^{-iθA}` at ψ."
function spin_generator(psi, A)
    D = size(A, 1)
    t = similar(psi)
    fill!(t, zero(eltype(t)))
    nd = ndims(psi)
    for c in 1:D, c2 in 1:D
        A[c, c2] == 0 && continue
        ic = ntuple(d -> d == nd ? (c:c) : Colon(), nd)
        i2 = ntuple(d -> d == nd ? (c2:c2) : Colon(), nd)
        @views t[ic...] .+= (-im * A[c, c2]) .* psi[i2...]
    end
    t
end

"`-i(L_z + F_z)ψ` — the EXACT symmetry, reusing the audited Coriolis L_z."
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
    # μ from the stationarity condition ⟨ψ,Hψ⟩/⟨ψ,ψ⟩; the constrained action
    # subtracts it, which is what makes ψ itself a null direction rather than
    # the stiffest one.
    g = similar(psi)
    fill!(g, zero(eltype(g)))
    E = energy_gradient!(g, psi, ws; k_squared_dev=ws.grid.k_squared)
    μ = _realdot(psi, g) * dV / (2 * n2)

    println("soft-mode probe — Eu151 F=6 $(GRID_N)^3 +DDI, after $NSTEPS steps")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    @printf("  |grad| = %.3e   E = %.10f   μ = %.6f\n\n", r.grad_norm, r.energy, μ)

    sm = ws.spin_matrices
    cands = Pair{String, Any}[
        "spin F_x (approx)" => spin_generator(psi, Matrix(sm.Fx)),
        "spin F_y (approx)" => spin_generator(psi, Matrix(sm.Fy)),
        "spin F_z (approx)" => spin_generator(psi, Matrix(sm.Fz)),
        "axial L_z+F_z (EXACT)" => axial_generator(psi, ws),
        "global phase (EXACT)" => im .* psi,
    ]
    rng = MersenneTwister(20260803)
    for k in 1:2
        v = randn(rng, ComplexF64, size(psi))
        push!(cands, "random tangent $k [control]" => v)
    end

    @printf("  %-28s %13s %13s\n", "direction", "Rayleigh λ", "|P v|/|v|")
    for (name, v) in cands
        pv = _tangent_project(v, psi, dV, n2)
        nv = sqrt(_realdot(v, v) * dV)
        npv = sqrt(_realdot(pv, pv) * dV)
        if npv / max(nv, eps()) < 1.0e-8
            @printf("  %-28s %13s %13.3e   (removed by the constraint)\n",
                name, "—", npv / nv)
            continue
        end
        Hv = constrained_hessian_action(ws, psi, pv; μ, dV, n2, ε=1.0e-5, order=4)
        λ = _realdot(pv, Hv) * dV / (npv^2)
        @printf("  %-28s %13.4e %13.3e\n", name, λ, npv / nv)
        flush(stdout)
    end

    println()
    println("  Sampled λ_min over the L-BFGS history was 1.8e-01, and the decay")
    println("  rate implies an effective λ_min about 15x below that.")
    println("  A candidate there, with the random controls in the bulk, identifies")
    println("  the soft mode. The two EXACT generators must come back ~0 — if they")
    println("  do not, the projection or the operator is wrong and nothing above")
    println("  means anything.")
end

main()
