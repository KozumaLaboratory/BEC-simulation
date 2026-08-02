# Is the ITP fused chain's splitting change SMALLER than the one dt already costs?
#
# Cost is settled: fusing the ITP `V DDI V` sandwich saves 30.6 % of the step at
# 64³ and 29.3 % at 96³ (bench/itp_spin_chain_prize.jl), against a threshold of
# 20 % fixed before the run. What is not settled is what it costs in accuracy, and
# it is NOT free the way the RTP fusion is: RTP freezes ψ_mf in its midpoint
# predictor-corrector, so one ⟨F⟩ serves all three substeps and the fusion is
# bit-identical (gated, 4/4 including the tabulated arm). ITP has no frozen field
# — its substeps see ⟨F⟩(ψ₀), ⟨F⟩(ψ₁), ⟨F⟩(ψ₂) — so fusing it is a different
# splitting.
#
# THE QUESTION IS NOT "is the change small". It is "is the change small against an
# error we have ALREADY ACCEPTED". Choosing dt accepts an O(dt²) splitting error;
# the honest yardstick is therefore the separate chain at dt vs at dt/2, which is
# that accepted error made visible. A fusion whose effect sits well under it
# changes nothing anyone was relying on. One quoted as "1e-5, small" would be a
# number with no scale attached.
#
#   arm S   separate chain, dt        the current production behaviour
#   arm B   separate chain, dt/2      S's own accepted error, made visible
#   arm F   fused chain,    dt        the proposal
#
#   verdict:  |F − S| / |S − B|   ≪ 1  admissible,  ≳ 1  not
#
# Everything is compared at the CONVERGED state, not after a fixed step count: ITP
# is a relaxation and the fixed point is the object, so an arm that takes a
# different path there is not thereby wrong. Arms run to the same tolerance and
# the same imaginary time, with dt/2 given twice the steps.
#
#   julia --project=. bench/itp_fused_chain_accuracy.jl [n] [max_steps]

using Printf
using LinearAlgebra: norm
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 64
const MAX_STEPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 40000
# THE SIGN OF c₁ IS A PARAMETER, and it was not one until now. Every number this
# bench has produced came from `c1_ratio = +0.05`, while CLAUDE.md records that
# `c₁ < 0` is the sign Eu F=6 PRODUCTION uses — so the one configuration the
# result is meant to license had never been run. A conclusion drawn at one sign of
# the spin coupling is not a conclusion about the other.
const C1_RATIO = length(ARGS) >= 3 ? parse(Float64, ARGS[3]) : 0.05
# The LHY kind is an argument because `polar_contact` CANNOT be built at c₁ < 0 —
# σ₀ goes negative and the closed form refuses (it used to die in `^`). That is
# not a limitation of the fusion question: the fused diagonal absorbs a tabulated
# LHY completely (measured under 2 % in every substep), so `none` exercises the
# same diag + spin-mixing + DDI chain the fusion changes.
const LHY = length(ARGS) >= 4 ? Symbol(ARGS[4]) : :polar_contact
const DT = 0.002
const TOL = 1.0e-10

function build(dt)
    grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(C1_RATIO),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params=SimParams(; dt=dt, n_steps=1, imaginary_time=true,
            save_every=10^9),
        psi_init=psi0, enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=(LHY === :none ? nothing : LHY), backend=CUDABackend())
    ws
end

"The current ITP half: three operators, each seeing its own ⟨F⟩."
function half_separate!(ws, dt, nc)
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
end

"The proposal: one pass, ⟨F⟩ frozen at the ψ entering the half."
function half_fused!(ws, dt, nc)
    zd = SpinorBEC._resolve_zeeman_diag(ws, ws.state.t)
    psi = ws.state.psi
    SpinorBEC._apply_spin_chain!(psi, ws, dt / 2, 3, true, ws.interactions,
        psi, zd, zd, psi)
end

