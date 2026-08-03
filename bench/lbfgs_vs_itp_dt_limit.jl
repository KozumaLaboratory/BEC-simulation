# Does L-BFGS land where ITP is heading as dt → 0?
#
# ITP is GFDN — evolve unconstrained, then normalize — and that is a FIRST-order
# splitting of the constrained flow, so its converged state carries an O(dt) error
# (2.4e-2 in density at the shipped dt = 2e-3, measured; see the `:dt` entry in
# ACCURACY_KNOBS). L-BFGS has no dt at all: the `dt = 0.001` at
# `lbfgs/driver.jl:201` exists only to fill a `SimParams` so `make_workspace` can
# be built, and the solver line-searches rather than propagating. Its accuracy is
# set by `grad_norm`.
#
# If that reasoning is right, E_LBFGS should sit at the dt → 0 END of the ITP
# sequence rather than beside any particular dt. That is the whole test, and it is
# a PREDICTION being checked, not a result being confirmed — it was recorded as
# unmeasured in the report and is measured here.
#
# WHAT WOULD FALSIFY IT, stated first so the reading is not chosen afterwards:
#
#   * E_LBFGS above E_ITP(dt/4)  ⇒ L-BFGS is NOT at the limit; it stopped early,
#     or its own floor is coarser than the ITP dt error, and "use L-BFGS for
#     accuracy" is wrong.
#   * E_LBFGS well below the ITP trend's extrapolated end ⇒ they are not finding
#     the same state, and no comparison of energies means anything. The density
#     distance is printed for exactly this.
#
# The ITP energies must be MONOTONE in dt for the extrapolation to mean anything;
# if they are not, the sequence is not in its asymptotic regime and the Richardson
# value is a number without a claim behind it.
#
#   julia --project=. bench/lbfgs_vs_itp_dt_limit.jl [n] [c1_ratio]

using Printf
using LinearAlgebra: norm
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
# +0.05, not the production −0.024: at −0.024 the shipped dt DIVERGES (c₀ is 20×
# larger there), so the ITP sequence this compares against does not exist at the
# shipped step. Establish the L-BFGS claim where ITP is well behaved first.
const C1_RATIO = length(ARGS) >= 2 ? parse(Float64, ARGS[2]) : 0.05
const DT0 = 0.002
const ITP_TOL = 1.0e-10
const MAX_STEPS = 40000

seed(grid) = init_psi(grid, SpinSystem(6); state=:spin_coherent,
    init_theta=π / 4, init_phi=0.3)
grid_of() = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))

const COMMON = (; atom=Eu151, zeeman=ZeemanParams(EU_p_weak, 0.0),
    enable_ddi=true, c_dd=EU_c_dd, ddi_padding=true, ddi_trunc_radius=-1.0,
    spinor_lhy=:polar_contact, backend=CUDABackend())

function itp_at(dt; steps)
    grid = grid_of()
    t0 = time()
    gs = find_ground_state(; grid, interactions=eu_interaction_params(C1_RATIO),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=seed(grid),
        # `save_every` is NOT only about saving: `itp_loop.jl:160` gates the
        # convergence check on `step % sp.save_every == 0`, so the 10^9 used here
        # to suppress output also suppressed the check — every arm came back
        # `conv=NO` with `dE=NaN` while its ENERGY matched a previously converged
        # run to seven digits. A knob named for output silently disabling a
        # termination test is worth knowing about; 200 is what the other benches
        # use and what produces a meaningful flag.
        dt, n_steps=steps, tol=ITP_TOL, tol_drho=1.0e-8, save_every=200,
        verbose=false, COMMON...)
    psi = Array(gs.workspace.state.psi)
    (E=gs.energy, psi=psi, ok=gs.converged, extra=gs.dE, label=@sprintf("ITP dt=%.1e", dt),
        secs=time() - t0)
end

function lbfgs_run(tol)
    grid = grid_of()
    t0 = time()
    r = find_ground_state_lbfgs(; grid, interactions=eu_interaction_params(C1_RATIO),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)), psi_init=seed(grid),
        n_steps=20000, tol, COMMON...)
    psi = Array(r.workspace.state.psi)
    (E=r.energy, psi=psi, ok=r.converged, extra=r.grad_norm,
        label=@sprintf("LBFGS tol=%.0e", tol), secs=time() - t0)
end

"Relative L2 distance between DENSITIES — ITP and L-BFGS leave different gauge
representatives of the same physical state, so a ψ difference reports gauge."
function ddist(a, b)
    na = dropdims(sum(abs2, a; dims=4); dims=4)
    nb = dropdims(sum(abs2, b; dims=4); dims=4)
    norm(vec(na) .- vec(nb)) / max(norm(vec(na)), eps())
end

println("="^78)
println("L-BFGS vs the ITP dt→0 limit — Eu F=6 D=13, $(N_GRID)³, c₁/c₀=$(C1_RATIO)")
println("prediction under test: L-BFGS has no dt, so it should sit at the LIMIT")
println("="^78)

