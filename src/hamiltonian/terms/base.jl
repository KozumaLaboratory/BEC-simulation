# --- HamTerm protocol ---
#
# Single source of truth for each Hamiltonian term. See
# `docs/conventions/sign_bug_proof_architecture.md` for the design.
#
# Each concrete `<: HamTerm` subtype declares its sign convention in
# ONE location. Propagator (`apply_step!`), energy
# (`energy_contribution`), gradient (`apply_operator!`), and directional
# sign oracle (`sign_oracle`) are all derived from that single
# declaration. The FD-consistency test in
# `test/oracles/test_term_consistency.jl` auto-verifies that the
# derived implementations agree numerically, ruling out the bug class
# documented in `feedback_hamiltonian_sign_oracle_discipline.md`.
#
# Performance discipline: use `Tuple{T1, T2, ...}` (NOT
# `Vector{HamTerm}`) to hold the term list in `Workspace`. The Julia
# compiler then specializes `for term in tuple` per-element, producing
# code equivalent to direct hand-written calls — zero abstraction
# overhead. Concrete `<: HamTerm` subtypes (e.g. `ZeemanTerm`) make
# `apply_step!(term, ...)` a compile-time dispatch.

"""
Abstract type for a single Hamiltonian term. Concrete subtypes
declare their sign convention via one coefficient function and
derive `apply_step!`, `energy_contribution`, `apply_operator!`, and
`sign_oracle` from it.
"""
abstract type HamTerm end

"""
    apply_step!(term::HamTerm, psi, dt, imaginary_time::Bool, ws)

Apply `exp(-i·dt·H_term)` (RT) or `exp(-H_term·dτ)` (IT) to `psi`.
"""
function apply_step! end

"""
    apply_operator!(out, term::HamTerm, ws, psi) -> out

THE single source for the term's operator action on `psi`. ACCUMULATES:
`out .+= H·ψ` per voxel. Never `fill!(out, …)` inside an implementation.

Gate-first rule: inactive terms return `out` untouched BEFORE any
allocation:
  `ws.ddi === nothing && return out`
  `(term.bx == 0.0 && term.by == 0.0) && return out`

Callers needing the bare action H·ψ must zero `out` first:
  `fill!(out, zero(eltype(out))); apply_operator!(out, term, ws, psi)`

Context-aware overload: `apply_operator!(out, term, ws, psi, ctx::GradientContext)`
reuses pre-built density/spin-density/FFT buffers from `ctx` to skip
per-call allocations on the hot registry path.

Convention for the trinity:
- Linear terms (kinetic, trap, zeeman, light_shift, raman, coriolis,
  magnetic_gradient): `energy_contribution = Re⟨ψ, apply_operator(ψ)⟩ · dV`.
- Mean-field terms (density_c0, spin_c1, ddi, tensor):
  `energy_contribution = (1/2) · Re⟨ψ, apply_operator(ψ)⟩ · dV`.
- LHY (n^(5/2) integrand): `energy = (2/5) · Re⟨ψ, apply_operator(ψ)⟩ · dV`.
- Gradient IS `apply_operator!` accumulation: callers zero `out`, then
  `apply_operator!(out, term, ws, psi)` to obtain `out = H·ψ`.
  The outer LBFGS driver applies the Wirtinger ×2.
- `apply_step!(term, ws, dt)` uses the SAME coefficient (e.g. the `c0`
  inside `apply_operator`) inside `exp(-i·dt·...)`. The propagator and
  the operator action share their coefficient source.

The FD-consistency oracle in
`test/oracles/test_master_oracle.jl` verifies that
`δE_term[ψ]/δψ̄` measured via finite differences agrees with
`apply_operator!(...)` for every term. If they drift, either
`energy_contribution` or `apply_operator!` is wrong, and the operator
is the single source of truth.
"""
function apply_operator! end

"""
    energy_contribution(term::HamTerm, psi, ws) -> Float64

Return this term's contribution to total energy `⟨ψ|H_term|ψ⟩`.
"""
function energy_contribution end

"""
    sign_oracle(term::HamTerm) -> NamedTuple{(:name, :predicate)}

Return a directional sign-oracle for this term as a NamedTuple
`(name="...", predicate=ws -> Bool)`. The predicate runs an ITP
from a known seed under H_term ONLY (other Hamiltonian terms set
to zero), measures a physical observable, and returns whether the
sign matches the user-spec convention.
"""
function sign_oracle end

# ============================================================================
# Shared scratch contexts (forward-declared so term files can specialise
# `apply_operator!(out, term, ws, psi, ctx::GradientContext)` /
# `energy_contribution(term, psi, ws, ctx::EnergyContext)` without an
# include-order trap). Builders live in `registry.jl`.
# ============================================================================

"""
    EnergyContext

Per-call scratch container shared across `energy_contribution(term,
psi, ws, ctx)` invocations. Pre-builds the total density and
spatial-spin density (`fx, fy, fz`) so DensityC0Term, SpinC1Term,
LHYTerm, ZeemanTerm, CoriolisTerm and others do not
duplicate that work.
"""
struct EnergyContext{ND, PsiT, FFTBuf, FFTPlan, SM, NRho, NF}
    # NOTE: the original definition typed psi_host as Array{ComplexF64, ND}
    # while n_pts/fft_buf are ND-dimensional SPATIAL objects — ψ has ND+1
    # dims, so the constructor could never be called. It had zero callers
    # until P1 wired the ctx into energy_breakdown_via_registry, which is
    # when the latent mismatch surfaced (dead scaffolding cannot be wrong
    # in a detectable way until something consumes it).
    psi_host::PsiT
    # `FFTBuf`, not `Array{ComplexF64, ND}`: this buffer is handed to
    # `ws.fft_plans`, which are planned for ψ's eltype, and FFTW's in-place plans
    # reinterpret the memory they receive. Pinning ComplexF64 here meant every
    # Float32 workspace fed a ComplexF64 buffer to a ComplexF32 in-place plan —
    # no error, garbage out: the F32 kinetic energy came back 0.0035 against
    # 0.48, i.e. the reported F32 total was ~10 % wrong while every other term
    # agreed to 1e-8 (2026-07-29). Gated by
    # test/gpu/test_mixed_precision.jl's per-term F32/F64 comparison.
    fft_buf::FFTBuf
    plans::FFTPlan
    spin_matrices::SM
    n_density::NRho
    fx::NF
    fy::NF
    fz::NF
    dV::Float64
    n_pts::NTuple{ND, Int}
end

"""
    GradientContext

Per-call scratch container shared across `apply_operator!(out, term,
ws, psi, ctx)` invocations. Pre-builds the total density, spin
density, FFT buffer, and a `deriv_buf` scratch so the registry path
matches the legacy `_grad_*` helpers' allocation pattern (no extra
allocs vs the hand-written sum in `energy_gradient!`).
"""
struct GradientContext{N, TF, TC, TD}
    fft_buf::TC
    deriv_buf::TC
    fx::TF
    fy::TF
    fz::TF
    n_density::TD
    n_pts::NTuple{N, Int}
end
