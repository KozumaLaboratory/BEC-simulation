# How much accuracy does separating two ground-state phases actually need?
#
# Not answerable as a single number, and the reason matters. On a phase boundary
# the competing states are degenerate by construction, so ΔE → 0 and NO finite
# accuracy resolves the boundary exactly. The answerable question is how far the
# boundary MOVES:
#
#     δB_boundary ≈ δ(ΔE) / |∂(ΔE)/∂B|
#
# So the observable is the GAP between two competing states, not the total
# energy. That distinction is the whole point of this script. `SPIN_TAYLOR_TOL`
# was budgeted against the total energy (2.4e-13 out of E ≈ 10, i.e. 3e-11 of the
# splitting error) — but errors COMMON to both states cancel in ΔE and only the
# non-cancelling part decides a phase. A 1e-13 error on a total of 10 is a 1e-7
# relative error on a gap of 1e-6. The energy budget licenses an energy claim; it
# says nothing about a phase boundary.
#
# WHAT THIS MEASURES
#
#   cost   make_workspace time (which is where a tabulated LHY builds its table)
#          separately from per-step time. `FullBdGLHY <: TabulatedLHY` with
#          n_points = 200, so its documented "~100× dearer" is a ONE-TIME build,
#          not a per-step cost — worth confirming rather than repeating.
#   gap    ΔE = E(CSV seed) − E(FL seed) at fixed parameters, per arm.
#   slope  ∂(ΔE)/∂B from two B values, to turn δ(ΔE) into a boundary shift.
#
# THE DEGENERACY GUARD IS NOT OPTIONAL. ITP from a seed can leave that seed's
# basin and relax to the other state, in which case ΔE collapses to ~0 and the
# whole comparison is empty. This project has already read exactly that as
# physics once — seed gaps of 0 and 8.9e-16 taken for degeneracy when the real
# cause was that `method: lbfgs` had dropped the LHY term entirely. So each arm
# reports how far apart its two converged states actually are, and a gap quoted
# without that number should not be believed.
#
#   julia --project=. bench/phase_gap_error_budget.jl [n] [steps]

using Printf
import CUDA
using SpinorBEC
using SpinorBEC: SPIN_TAYLOR_ENABLED, SPIN_TAYLOR_DEGREE_CAP, spin_density_vector
using LinearAlgebra: norm

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 24
const N_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 4000
const SEEDS = (:flower, :chiral_spin_vortex)

grid_of() = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))

"ITP from one seed. Returns (E, Fz field) so the caller can check the two states differ."
function relax(; seed::Symbol, B::Float64, kind, dt, n_steps, taylor::Bool, cap::Int)
    old_t, old_c = SPIN_TAYLOR_ENABLED[], SPIN_TAYLOR_DEGREE_CAP[]
    SPIN_TAYLOR_ENABLED[] = taylor
    SPIN_TAYLOR_DEGREE_CAP[] = cap
    try
        grid = grid_of()
        psi0 = init_psi(grid, SpinSystem(6); state=seed)
        gs = find_ground_state(;
            grid, atom=Eu151, interactions=eu_interaction_params(0.05),
            zeeman=ZeemanParams(linear_zeeman_p(Eu151, B, EU_ω_ref), 0.0),
            potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=psi0,
            dt, n_steps, tol=0.0, save_every=max(1, n_steps ÷ 2),
            enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
            spinor_lhy=kind, backend=CUDABackend(), verbose=false,
        )
        psi_h = Array(gs.workspace.state.psi)
        _, _, fz = spin_density_vector(psi_h, gs.workspace.spin_matrices, 3)
        (E=gs.energy, fz=fz)
    finally
        SPIN_TAYLOR_ENABLED[] = old_t
        SPIN_TAYLOR_DEGREE_CAP[] = old_c
    end
end

"ΔE between the two seeds at one B, plus how distinguishable the two states are."
function gap(; B, kind, dt, n_steps, taylor, cap)
    a = relax(; seed=SEEDS[1], B, kind, dt, n_steps, taylor, cap)
    b = relax(; seed=SEEDS[2], B, kind, dt, n_steps, taylor, cap)
    sep = norm(vec(a.fz) .- vec(b.fz)) / max(norm(vec(a.fz)), eps())
    (dE=b.E - a.E, sep=sep, EA=a.E, EB=b.E)
end

