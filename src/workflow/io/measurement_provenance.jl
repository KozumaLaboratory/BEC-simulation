export provenance_header, assert_same_provenance, stamped_csv, unstamped_outputs
export src_fingerprint, load_environment

# Captured at LOAD, not at write. A job that loads code at 18:00 and writes a file
# at 21:33 must not stamp the 21:33 tree — that names code which did not produce
# the numbers, and it happened: a sync ran while 16 shards were mid-flight and
# every shard stamped the post-sync commit. Reading the sources when the module
# loads is the closest a process can get to "what am I running".
const _SRC_FINGERPRINT = Ref{String}("uninitialised")
const _LOAD_ENV = Ref{String}("uninitialised")

"""
    src_fingerprint() -> String

SHA-1 over every `.jl` file under `src/`, computed once when the module loads.

The whole tree, not a hand-listed subset: an earlier version hashed three files by
name and would have missed a change to `sgpe.jl`, which holds the noise and
damping kernels the SPGPE runs on. A list of "the files that matter" is a
convention, and conventions drift out of date silently.

# What this does NOT establish

Julia may load a **precompiled cache** built from different sources than the ones
on disk — the depot is shared between jobs, and "SpinorBEC being precompiled by
another machine" is a message this project sees. So a matching fingerprint means
the sources agreed, not that the executed machine code came from them. Closing
that would mean interrogating the cache, and until then it is a documented hole
rather than an assumed non-issue.
"""
src_fingerprint() = _SRC_FINGERPRINT[]

"""
    load_environment() -> String

Julia version, thread count and hostname, captured at load. Results here have
differed across CPU/GPU and across worker counts before, so the environment is
part of what produced a number.
"""
load_environment() = _LOAD_ENV[]

function _capture_provenance!()
    root = normpath(joinpath(@__DIR__, "..", "..", ".."))
    src = joinpath(root, "src")
    files = String[]
    isdir(src) && for (dir, _, fs) in walkdir(src), f in fs
        endswith(f, ".jl") && push!(files, joinpath(dir, f))
    end
    sort!(files)
    ctx = SHA.SHA1_CTX()
    for f in files
        SHA.update!(ctx, codeunits(relpath(f, root)))
        try
            SHA.update!(ctx, read(f))
        catch
            SHA.update!(ctx, codeunits("unreadable"))
        end
    end
    _SRC_FINGERPRINT[] = isempty(files) ? "no-src" : bytes2hex(SHA.digest!(ctx))[1:12]
    # `cache=` says whether Julia loaded this module from a precompiled image, which
    # the source fingerprint cannot tell you: the depot is shared between jobs and
    # a cache built from other sources can be loaded against a src/ tree that has
    # since changed. A run whose fingerprint matches but which came off a stale
    # cache is not reproducible, and this is the field that makes that visible
    # rather than assumed away.
    cached = try
        !isnothing(Base.cache_file_entry(Base.PkgId(@__MODULE__)))
    catch
        false
    end
    _LOAD_ENV[] =
        "julia=$(VERSION) threads=$(Threads.nthreads()) " *
        "host=$(gethostname()) cached=$cached"
    nothing
end

"""
    provenance_header(sources...) -> String

A one-line `# provenance: …` record of what produced a measurement file: the git
`HEAD`, whether the tree was dirty, and the SHA-1 of each source file named in
`sources` (paths relative to the repo root).

Write it as the first line of every measurement output. [`assert_same_provenance`](@ref)
reads it back and refuses to aggregate files that disagree.

# Why this exists

`_assert_point_provenance` already refuses to reuse a `run_yaml` point whose
recorded `env.git_hash` differs from the current one. Figure and measurement
drivers under `docs/guides/figures/` bypass that entirely, and the same bug class
came back four times in one session:

  - Six jobs wrote to `gam_\$(MD)_\$(i).log` with the swept rate absent from the
    name, so three rates overwrote one file per setting.
  - A merge read CSVs stamped 10:49 as the output of a 13:34 rerun and reported
    pre-fix numbers as post-fix. Caught only because they agreed to every digit.
  - A long run started 14 seconds after its source was synced, and which version
    it loaded could not be established afterwards.
  - Three "different" initial conditions agreed to 13 digits because they were the
    same code.

Every one of those is the same failure: a measurement read as evidence about a
state of the code that did not produce it. Distinguishing filenames is a
convention and conventions get forgotten; a refusal does not.
"""
function provenance_header(sources::AbstractString...)
    head = try
        strip(read(`git rev-parse --short HEAD`, String))
    catch
        "unknown"
    end
    dirty = try
        !isempty(strip(read(`git status --porcelain`, String)))
    catch
        true
    end
    hashes = map(sources) do f
        h = isfile(f) ? bytes2hex(SHA.sha1(read(f)))[1:12] : "missing"
        "$(basename(f))=$h"
    end
    # src= is the load-time fingerprint of the whole tree and is the load-bearing
    # field; the per-file hashes are read now and are only a convenience for
    # eyeballing which file moved.
    "# provenance: head=$head dirty=$dirty src=$(src_fingerprint()) " *
    "$(load_environment())" * (isempty(hashes) ? "" : " " * join(hashes, " "))
