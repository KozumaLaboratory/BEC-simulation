# --- Claim ledger (docs/campaign/claims.toml) ---
#
# Reader for the ledger that holds a physics claim's STATUS as a field.
#
# The failure this exists to stop is not a wrong number. It is a correct
# retraction written 160 lines above the place the number is used:
# `docs/manuscript/klaus_protocol_sheet.md` retracts `0.468 ± 0.003` at lines
# 17-70 and then states it bare at 105, 125 and 233 — the last inside the
# numbered lab protocol, annotated `(default)`. Two PRs updated the retraction
# block and left the protocol steps alone, because the status of a claim was not
# a thing the tree could hold and so lived in whichever paragraph someone
# remembered.
#
# Three field-level rules do the work, and each one is a state that used to be
# unrepresentable:
#
#   `uncertainty` is REQUIRED and may not be empty. A row nobody has bounded is
#   a fact, and `absent` must not be able to read as `small`.
#
#   `refuted` and `superseded` are different values, and `superseded_by` is
#   OPTIONAL — "refuted with no replacement" is a real outcome (1.3 nT has no
#   operating window) and had no way to be written down.
#
#   `retired_literal` is required on every non-live row. It is the string the
#   gate hunts, so a retraction is enforced at the point of use rather than at
#   the point of apology.
#
# Parsing is fail-closed, like `campaign_fix_list`: a row missing a required
# field throws instead of being skipped, because skipping is exactly what lets a
# claim escape the gate it was entered into.
#
# NOT THE SAME THING AS `src/model/claim.jl`, and the near-collision is worth
# naming so a third one does not appear. That file's `Claim` is PROSPECTIVE: an
# assertion tied to `Stage`s that have not run, whose constructor refuses a :B/:C
# claim with no control arm and a :C claim with no arbitrating literature target.
# This file's `LedgerClaim` is RETROSPECTIVE: an assertion already made, with the
# status, uncertainty and document anchor it carries now. One guards the design
# of a measurement, the other the shelf life of its result. The A/B/C taxonomy is
# shared and is DERIVED from `CLAIM_KINDS` here rather than retyped — `uncertainty
# _basis = "control"` in this ledger means the same thing as the control arm
# there.

using TOML

export LedgerClaim, claim_ledger, claim_ledger_path,
    CLAIM_STATUSES, CLAIM_LEDGER_TYPES, CLAIM_UNCERTAINTY_BASES, CLAIM_EVIDENCE_STATUSES,
    CLAIM_PREDICTION_OUTCOMES, CLAIM_RETRACTION_MARKERS, CLAIM_RETRACTION_PREMISE_ESCAPE,
    CLAIM_REDUCTION_NAMES, CLAIM_BOUNDARY_RULES,
    claim_ledger_link_errors, claim_by_id,
    retraction_is_grounded, retraction_is_self_grounded,
    ledger_section_coverage,
    retired_literals,
    unmarked_retired_literal_sites

"""
    CLAIM_STATUSES

The closed set a claim's status may take. Closed on purpose: a free-text status
re-creates the prose problem one column to the right.

  `live`       — currently asserted
  `scoped`     — true only inside a stated restriction; the restriction is the claim
  `superseded` — replaced by a better statement of the same quantity
  `refuted`    — measured false. May or may not have a replacement
  `suggested`  — hypothesis, not measured. Never quotable as a result
  `open`       — a known gap, named so a deferral is distinguishable from an oversight
  `closed`     — an `open` row that was shut by DOING the work. Not `refuted`
                 (nothing measured it false) and not deleted: erasing it would
                 erase the fact that the gap existed, which is the part a reader
                 needs in order to trust that the rest were looked at too. A
                 `closed` row must carry a `note` saying what closed it.
"""
const CLAIM_STATUSES = ("live", "scoped", "superseded", "refuted", "suggested",
    "open", "closed")

"""
    CLAIM_LEDGER_TYPES

`CAMPAIGN.md` §5 taxonomy as ledger strings, DERIVED from `CLAIM_KINDS` in
`src/model/claim.jl` rather than retyped. The taxonomy already had exactly one
declaration and this file is not going to be its second.
"""
const CLAIM_LEDGER_TYPES = String.(CLAIM_KINDS)

