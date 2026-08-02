# --- The completion marker (invariant 4) ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §6, cutover step 2.
#
#   "A cache hit requires a completion marker written last, naming the bytes it
#    certifies. An id alone never serves."
#
# Before this file, admission was `isfile(payload)`. A run killed at 1 % of its
# step budget leaves a full-looking payload — the ITP swallows
# `InterruptException` (`solvers/ground_state/itp_loop.jl:223`), the pipeline
# runs on, `_exit_summary.json` records `completed = true` — and the next run is
# served that payload as if it had converged. Measured: an 0.64 %-wrong energy
# returned in 0.01 s.
#
# The marker closes that by being the LAST thing written and by naming the bytes
# rather than merely existing. Three defects it catches that an id cannot:
#
#  1. **Interrupted / diverged runs.** The writer withholds the marker, so the
#     payload stays admissible only under arm (b) below, and a fresh run
#     overwrites it.
#  2. **Truncation with no exception at all.** `_move_scratch_to_final`
#     (`run_registry.jl:681`) is `mv(…; force=true)`, and Julia's `_mv_replace`
#     (`base/file.jl:470`) falls back to `cp` + `rm` when `rename` fails —
#     which is exactly the `SPINORBEC_SCRATCH_DIR` (TSUBAME node-local SSD)
#     configuration. A walltime kill during that copy leaves a short file at the
#     final path. Only the recorded size sees it.
#  3. **A payload deleted out from under a pointer.** A light point stores
#     `gs_ref` instead of ψ; the marker names the stage artifact too, so
#     deleting the shared ψ turns the point into a miss instead of a throw.
#
# ## Granularity: a sibling marker per payload, not one per directory
#
# The design says "run! writes complete.toml last". It is realised as
# `<payload>.complete.toml` because every admission site in the tree tests ONE
# file, not a directory: the scan loop admits `point_017.jld2` individually
# (`run_registry.jl`) and the GS stage store admits one content-addressed
# artifact shared across configs (`run_step_ground_state.jl`). A single
# `<run_dir>/complete.toml` would also be an N-way concurrent write under
# `SPINORBEC_SCAN_ONLY_INDEX`, where N separate processes each write one point
# into the same directory.
#
# The sidecar name is load-bearing in one more way: `rsync` transfers
# alphabetically and `point_001.jld2` sorts BEFORE `point_001.jld2.complete.toml`,
# so an autopilot collect (`autopilot/ssh_transport.jl:52`) can never expose a
# marker whose bytes have not landed yet. A bare `complete.toml` would sort
# before every payload in the directory and open exactly that window.
#
# ## TOML, and why the sizes are `filesize`
#
# TOML for the same reasons as `model/io.jl`: stdlib, greppable, byte-
# deterministic under `sorted=true`. `filesize` FOLLOWS symlinks, and it is used
# on both the write and the read side, so the `point_001.jld2 -> result.jld2`
# symlink that `save_rotating_basis_result!` creates records and verifies as the
# size of its target. A size is not a checksum: it catches truncation and
# replacement-by-a-different-run, not a single flipped bit. Hashing multi-GB
# snapshot files on every admission is not affordable, and truncation is the
# failure this pass exists to stop.

# ## The tombstone, and why arm (b) cannot work without one
#
# The migration allowance below admits a payload that has NO marker, because at
# cutover there were 671 `.jld2` under `runs/` and zero markers. But a run killed
# AFTER its payload lands and BEFORE its marker is written leaves exactly that
# shape — payload present, marker absent — so arm (b) would go on serving killed
# runs forever, which is the defect this pass exists to stop. The two cases are
# indistinguishable from the bytes; the only thing that can tell them apart is a
# statement written by the killed run itself.
#
# Hence `<payload>.incomplete.toml`: a TOMBSTONE, written by a writer that knows
# its run was interrupted or diverged. It is not a completion marker (the
# mandatory control's "no complete.toml is written" stays literally true) — it
# is the discriminator that makes arm (b) mean "pre-cutover" instead of "not
# marked for any reason". A payload carrying one is REJECTED and recomputed.
#
# The payload is deliberately left on disk rather than deleted: it is the
# forensic record of what the killed run had reached, and `write_complete_marker`
# clears the tombstone when the recomputation succeeds.

