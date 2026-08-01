# RK4IP — 4th-order Runge-Kutta in the interaction picture.
#
# Why this and not another composition scheme. Composition integrators (Yoshida,
# Suzuki, Blanes-Moan) collapse to order ~1 on the spinor DDI path, because the
# base step is not time-symmetric for the nonlinear mean field: freezing Φ_DDI at
# each substep's ENTRY leaves a one-sided O(τ) error in the central substep that
# the composition cannot cancel. Recovering order 4 there costs an un-merged
# midpoint triple-jump with 3 Picard iterations — about 9 mean-field evaluations
# per step (PR #46).
#
# RK4IP is not a composition, so it never enters that trap: the Runge-Kutta order
# conditions ask nothing of time symmetry, and the mean field may be evaluated
# explicitly at each of the four stages. The kinetic operator — the stiff, linear,
# diagonal-in-k part — is absorbed into an interaction picture and applied
# exactly, so it does not limit `dt`.
#
# COST — and the CPU answer does not survive contact with the GPU.
#
# ms/step, Eu F=6 D=13 with padded DDI, `split_step!` / `midpoint` / `rk4ip`:
#
#   CPU 12³            3.00 / 4.46 / 2.61      rk4ip 0.87× the default
#   RTX 5070 Ti 128³ 175.21 / 257.83 / 258.15  rk4ip 1.47×
#   H100 128³         25.13 /  36.73 /  72.07  rk4ip **2.87×**
#   H100  64³          2.77 /   4.04 /   9.16  rk4ip 3.30×
#   H100  32³          0.62 /   0.92 /   4.63  rk4ip 7.44×
#
# The mechanism is the interaction picture itself: **this applies e^{K dt/2} four
# times per step (lines below) where Strang applies e^{K dt} once.** Each is an
# FFT pair. On CPU the mean-field and DDI work dominates and that 4× is invisible
# — RK4IP even comes out cheaper, because `split_step!` auto-dispatches to the
# midpoint predictor-corrector whenever DDI is active. On a GPU the FFTs dominate
# and the 4× is the whole story.
#
# Net speedup = the step ratio RK4IP holds under a fixed error budget
# (`scripts/validation/rk4ip_step_size_probe.jl`: 2.4× at 1e-4, 4.2× at 1e-5)
# divided by the cost ratio above. On the H100 at 128³ that is **0.84× at a 1e-4
# budget — a net LOSS — and 1.46× at 1e-5**. On CPU it is 2.7× and 4.9×.
#
# So: worth selecting when the tolerance is tight (≲1e-5) or on CPU; not worth it
# at ordinary tolerances on the production GPU, and not a candidate for the
# default. Memory is the other reason: the five scratch buffers below are 436 MB
# each at 128³ F64 D=13, and the measured allocator high-water for one step is
# 12.9 GiB on the H100 and 4.8 GiB of a 15.9 GiB consumer card.
#
# What it gives up: neither symplectic nor exactly norm-conserving. Over the
# 5-40 ms real-time windows this program runs that is not a constraint, and the
# norm drift is a free error monitor. Keep a composition scheme for imaginary
# time and for very long evolutions.
#
#     ψ_I  = e^{K dt/2} ψⁿ
#     k₁   = e^{K dt/2} [dt · N(ψⁿ, tⁿ)]
#     k₂   = dt · N(ψ_I + k₁/2, tⁿ + dt/2)
#     k₃   = dt · N(ψ_I + k₂/2, tⁿ + dt/2)
#     k₄   = dt · N(e^{K dt/2}(ψ_I + k₃), tⁿ + dt)
#     ψⁿ⁺¹ = e^{K dt/2}(ψ_I + (k₁ + 2k₂ + 2k₃)/6) + k₄/6
#
# `N(ψ,t) = -i (H − K) ψ` comes from the HamTerm registry's `apply_operator!`
# face — the same single coefficient declaration the propagator and the energy
# use, so no sign or factor can drift between this integrator and the others.

export rk4ip_step!

"""
    _rk4ip_nonkinetic!(out, ws, psi, t) -> out

`out .= −i (H − K) ψ` at time `t`, assembled from the term registry.

Every term except `KineticTerm` contributes through `apply_operator!`, which
ACCUMULATES (`out .+= H·ψ`) and gates itself off when inactive, so `out` is
zeroed once and the registry walked once. `LossTerm` is excluded too: it is not
part of the Hamiltonian flow and has its own Strang-compatible substep.

`ws.state.t` is set around the call because time-dependent terms read it, and is
restored on the way out — including on error.
"""
function _rk4ip_nonkinetic!(out, ws::Workspace, psi, t::Float64)
    t_saved = ws.state.t
    ws.state.t = t
    try
        fill!(out, 0)
        _rk4ip_accumulate!(out, build_h_terms_registry(ws), ws, psi)
    finally
        ws.state.t = t_saved
    end
    @. out *= -im
    out
end

# Unrolled over the registry NTuple so the walk stays type-stable.
@inline _rk4ip_accumulate!(out, ::Tuple{}, ws, psi) = nothing
@inline function _rk4ip_accumulate!(out, terms::Tuple, ws, psi)
    term = first(terms)
    if !(term isa KineticTerm) && !(term isa LossTerm)
        apply_operator!(out, term, ws, psi)
    end
    _rk4ip_accumulate!(out, Base.tail(terms), ws, psi)