"""
    CLAIM_UNCERTAINTY_BASES

How the `uncertainty` field was obtained. `none` is legal and means the claim is
unbounded — it must then be paired with an `uncertainty` that says so in words.
"""
const CLAIM_UNCERTAINTY_BASES = ("fit", "grid", "dt", "seed", "control", "none")

"""
    CLAIM_PREDICTION_OUTCOMES

What became of a registered prediction: `hit` / `miss` / `pending`.

**There was a fourth, `moot`, for one day.** It was added 2026-08-21 for a row
whose prediction I believed could not be answered because its premise had
dissolved. It could be answered: §12.3 had already tested it on its informative
arm and it failed. I had run the arm that predicts an ABSENCE, not read the
section that ran the other one, and then extended the taxonomy to fit that.

Removed rather than kept-in-case. A category invented to describe a misdiagnosis
describes the analyst and not the world, and it would have sat here as a
plausible-looking option for the next person with an inconvenient outcome. If a
prediction ever genuinely becomes unanswerable, the row can say so in `note` and
the case for a fourth value can be made from an instance rather than from a
hypothetical.
"""
const CLAIM_PREDICTION_OUTCOMES = ("hit", "miss", "pending")

"""
    CLAIM_EVIDENCE_STATUSES

Whether `evidence` resolves in this repo. `absent` is common and is not by itself
a defect — most campaign arms are never committed — but it is the difference
between "re-deriving this is a re-run" and "re-deriving this is a re-derivation",
and that difference should not have to be rediscovered.
"""
const CLAIM_EVIDENCE_STATUSES = ("in_tree", "partial", "absent")

"""
    LedgerClaim

One `[[claim]]` row of `docs/campaign/claims.toml`.

`uncertainty` is a String and never `nothing`: the parser rejects a row without
one. `superseded_by` and `supersedes` are `nothing` when unset, which is a
different fact from `""`. `supersedes` is a vector: one row can genuinely replace several, and it does here —
`edh-5p2nt-ordering-is-hold-dependent` retires both the two-branch structure and the
search for its mechanism, because the structure it was a mechanism FOR does not exist.
`retired_literal` is likewise a (possibly empty) vector — a
retracted claim usually survives in more than one wording, and the lab
instruction and the mechanism sentence are different points of use.
"""
struct LedgerClaim
    id::String
    claim::String
    status::String
    type::String
    scope::String
    uncertainty::String
    uncertainty_basis::String
    evidence::Vector{String}
    evidence_status::String
    commit::String
    doc::String
    section::String
    pr::Union{Nothing, Int}
    supersedes::Vector{String}
    superseded_by::Union{Nothing, String}
    quantity::Union{Nothing, String}
    retired_literal::Vector{String}
    replacement_literal::Vector{String}
    prediction::Union{Nothing, String}
    prediction_registered::Union{Nothing, String}
    prediction_outcome::Union{Nothing, String}
    note::Union{Nothing, String}
    retraction_evidence::Union{Nothing, String}
    window::Union{Nothing, String}
    reduction::Union{Nothing, String}
    boundary::Union{Nothing, String}
end

"""
The escape hatch for `retraction_evidence`: a claim that never rested on a
measurement cannot be killed on a comparable one, and saying so is information.
Mirrors the `unbounded:` convention `uncertainty` already uses — the point of a
keyword is that "there was nothing to compare" and "nobody wrote it down" stop
looking the same.
"""
const CLAIM_RETRACTION_PREMISE_ESCAPE = "premise_dissolved:"

"""
    CLAIM_REDUCTION_NAMES

Words in a `quantity` that mean the number is a REDUCTION over a trajectory or a
scan, and therefore that the window it was taken in is part of the measurement.

A named list rather than a rule, and unknown forms are innocent — a `quantity`
that names none of these is not required to carry a window. The alternative,
demanding the fields of every row, would redden correct writing (`eta_start`,
a walltime ratio, an algebraic coefficient) and a gate that does that gets
deleted.
"""
const CLAIM_REDUCTION_NAMES = ("peak", "argmax", "optimum", "endpoint")