# ## The verdict, and why the marker is where it goes
#
# A marker as written by cutover step 2 certifies BYTES: these files, these
# sizes, written last. It says nothing about whether the answer inside them is
# any good, and `admit_payload` had no way to ask — `grep converged` over this
# file found one occurrence and it was in a comment. Meanwhile the GS writer puts
# `converged` INTO the payload (`run_step_ground_state.jl:691`) and `_finish_point!`
# checks `:interrupted` and `isfinite`, so the verdict existed on both sides of
# admission and was readable by neither.
#
# That is Bazel issue 16179 in this tree: the action succeeded, the blobs
# uploaded, the action-cache entry was written, and the quality check failed
# afterwards — poisoning the cache for every later build. Nix registers a path in
# `ValidPaths` only after the output is hashed and reference-scanned; the Remote
# Execution API writes `UpdateActionResult` LAST, after and referencing
# already-validated content.
#
# The fix is NOT "refuse to mark a non-converged solve". This repo measured the
# opposite: the default `tol = 1e-8` sits below the ~5e-7 gradient floor an
# energy-gated line search can resolve, so `converged = false, floor_limited =
# true` is the BEST ACHIEVABLE answer for the problem and the method, not a
# failure (`solvers/lbfgs/driver.jl:436-456`). Refusing to mark it would throw
# away good ground states and would push every Eu production run into arm (b).
#
# So the marker CARRIES the verdict and admission can be asked to REQUIRE it.
# `admit_payload(path; require_converged = false)` keeps today's behaviour
# byte-for-byte; `require_converged = true` is for a caller whose claim depends
# on the solve having actually met its own `tol` — a BdG or stability gate, where
# a floor-limited state is a different object from a converged one. The four
# fields are the ones the solver already publishes, so nothing new is computed
# and nothing can drift: `converged`, `stop_reason`, `floor_limited`, `grad_norm`.

export CompletionMarker, PayloadEntry, Admission, MarkerVerdict
export COMPLETE_MARKER_FORMAT, MARKER_CUTOVER_UNIX, marker_path, incomplete_marker_path
export write_complete_marker, write_incomplete_marker, read_complete_marker, admit_payload
export gs_verdict

"On-disk marker format version. Readers refuse anything else rather than guess."
const COMPLETE_MARKER_FORMAT = 1

"""
The instant marker writing began: commit `ce9721cb`, "cutover step 2 — a cache
hit requires a completion marker", 2026-08-01T19:33:52+09:00.

A payload with NO marker whose mtime is AFTER this is `:rejected`, not
`:unmarked`. Before it, no writer in the tree could produce a marker, so an
unmarked payload is history. After it, every writer produces one — a marker on
success, a tombstone on a failure it knows about — so an unmarked payload is a
run that was killed hard enough that it wrote neither.

**Why a dated constant and not a backfill.** The obvious alternative is to walk
`runs/` once and stamp every existing payload with a marker, after which "no
marker" could mean "not complete" unconditionally. That is worse on three counts,
and the third is the one that decides it:

 1. **A backfilled marker would be a lie.** Its whole content is a certificate
    that some run completed. Nothing on disk today says which of the 522 `.jld2`
    in the main checkout came from a run that finished — that is precisely the
    information this cutover exists to start recording, and inventing it
    retroactively would put a certificate on the killed runs too.
 2. **It cannot be re-run.** A backfill is a one-shot mutation of a directory
    that is not in git (43 of 70 cited `runs/` directories are absent from the
    tree entirely), so a second checkout, a TSUBAME `SPINORBEC_RUNS_ROOT`, or a
    collaborator's copy would each need their own, and a missed one silently
    goes back to grandfathering.
 3. **A date is checkable; a stamp is not.** This constant is one integer that a
    test pins and a reader can verify against `git log -1 --format=%ct ce9721cb`.
    A backfill leaves no artifact stating what it did.

The failure direction is the safe one. An mtime that has been reset — `rsync`
without `-t`, a `cp` that does not preserve times, a fresh `git checkout` — makes
an old payload look new, and a payload that looks new is REJECTED, i.e.
recomputed. Never the reverse. (The collect path is `rsync -av`, which does
preserve mtimes: `autopilot/ssh_transport.jl:54`.)

Documented failure this closes: Snakemake issue 3808 — outputs of FAILED jobs
stopped being marked incomplete, the metadata read `"incomplete": false`, and
reruns never triggered. Its `incomplete()` is literally "exists and marked ⇒
incomplete, else complete", which is arm (b). Nix and Bazel do not grandfather at
all: a `/nix/store` path absent from `ValidPaths` is garbage.
"""
const MARKER_CUTOVER_UNIX = 1_785_580_432