end

"""
    assert_same_provenance(files; require_clean=false) -> String

Read the `# provenance:` line from each of `files` and throw unless they all
agree. Returns the shared provenance string.

Set `require_clean=true` to also refuse a dirty tree — appropriate for a published
number, not for a working measurement.

Files with no provenance line are an error rather than a skip: a file that does
not say what produced it is exactly the case this guards against, and treating it
as "probably fine" is how the mistake happened.
"""
function assert_same_provenance(files::AbstractVector{<:AbstractString};
    require_clean::Bool=false)
    isempty(files) && throw(ArgumentError("assert_same_provenance: no files"))
    provs = Dict{String, Vector{String}}()
    for f in files
        line = nothing
        for ln in eachline(f)
            startswith(ln, "# provenance:") && (line=ln; break)
            startswith(ln, "#") || break        # past the header block
        end
        line === nothing && throw(
            ArgumentError(
                "assert_same_provenance: $f has no `# provenance:` line. A file that " *
                "does not record what produced it cannot be aggregated — write one " *
                "with provenance_header()."),
        )
        push!(get!(provs, line, String[]), f)
    end
    if length(provs) > 1
        msg = join(("  $k\n    " * join(basename.(v), ", ") for (k, v) in provs), "\n")
        throw(
            ArgumentError(
                "assert_same_provenance: these files were produced by different code, " *
                "so aggregating them would average across versions:\n$msg"),
        )
    end
    prov = first(keys(provs))
    require_clean && occursin("dirty=true", prov) &&
        throw(
            ArgumentError(
                "assert_same_provenance: produced from a dirty tree, which cannot be " *
                "reproduced: $prov"),
        )
    prov
end

"""
    stamped_csv(path, sources; header) -> IO-taking function

Open `path` for writing, emit [`provenance_header`](@ref) then `header`, and hand
the stream to the caller:

```julia
stamped_csv(csv, ("src/solvers/spgpe.jl",); header="tau_Q,sigma_W") do io
    for row in rows; println(io, row); end
end
```

One place that writes the stamp, so a driver cannot half-adopt the convention. The
alternative — asking every driver to remember two `println`s — is the convention
that already failed four times in this repo, and there are a dozen drivers under
`docs/guides/figures/` writing CSVs by hand.
"""
function stamped_csv(f::Function, path::AbstractString,
    sources::Union{Tuple, AbstractVector}; header::AbstractString="")
    mkpath(dirname(path))
    open(path, "w") do io
        println(io, provenance_header(sources...))
        isempty(header) || println(io, header)
        f(io)
    end
    path
end

"""
    unstamped_outputs(dir; ext=".csv") -> Vector{String}

Every file under `dir` whose first non-blank line is not a `# provenance:` record.

This is the instrument for the coverage question — "which measurements cannot say
what produced them" — as opposed to the per-file refusal in
[`assert_same_provenance`](@ref). A driver that writes its own header without the
stamp shows up here rather than being discovered when a merge silently averages
two code versions.
"""
function unstamped_outputs(dir::AbstractString; ext::AbstractString=".csv")
    isdir(dir) || return String[]
    out = String[]
    for (root, _, files) in walkdir(dir), fn in files
        endswith(fn, ext) || continue
        p = joinpath(root, fn)
        stamped = false
        for ln in eachline(p)
            isempty(strip(ln)) && continue
            stamped = startswith(ln, "# provenance:")
            break
        end
        stamped || push!(out, p)
    end
    out
end