"""
    CLAIM_BOUNDARY_RULES

What was done when the reduction's argmax landed on the edge of its window.

  `reject`    — a boundary argmax was treated as a truncation, not a peak
  `accept`    — it was quoted as a peak. Often the defect, and it is written down
                rather than inferred: `edh-two-branches-5p2nt` says `accept` and
                is refuted for exactly that reason
  `unchecked` — nobody looked. NOT the same as `reject`, and it must not be able
                to read as it
  `n/a`       — the quantity is not an argmax at all (the detector above is a
                word list and will occasionally catch a fixed-time endpoint)
"""
const CLAIM_BOUNDARY_RULES = ("reject", "accept", "unchecked", "n/a")

"""
    claim_ledger_path(; repo=nothing) -> String

Path to `docs/campaign/claims.toml`. `repo` defaults to the package root.
"""
function claim_ledger_path(; repo::Union{Nothing, AbstractString}=nothing)
    root = repo === nothing ? normpath(joinpath(@__DIR__, "..", "..", "..")) : repo
    joinpath(root, "docs", "campaign", "claims.toml")
end

_opt(r, k) = (v=get(r, k, nothing); v isa AbstractString && !isempty(v) ? String(v) : nothing)

"""A field that is a string, an array of strings, or absent — normalised to a vector."""
function _strvec(r, k, id, path)
    v = get(r, k, nothing)
    v === nothing && return String[]
    v isa AbstractString && return [String(v)]
    v isa AbstractVector && return String[String(x) for x in v]
    throw(ArgumentError("$path claim `$id`: `$k` must be a string or an array of strings"))
end

function _required(r, k, i, path)
    v = get(r, k, nothing)
    (v isa AbstractString && !isempty(strip(v))) || throw(
        ArgumentError(
            "$path [[claim]] #$i ($(get(r, "id", "<no id>"))) is missing required " *
            "field `$k`. A row the gate cannot check must not exist — the whole " *
            "point of the ledger is that an unstated field reads as an unstated " *
            "fact and not as a benign default."),
    )
    String(v)
end