"""
    PayloadEntry(path, bytes)

One certified file. `path` is stored RELATIVE to the marker's own directory, so
a run directory stays admissible after being rsync'd off a compute node or moved
inside the store. Cross-directory references (a light point's stage artifact)
come out as `../_stage/<id>.jld2` and survive only a move that carries both —
which is the honest statement, since that is also the only move under which the
bytes are still there.
"""
struct PayloadEntry
    path::String
    bytes::Int
end

"""
    MarkerVerdict(converged, stop_reason, floor_limited, grad_norm)

What the solve behind a payload thought of its own answer. Written into the
marker's `[verdict]` table; read back by `admit_payload(...; require_converged)`.

Not a quality score and not a threshold — the four fields are copied verbatim
from what `find_ground_state_lbfgs` / the ITP already return, so this struct
cannot disagree with the solver. `converged` keeps its one meaning
(`grad_norm < tol`); the other three exist because that Bool alone cannot tell a
solve that FAILED from one that succeeded as far as the method allows:

  * `stop_reason` — `:tol` / `:line_search_stalled` / `:max_steps` / `:unknown`.
    Stored as a `String` because TOML has no symbol and a round-trip through
    `Symbol` would invent one.
  * `floor_limited` — `true` when the line search stalled ABOVE the requested
    `tol`, i.e. the requested tolerance is below what an energy-gated step can
    resolve. This is the legitimate `converged = false`.
  * `grad_norm` — the residual actually reached. `NaN` when the method reports
    none (ITP), which TOML writes and parses as `nan`.
"""
struct MarkerVerdict
    converged::Bool
    stop_reason::String
    floor_limited::Bool
    grad_norm::Float64
end

"""
    gs_verdict(result) -> Union{Nothing, MarkerVerdict}

Read a ground-state verdict out of a pipeline result dict, or `nothing` when the
pipeline had no ground-state step.

The four `:ground_state_*` keys are published by
`_run_step(::GroundStateStep, …)` (`pipeline/run_step_ground_state.jl`). This
function is the ONE place that names them, so the three marker writers do not
each grow their own copy of the spelling — the failure mode CLAUDE.md's naming
convention exists to stop.

`:ground_state_converged` is the discriminator: a dynamics-only pipeline never
sets it, and a verdict invented for such a run would be a claim about a solve
that did not happen.
"""
function gs_verdict(result)
    conv = get(result, :ground_state_converged, nothing)
    conv === nothing && return nothing
    MarkerVerdict(
        Bool(conv),
        String(get(result, :ground_state_stop_reason, "unknown")),
        Bool(get(result, :ground_state_floor_limited, false)),
        Float64(get(result, :ground_state_grad_norm, NaN)),
    )
end

