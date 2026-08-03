#!/usr/bin/env julia
# What IS the soft mode, and therefore what must a preconditioner diagonalise?
#
#   julia --project=. bench/probe_lbfgs_soft_mode_structure.jl [grid_n] [n_steps] [n_iter]
#
# Established: the ~600 L-BFGS iterations on Eu-151 F=6 24³ +DDI are
# conditioning. `λ_min ≤ 3.0e-2` against `μ_max ≈ 1.4e2` gives `κ ≥ 4.7e3`,
# within 2× of the `κ_eff ≈ 9e3` the decay rate implies, predicting 472
# iterations against ~600 observed. The method is achieving what its
# conditioning permits (`probe_lbfgs_lambda_min_bound.jl`).
#
# So preconditioning is the lever, and P_C — diagonal in real space AND in
# Fourier space — is the wrong one, measured 40× worse. This asks what the
# right one would have to be, by looking at the mode instead of guessing again.
# Guessing has already failed twice here: the gauge-alignment idea and the
# pseudo-Goldstone hypothesis were both mine and both died on measurement.
#
# Three decompositions, each chosen because it maps onto a class of
# preconditioner:
#
#   SPIN vs DENSITY   At each voxel, split v(x) against ψ(x) in C^D. The
#                     component parallel to ψ changes amplitude and local phase
#                     — a density/superfluid mode, which a real-space diagonal
#                     P_V acts on. The perpendicular component rotates the local
#                     spinor — a SPIN mode, which no real-space diagonal can
#                     see, because it is diagonal in x and structureless in the
#                     13 spin components.
#   k SPECTRUM        Long-wavelength weight says a Fourier-diagonal P_K could
#                     reach it; weight spread over k says it could not.
#   COMPONENT WEIGHT  Which m states carry the mode. Concentration in a few
#                     says a preconditioner in spin space needs only those.
#
# Controls throughout, since "concentrated at low k" means nothing absolute:
# every metric is also reported for ψ itself and for a random tangent vector,
# and the exact axial generator's overlap is printed so a mode that is merely
# the null space leaking through would be visible as such.

using SpinorBEC
using SpinorBEC: _realdot, _tangent_project, energy_gradient!, CoriolisTerm,
    apply_operator!
using Printf
using FFTW: fft
using LinearAlgebra: eigen, Hermitian
using Random: MersenneTwister