end

"Apply `e^{K dt/2}` in place. The phase is baked into the cache, so it is retuned
to `dt/2` at the top of every step; do not interleave `rk4ip_step!` with a
propagator that assumes the cache carries the full `dt`."
@inline function _rk4ip_half_kinetic!(ws::Workspace, arr)
    apply_kinetic_step_batched!(arr, ws.batched_kinetic)
    arr
end

const _RK4IP_SCRATCH = IdDict{Any, NTuple{5, Any}}()

function _rk4ip_scratch(psi::A) where {A <: AbstractArray}
    get!(_RK4IP_SCRATCH, (size(psi), eltype(psi), A)) do
        ntuple(_ -> similar(psi), 5)
    end
end

"""
    rk4ip_step!(ws; dt=ws.sim_params.dt)

One RK4IP step. Mutates `ws.state.psi`, advances `ws.state.t` by `dt` and
increments `ws.state.step`.

    run_simulation!(ws; stepper=rk4ip_step!)

The `dt` keyword is what makes this usable with the existing controller —

    adaptive_step!(ws, AdaptiveDtState(dt0); step! = rk4ip_step!, p = 4)

which supplies the Richardson defect estimate and the Söderlind PI3.4 proposal.
That matters more here than for a split-step: RK4IP has a hard stability wall
rather than a graceful one. Measured on an Eu-like 12³ DDI config
(`scripts/validation/rk4ip_step_size_probe.jl`) it holds 2.4× Strang's step at a
1e-4 error budget and 4.2× at 1e-5, then **diverges outright** between dt = 2.5e-2
and 5e-2 — 1.5e-1 relative error becomes 4e40. A unitary split-step degrades
instead of exploding, so it forgives an over-large `dt` and this does not.

Real time only — in imaginary time the interaction-picture factor is a growing
exponential and the RK stages are not a descent. Use `split_step!` for ITP.

`normalize_every` is deliberately NOT honoured. RK4IP is not norm-conserving, so
its norm drift is a free running error monitor (it tracks the L2 error to within
an order over four decades of `dt`); renormalising would erase the one diagnostic
the method hands you for nothing. Reach for `split_step!` if you want the norm
pinned.
"""
function rk4ip_step!(ws::Workspace; dt::Float64=ws.sim_params.dt)
    ws.sim_params.imaginary_time &&
        throw(ArgumentError("rk4ip_step! is real-time only; use split_step! for ITP"))

    t = ws.state.t
    psi = ws.state.psi
    psi_I, k1, k2, k3, tmp = _rk4ip_scratch(psi)

    # The cache phase is exp(-i k² dt/2) for THIS step's dt.
    _update_batched_kinetic_phase!(ws.batched_kinetic, ws.grid.k_squared, dt / 2, false)

    # ψ_I = e^{K dt/2} ψⁿ  and  k₁ = e^{K dt/2}[dt·N(ψⁿ,tⁿ)]
    _rk4ip_nonkinetic!(k1, ws, psi, t)
    @. k1 *= dt
    copyto!(psi_I, psi)
    _rk4ip_half_kinetic!(ws, psi_I)
    _rk4ip_half_kinetic!(ws, k1)

    # k₂ = dt·N(ψ_I + k₁/2, tⁿ + dt/2)
    @. tmp = psi_I + k1 / 2
    _rk4ip_nonkinetic!(k2, ws, tmp, t + dt / 2)
    @. k2 *= dt

    # k₃ = dt·N(ψ_I + k₂/2, tⁿ + dt/2)
    @. tmp = psi_I + k2 / 2
    _rk4ip_nonkinetic!(k3, ws, tmp, t + dt / 2)
    @. k3 *= dt

    # From here the overwrite order is load-bearing, so it is spelled out.
    # `tmp` takes the k₄ argument BEFORE k₁ is recycled, and k₂/k₃ are folded
    # into k₁ before k₂ is reused for k₄.

    # k₄ argument: e^{K dt/2}(ψ_I + k₃)
    @. tmp = psi_I + k3
    _rk4ip_half_kinetic!(ws, tmp)

    # ψ_I ← e^{K dt/2}(ψ_I + (k₁ + 2k₂ + 2k₃)/6)   — k₂, k₃ are dead after this
    @. k1 += 2 * k2 + 2 * k3
    @. psi_I += k1 / 6
    _rk4ip_half_kinetic!(ws, psi_I)

    # k₄, into the now-free k₂
    _rk4ip_nonkinetic!(k2, ws, tmp, t + dt)
    @. psi = psi_I + (dt / 6) * k2

    # Loss and the absorbing boundary are excluded from the RK stages above
    # (`_rk4ip_accumulate!` skips `LossTerm`) because they are not part of the
    # Hamiltonian flow, so they ride the same real-time epilogue every other RTP
    # step loop uses. Omitting this is not a small error: it makes every `loss:`
    # config run silently loss-free. `test/oracles/test_path_coverage.jl` gates
    # exactly that — any `src` file that advances `ws.state.step` must either
    # call this or be listed as an explicit exception.
    apply_rt_dissipation!(ws, dt, size(psi, ndims(psi)), ndims(psi) - 1)

    ws.state.t = t + dt
    ws.state.step += 1
    psi
end
