# Where is the ITP stability limit, as a function of c₀?
#
# `ground_state_preflight` refuses nothing on dt stability, and says why: the
# limit was bracketed at ONE point — between 1e-3 and 2e-3 at c₀ ≈ 34465, where
# the SHIPPED dt = 2e-3 diverges. One point is not a criterion, so the gate that
# sits in front of every ground state cannot act on the most consequential
# parameter a caller picks.
#
# This measures the limit across the production c₀ range and is meant to feed that
# gate. The axis is `c1_ratio`, because that is the axis production scans
# (`runs/eu_gs_phase_c1_B_kappa`: r ∈ [−0.024, +0.048]) and c₀ = c_total/(1 + 36r)
# spans 20× across it — 34465 at the bottom, 1674 at the top. Staying on the real
# axis means the answer maps onto real configs without a translation step.
#
# DIVERGENCE, NOT CONVERGENCE, is the question, and that makes this cheap: a
# blow-up appears in a few hundred steps, so no cell needs to converge and none is
# waited for. The earlier boundary sweep was killed twice at the wall clock partly
# because it asked for more than the question needed.
#
# WHAT WOULD MAKE THE RESULT UNUSABLE, stated first:
#   * a non-monotone limit in c₀ — then it is not a stability threshold in the
#     scale of the interaction and no single criterion covers it
#   * a limit that does not move at all across a 20× c₀ span — then c₀ is not what
#     sets it, and the preflight must key on something else
#
#   julia --project=. bench/itp_stability_limit_vs_c0.jl [n] [steps]

using Printf
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 600
const TIMING = get(ENV, "SPINORBEC_CELL_TIMING",
    joinpath(get(ENV, "SPINORBEC_GAP_CACHE", tempdir()), "stability_cells.log"))

# Production axis. All of these have c₀ > 0 and stay above the −1/36 pole.
const RATIOS = (-0.024, -0.015, -0.005, 0.0, 0.02, 0.05)
# Geometric in dt so the answer is a factor, not an offset.
const DTS = (4.0e-3, 2.0e-3, 1.0e-3, 5.0e-4, 2.5e-4, 1.25e-4)

"Does a short ITP at this (c₁ ratio, dt) stay finite? Convergence is not asked."
function stays_finite(r, dt)
    grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(r),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=true,
            save_every=10^9),
        psi_init=psi0, enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=:polar_contact, backend=CUDABackend())
    nc = ws.spin_matrices.system.n_components
    psi = ws.state.psi
    SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
    for _ in 1:STEPS
        SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
        SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
        SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
        SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws)
        SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
        SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
        SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
        SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
    end
    CUDA.synchronize()
    isfinite(SpinorBEC.total_energy(ws))
end

c0_of(r) = EU_c_total / (1 + 36 * r)

println("="^78)
println("ITP stability limit vs c₀ — Eu F=6 D=13, $(N_GRID)³, $(STEPS) steps, polar_contact")
println("cell = does a short ITP stay FINITE. convergence is not asked.")
println("="^78)
@printf("\n  %-9s %10s", "c1_ratio", "c₀")
for dt in DTS
    @printf(" %9.2e", dt)
end
@printf("  %12s\n", "largest ok")

limits = Tuple{Float64, Float64, Union{Nothing, Float64}}[]
for r in RATIOS
    c0 = c0_of(r)
    @printf("  %-9.3f %10.0f", r, c0)
    best = nothing
    for dt in DTS
        t0 = time()
        ok = stays_finite(r, dt)
        open(TIMING, "a") do io
            @printf(io, "r=%+.3f c0=%.0f dt=%.2e ok=%s %6.1f s\n", r, c0, dt, ok, time() - t0)
        end
        ok && best === nothing && (best = dt)
        @printf(" %9s", ok ? "ok" : "DIV")
        flush(stdout)
        GC.gc(true)
        CUDA.reclaim()
    end
    @printf("  %12s\n", best === nothing ? "none" : @sprintf("%.2e", best))
    flush(stdout)
    push!(limits, (r, c0, best))
end

println("\n  the relation")
usable = [(c0, b) for (_, c0, b) in limits if b !== nothing]
if length(usable) < 2
    println("    fewer than two c₀ values have a stable dt in the ladder — no relation")
else
    @printf("    %-10s %12s %14s\n", "c₀", "dt_max", "c₀ · dt_max")
    for (c0, b) in usable
        @printf("    %-10.0f %12.2e %14.3f\n", c0, b, c0 * b)
    end
    lims = [b for (_, b) in usable]
    c0s = [c for (c, _) in usable]
    mono = issorted(lims) == issorted(c0s; rev=true) || issorted(lims; rev=true) == issorted(c0s)
    prods = [c * b for (c, b) in usable]
    spread = maximum(prods) / max(minimum(prods), eps())
    @printf("\n    monotone in c₀: %s      c₀·dt_max spread: %.2f×\n",
        mono ? "yes" : "NO", spread)
    println("""
    A `c₀·dt_max` that is roughly CONSTANT means the limit is set by the
    interaction energy scale and `c₀·dt < const` is the criterion the preflight
    can carry. A spread of many × means it is not, and the honest gate stays a
    warning.""")
end

println("""

[read] The ladder is geometric, so `largest ok` is known only to a factor of 2 —
quote it as a bracket, not a value. And this is ONE grid, ONE trap, ONE atom
number: the stability limit of a split step depends on the largest energy scale in
the problem, and c₀ is only one contributor. Nothing here licenses a formula for
other shapes.""")
