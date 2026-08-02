# --- ref: the quote boundary between the literature and a number we use ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.5.
#
# `ref(:matsui2025, :dip_width_exp_scanwindow_nT)` returns one row of
# `refs/matsui2025.toml`. The load-bearing property is not that the file exists;
# it is that a published target is MEASURED off a committed fixture by the SAME
# metric that gets applied to our runs, never hand-typed. A typed number is one
# more place a value can drift from the paper, which is the disease rather than
# the cure — the 4,673 comment lines and the 45-key `metadata:` block this layer
# replaces are all typed numbers.
#
# So on a `provenance = "measured"` row `ref` RE-RUNS the measurement, every
# call, and returns what it measured. The `value` in the file is a cross-check:
# if it disagrees beyond the row's tolerance, `ref` throws rather than returning
# either number. That makes the file a cache of a measurement and gives the gate
# something non-circular to check — a test that reads the TOML and compares it
# with the TOML proves nothing, so `test/validation/test_matsui2025_ref.jl` pins
# the expected values as literals of its own as well.
#
# `read_off` and `reconstructed` rows cannot be re-measured, so they carry their
# argument instead. `read_off` names the line of the authors' published source;
# `reconstructed` — a value that source does NOT contain — additionally names the
# alternative it was chosen over and what choosing wrong costs. `_closed`
# enforces per-provenance key sets in both directions: an unknown key is an
# error, and a reconstruction without its alternative and its cost is an error.
#
# Loaded from `src/model.jl` after `stage.jl`. `resonance_dip` lives in
# `analysis/`, which `SpinorBEC.jl` includes AFTER `model.jl` — that is fine and
# already precedented here: `identity.jl` calls `content_id` from
# `workflow/experiment.jl` the same way. The call is resolved when `ref` runs,
# not when this file is parsed, and both names are in module `SpinorBEC`.

using TOML
using SHA: sha256

export ref, ref_measure, RefRow, ref_quantities, ref_source_path
export REFS_FORMAT, REF_PROVENANCES

"Serialised-reference format version. Bump when the on-disk shape changes."
const REFS_FORMAT = 1

"How a reference value came to be. Closed, and the reason the file is worth having."
const REF_PROVENANCES = (:measured, :read_off, :reconstructed)

"""
One row of `refs/<source>.toml`, with a shape that does not depend on which row
it is.

Written as an explicitly-typed `NamedTuple` rather than left to inference: a
`NamedTuple` carries its field types per instance, so building one row with
`alternative = nothing` and another with `alternative = 35000.0` would give two
different types and the shape could not be gated. `RefRow(...)` is the one
constructor, so every row `ref` returns is `::RefRow` and a test can say so.

The design (§2.5) types `Claim.target` as `Union{Nothing, NamedTuple}`; this is
that `NamedTuple`, pinned.

| field | meaning |
|---|---|
| `source` / `quantity` | which file, which row |
| `value` | the number. On a `measured` row this is the FRESH measurement, not the stored one |
| `units` | what `value` is in — no bare numbers |
| `provenance` | `:measured` / `:read_off` / `:reconstructed` |
| `locus` | where it came from: `file:line` for `read_off`, the derivation for the others |
| `note` | the argument for it |
| `dataset` … `window_from` | the measurement recipe; `nothing` unless `provenance == :measured` |
| `arbitrates` | whether this number decides a comparison, or is merely quotable |
| `quotable_digits` | how many figures survive the measurement's own sensitivity |
| `alternative` … `cost_kind` | what was chosen against, and what choosing wrong costs |
"""
const RefRow = @NamedTuple{
    source::Symbol,
    quantity::Symbol,
    value::Float64,
    units::String,
    provenance::Symbol,
    locus::String,
    note::String,
    dataset::Union{Nothing, Symbol},
    metric::Union{Nothing, Symbol},
    metric_field::Union{Nothing, Symbol},
    endpoint_baseline::Union{Nothing, Bool},
    window::Union{Nothing, Tuple{Float64, Float64}},
    window_from::String,
    arbitrates::Bool,
    quotable_digits::Int,
    alternative::Union{Nothing, Float64},
    alternative_locus::String,
    cost::Union{Nothing, Float64},
    cost_units::String,
    cost_kind::Symbol,
}

# ---------------------------------------------------------------------------
# the schema, declared once
# ---------------------------------------------------------------------------

const _REF_KEYS_ALWAYS = ("provenance", "value", "units", "note")