"""
    claim_ledger(; path=claim_ledger_path()) -> Vector{LedgerClaim}

Parse the ledger. Throws on any row that cannot be checked:

  - a missing required field (notably `uncertainty`)
  - a `status` / `type` / `uncertainty_basis` / `evidence_status` outside its set
  - `uncertainty_basis = "none"` on a row whose `uncertainty` does not say it is
    unbounded — a filled bound with no method behind it is the shape of a
    fabricated error bar
  - a non-`live` row with no `retired_literal`, which would be a retraction the
    gate cannot enforce anywhere
  - a non-`live` row with no `retraction_evidence`, i.e. a retraction that does
    not say on which axis the killing measurement differed from the killed one
  - a `quantity` that names a reduction (`peak`, `argmax`, `optimum`,
    `endpoint`) with no `window` / `reduction` / `boundary` — a peak with no
    window is not an observable

Link consistency between rows (`supersedes` ↔ `superseded_by`) is checked
separately by [`claim_ledger_link_errors`](@ref), so a single bad edge names
itself instead of aborting the parse.
"""
function claim_ledger(; path::AbstractString=claim_ledger_path())
    isfile(path) || throw(ArgumentError("claim ledger not found: $path"))
    doc = TOML.parsefile(path)
    rows = get(doc, "claim", nothing)
    rows isa AbstractVector || throw(ArgumentError("$path has no [[claim]] array"))
    out = LedgerClaim[]
    for (i, r) in enumerate(rows)
        id = _required(r, "id", i, path)
        status = _required(r, "status", i, path)
        status in CLAIM_STATUSES || throw(
            ArgumentError(
                "$path claim `$id` has status `$status`; must be one of " *
                join(CLAIM_STATUSES, ", "),
            ),
        )
        typ = _required(r, "type", i, path)
        typ in CLAIM_LEDGER_TYPES || throw(
            ArgumentError(
                "$path claim `$id` has type `$typ`; must be one of " *
                join(CLAIM_LEDGER_TYPES, ", ") * " (CAMPAIGN.md §5)",
            ),
        )
        unc = _required(r, "uncertainty", i, path)
        basis = _required(r, "uncertainty_basis", i, path)
        basis in CLAIM_UNCERTAINTY_BASES || throw(
            ArgumentError(
                "$path claim `$id` has uncertainty_basis `$basis`; must be " *
                "one of " * join(CLAIM_UNCERTAINTY_BASES, ", "),
            ),
        )
        if basis == "none" && !occursin("unbounded", lowercase(unc)) &&
            !occursin("not a measured", lowercase(unc)) &&
            !occursin("nothing to bound", lowercase(unc))
            throw(
                ArgumentError(
                    "$path claim `$id` has uncertainty_basis = \"none\" but an " *
                    "`uncertainty` that reads like a bound. Say `unbounded: <why>` " *
                    "— a stated bound with no method behind it is worse than a " *
                    "blank, because it survives being quoted."),
            )
        end
        estatus = _required(r, "evidence_status", i, path)
        estatus in CLAIM_EVIDENCE_STATUSES || throw(
            ArgumentError(
                "$path claim `$id` has evidence_status `$estatus`; must be " *
                "one of " * join(CLAIM_EVIDENCE_STATUSES, ", "),
            ),
        )
        retired = _strvec(r, "retired_literal", id, path)
        if status in ("superseded", "refuted") && isempty(retired)
            throw(
                ArgumentError(
                    "$path claim `$id` is `$status` but declares no " *
                    "`retired_literal`. Then nothing stops the retracted form " *
                    "being quoted, which is the exact defect this ledger was " *
                    "opened over."),
            )
        end
        # THE RETRACTION IS A CLAIM TOO. Eight times in this repo's history a
        # retraction was itself wrong and had to be withdrawn, and the shape was
        # never haste: the killed claim rested on a run and the killing one was
        # allowed to rest on prose. Two arms of
        # `test_retracted_numbers_carry_their_replacement.jl` already bind the
        # ROW DOING THE KILLING (a live `supersedes` row needs in_tree evidence
        # and a real basis; a bare retirement needs `note` + `pr`). What neither
        # could see is the COMPARISON: on which axis the killing measurement
        # differs from the killed one, and what the two values were.
        #
        # "The same convergence ladder" is the wrong requirement and was the
        # first draft of this field. A refutation usually differs deliberately on
        # exactly one axis — 32³ → 64³, an 8 ms hold → 16 ms, two seeds → eight —
        # and demanding sameness would forbid the move that does the work. What
        # is wanted is that the axis is NAMED and both sides are stated, so a
        # reader can tell a refinement from a different experiment.
        retr_ev = _opt(r, "retraction_evidence")
        if status in ("superseded", "refuted") && retr_ev === nothing
            throw(
                ArgumentError(
                    "$path claim `$id` is `$status` but declares no " *
                    "`retraction_evidence`. Name the axis the killing measurement " *
                    "moved and give both values (\"grid 32³ → 64³; the ordering " *
                    "inverts\"). If the claim never rested on a measurement, say " *
                    "`$(CLAIM_RETRACTION_PREMISE_ESCAPE) <why>` — that is a real " *
                    "outcome and must not look like a blank."),
            )
        end
        # A REDUCTION WITHOUT ITS WINDOW IS NOT AN OBSERVABLE. At B = 10.4 nT
        # three readings of the same cached arms put the argmax at three
        # different points, and 16 of 20 arms had theirs on the hold's FIRST
        # frame — a decaying pre-hold transient, ranked as if it were the
        # cascade. Nothing was wrong with the runs. The window and the reduction
        # were chosen after the campaign, which is what makes it not a
        # measurement.
        #
        # `quantity` already collides two rows that describe the same number.
        # These three fields make the number itself say what it is, so two
        # readings of one trajectory collide instead of coexisting.
        quant = _opt(r, "quantity")
        if quant !== nothing &&
            any(occursin(w, lowercase(quant)) for w in CLAIM_REDUCTION_NAMES)
            for k in ("window", "reduction", "boundary")
                _opt(r, k) === nothing && throw(
                    ArgumentError(
                        "$path claim `$id` has a `quantity` naming a reduction " *
                        "($quant) but no `$k`. A peak is a peak OF something OVER " *
                        "something; state the window, the reduction and what was " *
                        "done when the argmax hit the edge."),
                )
            end
            bnd = _opt(r, "boundary")
            bnd in CLAIM_BOUNDARY_RULES || throw(
                ArgumentError(
                    "$path claim `$id` has boundary `$bnd`; must be one of " *
                    join(CLAIM_BOUNDARY_RULES, ", ")),
            )
        end
        status == "closed" && _opt(r, "note") === nothing &&
            throw(
                ArgumentError(
                    "$path claim `$id` is `closed` but carries no `note`. A gap " *
                    "recorded as shut without saying what shut it is indistinguishable " *
                    "from one quietly dropped."),
            )
        pred_reg = _opt(r, "prediction_registered")
        pred_reg === nothing || pred_reg in ("before", "after") ||
            throw(
                ArgumentError(
                    "$path claim `$id`: prediction_registered must be " *
                    "`before` or `after`",
                ),
            )
        pred_out = _opt(r, "prediction_outcome")
        pred_out === nothing || pred_out in CLAIM_PREDICTION_OUTCOMES ||
            throw(
                ArgumentError(
                    "$path claim `$id`: prediction_outcome must be one of " *
                    join(CLAIM_PREDICTION_OUTCOMES, ", "),
                ),
            )
        ev = get(r, "evidence", String[])
        ev isa AbstractVector || throw(
            ArgumentError("$path claim `$id`: `evidence` must be an array")
        )
        prnum = get(r, "pr", nothing)
        push!(
            out,
            LedgerClaim(id, _required(r, "claim", i, path), status, typ,
                _required(r, "scope", i, path), unc, basis,
                String[String(e) for e in ev], estatus,
                _required(r, "commit", i, path), _required(r, "doc", i, path),
                _required(r, "section", i, path),
                prnum isa Integer ? Int(prnum) : nothing,
                _strvec(r, "supersedes", id, path), _opt(r, "superseded_by"),
                _opt(r, "quantity"), retired,
                _strvec(r, "replacement_literal", id, path),
                _opt(r, "prediction"), pred_reg, pred_out, _opt(r, "note"),
                retr_ev, _opt(r, "window"), _opt(r, "reduction"),
                _opt(r, "boundary")),
        )
    end
    isempty(out) && throw(ArgumentError("$path declares no claims"))
    ids = [c.id for c in out]
    length(unique(ids)) == length(ids) ||
        throw(ArgumentError("$path has duplicate claim ids"))
    out
