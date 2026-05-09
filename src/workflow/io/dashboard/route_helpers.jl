# --- Shared route-parsing helpers ---
#
# Almost every `_route_*` handler in routes.jl repeats the same URL
# decode + segment split + query parse boilerplate. The two URL shapes
# that show up are:
#
#   /api/<prefix>/<run>             — 1 segment (live, scan_status, data, scan_group, ...)
#   /api/<prefix>/<run>/<file>      — 2 segments (density, phase, density_bin, snapshots, ...)
#
# `_parse_run_file(path, prefix)` covers the 2-segment form and returns
# `(name, file, query)` or `nothing` for malformed URLs. `_parse_run_only`
# covers the 1-segment form. The `_q_*` family pulls scalar values out
# of the query string with sensible defaults — replacing the regex +
# parse + nothing-check triad that 19 handlers used to repeat inline.

"""Parse `/api/<prefix>/<run>/<file>[?query]` → `(name, file, query)` NamedTuple,
or `nothing` for a malformed URL (no `/` between prefix and the rest)."""
function _parse_run_file(path::AbstractString, prefix::AbstractString)
    rest = _uri_decode(path[(length(prefix) + 1):end])
    slash_idx = findfirst('/', rest)
    slash_idx === nothing && return nothing
    name = rest[1:(slash_idx - 1)]
    after = rest[(slash_idx + 1):end]
    qidx = findfirst('?', after)
    file, query = if qidx === nothing
        (after, "")
    else
        (after[1:(qidx - 1)], after[(qidx + 1):end])
    end
    (name=name, file=file, query=query)
end

"""Parse `/api/<prefix>/<run>[?query]` → `(name, query)` NamedTuple."""
function _parse_run_only(path::AbstractString, prefix::AbstractString)
    rest = _uri_decode(path[(length(prefix) + 1):end])
    qidx = findfirst('?', rest)
    if qidx === nothing
        (name=rest, query="")
    else
        (name=rest[1:(qidx - 1)], query=rest[(qidx + 1):end])
    end
end

# --- Query-string scalar extractors ---
#
# All accept signed integers; flags follow `key=1` convention.

"""
Anchor pattern so `key` must start a query parameter (begin-of-string or
just after `&`). Without the anchor, asking for `key="ab"` on a query
like `"cab=1&ab=2"` matches the embedded `ab=1` inside `cab=1` and
returns the wrong value.
"""
_q_anchor(key::AbstractString) = "(?:^|&)" * key * "="

function _q_int(query::AbstractString, key::AbstractString, default::Int)
    m = match(Regex(_q_anchor(key) * "(-?\\d+)"), query)
    m === nothing ? default : parse(Int, m.captures[1])
end

function _q_int_opt(query::AbstractString, key::AbstractString)
    m = match(Regex(_q_anchor(key) * "(-?\\d+)"), query)
    m === nothing ? nothing : parse(Int, m.captures[1])
end

function _q_float(query::AbstractString, key::AbstractString, default::Float64)
    m = match(Regex(_q_anchor(key) * "([0-9.eE+-]+)"), query)
    m === nothing ? default : parse(Float64, m.captures[1])
end

function _q_flag(query::AbstractString, key::AbstractString)::Bool
    occursin(Regex(_q_anchor(key) * "1(?:\$|&)"), query)
end

function _q_sym(query::AbstractString, key::AbstractString, default::Symbol)
    m = match(Regex(_q_anchor(key) * "(\\w+)"), query)
    m === nothing ? default : Symbol(m.captures[1])
end

# --- JLD2 streamed-vs-legacy compat helpers ---
#
# Saves written before 2026-04-29 stored dynamics arrays at top-level
# (`d["Lz"]`, `d["per_m_history"]`, …); the streamed save format moved
# them under `d["dynamics/Lz"]`, etc. The dashboard reads both formats
# transparently — these helpers absorb the haskey-cascade that
# `_route_scan_group` and `_route_physics_summary` previously repeated
# for every field.

"""Return the raw value at `dynamics/<key>` (canonical) or `<key>` (legacy),
or `nothing` when neither is present."""
function _load_dynamics_field(d::AbstractDict, key::AbstractString)
    haskey(d, "dynamics/$key") && return d["dynamics/$key"]
    haskey(d, key) && return d[key]
    nothing
end

"""Same as `_load_dynamics_field` but coerces to `Vector{Float64}`,
returning an empty vector when absent."""
function _load_dynamics_vec(d::AbstractDict, key::AbstractString)::Vector{Float64}
    raw = _load_dynamics_field(d, key)
    raw === nothing ? Float64[] : Float64.(raw)
end

"""Populate `out["<prefix>_min/max/init/final"]` from the dynamics field
named `key` (or skip silently when absent or empty)."""
function _populate_extremes!(
    out::AbstractDict, d::AbstractDict, key::AbstractString, prefix::AbstractString=key
)
    v = _load_dynamics_vec(d, key)
    isempty(v) && return out
    out["$(prefix)_min"] = minimum(v)
    out["$(prefix)_max"] = maximum(v)
    out["$(prefix)_init"] = v[1]
    out["$(prefix)_final"] = v[end]
    out
end

"""Maximum |norm − 1| across the run, or `nothing` when no norm history."""
function _norm_max_dev(d::AbstractDict)
    nv = _load_dynamics_vec(d, "norms")
    isempty(nv) ? nothing : maximum(abs.(nv .- 1.0))
end

"""Top-component (m = +F) population fraction at run start vs end, or
`nothing` when no per-m history is stored."""
function _per_m_top_fractions(d::AbstractDict)
    pm = _load_dynamics_field(d, "per_m_history")
    pm === nothing && return nothing
    T = size(pm, 2)
    col1 = sum(view(pm, :, 1))
    colT = sum(view(pm, :, T))
    (init=pm[1, 1] / max(col1, 1e-30), final=pm[1, T] / max(colT, 1e-30))
end
