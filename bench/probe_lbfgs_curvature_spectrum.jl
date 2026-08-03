#!/usr/bin/env julia
# What spectrum does L-BFGS actually see on this problem?
#
#   julia --project=. bench/probe_lbfgs_curvature_spectrum.jl [grid_n]
#
# Eu-151 F=6 24³ +DDI takes ~600 iterations and it is now unclear why.
# Preconditioning it with P_C measured 40× WORSE; the recorded reason (a
# collective Goldstone) does not survive measurement — the step is orthogonal
# to the orbit to machine precision (`probe_lbfgs_orbit_fraction.jl`). So the
# flat direction is not in the iterate path, and what is left is the ordinary
# conditioning of the Hessian on the orthogonal complement.
#
# That is directly observable without touching the solver, because L-BFGS
# already forms it. For each stored curvature pair,
#
#     λ_s = ⟨s,y⟩/⟨s,s⟩     Rayleigh quotient of the Hessian along s
#     μ_y = ⟨y,y⟩/⟨s,y⟩     ≥ λ_s, and equal only when s is an eigenvector
#
# bracket the curvature the method has sampled. Their spread across a run is
# the effective condition number κ the method is fighting.
#
# The returned `lbfgs_history` carries the last `m` pairs, so a solve at
# `n_steps = k` gives 20 samples of the spectrum AS SEEN AT step k, for the
# price of one solve. Sampling several k shows whether the conditioning is
# stationary or degrades as the state converges.
#
# And it makes a falsifiable prediction rather than just a table. For a
# CG/quasi-Newton method the asymptotic rate is (√κ−1)/(√κ+1) per iteration, so
# reaching |∇E| ~ 1e-6 from ~1 needs about
#
#     n ≈ ln(1e-6) / ln((√κ−1)/(√κ+1))
#
# iterations. If that lands near the observed count, the conditioning IS the
# explanation and a preconditioner that flattens THIS spectrum is the lever. If
# it is orders away, the count has another cause and preconditioning is not it.

using SpinorBEC
using SpinorBEC: _realdot
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const GRID_N = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const STAGES = [50, 100, 200, 400, 600]

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

q(v, p) = (s = sort(v); s[clamp(round(Int, p * length(s)), 1, length(s))])

"Predicted iterations to cut the gradient by `drop` at condition number κ."
function predicted_iters(κ, drop=1.0e-6)
    κ <= 1 && return 0.0
    r = (sqrt(κ) - 1) / (sqrt(κ) + 1)
    log(drop) / log(r)
end

function main()
    c = cell()
    dV = cell_volume(c.grid)
    println("curvature-spectrum probe — Eu151 F=6 $(GRID_N)^3 +DDI")
    println("commit: ", strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
    println()
    @printf("  %6s %5s %11s %11s %11s %11s %10s %10s\n",
        "step", "pairs", "λ min", "λ med", "λ max", "μ max", "κ", "n_pred")

    for k in STAGES
        r = find_ground_state_lbfgs(; c..., n_steps=k, tol=0.0)
        hist = r.lbfgs_history
        (hist === nothing || isempty(hist[3])) && (@printf("  %6d   (empty history)\n", k); continue)
        s_h, y_h, _ = hist
        λ = Float64[]
        μ = Float64[]
        for i in eachindex(s_h)
            s, y = s_h[i], y_h[i]
            ss = _realdot(s, s) * dV
            sy = _realdot(s, y) * dV
            yy = _realdot(y, y) * dV
            (ss > 0 && sy > 0) || continue      # a non-curvature pair; the
            # driver discards these, and they carry no spectrum information
            push!(λ, sy / ss)
            push!(μ, yy / sy)
        end
        isempty(λ) && (@printf("  %6d   (no positive-curvature pairs)\n", k); continue)
        κ = maximum(μ) / minimum(λ)
        @printf("  %6d %5d %11.4e %11.4e %11.4e %11.4e %10.3e %10.0f\n",
            k, length(λ), minimum(λ), q(λ, 0.5), maximum(λ), maximum(μ),
            κ, predicted_iters(κ))
        flush(stdout)
    end

    println()
    println("  λ = ⟨s,y⟩/⟨s,s⟩ and μ = ⟨y,y⟩/⟨s,y⟩ bracket the sampled curvature;")
    println("  κ = μ_max/λ_min is the conditioning the method is actually fighting,")
    println("  and n_pred = ln(1e-6)/ln((√κ−1)/(√κ+1)) is what that κ predicts.")
    println("  Compare n_pred with the ~600 observed. Agreement means conditioning")
    println("  IS the explanation and flattening THIS spectrum is the lever;")
    println("  orders apart means the count has another cause.")
end

main()
