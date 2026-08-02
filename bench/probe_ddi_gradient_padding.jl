#!/usr/bin/env julia
# How far does the DDI gradient-padding fix move a ground state?
#
#   julia --project=. bench/probe_ddi_gradient_padding.jl solve   <out.jld2>
#   julia --project=. bench/probe_ddi_gradient_padding.jl compare <a.jld2> <b.jld2>
#
# `_ddi_energy` branches on `ws.ddi_padded`; `_grad_ddi!` did not, so with
# padding on — the YAML default since 2026-07-29 — L-BFGS accepted steps on the
# PADDED energy while taking its direction from the UNPADDED gradient. It still
# decreased the padded energy monotonically, but along the wrong direction, and
# it stopped where that direction stopped helping. The endpoint is therefore not
# a stationary point of the energy it reports, and the `grad_norm` it reports is
# the norm of a different operator's gradient.
#
# This measures the size of that: same spec, same solver, two revisions, one
# node. What moves is the converged ψ, its energy, and the reported residual.

# Top level, not inside the `if` below: a macro is resolved when the enclosing
# top-level expression is LOWERED, so `using Printf` in the same block comes too
# late and `@printf` is undefined — which is exactly how the first run of this
# probe died, in the arm that never touches the compare branch.
using JLD2
using Printf

const MODE = length(ARGS) >= 1 ? ARGS[1] : "solve"

if MODE == "compare"
    a = load(ARGS[2])
    b = load(ARGS[3])
    println("=== ", ARGS[2], "  vs  ", ARGS[3], " ===")
    @printf("%-26s %20s %20s %14s\n", "", "A", "B", "B - A")
    for k in ("energy", "energy_ddi", "grad_norm", "polarisation")
        @printf("%-26s %20.12g %20.12g %14.3e\n", k, a[k], b[k], b[k] - a[k])
    end
    for k in ("last_step", "n_line_search_evals", "stop_reason", "converged")
        @printf("%-26s %20s %20s\n", k, string(a[k]), string(b[k]))
    end

    # ψ difference, after removing the global phase: two solves of the same
    # functional may land on the same state up to exp(iθ), and that is not a
    # physical difference.
    pa, pb = a["psi"], b["psi"]
    ov = sum(conj.(pa) .* pb)
    aligned = pb .* conj(ov / abs(ov))
    rel = maximum(abs, aligned .- pa) / maximum(abs, pa)
    @printf("\n%-26s %14.3e   (phase-aligned, relative to max|psi|)\n", "max |dpsi|", rel)
    @printf("%-26s %14.3e\n", "1 - |<A|B>|", 1 - abs(ov) * a["dV"])
    exit(0)
end

using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

out = ARGS[2]

grid = make_grid(GridConfig((24, 24, 24), (12.0, 12.0, 12.0)))
atom = AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0)
ip = interaction_params_from_constraint(; c_total=EU_c_total, c1_ratio=0.05, F=6)

r = find_ground_state_lbfgs(;
    grid, atom,
    interactions=ip,
    zeeman=ZeemanParams(EU_p_weak, 0.0),
    potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
    enable_ddi=true, c_dd=EU_c_dd,
    ddi_padding=true, ddi_pad_factor=2,      # the configuration the bug lives in
    initial_state=:m_plus_F,
    n_steps=2000, tol=1.0e-8,
    verbose=false,
)

ws = r.workspace
ws.ddi_padded === nothing && error("padded DDI path is not active — probe is vacuous")
psi = Array(ws.state.psi)
dV = cell_volume(grid)
N = 3
n_pts = grid.config.n_points
D = ws.spin_matrices.system.n_components

decomp = energy_decomposition(ws)

# Density-weighted |<F>|/F: the rotation-invariant order parameter (<F_z> alone
# is not invariant at B = 0).
fx = zeros(Float64, n_pts)
fy = similar(fx)
fz = similar(fx)
SpinorBEC._compute_spin_density!(fx, fy, fz, psi, ws.spin_matrices, Val(D), N, n_pts)
n_dens = SpinorBEC.total_density(psi, N)
pol = sum(sqrt.(fx .^ 2 .+ fy .^ 2 .+ fz .^ 2)) / (atom.F * sum(n_dens))

@printf("energy               = %.12g\n", r.energy)
@printf("energy_ddi           = %.12g\n", decomp.ddi)
@printf("grad_norm            = %.6e\n", r.grad_norm)
@printf("polarisation |<F>|/F = %.9f\n", pol)
@printf("last_step            = %d   stop_reason = %s   converged = %s\n",
    r.last_step, r.stop_reason, r.converged)
@printf("line-search evals    = %d\n", r.n_line_search_evals)

jldsave(out;
    psi=psi, dV=dV,
    energy=r.energy, energy_ddi=decomp.ddi, grad_norm=r.grad_norm,
    polarisation=pol, last_step=r.last_step,
    n_line_search_evals=r.n_line_search_evals,
    stop_reason=String(r.stop_reason), converged=r.converged,
    commit=strip(read(`git -C $(joinpath(@__DIR__, "..")) rev-parse --short HEAD`, String)))
println("wrote $out")