end

"""
    retraction_is_grounded(c::LedgerClaim) -> Bool

Whether a row that RETRACTS another rests on something the tree can resolve.

Binds only rows that are currently believed: a `superseded`/`refuted` row that
itself supersedes something is exempt, because a retraction later withdrawn is a
real outcome the ledger exists to hold, and demanding live evidence of a dead row
would push people to delete it.

It does NOT check that the evidence says what the row claims. It checks that a
replacement cannot be made out of nothing, which is what PR #295 was.
"""
retraction_is_grounded(status, supersedes, evidence_status, uncertainty_basis) =
    isempty(supersedes) || status in ("superseded", "refuted") ||
    (evidence_status == "in_tree" && uncertainty_basis != "none")

retraction_is_grounded(c::LedgerClaim) = retraction_is_grounded(
    c.status, c.supersedes, c.evidence_status, c.uncertainty_basis)

"""
    retraction_is_self_grounded(c::LedgerClaim) -> Bool

Whether a retirement WITH NO REPLACEMENT carries its own grounds.

`retraction_is_grounded` reaches only retractions that produced a successor, and
that is the smaller half: when a replacement exists the successor row carries the
measurement, and when there is none nothing else in the tree says why this died.

`note` + `pr`, not `evidence_status`: a refuted row's `evidence` describes what
the DEAD claim rested on. `commit` is deliberately not accepted — 9 of the 13
retired rows carried the literal string "unknown" there, so a rule keyed on it
would be satisfied by a value that names nothing.
"""
retraction_is_self_grounded(status, superseded_by, note, pr) =
    !(status in ("superseded", "refuted")) || superseded_by !== nothing ||
    (note !== nothing && !isempty(strip(note)) && pr !== nothing)