# --- cost: table build vs per step -----------------------------------------
function cost(kind)
    grid = grid_of()
    psi0 = init_psi(grid, SpinSystem(6); state=:flower)
    sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=true, save_every=10^9)
    build() = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), sim_params=sp, psi_init=psi0,
        enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=kind, backend=CUDABackend())
    build()                            # warm
    t0 = time();
    ws = build();
    t_build = time() - t0
    for _ in 1:5
        SpinorBEC.split_step!(ws)
    end
    CUDA.synchronize()
    best = Inf
    for _ in 1:20
        CUDA.synchronize();
        s = time_ns()
        SpinorBEC.split_step!(ws);
        CUDA.synchronize()
        best = min(best, (time_ns() - s) * 1e-9)
    end
    (build=t_build, step=best)
end

println("="^78)
println("Phase-gap error budget — Eu F=6 D=13, $(N_GRID)³, $(N_STEPS) ITP steps")
println("device: $(CUDA.name(CUDA.device()))   seeds: $(SEEDS)")
println("="^78)

println("\n[cost] make_workspace (tabulation) vs per RTP step")
@printf("  %-16s %12s %12s\n", "spinor_lhy", "build (s)", "step (ms)")
for kind in (nothing, :polar_contact, :full_bdg)
    c = cost(kind)
    @printf("  %-16s %12.2f %12.3f\n", repr(kind), c.build, c.step * 1e3)
    GC.gc(true);
    CUDA.reclaim()
end

# --- gap: two B values so the slope, hence a boundary shift, is available ----
const B1, B2 = 2.6e-9, 5.2e-9
const DT = 0.002

arms = [
    ("reference (Euler, full_bdg)", (kind=:full_bdg, dt=DT, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("production (Taylor, polar_contact)", (kind=:polar_contact, dt=DT, taylor=true,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("baseline probe: dt/2, reference", (kind=:full_bdg, dt=DT / 2, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
    ("control: rotation removed", (kind=:full_bdg, dt=DT, taylor=true, cap=0)),
    ("control: LHY removed", (kind=nothing, dt=DT, taylor=false,
        cap=SpinorBEC.SPIN_TAYLOR_RK_MAX)),
]

println("\n[gap] ΔE = E($(SEEDS[2])) − E($(SEEDS[1]))")
@printf("  %-36s %13s %13s %10s\n", "arm", "ΔE at B1", "ΔE at B2", "state sep")
results = Dict{String, Any}()
for (label, a) in arms
    ns = a.dt == DT ? N_STEPS : 2N_STEPS
    g1 = gap(; B=B1, a.kind, a.dt, n_steps=ns, a.taylor, a.cap)
    g2 = gap(; B=B2, a.kind, a.dt, n_steps=ns, a.taylor, a.cap)
    results[label] = (g1, g2)
    @printf("  %-36s %13.6e %13.6e %10.3e\n", label, g1.dE, g2.dE,
        min(g1.sep, g2.sep))
    GC.gc(true);
    CUDA.reclaim()
end

println("""

[read] `state sep` is |Fz(seedB) − Fz(seedA)| / |Fz(seedA)|. If it is ~0 the two
seeds relaxed to the SAME state and that row's ΔE is not a gap between phases —
it is a measure of nothing, and this project has misread exactly that before.""")

ref = results["reference (Euler, full_bdg)"]
slope = (ref[2].dE - ref[1].dE) / (B2 - B1)
bracketed = sign(ref[1].dE) != sign(ref[2].dE)
@printf("\n  ∂(ΔE)/∂B from the reference arm: %.4e  per unit B\n", slope)
@printf("  ΔE(B1) = %+.4e, ΔE(B2) = %+.4e  ⇒ boundary %s between B1 and B2\n",
    ref[1].dE, ref[2].dE, bracketed ? "IS bracketed" : "is NOT bracketed")
if !bracketed
    println("""
  The slope is therefore a LOCAL rate on one side of the boundary, not the rate
  at the crossing, and δB below is an extrapolation. Move B1/B2 until ΔE changes
  sign before quoting a boundary shift.

  Note which direction helps: a SMALL |∂(ΔE)/∂B| is the bad case. It means the
  two phases stay near-degenerate over a wide range of B, so any energy error
  moves the apparent boundary a long way — and if it is small enough, what is
  there is a crossover and not a boundary at all. Accuracy cannot fix that; only
  a different claim can.""")
end
if slope != 0
    println("  δB_boundary = δ(ΔE) / |∂(ΔE)/∂B| for each arm, against the reference:")
    for (label, _) in arms
        label == "reference (Euler, full_bdg)" && continue
        d = abs(results[label][1].dE - ref[1].dE)
        @printf("    %-36s δ(ΔE) %10.3e → δB %10.3e\n", label, d, d / abs(slope))
    end
    println("""
  The `dt/2` row is the baseline: the boundary shift the caller ALREADY accepted
  by choosing dt. An approximation whose δB is well under it is not what limits
  the boundary; one above it is.""")
end
