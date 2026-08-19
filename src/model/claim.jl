# --- Claim: the A/B/C taxonomy, enforced instead of asserted ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.5.
#
# The verification-type split — A: code correctness, B: physics agreement, C:
# model fidelity — has been repo policy for a long time and has been enforced by
# nothing. "Tests pass" is an A statement and "matches Klaus et al. 2022" is a C
# statement, and the only thing stopping a report from swapping them is whoever
# writes the report. The inner constructor below is the entire enforceable
# content of that taxonomy: three lines that refuse the three ways the categories
# get conflated. It is not a type hierarchy and should not become one — a
# `struct TypeCClaim <: AbstractClaim` would move the decision back to whoever
# picks the type.
#
# What each refusal buys:
#
# - `kind in (:A, :B, :C)` — the taxonomy is closed. `:physics` and `:C_ish` are
#   not categories.
# - a `:B` or `:C` claim needs a CONTROL: an arm that must FAIL. A physics claim
#   with no control is the failure mode this repository has hit repeatedly — a
#   null read as evidence, a bit-identical A/B read as physics, a knob the
#   observable is degenerate in. The constructor cannot check that the control
#   actually fails; only running it can. It can insist one was declared.
# - a `:C` claim needs a registered literature TARGET, and one that ARBITRATES.
#   Model fidelity is a statement about a published number, so it needs the
#   published number, from `refs/<paper>.toml` via `ref` — where the target is
#   measured off a committed fixture rather than typed. "Arbitrating" is not an
#   extra opinion: it means nothing in `REF_DISQUALIFIERS` applies, i.e. their
#   axis, the window and the metric all permit this number to decide. An `:A`
#   claim needs neither: GPU == CPU has no literature and needs no control beyond
#   the equality itself.
#
# Deliberately NOT enforced here, and worth naming rather than leaving to be
# discovered: `evidence = Stage[]` passes every check above, so a `:C` claim with
# a control, a target and NO EVIDENCE AT ALL constructs cleanly. That is exactly
# the shape someone reaches for to make a claim "done" before the computation
# exists. The design specifies eight lines and this is eight lines; the hole is
# pinned as behaviour by `test/validation/test_matsui2025_ref.jl` rather than
# silently closed here, so that closing it is a decision someone makes with the
# gap in front of them.

export Claim, claim, CLAIM_KINDS

"""
The verification types. `:A` code correctness (units, signs, conservation,
bit-identity, GPU == CPU) / `:B` physics agreement (closed-form limits, F=1
polar vs FM, polyhedral classification) / `:C` model fidelity (comparison with
published experimental data).
"""
const CLAIM_KINDS = (:A, :B, :C)

"""
    Claim(statement, kind, evidence, control, target)
    claim(statement; kind, evidence, control=nothing, target=nothing)

One assertion, with the arms that support it and the arm that must fail.

| field | meaning |
|---|---|
| `statement` | what is being claimed, in words |
| `kind` | `:A` code correctness / `:B` physics agreement / `:C` model fidelity |
| `evidence` | the stages whose results support it |
| `control` | the arm that must FAIL — required for `:B` and `:C` |
| `target` | a row from `refs/<paper>.toml` via `ref` — required for `:C`, and it must ARBITRATE |

```julia
claim("our Fig. 4B dip width reproduces Matsui et al.";
      kind = :C,
      evidence = [scan_stage],
      control  = c_dd_zero_stage,          # switch off the dipolar drive
      target   = ref(:matsui2025, :dip_width_exp_scanwindow_nT))
```

The control is the physics switched off, not a tolerance loosened: a control
that differs from the evidence only in its numerics tests the plumbing, and a
bit-identical A/B has been read as physics in this repository before.
"""
struct Claim
    statement::String
    kind::Symbol
    evidence::Vector{Stage}
    control::Union{Nothing, Stage}
    target::Union{Nothing, NamedTuple}

    function Claim(statement, kind, evidence, control, target)
        kind in CLAIM_KINDS || throw(ArgumentError("kind must be :A/:B/:C; got :$kind"))
        kind in (:B, :C) && control === nothing &&
            throw(ArgumentError("a :$kind claim needs a control that trips it"))
        kind === :C && target === nothing &&
            throw(ArgumentError("a :C claim needs a registered literature target"))
        # ...and the target has to be one that can DECIDE. `arbitrates` declared
        # exactly this ("whether this number decides a comparison, or is merely
        # quotable") and nothing read it, so a `:C` claim could be built against
        # `dip_centre_exp_nT` — the row whose own note says it "exists to be
        # quotable and to be REFUSED as a target", because the Fig. 4 caption
        # admits a 10 nT axis offset on a 3.2 nT centre. This is the one place in
        # the tree where a number is offered as deciding a comparison, so it is
        # the place the flag has to bite; a flag nothing reads should be cut, not
        # kept as documentation with a Bool type.
        kind === :C && target !== nothing && !get(target, :arbitrates, false) &&
            throw(
                ArgumentError(
                    "a :C claim needs an ARBITRATING target; " *
                    "$(get(target, :source, :?)).$(get(target, :quantity, :?)) is " *
                    "disqualified by " *
                    join(String.(get(target, :disqualified_by, Symbol[])), ", ") *
                    ". Those are properties of the reference (its axis, its window, " *
                    "its metric), not of our result — a number they disqualify is " *
                    "quotable, and quoting it as agreement claims more than it supports."),
            )
        new(statement, kind, evidence, control, target)
    end
end

claim(statement::AbstractString; kind::Symbol, evidence::AbstractVector{Stage},
    control::Union{Nothing, Stage}=nothing,
    target::Union{Nothing, NamedTuple}=nothing) = Claim(
    String(statement), kind, Vector{Stage}(evidence), control, target)

# Structural, for the same reason `Stage` needs it: `evidence` is a `Vector` and
# `Stage` reaches `Vector` fields, so the default `==` is object identity and two
# claims built from the same declaration would compare unequal.
Base.:(==)(a::Claim, b::Claim) = _speceq(a, b)
Base.hash(c::Claim, h::UInt) = _spechash(c, h)