# A measured row is a RECIPE: which bytes, which metric, which field of it, and
# over which window. `window` is required and not defaulted, because
# `resonance_dip`'s width is DEFINED by the window — the same published curve
# gives 15.02 / 13.07 / 12.75 nT over three of them — so a row without one is
# under-determined by more than the gap it is used to arbitrate.
const _REF_KEYS_MEASURED = ("dataset", "metric", "metric_field", "endpoint_baseline",
    "window", "window_from", "arbitrates", "quotable_digits")

const _REF_KEYS_LOCUS = ("locus",)

# All-or-nothing. Half a cost — a number with no units, or an alternative with no
# price — is the shape of an argument that was started and abandoned.
const _REF_KEYS_COST = ("alternative", "alternative_locus", "cost", "cost_units", "cost_kind")

const _COST_KINDS = (:analytic, :measured, :unpriced)

const _DATASET_KEYS = ("path", "sha256", "column", "preprocess", "abscissa", "note")

const _PAPER_KEYS = ("citation", "journal", "year", "doi", "arxiv", "data_doi", "licence",
    "source_sha256_time_f90", "source_sha256_initial_f90", "source_sha256_readme_txt")

# One metric, registered by name. A closed list of one rather than `getfield` on
# whatever the file says: an unregistered metric must be a named error, not a
# `MethodError` from somewhere three frames down.
const _REF_METRICS = (:resonance_dip,)

const _REF_PREPROCESS = (:sort, :mean_over_repeats)

# `resonance_dip`'s return fields. Listed rather than reflected because the point
# is to refuse a name the metric does not produce with a message that says what
# it does produce.
const _RESONANCE_DIP_FIELDS = (:center, :minimum, :x_min, :depth_left, :depth_right,
    :half_left, :half_right, :width)

# The stored `value` is a cross-check on the fresh measurement, so this is a
# BYTES-AND-METRIC tolerance, not a physics one: the two numbers are the same
# arithmetic on the same file and should agree to rounding. Loose enough to let
# the file quote 12 digits rather than 17, tight enough that any real change in
# either the fixture or the metric trips it — the smallest effect §0.7 discusses
# is 0.02 nT, seven orders above this.
#
# Both an absolute and a relative bound because the rows span five decades: 1e-9
# is a fine cross-check on a dip centre near -2.5 nT and is BELOW float spacing
# for a population near 12287, where a pure `atol` would be gating rounding noise
# rather than drift.
const REF_MEASURED_TOL = 1e-9
const REF_MEASURED_RTOL = 1e-12

# ---------------------------------------------------------------------------
# locating and parsing
# ---------------------------------------------------------------------------

"""
    ref_source_path(source::Symbol) -> String

Where `source`'s TOML lives. Resolved from the package root (`_package_root` in
`identity.jl`), not `pwd()` — run scripts `cd`, and this must name the package
that is loaded.
"""
ref_source_path(source::Symbol) = joinpath(_package_root(), "refs", String(source) * ".toml")

_refs_dir() = joinpath(_package_root(), "refs")

function _known_sources()
    d = _refs_dir()
    isdir(d) || return Symbol[]
    sort!([Symbol(splitext(f)[1]) for f in readdir(d) if endswith(f, ".toml")])
end

# Parsed files are memoised; MEASUREMENTS are not. Parsing is the only cost worth
# avoiding, and the measurement is the part that must not be cached — "the value
# equals what the metric produces off the fixture TODAY" is a claim about every
# call, not about the first one.
#
# Keyed on the file's own CONTENT, like `_FIXTURE_CACHE`, not on the source name:
# a memo keyed on a name is stale the moment the file behind the name changes,
# and a reference file edited in a live session would keep answering with what it
# used to say. It also means nothing needs to reach in and clear this.
const _REF_DOC_CACHE = Dict{Tuple{Symbol, String}, Dict{String, Any}}()

