# --- HamTerm protocol ---
#
# Single source of truth for each Hamiltonian term. See
# `docs/conventions/sign_bug_proof_architecture.md` for the design.
#
# Each concrete `<: HamTerm` subtype declares its sign convention in
# ONE location. Propagator (`apply_step!`), energy
# (`energy_contribution`), gradient (`add_gradient!`), and directional
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
# overhead. Concrete `<: HamTerm` subtypes (e.g. `LinearZeemanZ`) make
# `apply_step!(term, ...)` a compile-time dispatch.

"""
Abstract type for a single Hamiltonian term. Concrete subtypes
declare their sign convention via one coefficient function and
derive `apply_step!`, `energy_contribution`, `add_gradient!`, and
`sign_oracle` from it.
"""
abstract type HamTerm end

"""
    apply_step!(term::HamTerm, psi, dt, imaginary_time::Bool, ws)

Apply `exp(-i·dt·H_term)` (RT) or `exp(-H_term·dτ)` (IT) to `psi`.
"""
function apply_step! end

"""
    energy_contribution(term::HamTerm, psi, ws) -> Float64

Return this term's contribution to total energy `⟨ψ|H_term|ψ⟩`.
"""
function energy_contribution end

"""
    add_gradient!(grad, term::HamTerm, psi, ws)

Add this term's contribution to `grad += δE/δψ*`. The standard
SpinorBEC convention is that `grad` later gets multiplied by 2 in
the outer `energy_gradient!` (see `energy_gradient.jl:85-88`). So
each `add_gradient!` adds `δE_term/δψ*` (no factor of 2).
"""
function add_gradient! end

"""
    sign_oracle(term::HamTerm) -> NamedTuple{(:name, :predicate)}

Return a directional sign-oracle for this term as a NamedTuple
`(name="...", predicate=ws -> Bool)`. The predicate runs an ITP
from a known seed under H_term ONLY (other Hamiltonian terms set
to zero), measures a physical observable, and returns whether the
sign matches the user-spec convention.
"""
function sign_oracle end
