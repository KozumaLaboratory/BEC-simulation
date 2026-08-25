# --- store_census: what is actually IN the run store, duplicate-wise ---
#
# #478 asked why a re-launch does not hit the cache, and pre-registered three
# causes: (a) the values really differ, (b) same physics different BYTES (the
# `run_yaml` directory key is `sha256(config bytes)`), (c) same config different
# producing commit. PR #482 measured (b) at 3.2 % of committed configs and
# dissolved (c) — the mismatch it would relax is not what the gate refuses; all
# 224 stamped points record `git_dirty = true`, which no hash granularity fixes.
#
# What #482 could NOT measure was (a), and it said so: the store predates the
# current 16-hex naming, so a run directory cannot be reverse-mapped to its
# source YAML. It reported the ceiling instead — 34 basenames spread over 77
# directories, 35 % of the store — and estimated that most of it was (a).
#
# That estimate is what this closes, and it does not need the reverse map: every
# run directory carries its own `config.yaml`. Two directories sharing a basename
# can therefore be diffed DIRECTLY, and the answer is not a count but the SET OF
# DOTTED PATHS on which they disagree — which separates the pre-registered causes
# from a fourth the pre-registration did not have:
#
#   (e) deliberate A/B pairs. `00_scalar_free_uniform_stationary_*` differs on
#       `backend: cuda` vs `cpu` and nothing else. That is a GPU=CPU parity arm,
#       i.e. two runs that are SUPPOSED to exist. Counting it as a cache miss
#       would have made a validation ladder look like waste, and "eliminate the
#       duplicate" would have deleted a Level-0 gate.
#
# So the census reports groups keyed by their differing paths. A canonical
# parameter grid acts on (a) groups; the `Experiment` path acts on (b) groups; (e)
# groups are the store working correctly and must not be swept into either.

export StoreCensus, store_census, store_census_report, store_run_basename
export store_path_class

"""
    STORE_EXECUTION_KNOBS

Config keys that change HOW a run executes, not WHAT it computes. A group of run
directories differing only on these is a parity or replicate arm.

A named list, and unknown keys are treated as PHYSICS — the conservative
direction. Mis-filing a physics knob as execution would report real duplicated
work as intentional; mis-filing an execution knob as physics only overstates
cause (a), which the report shows path-by-path so a reader can see it.
"""
const STORE_EXECUTION_KNOBS = ("backend", "dtype", "device", "threads",
    "verbose", "seed", "save", "save_every", "output", "outdir", "notes")

"""
    STORE_ANNOTATION_PREFIXES

Top-level config blocks that are BOOKKEEPING: they enter the run-directory key
(which is `sha256` of the whole file's bytes) and reach no physics.

This distinction is where cause (b) actually lives. Canonical-byte equality
finds nothing on disk, because two runs of the same physics almost never differ
by whitespace — they differ by a `metadata.suite` label or a
`metadata.noise_convention` note that was added between launches. Same physics,
different bytes, recomputed: (b), arriving through a door the pre-registration
did not name.
"""
const STORE_ANNOTATION_PREFIXES = ("metadata", "notes", "description", "provenance")

"""
    store_path_class(path) -> Symbol

`:annotation` for a differing path inside an annotation block, `:execution` for an
execution knob, `:physics` for everything else.

`:physics` is the fallback ON PURPOSE. An unrecognised key read as execution
would report duplicated physics as intentional, which is the direction that loses
work; read as physics it only overstates cause (a), and the report prints every
path so the overstatement is visible rather than baked into a count.
"""
function store_path_class(path::AbstractString)
    parts = split(path, '.')
    first(parts) in STORE_ANNOTATION_PREFIXES && return :annotation
    # Array indices arrive as `pipeline[1]`, so compare on the bare key.
    leaf = replace(String(last(parts)), r"\[\d+\]$" => "")
    leaf in STORE_EXECUTION_KNOBS && return :execution
    :physics
end

