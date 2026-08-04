# Adding a new Hamiltonian term

This is the canonical procedure since Phase 3 of the sign-bug-proof
architecture (2026-06-04). See
`docs/conventions/sign_bug_proof_architecture.md` for the architectural
motivation.

## Step 1: Pick the sign convention

Refer to `src/workflow/experiments/runtime/b_block_builders.jl:27`:

```
H_Zeeman = -p·F_z + q·F_z²          # operator form (Kawaguchi-Ueda)
         = +(g_F μ_B B · F) + q F_z²   # in lab field, since p ≡ -g_F μ_B B
# Read `-(g_F μ_B B · F)` until 2026-08-04 — the lab-field sign was inverted
# here and in docs/conventions/hamiltonian_sign_audit.md. +Bz on a g_F>0 atom
# (Eu, Cr, He*) gives ground state m = -F. Declared once in Units.bfield_to_p.
```

For your term, write the equivalent one-line H expression at the top
of your file as a comment. This is the source of truth.

## Step 2: Create `src/hamiltonian/terms/<your_term>.jl`

Boilerplate (model after `src/hamiltonian/terms/zeeman_z.jl`):

```julia
# --- YourTerm HamTerm ---
#
# H_<your_term> = <one-line expression involving coupling, ψ, F, ∇, ...>.

"""<one-line docstring>"""
struct YourTerm <: HamTerm
    coupling::Float64
    # ... other fields
end

# THE ONE LINE. Sign convention lives here exclusively.
# Choose either:
#   _diag_coef(term, m) = ...            # for diagonal-in-m terms
#   _h_matrix(term, sm) = ...            # for matrix-local terms
#   _<your_op_name>(term, ...) = ...     # for FFT/spectral/non-local terms

function apply_step!(term::YourTerm, psi, dt::Real, imaginary_time::Bool, ws)
    # Either implement directly from the coefficient function, OR
    # delegate to an existing audited routine (e.g.
    # `_apply_coriolis_step!` for FFT-spectral).
    return nothing
end

function energy_contribution(term::YourTerm, psi, ws)
    # Compute ⟨ψ|H_<your_term>|ψ⟩.
    return 0.0
end

function add_gradient!(grad, term::YourTerm, psi, ws)
    # Add δE/δψ̄ contribution. NO factor of 2 (energy_gradient! adds it
    # at the end). Mirror `_grad_*` patterns for spinor matrix
    # multiplication.
    return nothing
end

sign_oracle(::Type{YourTerm}) = (
    name="YourTerm: +coupling ⇒ <physical observable> > 0",
    predicate=function (psi, ws)
        # Compute observable, return Bool: does it have the expected sign?
        return ...
    end,
)
```

## Step 3: Register

Edit `src/hamiltonian.jl`, add the include line:

```julia
include("hamiltonian/terms/your_term.jl")
```

after the existing term includes.

Edit `src/hamiltonian/terms/registry.jl`, add your term to
`build_h_terms_registry`:

```julia
return (
    Kinetic(),
    ...
    YourTerm(<derive coupling from ws fields>),
    ...
)
```

Optional: add to `energy_breakdown_via_registry` NamedTuple if you want
a per-term breakdown report.

## Step 4: Add the directional sign test

Edit `test/oracles/test_hamiltonian_sign_oracles.jl`, add:

```julia
@testset "+coupling ⇒ ⟨observable⟩ > 0 (YourTerm)" begin
    grid = make_grid(...)
    zeeman = ...   # parity-breaker if needed
    r = find_ground_state(... use only your term + parity breaker)
    @test <observable> > <threshold>
end
```

## Step 5: Verify

```bash
LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. -e \
    'using SpinorBEC, Test, FFTW;
     include("test/oracles/test_hamiltonian_sign_oracles.jl");
     include("test/oracles/test_term_consistency.jl")'
```

Should report ALL tests passing — both directional sign oracle and
FD consistency check between your `energy_contribution` and
`add_gradient!`.

For terms with a legacy routine to compare against, also add a
bit-identity gate to `test/oracles/test_term_legacy_equivalence.jl`
(model after the `LinearZeemanZ` testset there).

## Why this discipline matters

Between 2026-06-02 and 2026-06-04 PM, **five** sign / missing-term
bugs of the same class appeared in the codebase. Every one was a
manual-duplication mistake between two implementations of the same
physics — propagator vs energy vs gradient vs CPU/GPU. Phase 1-3
of the sign-bug-proof architecture eliminates the root cause for
energy and gradient paths: the registry pattern means a new term
either is present in all paths or in none.

A new H term that follows the procedure above CANNOT produce a
sign / missing-term bug in energy or gradient. The CI gate
(`test/oracles/test_term_consistency.jl` in the `:ci` tier of
`runtests.jl`) enforces this on every PR.