retraction_is_self_grounded(c::LedgerClaim) = retraction_is_self_grounded(
    c.status, c.superseded_by, c.note, c.pr)

"""
    claim_by_id(claims, id) -> Union{Claim, Nothing}
"""
claim_by_id(claims::AbstractVector{LedgerClaim}, id::AbstractString) =
    (i=findfirst(c -> c.id == id, claims); i === nothing ? nothing : claims[i])

"""
    claim_ledger_link_errors(claims) -> Vector{String}

Every way the supersession graph can be inconsistent, as human-readable lines.
Empty means the graph is sound.

Checked: dangling ids, self-links, and — the one that actually bites — a
`supersedes` edge whose target does not name it back. A half-declared retraction
is how a superseded row keeps reading as live from one side.
"""
function claim_ledger_link_errors(claims::AbstractVector{LedgerClaim})
    errs = String[]
    ids = Set(c.id for c in claims)
    for c in claims
        for (field, target) in vcat([("supersedes", t) for t in c.supersedes],
            [("superseded_by", c.superseded_by)])
            target === nothing && continue
            target == c.id && push!(errs, "claim `$(c.id)`: $field points at itself")
            target in ids ||
                push!(errs, "claim `$(c.id)`: $field = `$target`, which is not a claim id")
        end
        for sid in c.supersedes
            sid in ids || continue
            other = claim_by_id(claims, sid)
            other.superseded_by == c.id || push!(
                errs,
                "claim `$(c.id)` supersedes `$(other.id)`, but `$(other.id)` names " *
                "`$(something(other.superseded_by, "nothing"))` as its successor. " *
                "One-directional supersession leaves the old row reading live from " *
                "its own side.",
            )
            other.status == "live" && push!(
                errs,
                "claim `$(other.id)` is superseded by `$(c.id)` yet still has " *
                "status `live`.",
            )
        end
        if c.superseded_by !== nothing && c.superseded_by in ids
            other = claim_by_id(claims, c.superseded_by)
            c.id in other.supersedes || push!(
                errs,
                "claim `$(c.id)` names `$(other.id)` as its successor, but " *
                "`$(other.id)` does not declare `supersedes = \"$(c.id)\"`.",
            )
        end
        if c.prediction !== nothing && c.prediction_registered === nothing
            push!(
                errs,
                "claim `$(c.id)` carries a prediction with no " *
                "`prediction_registered`. A statement written after the measurement " *
                "is a description, and counting it as a prediction is how a ledger " *
                "starts flattering itself.",
            )
        end
    end
    # TWO ROWS MAY NOT ASSERT DIFFERENT VALUES OF ONE QUANTITY.
    #
    # This is the gate that would have caught 2026-08-21. `edh-104nt-bump-at-0p65`
    # measured peak P_adj at 10.4 nT over the whole trajectory; §12.2 had measured
    # the same quantity inside the hold a day earlier and got a different number.
    # Nothing collided, because §12 was never poured into the ledger and a row can
    # only collide with a row. Pouring is enforced by the coverage ratchet;
    # collision is enforced here.
    #
    # Only NON-RETIRED rows participate: a superseded row is supposed to disagree
    # with its successor, and that is the one disagreement the ledger exists to
    # record rather than forbid.
    byq = Dict{String, Vector{String}}()
    for c in claims
        c.quantity === nothing && continue
        c.status in ("live", "scoped", "open") || continue
        push!(get!(byq, c.quantity, String[]), c.id)
    end
    for (q, ids) in byq
        length(ids) > 1 && push!(
            errs,
            "quantity `$q` is asserted by $(length(ids)) non-retired rows " *
            "($(join(sort(ids), ", "))). Two live rows about one measured " *
            "quantity is the state this ledger exists to make unrepresentable: " *
            "one of them supersedes the other, or they are different quantities " *
            "and the strings should say so.",
        )
    end
    errs