"""
    StoreCensus

Duplicate structure of a run store, grouped by run-directory basename.

Fields:
* `root`          — the store scanned
* `n_dirs`        — run directories seen (a directory holding `config.yaml`)
* `n_basenames`   — distinct basenames
* `groups`        — basename → `Vector{String}` of directory names, for the
                    basenames with more than one directory
* `differing`     — basename → sorted dotted paths on which the group's configs
                    disagree. Empty vector = canonically identical (cause **b**)
* `unreadable`    — directories whose `config.yaml` would not parse
* `n_no_config`   — run directories with no `config.yaml` at all
* `n_keyed`       — directories whose name carries a content-hash suffix
* `stale_key`     — directories whose `config.yaml` no longer hashes to their own
                    suffix, i.e. the config was edited AFTER the run

`differing` is the load-bearing field. A count of duplicates is not actionable;
the knob they differ on is.

`stale_key` is the field with a free positive control. The directory name IS
`sha256(config bytes)`, so re-hashing the file either reproduces the name or does
not, and a scan that reported zero while unable to look is impossible here: the
219 verifying directories ARE the negative control and any mismatch is the
positive one. It is not a hypothetical — `bce2068f` ("211 Eu configs pinned m=-F
under a field that prefers m=+F") edited a committed run directory's config in
place, so the committed `matsui_edh_baseline_9ca97308/config.yaml` hashes to
`89b5ed0b` and describes DIFFERENT physics from the run stored under that name.
"""
struct StoreCensus
    root::String
    n_dirs::Int
    n_basenames::Int
    groups::Dict{String, Vector{String}}
    differing::Dict{String, Vector{String}}
    unreadable::Vector{String}
    n_no_config::Int
    n_keyed::Int
    stale_key::Dict{String, String}
end

# `<basename>_<hash>` → `<basename>`. Both namings are live on disk: the current
# key is `sha256(bytes)[1:16]` and everything older carries an 8-hex suffix, so
# the pattern admits either width rather than the current one only — a scan that
# saw just the new form would report a store of 0 duplicates and be believed.
const _STORE_HASH_SUFFIX = r"_[0-9a-f]{8}(?:[0-9a-f]{8})?$"

"""
    store_run_basename(dirname) -> String

Strip a trailing content-hash suffix from a run directory name. Returns the name
unchanged when there is none — a hand-named directory is its own basename, not a
group with everything else that lacks a hash.
"""
store_run_basename(name::AbstractString) = replace(String(name), _STORE_HASH_SUFFIX => "")

# Sorted dotted paths on which any two configs in `configs` disagree. Pairwise
# against the first is enough: a path that distinguishes ANY pair distinguishes
# it from at least one of them, and the union over pairs-with-first is the union
# over all pairs for the purpose of naming the knobs.
function _differing_paths(configs::Vector{Any})
    paths = Set{String}()
    for i in 2:length(configs)
        for e in flatten_diff(diff_dicts(configs[1], configs[i]))
            push!(paths, path_string(e.path))
        end
    end
    sort!(collect(paths))
end

"""
    store_census(root=default_run_root()) -> StoreCensus

Group the run directories under `root` by basename and diff the configs within
each group.

Reads `config.yaml` only — no point file is opened, so this is seconds over a
261 GB store. Directories with no config are COUNTED rather than skipped: the
store predates several conventions and a silent skip would report a cleaner
store than exists.
"""
function store_census(root::AbstractString=default_run_root())
    isdir(root) || throw(ArgumentError("store_census: not a directory: $root"))
    by_base = Dict{String, Vector{String}}()
    cfgs = Dict{String, Any}()
    unreadable = String[]
    stale_key = Dict{String, String}()
    n_dirs = 0
    n_no_config = 0
    n_keyed = 0
    for name in sort(readdir(root))
        d = joinpath(root, name)
        isdir(d) || continue
        cfg = joinpath(d, "config.yaml")
        if !isfile(cfg)
            # Not a run directory at all (`_stage/`, a scan parent) unless it
            # holds points, in which case it IS one and its config is missing.
            any(f -> startswith(f, "point_") && endswith(f, ".jld2"), readdir(d)) &&
                (n_dirs += 1; n_no_config += 1)
            continue
        end
        n_dirs += 1
        # Does the config still hash to the directory it lives in? `compute_run_dir`
        # keys on the raw bytes, so this is an equality and not a heuristic.
        m = match(_STORE_HASH_SUFFIX, name)
        if m !== nothing
            n_keyed += 1
            want = m.match[2:end]           # drop the leading underscore
            got = bytes2hex(sha256(read(cfg)))[1:length(want)]
            got == want || (stale_key[name] = got)
        end
        parsed = try
            YAML.load_file(cfg)
        catch
            push!(unreadable, name)
            continue
        end
        cfgs[name] = parsed
        push!(get!(by_base, store_run_basename(name), String[]), name)
    end
    groups = Dict{String, Vector{String}}()
    differing = Dict{String, Vector{String}}()
    for (base, names) in by_base
        length(names) > 1 || continue
        groups[base] = names
        differing[base] = _differing_paths(Any[cfgs[n] for n in names])
    end
    StoreCensus(String(root), n_dirs, length(by_base), groups, differing,
        unreadable, n_no_config, n_keyed, stale_key)
end