"""
    CompletionMarker

The typed reading of a `<payload>.complete.toml`. `read_complete_marker` returns
this, never a `Dict` — a `Dict` return is how a field nothing reads accumulates,
and the closed decode below is what makes an unknown key an error instead of a
shrug.

`artifact_id` and `code_rev` are `Union{Nothing,String}`: `code_rev` because
`_code_rev_or_nothing` degrades rather than inventing a revision when `src/` is
being rsync'd under a running job, and `artifact_id` because a payload can be
written by a run that HAS no id — since cutover step 3 the GS stage cache is
keyed on `artifact_id`, and a config whose `Model` does not resolve gets none, so
it recomputes and its point files carry `nothing` here. Absent means absent;
neither is a hit criterion.

`verdict` is `Union{Nothing, MarkerVerdict}` for the same reason and one more: a
`kind = "dynamics"` payload is an evolution, which has no convergence to report,
and every marker written before the verdict landed has none either. Absent is
absent — `require_converged = true` refuses it rather than assuming.
"""
struct CompletionMarker
    format::Int
    kind::String
    artifact_id::Union{Nothing, String}
    code_rev::Union{Nothing, String}
    written_at::String
    payload::Vector{PayloadEntry}
    verdict::Union{Nothing, MarkerVerdict}
end

"""
    Admission

Why a payload was or was not served.

| `provenance` | `hit` | meaning |
|---|---|---|
| `:marked` | `true` | a marker was found and every byte it names is there |
| `:unmarked` | `true` | no marker at all — a pre-cutover artifact, arm (b) |
| `:rejected` | `false` | a marker was found and it DISAGREES with the tree |
| `:absent` | `false` | no payload; an ordinary cache miss |

`:rejected` is not `:absent` with extra words. An absent payload is history not
yet made; a disagreeing marker is a payload that was truncated, replaced, or
partially collected, and it is the one case where serving the file would be
serving corruption. It misses loudly and the run recomputes over it.
"""
struct Admission
    hit::Bool
    provenance::Symbol
    reason::String
    marker::Union{Nothing, CompletionMarker}
end

"""
    marker_path(payload) -> String

`<payload>.complete.toml`. Pure string function: it does not touch the disk, so
it is safe to call on a path that does not exist yet.
"""
marker_path(payload::AbstractString) = String(payload) * ".complete.toml"

"""
    incomplete_marker_path(payload) -> String

`<payload>.incomplete.toml` — the tombstone. See the header: it is what stops
arm (b) from grandfathering runs killed after this cutover.
"""
incomplete_marker_path(payload::AbstractString) = String(payload) * ".incomplete.toml"

# ---------------------------------------------------------------------------
# write
# ---------------------------------------------------------------------------

"""
    write_complete_marker(anchor, payloads; kind, artifact_id=nothing,
                          code_rev=_code_rev_or_nothing()) -> String

Write `marker_path(anchor)` naming every path in `payloads` with its current
size, and return the marker path.

**Call this LAST**, after the payload is at its final path and after every
derived file the run writes. It is the completion statement, so anything that
can still fail must fail before it.

Atomic by construction: the TOML goes to `<marker>.tmp.<pid>` in the SAME
directory and is renamed into place, so `rename(2)` applies and a reader never
sees a half-written marker. (The payload writers' own `mv` is only atomic when
`SPINORBEC_SCRATCH_DIR` is unset — see the header. The marker's is unconditional
because the temp path is derived from the marker, not from a scratch root.)

Throws on failure. Callers that have already completed a multi-hour run must
wrap this in `try`/`@warn`: a completed run must not acquire a new way to fail,
and the degraded outcome — a payload with no marker — is exactly arm (b), i.e.
the status quo for every artifact written before this cutover.

`anchor` is separate from `payloads` because one writer can produce several
payload files and admission may be asked about more than one of them. Each
anchor gets its own marker naming the same set; do NOT anchor a marker on a file
another writer owns (the shared GS stage artifact writes its own).
"""
function write_complete_marker(anchor::AbstractString, payloads::AbstractVector{<:AbstractString};
    kind::AbstractString,
    artifact_id::Union{Nothing, AbstractString}=nothing,
    code_rev::Union{Nothing, AbstractString}=_code_rev_or_nothing(),
    verdict::Union{Nothing, MarkerVerdict}=nothing,
)
    isempty(payloads) &&
        throw(
            ArgumentError("write_complete_marker: a marker that names no bytes certifies nothing")
        )
    mp = marker_path(anchor)
    mdir = dirname(abspath(mp))
    entries = Vector{Dict{String, Any}}(undef, length(payloads))
    for (i, p) in enumerate(payloads)
        ispath(p) || throw(
            ArgumentError(
                "write_complete_marker: payload does not exist: $p " *
                "(the marker is written LAST, after the payload is at its final path)"),
        )
        entries[i] = Dict{String, Any}(
            "path" => relpath(abspath(p), mdir), "bytes" => Int(filesize(p)))
    end
    d = Dict{String, Any}(
        "format" => COMPLETE_MARKER_FORMAT,
        "kind" => String(kind),
        "written_at" => _marker_timestamp(),
        "payload" => entries,
    )
    artifact_id === nothing || (d["artifact_id"] = String(artifact_id))
    code_rev === nothing || (d["code_rev"] = String(code_rev))
    verdict === nothing || (d["verdict"] = _verdict_to_dict(verdict))

    _write_marker_atomically(mp, d)
    # A recomputation that succeeded must clear the tombstone its predecessor
    # left, or `admit_payload` would keep rejecting the good bytes.
    rm(incomplete_marker_path(anchor); force=true)
    mp
