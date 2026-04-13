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

const OverrideMap = Dict{String,Any}

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
            idx === nothing && throw(ArgumentError("Override path segment '$key' is not a valid list index"))
            idx += 1  # 0-based → 1-based
            1 <= idx <= length(cursor) || throw(ArgumentError("Override list index $key out of bounds (length=$(length(cursor)))"))
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
                next = Dict{String,Any}()
                cursor[key] = next
            end
            cursor = next
        else
            throw(ArgumentError("Override path cannot traverse $(typeof(cursor)) at segment '$key'"))
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

Expand a scan spec into a list of override maps, one per scan point.

Supported forms (mutually exclusive):

  zip:
    system.ddi.c_dd:    [0.0, 4000.0, 7647.0]
    ground_state.zeeman.p: [100.0, 10.0, 1.0]

  product:
    system.interactions.c1_ratio: [-0.02, -0.01, 0.0]
    ground_state.target_magnetization: [-6.0, -3.0, 0.0]

`zip` produces N points (all axes must agree on length). `product` produces
∏ Nᵢ points (Cartesian product, lexicographic over the path order).

If neither key is present, returns a single empty override (= base config
unchanged), so a YAML can declare a scan with only `comparison_runs:` and
sweep nothing.
"""
function expand_scan_points(scan_dict::Dict)
    has_zip = haskey(scan_dict, "zip")
    has_product = haskey(scan_dict, "product")
    has_zip && has_product &&
        throw(ArgumentError("scan: zip and product are mutually exclusive"))

    if has_zip
        return _expand_zip(scan_dict["zip"])
    elseif has_product
        return _expand_product(scan_dict["product"])
    else
        return [OverrideMap()]
    end
end

function _expand_zip(d::Dict)
    isempty(d) && return [OverrideMap()]
    paths = collect(keys(d))
    cols = [collect(d[p]) for p in paths]
    lens = length.(cols)
    all(==(lens[1]), lens) || throw(ArgumentError(
        "scan.zip: all axes must have the same length, got $lens for paths $paths",
    ))
    n = lens[1]
    [OverrideMap(paths[i] => cols[i][k] for i in eachindex(paths)) for k in 1:n]
end

function _expand_product(d::Dict)
    isempty(d) && return [OverrideMap()]
    paths = collect(keys(d))
    cols = [collect(d[p]) for p in paths]
    points = OverrideMap[]
    _product_recurse!(points, paths, cols, 1, OverrideMap())
    points
end

function _product_recurse!(out, paths, cols, depth, acc)
    if depth > length(paths)
        push!(out, copy(acc))
        return
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
