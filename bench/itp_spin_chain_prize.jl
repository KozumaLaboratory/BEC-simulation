# What would fusing the ITP `V DDI V` sandwich actually BUY?
#
# The substep budget (bench/profile_itp_substeps.jl, 96³, parts reconciling to
# 102.1 % of the step) says the spin-mixing rotation is 70.2 % of V and V runs
# four times, i.e. **25.5 % of the whole ITP step** — the largest single operator
# after the DDI FFTs, which are already within ~3× of their bandwidth floor.
#
# The RTP path already fuses exactly that sandwich, in one pass over ψ, via
# `_apply_spin_chain!`. But it is BIT-IDENTICAL there only because RTP's midpoint
# predictor-corrector has already frozen ψ_mf, so ⟨F⟩ is computed once and fed to
# both rotations and the convolution. ITP has no frozen field: its three substeps
# see ⟨F⟩(ψ₀), ⟨F⟩(ψ₁), ⟨F⟩(ψ₂). **Fusing ITP therefore changes the splitting.**
# It is not free, and `_spin_chain_reason` declining `psi_mf === nothing` is
# correct rather than an oversight.
#
# That leaves a well-posed trade — an O(dt²) change to a splitting error ITP
# already accepts by choosing dt — and the order to settle it in is COST FIRST.
# If the fusion saves 10 % of the step, changing the splitting is not worth
# discussing. If it saves 25 %, it is.
#
# So this measures only the cost, by running the fused kernel with ψ_mf frozen at
# the current ψ — which IS the proposed ITP variant, not an approximation of it —
# against the operator-by-operator chain on the same state. It deliberately says
# NOTHING about accuracy: that is a separate measurement against the dt/2
# baseline, and it is only worth taking if the number here is large.
#
#   julia --project=. bench/itp_spin_chain_prize.jl [n] [reps]

using Printf
import CUDA
using SpinorBEC

include(joinpath(@__DIR__, "eu151_params.jl"))

const N_GRID = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 96
const REPS = length(ARGS) >= 2 ? parse(Int, ARGS[2]) : 30

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
        spinor_lhy=:polar_contact, backend=CUDABackend())
    dV = prod(grid.config.box_size ./ grid.config.n_points)
    ws.state.psi ./= sqrt(sum(abs2, ws.state.psi) * dV)
    ws
end

"Min-of-REPS, warmed. Min because every sample is the work plus a non-negative
disturbance, so the minimum is the least-disturbed one."
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
ip = ws.interactions
zd = SpinorBEC._resolve_zeeman_diag(ws, ws.state.t)

println("="^78)
println("ITP spin-chain PRIZE — Eu F=6 D=13, $(N_GRID)³, $(CUDA.name(CUDA.device()))")
println("cost only. accuracy is a separate measurement and is not implied here.")
println("="^78)

# Is the fused kernel even reachable on this backend and config? Everything in
# `_spin_chain_reason` EXCEPT the frozen-field clause has to already pass, or the
# number below is about some other blocker and not about the splitting trade.
reason = SpinorBEC._spin_chain_reason(ws, ip, psi)     # psi as the frozen field
avail = SpinorBEC._spin_chain_available(psi, ws)
println("\n  _spin_chain_reason(ψ_mf = ψ) = $(repr(reason))")
println("  _spin_chain_available        = $avail")
if reason !== nothing || !avail
    println("""
  The fused path is blocked for a reason OTHER than the frozen field, so there is
  no prize to quote — fix or report that blocker first. Nothing below would be
  about the splitting trade.""")
    exit(0)
end

"The current ITP half: three operators, each seeing its own ⟨F⟩."
function chain_separate!()
    SpinorBEC._outer_potential_fwd!(ws, dt / 4, nc, 3, true)
    SpinorBEC._ddi_step!(ws, dt / 2, 3, true)
    SpinorBEC._outer_potential_bwd!(ws, dt / 4, nc, 3, true)
end

"The proposed ITP half: one pass, ⟨F⟩ frozen at the entering ψ."
function chain_fused!()
    SpinorBEC._apply_spin_chain!(psi, ws, dt / 2, 3, true, ip, psi, zd, zd, psi)
end

t_sep = best_ms(chain_separate!)
t_fus = best_ms(chain_fused!)

# The half runs twice per ITP step; K and normalize are untouched by the trade, so
# they are measured to put the half-level saving on a whole-step footing.
t_k = best_ms(() -> SpinorBEC.apply_step!(SpinorBEC.KineticTerm(), psi, 0.0, false, ws))
t_n = best_ms(() -> SpinorBEC._normalize_psi!(psi, ws.grid, nc, 3))

step_sep = 2 * t_sep + t_k + t_n
step_fus = 2 * t_fus + t_k + t_n

@printf("\n  %-40s %10s\n", "half-step V DDI V", "ms")
@printf("  %-40s %10.4f\n", "separate (current ITP)", t_sep)
@printf("  %-40s %10.4f\n", "fused    (ψ_mf frozen at ψ)", t_fus)
@printf("  %-40s %10.4f  (%.2f×)\n", "saving per half", t_sep - t_fus,
    t_sep / max(t_fus, eps()))

@printf("\n  %-40s %10s\n", "whole ITP step (2 halves + K + normalize)", "ms")
@printf("  %-40s %10.4f\n", "K (dt)", t_k)
@printf("  %-40s %10.4f\n", "normalize", t_n)
@printf("  %-40s %10.4f\n", "step, separate", step_sep)
@printf("  %-40s %10.4f\n", "step, fused", step_fus)
@printf("  %-40s %9.1f%%  (%.2f×)\n", "STEP SAVING",
    100 * (step_sep - step_fus) / step_sep, step_sep / max(step_fus, eps()))

println("""

[read] This is a COST number and nothing else. The fused half computes ⟨F⟩ once
and feeds it to both rotations and the convolution, where the current chain
recomputes it three times from three different ψ — so the two do NOT produce the
same state, and no part of this run says they should.

What to do with it: below ~10 % of the step, drop the idea — an O(dt²) change to
the splitting is not worth that. Above ~20 %, the next measurement is the one that
matters: converge ITP both ways and compare the converged states against the dt/2
baseline, i.e. against the splitting error already accepted by choosing dt.""")