end

"""
    write_incomplete_marker(anchor, payloads; kind, reason, artifact_id=nothing) -> String

Write the tombstone at `incomplete_marker_path(anchor)`: this payload exists but
must not be served.

Called by a writer that KNOWS its run did not finish — the ITP and both RTP
loops catch `InterruptException` and return normally, so "did not finish" is a
fact only the writer holds. Without it, a killed run is byte-indistinguishable
from a pre-cutover artifact and arm (b) of `admit_payload` would serve it.

`payloads` is recorded for forensics (what the killed run had produced, and how
far it got); admission does not check those sizes, because the tombstone rejects
regardless. Sizes are recorded best-effort so a payload that is itself missing
cannot make the tombstone fail to write.

No `[verdict]` here, deliberately. A tombstone is written when the run was
interrupted or diverged, and `gs_verdict` would report the GROUND-STATE step's
opinion — which can perfectly well be `converged = true` while the DYNAMICS that
followed it went non-finite. `converged = true` printed beside
`reason = "psi is not finite (the run diverged)"` is a contradiction on its face,
and the tombstone rejects regardless, so the field would be a misleading number
that nothing reads.
"""
function write_incomplete_marker(anchor::AbstractString, payloads::AbstractVector{<:AbstractString};
    kind::AbstractString, reason::AbstractString,
    artifact_id::Union{Nothing, AbstractString}=nothing,
    code_rev::Union{Nothing, AbstractString}=_code_rev_or_nothing(),
)
    mp = incomplete_marker_path(anchor)
    mdir = dirname(abspath(mp))
    entries = Dict{String, Any}[]
    for p in payloads
        isfile(p) || continue
        push!(
            entries,
            Dict{String, Any}(
                "path" => relpath(abspath(p), mdir), "bytes" => Int(filesize(p))),
        )
    end
    d = Dict{String, Any}(
        "format" => COMPLETE_MARKER_FORMAT,
        "kind" => String(kind),
        "reason" => String(reason),
        "written_at" => _marker_timestamp(),
        "payload" => entries,
    )
    artifact_id === nothing || (d["artifact_id"] = String(artifact_id))
    code_rev === nothing || (d["code_rev"] = String(code_rev))
    _write_marker_atomically(mp, d)
    # A stale completion marker from an earlier, successful run of the same cell
    # would otherwise out-vote the tombstone.
    rm(marker_path(anchor); force=true)
    mp
end

function _write_marker_atomically(mp::AbstractString, d::AbstractDict)
    mdir = dirname(abspath(mp))
    isdir(mdir) || mkpath(mdir)
    tmp = mp * ".tmp." * string(getpid())
    try
        open(io -> TOML.print(io, d; sorted=true), tmp, "w")
        mv(tmp, mp; force=true)
    catch err
        isfile(tmp) && rm(tmp; force=true)
        rethrow(err)
    end
    mp
end

