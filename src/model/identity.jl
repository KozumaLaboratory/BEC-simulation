# --- Identity: one id over the whole declaration ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.3, invariants 1
# and 3.
#
# The hasher is NOT redefined here. `content_id` (`workflow/experiment.jl:120`)
# is already the project's canonical-bytes SHA-256, and `_canonical_bytes!`
# (`:61-105`) is the enforcement invariant 1 rests on: it ERRORS on any type it
# cannot canonicalise (`:103`) and on non-finite floats (`:86`), so a field that
# cannot be hashed is a hard failure rather than a silent omission. A second
# hasher would be a second declaration of what identity means.
#
# `content_id` lives under `src/workflow/`, which `SpinorBEC.jl` includes AFTER
# `model.jl`. No include reordering is needed and none was done: the call is
# resolved when `artifact_id` runs, not when this file is parsed, and both names
# are in module `SpinorBEC`.

export code_tree_hash, artifact_id

# ---------------------------------------------------------------------------
# code_tree_hash
# ---------------------------------------------------------------------------

# Editor and coverage droppings. Deliberately short: every entry is a
# hand-maintained exclusion, and a hand-maintained list is the failure class
# this design deletes elsewhere. `test/model/test_artifact_id.jl` cross-checks
# the resulting path set against `git ls-files` wherever git is available, so
# the day this list stops matching the repository the gate says so.
const _CODE_TREE_SKIP_SUFFIXES = (".jl.cov", ".jl.mem", ".swp", ".swo", "~", ".orig", ".rej")

"The two directories that are the running code. `test/`, `scripts/` and `docs/` are not."
const CODE_TREE_DIRS = ("src", "ext")

# From `@__DIR__`, not `pwd()`: run scripts `cd`, and this must name the package
# that is loaded, not the directory a job happened to start in.
_package_root() = normpath(joinpath(@__DIR__, "..", ".."))

function _code_tree_paths(root::AbstractString)
    paths = String[]
    for d in CODE_TREE_DIRS
        dir = joinpath(root, d)
        isdir(dir) || continue
        for (dirpath, _, files) in walkdir(dir; follow_symlinks=false)
            for f in files
                any(s -> endswith(f, s), _CODE_TREE_SKIP_SUFFIXES) && continue
                push!(paths, relpath(joinpath(dirpath, f), root))
            end
        end
    end
    sort!(paths)
end

function _code_tree_hash_uncached(root::AbstractString)
    ctx = SHA2_256_CTX()
    for p in _code_tree_paths(root)
        bytes = read(joinpath(root, p))
        update!(ctx, Vector{UInt8}(codeunits(p)))
        update!(ctx, UInt8[0x00])
        # Length-prefix the content, or a path/content boundary is ambiguous and
        # two different trees can produce one byte stream.
        update!(ctx, collect(reinterpret(UInt8, [hton(UInt64(length(bytes)))])))
        update!(ctx, bytes)
    end
    bytes2hex(digest!(ctx))
end

# 11.5 ms warm per call; a 1000-cell sweep would pay 16.8 s of it. Memoising is
# also the MORE correct reading, not a shortcut: the code that ran was fixed at
# `using SpinorBEC`, so the first call is closer to what actually executed than a
# re-read after a mid-session edit.
const _CODE_TREE_HASH_MEMO = Dict{String, String}()

"""
    code_tree_hash(root = package root; refresh=false) -> String

SHA-256 over the bytes of every file under `src/` and `ext/`, keyed by
root-relative path. 64 hex chars.

**A content hash, not a git revision.** `git rev-parse HEAD:src` does not move
for uncommitted edits or for untracked files the package actually loads, and —
decisively — the autopilot ships code to TSUBAME with `rsync --exclude=.git/`
(`workflow/autopilot/ssh_transport.jl:72`), so on the compute node there is no
repository to ask. Worse than absent: inside an unrelated enclosing repo
`git rev-parse` would succeed and describe the wrong project. Invariant 3's
point is that a stale checkout becomes VISIBLE, which requires the hash to be
computed on the node from the actual bytes.

Deterministic across worktrees, machines and mtimes: it reads only relative path
bytes and file bytes, and `sort!` on `String` is `memcmp`, so no locale enters.

Known limits, in the order they are likely to bite:

1. **Loaded code need not be hashed code.** This reads the disk when called.
   Under `-J <sysimage>` (`autopilot/backends_uge.jl:184`) or a stale precompile
   cache the process can be running different bytes.
2. `Project.toml` / `Manifest.toml` are out of scope, so `Pkg.up` moves no id.
3. Symlinks are followed for content but not recorded as links.
4. Hashing during an in-flight `rsync` or `git checkout` digests a state that
   never existed.

The value does not resolve back to a commit. Record `_capture_code_sha()`
(`autopilot/queue.jl:504`) beside it when that matters — as archeology, not as
identity.
"""
function code_tree_hash(root::AbstractString=_package_root(); refresh::Bool=false)
    key = abspath(root)
    (refresh || !haskey(_CODE_TREE_HASH_MEMO, key)) &&
        (_CODE_TREE_HASH_MEMO[key] = _code_tree_hash_uncached(key))
    _CODE_TREE_HASH_MEMO[key]
end

# For record writers only. `code_tree_hash` reads the disk, and a record writer
# is the one caller that must not acquire a new way to fail — TSUBAME re-syncs
# `src/` under running jobs (`autopilot/ssh_transport.jl:72`), so a transient
# read error is reachable. It warns rather than returning a placeholder: a
# plausible-looking wrong revision is worse than an absent one.
function _code_rev_or_nothing()
    try
        code_tree_hash()
    catch err
        @warn "code_tree_hash failed; this run's record carries no code revision" exception = err
        nothing
    end
end

# ---------------------------------------------------------------------------
# artifact_id
# ---------------------------------------------------------------------------

"""
    artifact_id(s::Stage; n=16) -> String

The content id of everything `s` declares: model, kind, method, backend, params,
predecessor, and the code that would run it.

**Nothing is selected, so nothing can be omitted.** That is the whole difference
from `_gs_cache_key` (`run_step_ground_state.jl:249`), which hand-lists 19 keys
and — as its own docstring admits — leaves out `light_shift` and
`rotating_frame_omega`.

`from` recurses into the predecessor's id rather than its value: a serial chain
is identified by what it was built on, and folding the whole ancestry in
verbatim would make the id of an N-stage chain grow with N.

`from` is also the one field that must NOT go through `_enc`. `Nothing` has no
fields, so the generic struct arm would reflect it into an empty table — which
is why that arm now refuses fieldless types outright (`io.jl`).
"""
function artifact_id(s::Stage; n::Int=16)
    content_id(
        Dict{String, Any}(
            "model" => model_toml_dict(s.model),
            "kind" => String(s.kind),
            "method" => String(s.method),
            "backend" => String(s.backend),
            "params" => _enc(s.params),
            "from" => s.from === nothing ? nothing : artifact_id(s.from; n),
            "code_rev" => code_tree_hash(),
        ); n)
end