include(joinpath(@__DIR__, "eu151_params.jl"))
include(joinpath(@__DIR__, "rayleigh_descent.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const NSTEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600
const NITER = length(ARGS) >= 3 ? parse(Int, ARGS[3]) : 400

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

"Weight of `v` parallel / perpendicular to `psi` in the LOCAL spin space."
function spin_vs_density(v, psi)
    n = size(psi)
    D = n[end]
    sp = reshape(psi, :, D)
    sv = reshape(v, :, D)
    par = 0.0
    per = 0.0
    @inbounds for i in axes(sp, 1)
        nrm = 0.0
        for c in 1:D
            nrm += abs2(sp[i, c])
        end
        nrm == 0 && continue
        ip = zero(ComplexF64)
        for c in 1:D
            ip += conj(sp[i, c]) * sv[i, c]
        end
        # |⟨ψ̂,v⟩|² is the parallel weight; the rest rotates the local spinor.
        p = abs2(ip) / nrm
        tot = 0.0
        for c in 1:D
            tot += abs2(sv[i, c])
        end
        par += p
        per += max(tot - p, 0.0)
    end
    (par, per)
end

"Fraction of |v̂(k)|² below `frac`·k_max, per spatial dimension count."
function low_k_weight(v, grid, frac)
    n = size(v)
    N = length(n) - 1
    D = n[end]
    kmax2 = maximum(grid.k_squared)
    lo = 0.0
    tot = 0.0
    for c in 1:D
        idx = ntuple(d -> d == N + 1 ? c : Colon(), N + 1)
        vc = fft(v[idx...])
        @inbounds for I in CartesianIndices(size(vc))
            w = abs2(vc[I])
            tot += w
            grid.k_squared[I] <= frac^2 * kmax2 && (lo += w)
        end
    end
    lo / tot
end

function component_weights(v)
    n = size(v)
    D = n[end]
    N = length(n) - 1
    [sum(abs2, v[ntuple(d -> d == N + 1 ? c : Colon(), N + 1)...]) for c in 1:D]
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

"""
    spin_rank(v) → (fractions, u)

Eigenvalue fractions of `M = Σ_x v(x)v(x)†`, the D×D spin-space correlation of
the mode, and its leading spinor.

This is the sizing question for the replacement preconditioner. If the mode is
`f(x)·u` for one fixed `u ∈ C^D`, `M` is rank 1 and a SINGLE global D×D
operator preconditions it — 13×13 applied per voxel, negligible against a 25 ms
iteration. If the weight is spread over several eigenvalues the spin structure
varies in space and the operator has to be built per voxel, which is 169
complex multiplies per grid point and no longer free.
"""
function spin_rank(v)
    n = size(v)
    D = n[end]
    sv = reshape(v, :, D)
    M = zeros(ComplexF64, D, D)
    @inbounds for i in axes(sv, 1), a in 1:D, b in 1:D
        M[a, b] += sv[i, a] * conj(sv[i, b])
    end
    F = eigen(Hermitian(M))
    ev = sort(real.(F.values); rev=true)
    u = F.vectors[:, argmax(real.(F.values))]
    (ev ./ sum(ev), u)
end

function report(name, v, psi, grid)
    par, per = spin_vs_density(v, psi)
    tot = par + per
    w = component_weights(v)
    w ./= sum(w)
    top = sortperm(w; rev=true)[1:3]
    @printf("  %-22s spin %5.1f %%  density %5.1f %%   k<0.1 %5.1f %%  k<0.3 %5.1f %%\n",
        name, 100 * per / tot, 100 * par / tot,
        100 * low_k_weight(v, grid, 0.1), 100 * low_k_weight(v, grid, 0.3))
    @printf("  %-22s top components m = %s  (%.0f %%, %.0f %%, %.0f %%)\n", "",
        join(["$(7 - c)" for c in top], ", "), 100w[top[1]], 100w[top[2]], 100w[top[3]])
    fr, u = spin_rank(v)
    uw = abs2.(u)
    ut = sortperm(uw; rev=true)[1:3]
    @printf("  %-22s spin rank: λ₁ %.1f %%  λ₁₂ %.1f %%  λ₁₂₃ %.1f %%   leading spinor m = %s\n",
        "", 100fr[1], 100 * sum(fr[1:2]), 100 * sum(fr[1:3]),
        join(["$(7 - c)" for c in ut], ", "))
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

    println("soft-mode structure — Eu151 F=6 $(GRID_N)^3 +DDI, after $NSTEPS steps")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    @printf("  |grad| = %.3e   μ = %.6f\n\n", r.grad_norm, μ)

    v0, λ0 = softest_history_direction(r.lbfgs_history, dV)
    v0 === nothing && (println("  no usable history pair — cannot start"); return)
    @printf("  starting from the softest history direction, λ = %.4e\n", λ0)
    res = rayleigh_descent(ws, psi, ComplexF64.(v0); μ, dV, n2, n_iter=NITER)
    @printf("\n  λ_min ≤ %.6e   resid %.3e (%.0f %% of q)   converged=%s\n",
        res.q, res.resid, 100 * res.resid / abs(res.q), res.converged)

    ax = _tangent_project(axial_generator(psi, ws), psi, dV, n2)
    ov = abs(_realdot(ax, res.v) * dV) /
         sqrt(_realdot(ax, ax) * dV * _realdot(res.v, res.v) * dV)
    @printf("  overlap with the exact axial generator: %.4f", ov)
    println(ov > 0.5 ? "   <-- this is the null space, not a soft mode" : "")
    println()

    rng = MersenneTwister(20260803)
    rnd = _tangent_project(randn(rng, ComplexF64, size(psi)), psi, dV, n2)
    report("SOFT MODE", res.v, psi, c.grid)
    report("psi [reference]", psi, psi, c.grid)
    report("random [control]", rnd, psi, c.grid)

    println()
    println("  Reading it: a mode that is mostly SPIN cannot be reached by a")
    println("  real-space diagonal preconditioner, which is what P_V is, however")
    println("  alpha is chosen — it is structureless across the 13 components.")
    println("  Low-k weight far above the random control means P_K's Fourier")
    println("  diagonal does see it; weight spread like the control means it does")
    println("  not. Together those say which factor of P_C = P_V^1/2 P_K P_V^1/2")
    println("  is failing, and whether the replacement has to act in spin space.")
    println()
    println("  And `spin rank` sizes the replacement. λ₁ near 100 % means the mode is")
    println("  f(x)·u for ONE fixed spinor, so a single global 13×13 preconditions it")
    println("  and costs nothing. Weight spread across eigenvalues means the spin")
    println("  structure varies in space and the operator must be built per voxel —")
    println("  169 complex multiplies per grid point, which is no longer free.")
end

main()