# Archeology only — nothing dispatches on it and admission never reads it. An
# mtime would be destroyed by the rsync that collects the directory; this
# survives, and it is the field a person reads when asking which of two runs
# wrote the artifact they are holding.
_marker_timestamp() = string(now())

# For the rejection message only. A raw epoch second is not something a person
# can compare against a commit date without a second tool.
_unix_to_iso(t::Real) = string(Dates.format(
        Dates.unix2datetime(floor(Int, t)), "yyyy-mm-ddTHH:MM:SS"), "Z")

# ---------------------------------------------------------------------------
# read
# ---------------------------------------------------------------------------

const _MARKER_KEYS = ("format", "kind", "written_at", "payload", "artifact_id", "code_rev",
    "reason", "verdict")
const _ENTRY_KEYS = ("path", "bytes")
const _VERDICT_KEYS = ("converged", "stop_reason", "floor_limited", "grad_norm")

# All four, always. A verdict missing a field is not a partial verdict — it is a
# verdict whose reader has to guess a default, and the whole point of the table
# is that `converged = false` alone is ambiguous.
function _verdict_to_dict(v::MarkerVerdict)
    Dict{String, Any}(
        "converged" => v.converged,
        "stop_reason" => v.stop_reason,
        "floor_limited" => v.floor_limited,
        "grad_norm" => v.grad_norm,
    )
end

function _verdict_from_dict(d)
    d isa AbstractDict ||
        throw(ArgumentError("completion marker: `verdict` must be a table"))
    _marker_closed(d, _VERDICT_KEYS, "completion marker verdict")
    for k in _VERDICT_KEYS
        haskey(d, k) || throw(
            ArgumentError(
                "completion marker verdict is missing \"$k\"; all of " *
                join(_VERDICT_KEYS, ", ") * " are required, because " *
                "`converged` on its own cannot tell a failed solve from one that " *
                "reached its method's floor"),
        )
    end
    MarkerVerdict(
        Bool(d["converged"]),
        String(d["stop_reason"]),
        Bool(d["floor_limited"]),
        Float64(d["grad_norm"]),
    )
end

"""
    read_complete_marker(path) -> CompletionMarker

Parse a marker file. Throws `ArgumentError` on anything it cannot read —
a wrong format version, a missing key, an unknown key. `admit_payload` turns
those throws into `:rejected`, which is the correct reading: a marker that
cannot be understood is a marker that cannot certify.
"""
function read_complete_marker(path::AbstractString)
    d = TOML.parsefile(path)
    _marker_closed(d, _MARKER_KEYS, "completion marker")
    fmt = get(d, "format", nothing)
    fmt == COMPLETE_MARKER_FORMAT && return _marker_from_dict(d)
    throw(
        ArgumentError(
            "completion marker format $(repr(fmt)) is not $COMPLETE_MARKER_FORMAT; " *
            "no migration path is registered for it"),
    )
end

function _marker_from_dict(d::AbstractDict)
    raw = get(d, "payload", nothing)
    raw isa AbstractVector ||
        throw(ArgumentError("completion marker: `payload` must be a list of tables"))
    # A tombstone may legitimately name nothing (the payload it was written for
    # can have been removed); a completion marker may not, and `write_complete_marker`
    # refuses to produce one.
    (isempty(raw) && !haskey(d, "reason")) &&
        throw(ArgumentError("completion marker: `payload` names no bytes"))
    entries = PayloadEntry[]
    for e in raw
        e isa AbstractDict ||
            throw(ArgumentError("completion marker: each `payload` entry must be a table"))
        _marker_closed(e, _ENTRY_KEYS, "completion marker payload entry")
        haskey(e, "path") && haskey(e, "bytes") ||
            throw(ArgumentError("completion marker payload entry needs `path` and `bytes`"))
        push!(entries, PayloadEntry(String(e["path"]), Int(e["bytes"])))
    end
    _str_or_nothing(k) = haskey(d, k) ? String(d[k]) : nothing
    CompletionMarker(
        Int(d["format"]),
        String(get(d, "kind", "")),
        _str_or_nothing("artifact_id"),
        _str_or_nothing("code_rev"),
        String(get(d, "written_at", "")),
        entries,
        haskey(d, "verdict") ? _verdict_from_dict(d["verdict"]) : nothing,
    )