function _ref_doc(source::Symbol)
    path = ref_source_path(source)
    isfile(path) || throw(
        ArgumentError(
            "no reference source :$source — $(path) does not exist. " *
            "Registered sources: " *
            (isempty(_known_sources()) ? "(none)" :
             join(String.(_known_sources()), ", "))),
    )
    get!(_REF_DOC_CACHE, (source, bytes2hex(open(sha256, path)))) do
        d = TOML.parsefile(path)
        fmt = get(d, "format", nothing)
        fmt == REFS_FORMAT || throw(
            ArgumentError(
                "reference file $(path) declares format $(repr(fmt)), not $REFS_FORMAT; " *
                "no migration path is registered for it"),
        )
        _closed(d, ("format", "paper", "dataset", "quantity"), "reference file $source")
        for k in ("paper", "dataset", "quantity")
            haskey(d, k) ||
                throw(ArgumentError("reference file $(path) is missing the [$k] section"))
        end
        _closed(d["paper"], _PAPER_KEYS, "[paper] in $source")
        for (name, t) in d["dataset"]
            _closed(t, _DATASET_KEYS, "[dataset.$name] in $source")
            for k in _DATASET_KEYS
                haskey(t, k) ||
                    throw(ArgumentError("[dataset.$name] in $source is missing \"$k\""))
            end
        end
        d
    end
end

"""
    ref_quantities(source::Symbol) -> Vector{Symbol}

Every quantity `source` registers, sorted. This is what an unknown-quantity error
lists, and what the gate iterates so a row cannot be added without being checked.
"""
ref_quantities(source::Symbol) = sort!(Symbol.(collect(keys(_ref_doc(source)["quantity"]))))

# ---------------------------------------------------------------------------
# the measurement
# ---------------------------------------------------------------------------

# Deliberately the ONLY parser of these fixtures inside `src/`. The same CSV is
# also read by `test/validation/test_matsui_fig4_dip.jl` and by
# `scripts/validation/matsui_fig4b_report.jl`; three implementations of one parse
# is a parallel declaration of the reference curve, which is the disease one
# level down. Those two are the next callers to move onto this.
function _split_quoted(line::AbstractString)
    out = String[]
    buf = IOBuffer()
    inq = false
    for c in line
        if c == '"'
            inq = !inq
        elseif c == ',' && !inq
            push!(out, String(take!(buf)))
        else
            print(buf, c)
        end
    end
    push!(out, String(take!(buf)))
    out
end

# Keyed on (path, sha), not on the path: a fixture whose bytes changed AND whose
# declared hash changed with them would otherwise be served the previous parse
# for the rest of the session, which is exactly the staleness the hash exists to
# refuse. The hash is recomputed on every call regardless, so this only ever
# saves the parse.
const _FIXTURE_CACHE = Dict{
    Tuple{String, String}, Tuple{Vector{Float64}, Matrix{Float64}, Vector{String}}
}()

# Hashed on load and compared with the row's `sha256`: "measured off the
# COMMITTED fixture" is only a checkable statement if the bytes are checked.
function _load_fixture(path::AbstractString, want_sha::AbstractString)
    isfile(path) || throw(ArgumentError("reference fixture $(path) does not exist"))
    got = bytes2hex(open(sha256, path))
    got == want_sha || throw(
        ArgumentError(
            "reference fixture $(path) has sha256 $got, but the reference file " *
            "declares $want_sha — the bytes a measured target is measured off have " *
            "changed, so the target is no longer that measurement"),
    )
    x, raw, hdr = get!(_FIXTURE_CACHE, (path, got)) do
        lines = filter(!isempty, readlines(path))
        hdr = _split_quoted(lines[1])
        rows = [parse.(Float64, split(l, ',')) for l in lines[2:end]]
        m = permutedims(reduce(hcat, rows))
        (m[:, 1], m, hdr)
    end
    (x, raw, hdr)
end

_ref_sort(x, y) = (p=sortperm(x); (x[p], y[p]))

# Their experimental scan concatenates repeated passes; Fig. 4B plots the
# per-field mean. Rounding to 4 dp before grouping is not load-bearing here (the
# exact-unique and 4-dp-unique counts are both 61) but it is what makes the rule
# independent of the sheet's float formatting.
function _ref_mean_over_repeats(x, y)
    k = round.(x; digits=4)
    ks = sort(unique(k))
    (ks, Float64[sum(y[k .== v]) / count(==(v), k) for v in ks])
end

function _ref_preprocess(sym::Symbol, x, y)
    sym === :sort && return _ref_sort(x, y)
    sym === :mean_over_repeats && return _ref_mean_over_repeats(x, y)
    throw(
        ArgumentError(
            "unknown preprocess :$sym; registered: " *
            join(String.(_REF_PREPROCESS), ", "),
        ),
    )
end

