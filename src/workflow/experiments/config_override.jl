# --- Config override primitive ---
#
# A single mechanism for expressing parameter variations across the YAML
# config tree. Used by:
#   - scans (each scan point is one override map)
#   - comparison runs (each run is one override map)
#   - dynamics phases (each phase carries an override applied before running)
#
# An OverrideMap is `Dict{String,Any}` whose keys are dotted paths into the
# raw YAML dict (e.g. "system.ddi.c_dd", "ground_state.zeeman.p"). Applying
# the override produces a deep-copied dict with those leaves replaced.
#
# Scans are then literally a list of OverrideMaps generated from a higher-
# level scan spec (zip / product over a few paths).

const OverrideMap = Dict{String, Any}

"""
    apply_override!(d::Dict, path::String, value)

Walk dotted `path` into `d`, creating intermediate dicts as needed, and set
the leaf to `value`. Mutates `d`.
"""
function apply_override!(d::Dict, path::AbstractString, value)
    parts = split(path, '.')
    cursor::Any = d
    for (i, part) in enumerate(parts)
        key = String(part)
        if i == length(parts)
            # Final segment: set value
            if cursor isa AbstractVector
                idx = parse(Int, key) + 1  # 0-based → 1-based
                cursor[idx] = value
            elseif cursor isa Dict
                cursor[key] = value
            end
            return d
        end
        # Navigate: handle Dict keys, list indices, and single-key unwrap
        if cursor isa AbstractVector
            idx = tryparse(Int, key)
            idx === nothing &&
                throw(ArgumentError("Override path segment '$key' is not a valid list index"))
            idx += 1  # 0-based → 1-based
            1 <= idx <= length(cursor) || throw(
                ArgumentError("Override list index $key out of bounds (length=$(length(cursor)))"),
            )
            elem = cursor[idx]
            # Auto-unwrap single-key dicts (pipeline steps like {ground_state: {...}})
            if elem isa Dict && length(elem) == 1
                cursor = first(values(elem))
            else
                cursor = elem
            end
        elseif cursor isa Dict
            next = get(cursor, key, nothing)
            if next === nothing
                next = Dict{String, Any}()
                cursor[key] = next
            end
            cursor = next
        else
            throw(
                ArgumentError("Override path cannot traverse $(typeof(cursor)) at segment '$key'")
            )
        end
    end
    d
end

"""
    apply_overrides(base::Dict, overrides::OverrideMap...) → Dict

Return a deep copy of `base` with each override map applied in order.
"""
function apply_overrides(base::Dict, overrides::OverrideMap...)
    out = deepcopy(base)
    for ov in overrides
        for (path, value) in ov
            apply_override!(out, path, value)
        end
    end
    out
end

"""
    expand_scan_points(scan_dict::Dict) → Vector{OverrideMap}

Expand a scan spec into override maps. Supports zip, product, or both combined
(Cartesian product of zip × product). When both are present, each zip point is
crossed with all product points.
"""
function expand_scan_points(scan_dict::Dict)
    has_zip = haskey(scan_dict, "zip")
    has_product = haskey(scan_dict, "product")

    zip_points = has_zip ? _expand_zip(scan_dict["zip"]) : [OverrideMap()]
    prod_points = has_product ? _expand_product(scan_dict["product"]) : [OverrideMap()]

    if !has_zip && !has_product
        return [OverrideMap()]
    end

    # Cartesian product of zip × product
    [merge(z, p) for z in zip_points for p in prod_points]
end

"""
    _expand_values(spec) → Vector

Expand a scan axis value specification into a concrete list of values.

Supported forms:
  [1.0, 2.0, 3.0]                        # explicit list
  {from: 0, to: 1, n: 11}                # linspace
  {from: 100, to: 0.1, n: 7, scale: log} # logspace
  {from: 0, to: 10, step: 0.5}           # range with step size
"""
function _expand_values(spec)
    spec isa AbstractVector && return collect(spec)
    spec isa Dict || throw(ArgumentError("Scan values must be a list or {from, to, ...} dict"))

    from = Float64(spec["from"])
    to = Float64(spec["to"])

    if haskey(spec, "step")
        step = Float64(spec["step"])
        return collect(from:step:to)
    end

    n = Int(get(spec, "n", 11))
    n >= 2 || throw(ArgumentError("scan n must be >= 2"))
    scale = Symbol(get(spec, "scale", "linear"))

    if scale == :linear
        return collect(range(from, to; length=n))
    elseif scale == :log
        from > 0 && to > 0 || throw(ArgumentError("log scale requires positive from/to"))
        return [exp(v) for v in range(log(from), log(to); length=n)]
    elseif scale == :sqrt
        # √ scale: denser near 0, sparser at large values
        s_from = sign(from) * sqrt(abs(from))
        s_to = sign(to) * sqrt(abs(to))
        return [sign(v) * v^2 for v in range(s_from, s_to; length=n)]
    elseif scale == :geom
        # Geometric: same as log but allows from=0 by shifting
        from >= 0 && to > 0 || throw(ArgumentError("geom scale requires non-negative from/to"))
        if from == 0
            return [0.0; [exp(v) for v in range(log(to / n), log(to); length=n - 1)]]
        end
        return [exp(v) for v in range(log(from), log(to); length=n)]
    elseif scale == :cosine
        # Cosine spacing: denser at endpoints (Chebyshev nodes)
        return [(from + to) / 2 + (to - from) / 2 * cos(π * (n - k) / (n - 1)) for k in 1:n]
    elseif scale == :reverse_log
        # Denser near `to` (log-reversed)
        to > 0 || throw(ArgumentError("reverse_log requires to > 0"))
        reversed = [exp(v) for v in range(log(to), log(max(from, to/1000)); length=n)]
        return reverse(reversed)
    else
        throw(
            ArgumentError(
                "Unknown scale: $scale. Supported: linear, log, sqrt, geom, cosine, reverse_log"
            ),
        )
    end
end

function _expand_zip(d::Dict)
    isempty(d) && return [OverrideMap()]
    paths = collect(keys(d))
    cols = [_expand_values(d[p]) for p in paths]
    lens = length.(cols)
    all(==(lens[1]), lens) || throw(
        ArgumentError(
            "scan.zip: all axes must have the same length, got $lens for paths $paths"
        ),
    )
    n = lens[1]
    [OverrideMap(paths[i] => cols[i][k] for i in eachindex(paths)) for k in 1:n]
end

function _expand_product(d::Dict)
    isempty(d) && return [OverrideMap()]
    paths = collect(keys(d))
    cols = [_expand_values(d[p]) for p in paths]
    points = OverrideMap[]
    _product_recurse!(points, paths, cols, 1, OverrideMap())
    points
end

function _product_recurse!(out, paths, cols, depth, acc)
    if depth > length(paths)
        push!(out, copy(acc))
        return nothing
    end
    for v in cols[depth]
        acc[paths[depth]] = v
        _product_recurse!(out, paths, cols, depth + 1, acc)
    end
    delete!(acc, paths[depth])
end

"""
    parse_override_map(d::Dict) → OverrideMap

Parse a YAML override block (a flat dict of dotted-path → value) into an
OverrideMap. Currently a thin wrapper that copies the keys; reserved for
future validation (e.g. existence checks against a known schema).
"""
function parse_override_map(d::Dict)
    OverrideMap(String(k) => v for (k, v) in d)
end

parse_override_map(::Nothing) = OverrideMap()
