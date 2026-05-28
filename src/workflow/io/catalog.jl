# Human-navigation layer over the content-addressed run store.
#
# CAS (`runs/<hash>/`) gives machine identity — dedup, idempotence,
# immutability — but zero human navigability: `ls runs/` is a sea of
# hashes by design, exactly like `/nix/store` or `.git/objects`. Nobody
# navigates those by hash; a human layer (nix profiles, git refs) sits on
# top. This file is the first such primitive: **tags** — stable names →
# content_id (`paper3_fig6_final → a1a20…`), the git-tag / nix-profile
# analogue. One name resolves to one cid; one cid may carry many names.
#
# All catalog state lives under `<runs_root>/.catalog/`. The CAS run dirs
# are NEVER modified — the catalog is purely additive, rebuildable, and
# safe to delete.

export TagRecord, catalog_dir, tags_path,
    load_tags, tag_run!, untag!, resolve_tag, tags_for

const CATALOG_DIRNAME = ".catalog"
const TAGS_FILENAME = "tags.toml"
const CATALOG_SCHEMA_VERSION = "1.0"
# git-tag-safe and readable: letters, digits, and . _ - /
const _TAG_NAME_RE = r"^[A-Za-z0-9._/-]+$"

struct TagRecord
    name::String
    content_id::String
    created_at::DateTime
    created_by::String
end

catalog_dir(runs_root::AbstractString=default_store().root) = joinpath(
    String(runs_root), CATALOG_DIRNAME
)

tags_path(runs_root::AbstractString=default_store().root) = joinpath(
    catalog_dir(runs_root), TAGS_FILENAME
)

# Serialize read-modify-write across concurrent taggers (two dashboard
# POSTs racing). mkdir is atomic on POSIX; stale locks are reclaimed.
function _with_catalog_lock(f::Function, runs_root::AbstractString;
    stale_after_s::Real=60)
    dir = catalog_dir(runs_root)
    isdir(dir) || mkpath(dir)
    lockdir = joinpath(dir, ".lock")
    attempts = 0
    while true
        try
            mkdir(lockdir)
            break
        catch err
            (err isa SystemError && isdir(lockdir)) || rethrow(err)
            if time() - mtime(lockdir) > stale_after_s
                rm(lockdir; recursive=true, force=true)
                continue
            end
            (attempts += 1) > 100 && error("catalog lock held too long: $lockdir")
            sleep(0.05)
        end
    end
    try
        return f()
    finally
        rm(lockdir; recursive=true, force=true)
    end
end

_parse_dt(s) =
    try
        DateTime(String(s))
    catch
        DateTime(0)
    end

"""
    load_tags(; runs_root=default_store().root) -> Vector{TagRecord}

Read all tags, sorted by name. Empty when no catalog exists yet.
"""
function load_tags(; runs_root::AbstractString=default_store().root)
    p = tags_path(runs_root)
    isfile(p) || return TagRecord[]
    d = try
        TOML.parsefile(p)
    catch e
        @warn "tags.toml parse failed" path=p exception=e
        return TagRecord[]
    end
    out = TagRecord[]
    for (name, rec) in get(d, "tags", Dict())
        rec isa AbstractDict || continue
        push!(
            out,
            TagRecord(
                String(name),
                String(get(rec, "content_id", "")),
                _parse_dt(get(rec, "created_at", "")),
                String(get(rec, "created_by", "")),
            ),
        )
    end
    sort!(out; by=t -> t.name)
    return out
end

function _write_tags(records::AbstractVector{TagRecord},
    runs_root::AbstractString)
    d = Dict{String, Any}(
        "schema_version" => CATALOG_SCHEMA_VERSION,
        "tags" => Dict{String, Any}(
            t.name => Dict{String, Any}(
                "content_id" => t.content_id,
                "created_at" => string(t.created_at),
                "created_by" => t.created_by,
            ) for t in records
        ),
    )
    p = tags_path(runs_root)
    isdir(dirname(p)) || mkpath(dirname(p))
    tmp = p * ".tmp"
    open(tmp, "w") do io
        TOML.print(io, d)
    end
    mv(tmp, p; force=true)
    return p
end

"""
    tag_run!(name, content_id; created_by="", runs_root=...) -> TagRecord

Pin a stable human name to a run's `content_id`. Re-tagging an existing
name re-points it (last write wins). Does NOT verify the run dir exists —
the HTTP route checks that at the system boundary; the core stays pure
for testability.
"""
function tag_run!(name::AbstractString, content_id::AbstractString;
    created_by::AbstractString="",
    runs_root::AbstractString=default_store().root)
    nm = String(name)
    occursin(_TAG_NAME_RE, nm) || throw(ArgumentError(
        "invalid tag name $(repr(nm)); allowed: letters, digits, . _ - /"))
    isempty(content_id) && throw(ArgumentError("content_id required"))
    rec = TagRecord(nm, String(content_id), now(), String(created_by))
    _with_catalog_lock(runs_root) do
        recs = load_tags(; runs_root=runs_root)
        filter!(t -> t.name != nm, recs)
        push!(recs, rec)
        _write_tags(recs, runs_root)
    end
    return rec
end

"""
    untag!(name; runs_root=...) -> Bool

Remove a tag. Returns true if it existed.
"""
function untag!(name::AbstractString;
    runs_root::AbstractString=default_store().root)
    nm = String(name)
    removed = Ref(false)
    _with_catalog_lock(runs_root) do
        recs = load_tags(; runs_root=runs_root)
        n0 = length(recs)
        filter!(t -> t.name != nm, recs)
        removed[] = length(recs) < n0
        removed[] && _write_tags(recs, runs_root)
    end
    return removed[]
end

"""
    resolve_tag(name; runs_root=...) -> Union{String, Nothing}

Name → content_id, or nothing if the name is not tagged.
"""
function resolve_tag(name::AbstractString;
    runs_root::AbstractString=default_store().root)
    nm = String(name)
    for t in load_tags(; runs_root=runs_root)
        t.name == nm && return t.content_id
    end
    return nothing
end

"""
    tags_for(content_id; runs_root=...) -> Vector{String}

Reverse lookup: all human names pinned to a cid.
"""
function tags_for(content_id::AbstractString;
    runs_root::AbstractString=default_store().root)
    cid = String(content_id)
    [t.name for t in load_tags(; runs_root=runs_root) if t.content_id == cid]
end