"""Relax to the fixed point and return the converged ψ (host) plus diagnostics.

`n_steps` scales as 1/dt so every arm covers the same imaginary time — without
that the dt/2 arm is a shorter run wearing a smaller-error label, which is a
mistake this project has already made once in this bench family."""
function relax(half!; dt, max_steps, label="")
    t0 = time()
    ws = build(dt)
    nc = ws.spin_matrices.system.n_components
    psi = ws.state.psi
    SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
    e_prev = SpinorBEC.total_energy(ws)
    conv, last = false, 0
    dE = NaN
    for step in 1:max_steps
        half!(ws, dt, nc)
        SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws)
        half!(ws, dt, nc)
        SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
        if step % 200 == 0
            e = SpinorBEC.total_energy(ws)
            dE = abs(e - e_prev) / max(abs(e), eps())
            e_prev = e
            last = step
            if dE < TOL
                conv = true
                break
            end
        end
    end
    CUDA.synchronize()
    # ONE LINE PER ARM, flushed. Without it a config prints nothing until all five
    # relaxations finish, so a slow arm and a hung one look identical from
    # outside — which is how a run sat unreadable for 2.5 h before being killed.
    # "Absent" was being read as "still fine".
    @printf("    %-18s dt=%.1e  %6d steps  dE=%.2e  conv=%-3s  %6.1f s\n",
        label, dt, last, dE, conv ? "yes" : "NO", time() - t0)
    flush(stdout)
    (psi=Array(psi), E=SpinorBEC.total_energy(ws), conv=conv, dE=dE, steps=last)
end

"Relative L2 distance between two states' DENSITIES.

Density, not ψ: ITP leaves a global U(1) phase and a z-spin rotation free, so a
ψ-difference reports gauge as if it were physics. This is the same reason
`tol_drho` exists."
function ddist(a, b)
    na = dropdims(sum(abs2, a; dims=4); dims=4)
    nb = dropdims(sum(abs2, b; dims=4); dims=4)
    norm(vec(na) .- vec(nb)) / max(norm(vec(na)), eps())
end

println("="^78)
println("ITP fused-chain ACCURACY — Eu F=6 D=13, $(N_GRID)³, c₁/c₀=$(C1_RATIO), lhy=$(LHY), tol=$(TOL), $(CUDA.name(CUDA.device()))")
println("verdict = |F−S| / |S−B|, where S−B is the error dt ALREADY costs")
println("="^78)

println("  arms (streamed as each finishes):"); flush(stdout)
S = relax(half_separate!; dt=DT, max_steps=MAX_STEPS, label="S separate dt")
B = relax(half_separate!; dt=DT / 2, max_steps=2 * MAX_STEPS, label="B separate dt/2")
F = relax(half_fused!; dt=DT, max_steps=MAX_STEPS, label="F fused dt")
# A THIRD dt, which is what turns "closer to the dt/2 reference" into a statement
# about accuracy. With only dt and dt/2 there is no way to tell a smaller error
# from a different one that happens to land nearby, and the first run of this
# bench was read exactly that far and no further.
R = relax(half_separate!; dt=DT / 4, max_steps=4 * MAX_STEPS, label="R separate dt/4")
Fh = relax(half_fused!; dt=DT / 2, max_steps=2 * MAX_STEPS, label="F fused dt/2")

@printf("\n  %-28s %14s %6s %10s %8s\n", "arm", "E", "conv", "final dE", "steps")
for (name, r) in (("S separate, dt", S), ("B separate, dt/2", B),
    ("R separate, dt/4", R), ("F fused, dt", F), ("F fused, dt/2", Fh))
    @printf("  %-28s %14.8f %6s %10.2e %8d\n", name, r.E, r.conv ? "yes" : "NO",
        r.dE, r.steps)
end

# The FULL pairwise matrix, because the first version of this printed only
# |F−S| and |S−B| and that was the wrong pair. The verdict it computed —
# |F−S|/|S−B| — measures how far the proposal sits from the CURRENT behaviour,
# and treats "differs from what we do now" as "wrong". But S is not the truth; B
# (dt/2) is the better estimate of it, and the run showed F landing on B in
# energy to 1.5e-7 while S sits 3.0e-4 away. Under the old rule that read as
# ratio ≈ 1 and "the idea dies", when the arithmetic was saying the opposite.
#
# So the quantity that decides is |F−B| against |S−B|: distance from the best
# available reference, for each of the two candidates at dt.
#
# And |F−B| is needed in DENSITY, not only energy. Energy is one scalar and two
# different states can share it; the earlier run's energy agreement is not by
# itself evidence that the states agree.
dist = (
    ("|S − B|  current vs dt/2", ddist(S.psi, B.psi), abs(S.E - B.E) / abs(B.E)),
    ("|F − B|  proposal vs dt/2", ddist(F.psi, B.psi), abs(F.E - B.E) / abs(B.E)),
    ("|F − S|  proposal vs current", ddist(F.psi, S.psi), abs(F.E - S.E) / abs(S.E)),
)
@printf("\n  %-32s %12s %12s\n", "", "density", "energy")
for (name, d, e) in dist
    @printf("  %-32s %12.4e %12.4e\n", name, d, e)