runs = Any[]
for (dt, steps) in ((DT0, MAX_STEPS), (DT0 / 2, 2 * MAX_STEPS), (DT0 / 4, 4 * MAX_STEPS))
    r = itp_at(dt; steps)
    push!(runs, r)
    @printf("  %-18s E=%.8f  conv=%-3s  dE=%.2e  %6.1f s\n",
        r.label, r.E, r.ok ? "yes" : "NO", r.extra, r.secs)
    flush(stdout)
    GC.gc(true)
    CUDA.reclaim()
end
for tol in (1.0e-8, 1.0e-10)
    r = lbfgs_run(tol)
    push!(runs, r)
    @printf("  %-18s E=%.8f  conv=%-3s  |g|=%.2e  %6.1f s\n",
        r.label, r.E, r.ok ? "yes" : "NO", r.extra, r.secs)
    flush(stdout)
    GC.gc(true)
    CUDA.reclaim()
end

itp = runs[1:3]
lb = runs[4:end]
R = itp[3]                       # ITP at dt/4, the finest of the sequence

println("\n  ITP energies vs dt (must be MONOTONE for the trend to mean anything)")
dEs = [r.E for r in itp]
mono = issorted(dEs) || issorted(dEs; rev=true)
@printf("    %.8f → %.8f → %.8f   monotone: %s\n", dEs..., mono ? "yes" : "NO")
# MEASURE the order, do not assume it. This was hard-coded to the first-order form
# `2E(h/2) − E(h)` on the grounds that GFDN is a first-order splitting — true of
# the STATE, false of the energy, and the difference is not a detail:
#
#     energy differences 0.24059 / 0.06412 → ratio 3.75 → p = 1.91
#     density order, measured separately             → p = 0.93
#
# They agree once the reason is stated: E is STATIONARY at the minimum, so a state
# error δ costs an energy error O(δ²), and 2 × 0.93 = 1.86 ≈ 1.91. The energy
# converges at TWICE the order of the state.
#
# Assuming p = 1 put E(dt→0) at 770.947 instead of 770.988 and made L-BFGS look
# 5.6e-5 off the limit when it is 3.2e-6 off — a factor of 17, in the direction
# that would have reported the prediction as failing.
p_ord = log2((dEs[1] - dEs[2]) / (dEs[2] - dEs[3]))
rich = dEs[3] - (dEs[2] - dEs[3]) / (2^p_ord - 1)
@printf("    measured order p = %.3f  (differences %.5f / %.5f)\n",
    p_ord, dEs[1] - dEs[2], dEs[2] - dEs[3])
@printf("    Richardson AT THAT ORDER: E(dt→0) ≈ %.8f\n", rich)
println("    NB: p ≈ 2 here while the STATE converges at p ≈ 1 — E is stationary")
println("    at the minimum, so energy error is the square of state error. Energy")
println("    is therefore a POOR probe of state accuracy: it looks converged")
println("    while the state it sits on is an order less so.")

println("\n  distance to the ITP dt/4 state")
@printf("    %-18s %12s %14s\n", "", "ΔE (rel)", "density")
for r in vcat(itp[1:2], lb)
    @printf("    %-18s %12.4e %14.4e\n", r.label,
        abs(r.E - R.E) / abs(R.E), ddist(r.psi, R.psi))
end

println("\n  the test")
for r in lb
    closer = abs(r.E - rich) < abs(itp[1].E - rich)
    @printf("    %-18s |E − E(dt→0)| = %.4e   vs ITP@dt %.4e   %s\n",
        r.label, abs(r.E - rich), abs(itp[1].E - rich),
        closer ? "← closer to the limit" : "← NOT closer")
end

println("""

[read] The prediction is that L-BFGS sits at the dt → 0 end, not beside a
particular dt. Read the DENSITY column with the energy one: two states can share
an energy without being the same state, and if the densities disagree then no
energy comparison here means anything.

If `monotone: NO`, the ITP sequence is not in its asymptotic regime and the
Richardson value is a number with no claim behind it — stop there.

THE WALL TIMES ARE NOT COMPARABLE ACROSS NODES and no speed ratio should be read
from them. Two runs of this file, identical iteration counts and energies to eight
digits, gave L-BFGS 1000 iterations in 47.4 s on r18n8 and 167.9 s on r4n3 — 3.5×
— while the ITP arms moved ~15 %. L-BFGS line-searches through host BLAS level-1
and is machine-dependent (156.6 → 50.2 ms/it measured on the same problem); ITP is
GPU-FFT bound. Putting both arms on ONE node is not enough, because they respond
to different parts of the machine. A speed claim needs a repeated, same-node,
both-arms measurement, which this is not.

And note what this does NOT settle: it is one grid, one c₁, one seed, and at
c₁/c₀ = −0.024 the shipped dt diverges outright, so the comparison cannot even be
posed there without first choosing a stable dt.""")
