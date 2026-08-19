# --- Does the claim's CONTROL switch anything off? ---
#
# `Claim`'s constructor enforces that a `:B`/`:C` claim DECLARED a control, and
# says so in its own comment: "The constructor cannot check that the control
# actually fails; only running it can. It can insist one was declared." That
# leaves a gap the constructor named and could not close, and this file closes
# the half of it that does not need a run.
#
# The half that does: a control which differs from the evidence only in its
# NUMERICS is not a control. `Claim`'s docstring already states the rule — "the
# control is the physics switched off, not a tolerance loosened: a control that
# differs from the evidence only in its numerics tests the plumbing, and a
# bit-identical A/B has been read as physics in this repository before" — and
# nothing read it. That failure is on the record twice, as
# `mistake_bit_identical_ab_read_as_physics_2026_07_29` and as
# `mistake_null_from_a_degenerate_knob_2026_07_31`, and in both cases the
# declaration in front of the author already contained the evidence: the two
# arms differed in a field that cannot move the observable.
#
# The half that does NOT: whether the control's number actually comes out wrong.
# That needs both arms run and an observable, and `Claim` carries no predicate,
# so `verify_claim` deliberately does not pretend to it. `checked_by_running =
# false` is in the audit for exactly the reason `VerdictAudit.checked` is in that
# one — "the instrument read zero" and "the instrument was not switched on" are
# different results and a struct that conflates them is worse than no struct.
#
# WHY THE NUMERICS SET IS A LIST AND NOT A RULE. The obvious rule — "the physics
# is in `Model`, the numerics are in `Stage`" — is wrong in this tree, and the
# counterexample is the claim that motivated the layer. Klaus 2022's control is
# the stir tilt taken to zero, and `evolve_stage` puts the stir protocol in
# `Stage.params` because `Model` is spinor-shaped and the scalar eGPE path
# cannot produce one. A gate built on that rule would have reddened on the one
# well-formed control in the repository, and a gate that fires on correct work
# gets switched off. So the discrimination is a NAMED LIST of param keys that
# are unambiguously numerics, it is deliberately short, and being absent from it
# is not an accusation — an unrecognised key counts as physics-bearing, i.e. the
# list can only ever cause a PASS, never a failure. Adding a key to it is
# therefore a decision to stop the gate seeing that key, and belongs in a diff
# where a reviewer sees it.

export ClaimAudit, verify_claim

"""
    ClaimAudit

What could be established about a `Claim` WITHOUT running it.

`ok` is a statement about the claim's *structure*, never about its result:
`checked_by_running` is always `false` and is present so that no caller can read
a structural pass as an experimental one. A claim can be perfectly well formed
and still be false.

`problems` is empty iff `ok`. `differences` maps each evidence stage's index to
the dotted paths on which the control differs from it, so a failure names the
fields rather than asserting a verdict.
"""
struct ClaimAudit
    ok::Bool
    checked_by_running::Bool
    problems::Vector{String}
    differences::Dict{Int, Vector{String}}
end

# Stage params that are unambiguously numerics. See the header: absence from
# this list is not an accusation, so the list stays short and errs toward
# omission — every key NOT here is treated as physics-bearing, which can only
# make the gate quieter, never louder.
const _NUMERICS_ONLY_PARAMS = Set{Symbol}([
    :dt, :n_steps, :n_save, :save_every, :tol, :max_iters, :max_iterations,
    :checkpoint_every, :verbose, :dtype, :seed,
])

_diff_paths(prefix::String, a, b) =
    _speceq(a, b) ? String[] : [prefix]

function _nt_diff_paths(prefix::String, a::NamedTuple, b::NamedTuple)
    out = String[]
    for k in union(keys(a), keys(b))
        av = get(a, k, nothing)
        bv = get(b, k, nothing)
        _speceq(av, bv) || push!(out, "$prefix.$k")
    end
    sort!(out)
    out
end

function _model_diff_paths(a::Model, b::Model)
    out = String[]
    for i in 1:fieldcount(Model)
        _speceq(getfield(a, i), getfield(b, i)) ||
            push!(out, "model.$(fieldname(Model, i))")
    end
    out
end

"""
    stage_differences(a::Stage, b::Stage) -> Vector{String}

The dotted paths on which two stages differ — `model.<field>`, `params.<key>`,
`kind`, `method`, `backend`, `from`.

`from` is compared as a whole rather than recursed: a control that branches from
a different predecessor differs, and *which* ancestor field moved is a question
about that ancestor's own claim.
"""
function stage_differences(a::Stage, b::Stage)
    out = String[]
    append!(out, _diff_paths("kind", a.kind, b.kind))
    append!(out, _model_diff_paths(a.model, b.model))
    append!(out, _diff_paths("method", a.method, b.method))
    append!(out, _diff_paths("from", a.from, b.from))
    append!(out, _nt_diff_paths("params", a.params, b.params))
    append!(out, _diff_paths("backend", a.backend, b.backend))
    out
end

# A path is physics-bearing unless it is one of the two numerics-only stage
# fields or a param on the named list. `from` counts as physics-bearing: a
# control seeded from a different state is a different experiment, and calling
# that "numerics" would admit the case where the whole control IS the reseed.
function _is_numerics_only(path::AbstractString)
    path in ("method", "backend") && return true
    startswith(path, "params.") || return false
    Symbol(path[8:end]) in _NUMERICS_ONLY_PARAMS
end

"""
    verify_claim(c::Claim) -> ClaimAudit

Check what can be checked about a claim without running it.

Three refusals, each one a failure this repository has actually shipped:

1. **no evidence at all.** `Claim`'s constructor admits `evidence = Stage[]` on
   purpose — its comment says the hole is "pinned as behaviour ... rather than
   silently closed here, so that closing it is a decision someone makes with the
   gap in front of them". This is that decision, made *here* rather than in the
   constructor, so building a claim to hold a plan still works and only
   *auditing* one insists the computation exists.
2. **the control IS an evidence stage.** Nothing is switched off.
3. **the control differs from an evidence stage only in numerics.** The
   plumbing-vs-physics failure named in `Claim`'s own docstring.

Returns rather than throws: an audit that throws on the first problem reports
one of three, and the useful output is the whole list.

`ok = true` says the claim is WELL FORMED. It does not say the claim is true —
`checked_by_running` is `false` in every audit this function returns, because
`Claim` carries no predicate and no observable to apply one to.

```julia
a = verify_claim(c)
a.ok || foreach(println, a.problems)
```
"""
function verify_claim(c::Claim)
    problems = String[]
    differences = Dict{Int, Vector{String}}()

    isempty(c.evidence) && push!(problems,
        "a :$(c.kind) claim with no evidence: `evidence` is empty, so nothing " *
        "was computed for \"$(c.statement)\"")

    if c.control !== nothing
        for (i, e) in enumerate(c.evidence)
            d = stage_differences(c.control, e)
            differences[i] = d
            if isempty(d)
                push!(problems,
                    "control is identical to evidence[$i]: nothing is switched off")
            elseif all(_is_numerics_only, d)
                push!(problems,
                    "control differs from evidence[$i] only in numerics " *
                    "($(join(d, ", "))): that tests the plumbing, not the physics")
            end
        end
    end

    ClaimAudit(isempty(problems), false, problems, differences)
end
