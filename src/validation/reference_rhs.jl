# --- Reference RHS (self-contained validation chain) ---
#
# Minimal CPU-only term-by-term Hψ implementations of every operator
# in the spinor GP Hamiltonian. Independent of the production
# split-step / propagator path. Used by `test/test_reference_rhs.jl`
# to diff against `energy_decomposition` and finite-difference of
# `split_step!`.
#
# Convention: each `reference_<term>_apply!(out, psi, ...)` writes
# `(H_term ψ)(r)` into `out`. Each `reference_<term>_energy(psi, ...)`
# returns `⟨ψ|H_term|ψ⟩` with the *same* numeric prefactor as the
# production `_<term>_energy` in `src/analysis/energy.jl` (i.e. the
# 1/2 for two-body terms is baked in here too). So `validation`-level
# code can compare them directly without juggling factor-of-2s.
#
# Why a separate file tree under src/validation/ rather than
# scripts/validation/: tests need it loadable as `SpinorBEC.<name>`,
# and we want the GP convention assertions to live next to a real
# implementation, not in a side-script.
#
# Status: BLOCKED_EXTERNAL Ueda comparison superseded by these
# reference kernels (2026-05-26 pivot, see
# `docs/validation/ueda_status.md`).

include("reference_rhs/scalar.jl")
include("reference_rhs/zeeman.jl")
include("reference_rhs/contact.jl")
include("reference_rhs/ddi.jl")
include("reference_rhs/loss.jl")
include("reference_rhs/total.jl")
