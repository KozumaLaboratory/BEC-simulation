# Where does an ITP step spend its time, AFTER the diagonal fusion?
#
# The fused GPU diagonal kernel took the 32³ Eu step from 1.305 to 0.451 ms
# (2.89×) by giving the tabulated LHY a path into it. That was the last measured
# ITP win, and nothing since has measured what the remaining 0.45 ms is made of.
# Every subsequent lever has been argued from an old breakdown or from the RTP
# profile, which is a DIFFERENT chain.
#
# ITP is not `split_step!`. `_run_itp_loop!` runs
#
#     V(dt/4) DDI(dt/2) V(dt/4) | K(dt) | V(dt/4) DDI(dt/2) V(dt/4) | normalize
#
# so `bench/profile_1step_gpu.jl` (which profiles `split_step!` at c₁ = 0 and no
# LHY) does not describe it. This does, at the production shape: Eu F=6, D=13,
# c₁ ≠ 0, tabulated LHY, padded DDI.
#
# Read it as a BUDGET, not a ranking: the substeps sum to the step, so a lever is
# worth chasing only in proportion to the share it can touch. The DDI FFTs were
# measured within ~3× of their bandwidth floor, so if DDI dominates here the
# remaining ITP speed is small and the honest answer is to say so.
#
#   julia --project=. bench/profile_itp_substeps.jl [n] [reps] [lhy]

using Printf
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 32
const REPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 50
const LHY = length(ARGS) >= 3 ? Symbol(ARGS[3]) : :polar_contact

function build()
    grid = make_grid(GridConfig(ntuple(_ -> N_GRID, 3), ntuple(_ -> 12.0, 3)))
    psi0 = init_psi(grid, SpinSystem(6); state=:spin_coherent,
        init_theta=π / 4, init_phi=0.3)
    ws = make_workspace(;
        grid, atom=Eu151, interactions=eu_interaction_params(0.05),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        sim_params=SimParams(; dt=0.002, n_steps=1, imaginary_time=true,
            save_every=10^9),
        psi_init=psi0, enable_ddi=true, c_dd=EU_c_dd,
        ddi_padding=true, ddi_trunc_radius=-1.0,
        spinor_lhy=(LHY === :none ? nothing : LHY), backend=CUDABackend())
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

"""Min-of-REPS wall time for `f`, warmed first.

MIN, not mean: the quantity wanted is the cost of the work, and every sample is
that plus a non-negative disturbance. The minimum is the least-disturbed sample;
a mean reports the disturbance too.
"""
function best_ms(f)
    for _ in 1:5
        f()
    end
    CUDA.synchronize()
    b = Inf
    for _ in 1:REPS
        CUDA.synchronize()
        t0 = time_ns()
        f()
        CUDA.synchronize()
        b = min(b, (time_ns() - t0) * 1e-6)
    end
    b
end

ws = build()
dt = ws.sim_params.dt
nc = ws.spin_matrices.system.n_components
psi = ws.state.psi

# The chain `_run_itp_loop!` actually executes, substep by substep. Each entry is
# run in isolation on the SAME state — the timings are per-operator costs, not a
# trajectory, which is what a budget needs.
substeps = [
    ("V fwd (dt/4)  diag+spin-mix", () -> SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)),
    ("DDI (dt/2)    6 FFT + contract", () -> SpinorBEC._ddi_step!(ws, dt / 2, 3, true)),
    ("V bwd (dt/4)  diag+spin-mix", () -> SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)),
    ("K (dt)        batched FFT", () -> SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws)),
    ("normalize", () -> SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)),
]

"One full ITP step — the sum the parts have to reconcile against."
function full_step!()
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws)
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3)
end

# Per-step multiplicity: the chain runs V and DDI twice, K and normalize once.
const MULT = Dict("V fwd (dt/4)  diag+spin-mix" => 2, "DDI (dt/2)    6 FFT + contract" => 2,
    "V bwd (dt/4)  diag+spin-mix" => 2, "K (dt)        batched FFT" => 1,
    "normalize" => 1)

println("="^78)
println("ITP substep budget — Eu F=6 D=13, $(N_GRID)³, lhy=$(LHY), $(CUDA.name(CUDA.device()))")
println("="^78)

step_ms = best_ms(full_step!)
@printf("\n  %-34s %10s %6s %10s\n", "substep", "ms (each)", "×/step", "ms/step")
total = 0.0
for (name, f) in substeps
    t = best_ms(f)
    m = MULT[name]
    total += t * m
    @printf("  %-34s %10.4f %6d %10.4f\n", name, t, m, t * m)
end
@printf("\n  %-34s %28.4f\n", "SUM OF PARTS", total)
@printf("  %-34s %28.4f\n", "MEASURED FULL STEP", step_ms)
@printf("  %-34s %27.1f%%\n", "parts / step", 100 * total / step_ms)

println("""

[read] Reconcile FIRST. If the parts do not sum to the step within a few percent,
the breakdown is describing something other than the step and no share in it can
be used — isolated substeps miss cross-substep overlap and any state-dependence,
so a large gap means this instrument, not a discovery.

Only then read shares. A lever is worth chasing in proportion to the share it can
touch: the DDI FFTs were measured within ~3× of their bandwidth floor, so a
DDI-dominated budget means the remaining ITP speed is small, and saying so is the
result.""")