function _apply_metric(metric::Symbol, field::Symbol, x, y, endpoint_baseline::Bool)
    metric === :resonance_dip || throw(
        ArgumentError(
            "unknown reference metric :$metric; registered metrics are " *
            join(String.(_REF_METRICS), ", "),
        ),
    )
    field in _RESONANCE_DIP_FIELDS || throw(
        ArgumentError(
            "resonance_dip has no field :$field; it returns " *
            join(String.(_RESONANCE_DIP_FIELDS), ", "),
        ),
    )
    d = resonance_dip(x, y; endpoint_baseline)
    Float64(getfield(d, field))
end

"""
    ref_measure(source, quantity) -> Float64

Run a `measured` row's recipe against the committed fixture and return what it
produces, ignoring the stored `value` entirely. `ref` calls this and compares;
the gate calls it directly, so the comparison in the gate is
measurement-vs-literal rather than file-vs-file.
"""
function ref_measure(source::Symbol, quantity::Symbol)
    t = _quantity_table(source, quantity)
    String(t["provenance"]) == "measured" || throw(
        ArgumentError(
            "$source.$quantity has provenance $(repr(String(t["provenance"]))), " *
            "so there is nothing to measure — only a :measured row has a recipe"),
    )
    doc = _ref_doc(source)
    dsname = String(t["dataset"])
    haskey(doc["dataset"], dsname) || throw(
        ArgumentError(
            "$source.$quantity names dataset \"$dsname\", which [dataset] does not " *
            "register; registered datasets are " *
            join(sort!(collect(keys(doc["dataset"]))), ", ")),
    )
    ds = doc["dataset"][dsname]

    x, raw, _ = _load_fixture(joinpath(_package_root(), String(ds["path"])),
        String(ds["sha256"]))
    col = Int(ds["column"])
    (2 <= col <= size(raw, 2)) || throw(
        ArgumentError(
            "[dataset.$dsname] column $col is outside the fixture's " *
            "$(size(raw, 2)) columns (column 1 is the abscissa)",
        ),
    )
    y = raw[:, col]

    for p in ds["preprocess"]
        x, y = _ref_preprocess(Symbol(String(p)), x, y)
    end

    w = _window(t, source, quantity)
    if w !== nothing
        keep = (x .>= w[1]) .& (x .<= w[2])
        count(keep) >= 5 || throw(
            ArgumentError(
                "$source.$quantity restricts $dsname to $(w) and only $(count(keep)) " *
                "samples survive — resonance_dip needs at least 5"),
        )
        x, y = x[keep], y[keep]
    end

    _apply_metric(Symbol(String(t["metric"])), Symbol(String(t["metric_field"])),
        x, y, Bool(t["endpoint_baseline"]))
end

# `window = "full"` is the explicit statement "the whole published range", and is
# a VALUE rather than an omission on purpose: absence must stay an error, or the
# window quietly acquires a default and the width silently becomes whichever
# number the file happened to be measured with.
function _window(t, source, quantity)
    w = t["window"]
    w isa AbstractString && (
        if String(w) == "full"
            (return nothing)
        else
            throw(
                ArgumentError(
                    "$source.$quantity has window $(repr(String(w))); a window is either " *
                    "\"full\" or a two-element [lo, hi]"),
            )
        end
    )
    (w isa AbstractVector && length(w) == 2) || throw(
        ArgumentError(
            "$source.$quantity has a malformed window $(repr(w)); " *
            "expected \"full\" or [lo, hi]",
        ),
    )
    lo, hi = Float64(w[1]), Float64(w[2])
    lo < hi || throw(ArgumentError("$source.$quantity has window [$lo, $hi] with lo >= hi"))
    (lo, hi)
end

# ---------------------------------------------------------------------------
# ref
# ---------------------------------------------------------------------------

function _quantity_table(source::Symbol, quantity::Symbol)
    q = _ref_doc(source)["quantity"]
    key = String(quantity)
    haskey(q, key) || throw(
        ArgumentError(
            "reference source :$source has no quantity :$quantity. " *
            "Registered quantities are " *
            join(String.(ref_quantities(source)), ", ")),
    )
    q[key]
end