"""
    store_census_report(c::StoreCensus; io=stdout) -> Dict{String,Any}

Print the census bucketed by WHAT distinguishes each duplicate set, and return
the same content as a Dict.

The buckets are the #478 causes, so a reader gets a verdict and not a table:

  * `identical`        — the two configs are canonically equal. Cause **(b)** in
                         its pure form: only whitespace or key order moved.
  * `annotation_only`  — every differing path is bookkeeping
                         ([`STORE_ANNOTATION_PREFIXES`](@ref)). Cause **(b)** as
                         it actually occurs: the physics is identical, the bytes
                         are not because a `metadata.suite` label was added, and
                         the run re-computed. This is the recoverable waste.
  * `execution_only`   — no physics path differs and at least one execution knob
                         does ([`STORE_EXECUTION_KNOBS`](@ref)). Cause **(e)**,
                         which the pre-registration did not have: GPU=CPU parity
                         and seed-replicate arms. These are the store working, and
                         deduplicating them would delete a Level-0 gate.
  * `physics`          — at least one physics or resolution path differs. Cause
                         **(a)**: genuinely different points. A canonical
                         parameter grid acts here; deduplication does not.
"""
function store_census_report(c::StoreCensus; io::IO=stdout)
    ident = String[]
    annotation_only = Dict{String, Vector{String}}()
    execution_only = Dict{String, Vector{String}}()
    physics = Dict{String, Vector{String}}()
    for (base, paths) in c.differing
        classes = Set(store_path_class.(paths))
        if isempty(paths)
            push!(ident, base)
        elseif :physics in classes
            physics[base] = paths
        elseif :execution in classes
            execution_only[base] = paths
        else
            annotation_only[base] = paths
        end
    end
    sort!(ident)
    n_dup_dirs = sum(length(v) for v in values(c.groups); init=0)
    dirs(b) = length(c.groups[b])
    println(io, "store census: $(c.root)")
    println(
        io,
        "  $(c.n_dirs) run dirs · $(c.n_basenames) basenames · " *
        "$(length(c.groups)) basenames with >1 dir covering $n_dup_dirs dirs " *
        "($(round(100 * n_dup_dirs / max(c.n_dirs, 1); digits=1)) %)",
    )
    c.n_no_config == 0 ||
        println(io, "  $(c.n_no_config) dirs hold points but no config.yaml")
    isempty(c.unreadable) ||
        println(
            io,
            "  $(length(c.unreadable)) unparseable config.yaml: " *
            join(first(c.unreadable, 5), ", "),
        )
    println(
        io,
        "  $(c.n_keyed) content-keyed dirs · " *
        "$(length(c.stale_key)) whose config.yaml no longer hashes to " *
        "its own suffix",
    )
    for (n, got) in sort!(collect(c.stale_key); by=first)
        println(
            io,
            "      STALE KEY  $n  ->  $got  " *
            "(the stored config describes different physics than the run)",
        )
    end
    for (tag, label, bucket) in (
        ("(b)", "canonically identical (bytes only)", nothing),
        ("(b)", "annotation only — same physics, recomputed", annotation_only),
        ("(e)", "execution knob only — parity / replicate", execution_only),
        ("(a)", "a physics or resolution knob differs", physics))
        keys_ = bucket === nothing ? ident : sort!(collect(keys(bucket)))
        nd = sum(dirs.(keys_); init=0)
        println(
            io,
            "  $tag $(rpad(label, 44)) $(lpad(length(keys_), 3)) " *
            "basenames / $(lpad(nd, 3)) dirs",
        )
        for b in keys_
            paths = bucket === nothing ? String[] : bucket[b]
            println(
                io,
                "      $b ($(dirs(b)) dirs)" *
                (
                    if isempty(paths)
                        ""
                    else
                        "  ←  " *
                        join(first(paths, 5), ", ") *
                        (length(paths) > 5 ?
                         " …(+$(length(paths) - 5))" : "")
                    end
                ),
            )
        end
    end
    Dict{String, Any}(
        "root" => c.root, "n_dirs" => c.n_dirs, "n_basenames" => c.n_basenames,
        "n_duplicate_basenames" => length(c.groups), "n_duplicate_dirs" => n_dup_dirs,
        "n_no_config" => c.n_no_config, "unreadable" => c.unreadable,
        "n_keyed" => c.n_keyed,
        "stale_key" => Dict{String, Any}(k => v for (k, v) in c.stale_key),
        "identical" => ident,
        "annotation_only" => Dict{String, Any}(k => v for (k, v) in annotation_only),
        "execution_only" => Dict{String, Any}(k => v for (k, v) in execution_only),
        "physics" => Dict{String, Any}(k => v for (k, v) in physics),
    )
end