end

"""
    retired_literals(claims) -> Vector{Pair{String, String}}

`retired_literal => claim id` for every non-live row. This is the list the
point-of-use gate scans documents for.
"""
retired_literals(claims::AbstractVector{LedgerClaim}) =
    [lit => c.id for c in claims for lit in c.retired_literal]

# --- The point-of-use gate ---------------------------------------------------

"""
    CLAIM_RETRACTION_MARKERS

The vocabulary a document must use where it states a retracted claim. Small and
closed on purpose: the gate has to be able to tell a marker from ordinary prose,
and a document that says "does not matter" in its own words is indistinguishable
from one that says nothing.

Case-sensitive members are included deliberately — `SUPERSEDED` in a table cell
reads as a status, `superseded` in a sentence reads as a description, and both
are legitimate marks.
"""
const CLAIM_RETRACTION_MARKERS = (
    "superseded", "refuted", "retired", "retracted", "no replacement",
    "vintage", "re-derived", "historical",
)

_collapse_ws(s::AbstractString) = replace(strip(s), r"[ \t]+" => " ")

"""
    unmarked_retired_literal_sites(; claims, docs_root, window=6, skip=("archive",))
        -> Vector{NamedTuple}

Every place a retired claim is stated in a live document without a retraction
marker near it. One NamedTuple per site: `(file, line, literal, claim_id, text)`.

**The rule is proximity, and the reason is measured.** `klaus_protocol_sheet.md`
carries a correct, thorough retraction of `0.468 ± 0.003` at its head and then
states the number bare 160 lines later, inside the numbered lab protocol, marked
`(default)`. A reader following the protocol never sees the retraction. So a mark
in the same document is not enough; it has to be where the number is used.

`window` is how many lines either side count as "near". It is a real threshold
and it is set loose (6) rather than tight (0), because prose wraps and a gate
that reddens on correct writing gets deleted — the failure mode this project has
recorded is gates that are too strict, not too lax. At 6 the two cases are still
159 lines apart.

`files` overrides the walk with an explicit corpus. The caller supplies it so
that "which documents must be true" stays declared in exactly one place —
`LIVE_DOCS` in `test/test_docs_live_set.jl` — instead of this function growing a
second opinion about it. Directories in `skip` are excluded from the default
walk: `docs/archive/` is where history is kept on purpose.

**What this does NOT reach.** A document that carries a dated FROZEN header is
not required to be true, so the caller normally excludes it — and
`docs/manuscript/klaus_protocol_sheet.md` is FROZEN while still carrying a
numbered lab protocol. That is not a hole in the gate; it is a document whose
label and whose use disagree, and it is recorded as claim
`klaus-sheet-frozen-but-prescriptive` rather than patched over here.

**What this does NOT catch**, said plainly because a gate that overstates its
reach is worse than none: it matches literals, so a paraphrase of a retracted
claim passes. It guards the observed failure — a table or a protocol step copied
forward verbatim — and not the general one.
"""
function unmarked_retired_literal_sites(;
    claims::AbstractVector{LedgerClaim}=claim_ledger(),
    docs_root::AbstractString=joinpath(
        normpath(joinpath(@__DIR__, "..", "..", "..")), "docs"),
    files::Union{Nothing, AbstractVector}=nothing,
    window::Int=6,
    skip=("archive",))
    lits = retired_literals(claims)
    isempty(lits) && return NamedTuple[]
    normlits = [(_collapse_ws(l), id) for (l, id) in lits]
    out = NamedTuple[]
    # `docs/archive/` is excluded even when the caller passes it explicitly. A
    # ledger row's `doc` may point into the archive because that is WHERE THE CLAIM
    # WAS ORIGINALLY WRITTEN — a provenance anchor, not an assertion being made
    # today. Requiring every line of a retired document to re-declare its own
    # retirement is the cost that would make the archive unwritable, and the
    # archive already carries a whole-file header saying it is history.
    isarchive(f) = occursin(joinpath("docs", "archive"), String(f))
    paths = if files !== nothing
        String[String(f) for f in files if endswith(String(f), ".md") && !isarchive(f)]
    else
        isdir(docs_root) || return out
        acc = String[]
        for (dir, dirs, fs) in walkdir(docs_root)
            filter!(d -> !(d in skip), dirs)
            append!(acc, [joinpath(dir, f) for f in fs if endswith(f, ".md")])
        end
        acc
    end
    for path in paths
        lines = try
            readlines(path)
        catch
            continue
        end
        norm = _collapse_ws.(lines)
        for (i, ln) in pairs(norm)
            for (lit, id) in normlits
                occursin(lit, ln) || continue
                # A markdown table row is its own claim, so the window collapses
                # to the line. Measured 2026-08-20: in this document's §0 verdict
                # table the refuted row 17 (`2.25×`) sat one line above row 13,
                # which says "**refuted**" about an unrelated claim — and that
                # neighbour's marker made row 17 invisible to this gate. Prose
                # wraps and needs the loose window; table rows do not, and their
                # neighbours are always OTHER claims, which is exactly the
                # arrangement that shields.
                istable = startswith(ln, "|")
                lo, hi = istable ? (i, i) :
                         (max(1, i - window), min(length(norm), i + window))
                # Case-insensitive, because the list carried "SUPERSEDED" and
                # "superseded" and "REFUTED" and "refuted" as separate entries
                # and then had only lowercase "retracted" — so a line reading
                # "**RETRACTED**" was not a retraction to this gate. Enumerating
                # the casings of a word is a list nobody finishes; fold once.
                marked = any(
                    any(occursin(m, lowercase(norm[j]))
                        for m in CLAIM_RETRACTION_MARKERS)
                    for j in lo:hi)
                marked && continue
                push!(
                    out,
                    (file=relpath(path, dirname(rstrip(docs_root, '/'))), line=i,
                        literal=lit, claim_id=id, text=strip(lines[i])),
                )
            end
        end
    end
    out