"""
    ref(source::Symbol, quantity::Symbol) -> RefRow

One row of `refs/<source>.toml`.

On a `provenance = :measured` row the returned `value` is measured off the
committed fixture on THIS call, by the metric, window and baseline the row
declares; the file's own `value` is compared with it and a disagreement beyond
`REF_MEASURED_TOL` throws rather than resolving in either direction. A number
that cannot be re-measured is not a target.

Fails by name and never returns `nothing`: an unknown source lists the sources
that exist, an unknown quantity lists the quantities that do. A `nothing` here
would surface downstream as `Claim`'s "a :C claim needs a registered literature
target" — a true message about the wrong file.

```julia
r = ref(:matsui2025, :dip_width_exp_scanwindow_nT)
r.value        # 12.838286496502047, measured just now
r.window       # (-13.0, 9.0) — without which the value is under-determined by 2.2 nT
r.arbitrates   # true
```
"""
function ref(source::Symbol, quantity::Symbol)
    t = _quantity_table(source, quantity)
    what = "$source.$quantity"

    haskey(t, "provenance") || throw(ArgumentError("$what has no provenance"))
    prov = Symbol(String(t["provenance"]))
    prov in REF_PROVENANCES || throw(
        ArgumentError(
            "$what has provenance :$prov; it must be one of " *
            join(String.(REF_PROVENANCES), ", "),
        ),
    )

    measured = prov === :measured
    has_cost = any(k -> haskey(t, k), _REF_KEYS_COST)

    allowed = (_REF_KEYS_ALWAYS...,
        (measured ? _REF_KEYS_MEASURED : _REF_KEYS_LOCUS)...,
        (measured ? () : _REF_KEYS_COST)...)
    _closed(t, allowed, "[quantity.$quantity] (:$prov) in $source")

    required = (_REF_KEYS_ALWAYS...,
        (measured ? _REF_KEYS_MEASURED : _REF_KEYS_LOCUS)...,
        # A reconstruction is a CHOICE, so it owes the alternative and the price.
        # A read-off may or may not have had one; if it names any part of a cost
        # it owes all of it.
        (prov === :reconstructed || (!measured && has_cost) ? _REF_KEYS_COST : ())...)
    for k in required
        haskey(t, k) || throw(
            ArgumentError(
                "[quantity.$quantity] in $source is a :$prov row and is missing \"$k\"" *
                (
                    if prov === :reconstructed && k in _REF_KEYS_COST
                        " — a reconstruction without its alternative and its cost is a value " *
                        "without its argument"
                    else
                        ""
                    end
                )),
        )
    end

    value = Float64(t["value"])
    if measured
        got = ref_measure(source, quantity)
        isapprox(got, value; atol=REF_MEASURED_TOL, rtol=REF_MEASURED_RTOL) || throw(
            ArgumentError(
                "$what stores value $value but measuring it off the committed fixture " *
                "TODAY gives $got (|Δ| = $(abs(got - value)), tolerance " *
                "atol=$REF_MEASURED_TOL rtol=$REF_MEASURED_RTOL). " *
                "A published target is the measurement, not the stored number — " *
                "re-derive the row rather than editing either side to match."),
        )
        value = got
    end

    ck = has_cost || prov === :reconstructed ? Symbol(String(t["cost_kind"])) : :none
    (ck === :none || ck in _COST_KINDS) || throw(
        ArgumentError(
            "$what has cost_kind :$ck; it must be one of " *
            join(String.(_COST_KINDS), ", "),
        ),
    )

    RefRow((
        source,
        quantity,
        value,
        String(t["units"]),
        prov,
        measured ? _measured_locus(source, quantity, t) : String(t["locus"]),
        String(t["note"]),
        measured ? Symbol(String(t["dataset"])) : nothing,
        measured ? Symbol(String(t["metric"])) : nothing,
        measured ? Symbol(String(t["metric_field"])) : nothing,
        measured ? Bool(t["endpoint_baseline"]) : nothing,
        measured ? _window(t, source, quantity) : nothing,
        measured ? String(t["window_from"]) : "",
        measured ? Bool(t["arbitrates"]) : false,
        measured ? Int(t["quotable_digits"]) : 0,
        ck === :none ? nothing : Float64(t["alternative"]),
        ck === :none ? "" : String(t["alternative_locus"]),
        ck === :none ? nothing : Float64(t["cost"]),
        ck === :none ? "" : String(t["cost_units"]),
        ck,
    ))
end

# A measured row's locus is its recipe, spelled out, so the row prints as
# something someone can re-run by hand.
function _measured_locus(source::Symbol, quantity::Symbol, t)
    w = _window(t, source, quantity)
    string(t["metric"], ".", t["metric_field"],
        " on ", _ref_doc(source)["dataset"][String(t["dataset"])]["path"],
        " over ", w === nothing ? "the full published range" : "[$(w[1]), $(w[2])]",
        " (endpoint_baseline = ", t["endpoint_baseline"], ")")
end