end
d_SB, d_FB = dist[1][2], dist[2][2]
e_SB, e_FB = dist[1][3], dist[2][3]
@printf("\n  %-32s %12.4f %12.4f\n", "VERDICT  |F−B| / |S−B|",
    d_FB / max(d_SB, eps()), e_FB / max(e_SB, eps()))
println("    < 1  the fusion is CLOSER to the dt/2 reference than the current chain")
println("    ≈ 1  it is a different error of the same size — a lateral move")
println("    > 1  it is worse, and the speed does not buy it")
println("  Both columns have to agree. Energy alone cannot settle it: one scalar")
println("  can coincide between states that differ.")

# --- Richardson: does each chain CONVERGE, and at what rate? ---------------
#
# Against the finest reference R = separate at dt/4, a second-order chain should
# have its error fall ~4× per halving. That rate is what distinguishes "smaller
# error" from "different error that happens to land near dt/2", and without it
# `|F−B| ≪ |S−B|` cannot be called accuracy.
#
# The practical question is on the same table: if the fused chain at dt is closer
# to R than the separate chain at dt/2 is, then it wins twice — 0.70× the step AND
# half the steps for the same distance to the reference.
println("\n  distance to R = separate at dt/4 (the finest reference here)")
@printf("  %-32s %12s %12s\n", "", "density", "energy")
rows = (("S separate, dt", S), ("S separate, dt/2", B),
    ("F fused, dt", F), ("F fused, dt/2", Fh))
for (name, r) in rows
    @printf("  %-32s %12.4e %12.4e\n", name,
        ddist(r.psi, R.psi), abs(r.E - R.E) / abs(R.E))
end
let sd = ddist(S.psi, R.psi), bd = ddist(B.psi, R.psi),
    fd = ddist(F.psi, R.psi), fhd = ddist(Fh.psi, R.psi)

    @printf("\n  %-32s %12.2f %12.2f\n", "order rate  S(dt)/S(dt/2), F(dt)/F(dt/2)",
        sd / max(bd, eps()), fd / max(fhd, eps()))
    println("    ~4 = second order and converging. Far from it ⇒ the arm is not in")
    println("    its asymptotic regime and no order can be read from these three.")
    println(fd < bd ?
            "\n  F at dt is CLOSER to R than S at dt/2 is — the fused chain wins twice:
  0.70× the step AND half the steps for the same distance to the reference." :
            "\n  F at dt is NOT closer to R than S at dt/2 — the fusion buys step time
  only, and the step-count comparison has to be made on equal footing.")
end

if !(S.conv && B.conv && F.conv && R.conv && Fh.conv)
    println("""

  AT LEAST ONE OF THE FIVE ARMS DID NOT CONVERGE. Every ratio above is then a comparison of
  points on trajectories rather than of fixed points, and none of them decides
  anything. Raise max_steps and re-run before reading further.""")
end

println("""

[read] The denominator is the point. `|S − B|` is what choosing dt already costs,
measured rather than assumed, so the ratio puts the proposal on the scale of a
knob already set. A distance quoted alone would be a number with no scale.

CAVEAT ON B. dt/2 is a BETTER estimate of the dt→0 limit than dt, not the limit
itself, so `|F−B| ≪ |S−B|` says the fusion agrees with a better estimate — it does
not by itself prove convergence to the true fixed point. Confirming that needs a
third dt (a Richardson check), and this bench does not do it. Say "closer to the
dt/2 reference", not "more accurate", until it does.

If the verdict is < 1 in BOTH columns the fusion is admissible at this dt and
grid, and it saves 30.6 % of the step at 64³. If it is ≳ 1 the fusion is a real
change to the answer and the speed does not buy it — the fallback, dt/2 with the
fused chain, is 2× the steps at 0.70× the step, i.e. a loss, so the idea dies.""")