end

"""
    ledger_section_coverage(; claims, repo) -> Vector{NamedTuple}

Per cited document: `(doc, total, covered, uncovered)` over its numbered sections.

**Why this is a gate and not a report.** On 2026-08-21 a row was added measuring a
quantity that a section of the SAME document had already measured, by a method
that same section had refuted the day before. Nothing collided, because the
`quantity` gate can only compare a row against a row — and 47 of that document's
70 sections had never been poured. A ledger that cites a document and covers a
third of it can be read as complete, and was.

The ratchet in `claims.toml`'s `[[coverage]]` table pins the current number per
document. It may rise and must not fall, so adding sections to a cited document
without pouring them is red. That is deliberately weaker than "cover everything"
— the debt is real and demanding it in one commit would get the gate deleted —
and deliberately stronger than a report nobody reads.
"""
function ledger_section_coverage(;
    claims::AbstractVector{LedgerClaim}=claim_ledger(),
    repo::AbstractString=normpath(joinpath(@__DIR__, "..", "..", "..")))
    out = NamedTuple[]
    for d in sort(unique(c.doc for c in claims if endswith(c.doc, ".md")))
        path = joinpath(repo, d)
        isfile(path) || continue
        secs = String[]
        for l in readlines(path)
            m = match(r"^#{2,3} (\d+(?:\.\d+)?)\.? ", l)
            m === nothing || push!(secs, m.captures[1])
        end
        isempty(secs) && continue
        cov = Set(c.section for c in claims if c.doc == d)
        unc = [x for x in unique(secs) if !(x in cov)]
        push!(
            out,
            (doc=d, total=length(unique(secs)),
                covered=length(unique(secs)) - length(unc), uncovered=unc),
        )
    end
    out
end