end

# Same rule as `model/io.jl:_closed`, restated locally because that one is a
# decoder helper for `Model` and its message names model fields.
function _marker_closed(v::AbstractDict, allowed, what::AbstractString)
    extra = setdiff(collect(String.(keys(v))), collect(allowed))
    isempty(extra) && return nothing
    throw(
        ArgumentError(
            "$what has no key(s) " * join(sort!(extra), ", ") *
            "; known keys are " * join(allowed, ", "),
        ),
    )
end

# ---------------------------------------------------------------------------
# admit
# ---------------------------------------------------------------------------

# One warning per store, not one per hit — a 45-point scan directory would
# otherwise emit 45 identical lines and the signal would be read as noise. The
# "store" is the directory holding the payload: that is one line per run
# directory and one line for the whole GS stage cache, which is the granularity
# at which a person decides to regenerate or to leave history alone.
const _UNMARKED_WARNED = Set{String}()
const _UNMARKED_WARNED_LOCK = ReentrantLock()

function _warn_unmarked_once(payload::AbstractString)
    store = dirname(abspath(payload))
    fresh = lock(_UNMARKED_WARNED_LOCK) do
        store in _UNMARKED_WARNED ? false : (push!(_UNMARKED_WARNED, store); true)
    end
    fresh || return nothing
    @warn "admitting a payload with NO completion marker (pre-cutover artifact). " *
        "It cannot be distinguished from a run that was killed after writing its " *
        "payload. Delete it to force a marked recomputation." store
    nothing
end

"For tests, and for a long-lived process that wants the warning again."
_reset_unmarked_warnings!() = (lock(() -> empty!(_UNMARKED_WARNED), _UNMARKED_WARNED_LOCK); nothing)

"""
    admit_payload(path; require_converged=false) -> Admission

The one admission decision. Every cache-hit site calls this instead of `isfile`.

Three outcomes, and the middle one is a dated migration allowance:

  * **valid marker** → hit, `provenance = :marked`.
  * **no marker at all** → hit, `provenance = :unmarked`, warned once per store.
  * **marker that disagrees with the bytes** → MISS, `provenance = :rejected`,
    warned every time with the file and the two sizes.

Arm (b) exists for one measured reason: at cutover there were 671 `.jld2` under
`runs/` and ZERO markers, and rejecting all of them would have meant recomputing
the tree. It has a sharp edge — a run hard-killed AFTER its payload lands but
BEFORE its marker is written looks byte-for-byte like a pre-cutover artifact —
which the tombstone covers for writers that KNOW they failed and
`MARKER_CUTOVER_UNIX` covers for the ones that never got the chance.

`require_converged = true` additionally demands that the marker carry a
`[verdict]` saying `converged = true`. It is OFF by default and the default path
is byte-for-byte what it was: this knob changes what a CALLER asks for, never
what the store contains. Two things it deliberately refuses:

  * an `:unmarked` payload — arm (b) carries no verdict, so admitting it under
    `require_converged` would make the knob bypassable by the entire legacy
    population, which is most of the tree;
  * a marked payload whose verdict says `floor_limited = true`. That state is
    the best the method can produce (`solvers/lbfgs/driver.jl:436`) and is a
    perfectly good ground state — it is refused here only because
    `require_converged` means what it says. A caller who wants "converged OR
    floor-limited" reads it off the returned marker: `adm.marker.verdict` is
    published for exactly that, so the richer decision needs no second knob.
"""
function admit_payload(path::AbstractString; require_converged::Bool=false)
    isfile(path) ||
        return Admission(false, :absent, "no payload at $path", nothing)
    # The tombstone is checked FIRST and out-votes everything: it is a statement
    # by the writer that the run behind these bytes did not finish, and no size
    # check can recover that. See the header for why arm (b) needs it to exist.
    tomb = incomplete_marker_path(path)
    if isfile(tomb)
        why = try
            String(get(TOML.parsefile(tomb), "reason", "no reason recorded"))
        catch
            "its tombstone does not parse"
        end
        return _reject(path, "the run that wrote it did NOT complete ($why)")
    end
    mp = marker_path(path)
    isfile(mp) || begin
        require_converged && return _reject(path,
            "it has NO completion marker, so it carries no verdict, and this " *
            "caller requires `converged = true`")
        # The cutoff that bounds arm (b). A payload written AFTER marker writing
        # existed and carrying no marker is not history — it is a run that died
        # between the payload and the marker, or one that threw. See
        # `MARKER_CUTOVER_UNIX` for why this is a dated constant and not a
        # backfill.
        mt = mtime(path)
        mt > MARKER_CUTOVER_UNIX && return _reject(path,
            "it has NO completion marker but was written at " *
            "$(_unix_to_iso(mt)), AFTER marker writing began " *
            "($(_unix_to_iso(MARKER_CUTOVER_UNIX)), commit ce9721cb). Every writer " *
            "since then leaves a marker on success or a tombstone on a failure it " *
            "knows about, so neither means the run was killed hard (OOM, walltime, " *
            "lost node) — or that its mtime was reset by a copy that does not " *
            "preserve times, which is the same answer: recompute")
        _warn_unmarked_once(path)
        return Admission(true, :unmarked, "no completion marker beside $(basename(path))", nothing)
    end
    marker = try
        read_complete_marker(mp)
    catch err
        return _reject(path, "its completion marker does not parse: $(sprint(showerror, err))")
    end
    mdir = dirname(abspath(mp))
    for e in marker.payload
        p = normpath(joinpath(mdir, e.path))
        isfile(p) || return _reject(path,
            "its completion marker names $(e.path), which is not on disk")
        actual = Int(filesize(p))
        actual == e.bytes || return _reject(path,
            "its completion marker records $(e.bytes) bytes for $(e.path) " *
            "but the file is $(actual)")
    end
    if require_converged
        v = marker.verdict
        v === nothing && return _reject(path,
            "its completion marker carries no [verdict] (a dynamics payload, or one " *
            "written before the verdict landed) and this caller requires " *
            "`converged = true`")
        v.converged || return _reject(path,
            "its verdict says converged = false (stop_reason = $(v.stop_reason), " *
            "floor_limited = $(v.floor_limited), grad_norm = $(v.grad_norm)) and " *
            "this caller requires `converged = true`")
    end
    Admission(true, :marked, "marker verified $(length(marker.payload)) file(s)", marker)
end

function _reject(path::AbstractString, why::AbstractString)
    reason = why * " " * _reject_detail(path)
    @warn "REJECTED a cached artifact and will RECOMPUTE it: $reason" payload = path
    Admission(false, :rejected, reason, nothing)
end

# The diagnosis goes into `Admission.reason`, not only into the log line. A
# message a person can only see by capturing `@warn` output is a message no test
# can assert on, and this is the one field admission publishes about a failure.
#
# Two causes, and naming the wrong one sends the reader to the wrong file.
# `save_rotating_basis_result!` publishes `point_001.jld2` as a SYMLINK to
# `result.jld2`, and `filesize` follows symlinks — so when the rejected payload
# is a link, the bytes that disagree were never written by "this file"'s writer
# at all, and neither truncation nor a partial rsync is a plausible reading.
function _reject_detail(path::AbstractString)
    if islink(path)
        target = try
            readlink(path)
        catch
            "<unreadable>"
        end
        return "NOTE: this payload is a SYMLINK to `$target`, so the size that " *
               "disagrees is the TARGET's and nothing about this name was written " *
               "short. A STALE LINK is the likely cause: before 2026-08-01 " *
               "`save_rotating_basis_result!` re-pointed `point_001.jld2` at " *
               "`result.jld2` once per scan point, leaving point 1's name on the " *
               "LAST point's data. Check the link target, not the writer."
    end
    "This is truncation or partial collection, not history — the marker is " *
    "written last precisely so that this case cannot be served."
end
