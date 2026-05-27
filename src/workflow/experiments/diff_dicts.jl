# --- Generic dict / vector diff primitive ---
#
# Foundation for inspector's structural lift. Used by:
#   - input_vs_resolved key-drop detection (Check A)
#   - sweep_axis_silent_drift (per-cell pairwise diff in inspect_batch)
#   - raw-vs-resolved YAML viewer
#
# Returns a `Diff` of dotted-path changes. Symbol vs string keys are
# normalised to string so YAML.load and Dict literals diff identically.

export DictDiff, DiffEntry, diff_dicts, flatten_diff

"""
Path component for `DiffEntry`. `String` for dict keys (Symbol keys are
stringified), `Int` for array indices (1-based, matching Julia).
"""
const DiffPath = Vector{Union{String, Int}}

struct DiffEntry
    path::DiffPath
    kind::Symbol                        # :added | :removed | :changed
    before::Any                         # missing when :added
    after::Any                          # missing when :removed
end

struct DictDiff
    added::Vector{DiffEntry}            # present in `b`, absent in `a`
    removed::Vector{DiffEntry}          # present in `a`, absent in `b`
    changed::Vector{DiffEntry}          # present in both, value differs
end

"""
    diff_dicts(a, b) -> DictDiff

Recursive structural diff between two dict / array / scalar trees.
Treats `Symbol` and `String` keys as equivalent. Two `Real`s are equal
if `isequal` is true (so `NaN == NaN` for diff purposes). Nested arrays
are compared element-wise by index; differing lengths produce
:added/:removed entries for the surplus tail.
"""
function diff_dicts(a, b)
    diff = DictDiff(DiffEntry[], DiffEntry[], DiffEntry[])
    _diff_walk!(diff, DiffPath(), a, b)
    return diff
end

function _diff_walk!(diff::DictDiff, path::DiffPath, a, b)
    if a isa AbstractDict && b isa AbstractDict
        _diff_dict_pair!(diff, path, a, b)
    elseif a isa AbstractVector && b isa AbstractVector
        _diff_vector_pair!(diff, path, a, b)
    elseif _scalar_equal(a, b)
        return nothing
    else
        push!(diff.changed, DiffEntry(copy(path), :changed, a, b))
    end
end

function _diff_dict_pair!(diff::DictDiff, path::DiffPath,
    a::AbstractDict, b::AbstractDict)
    a_keys = Dict{String, Any}(string(k) => v for (k, v) in a)
    b_keys = Dict{String, Any}(string(k) => v for (k, v) in b)
    for (k, av) in a_keys
        if haskey(b_keys, k)
            push!(path, k)
            _diff_walk!(diff, path, av, b_keys[k])
            pop!(path)
        else
            child = copy(path);
            push!(child, k)
            push!(diff.removed, DiffEntry(child, :removed, av, missing))
        end
    end
    for (k, bv) in b_keys
        if !haskey(a_keys, k)
            child = copy(path);
            push!(child, k)
            push!(diff.added, DiffEntry(child, :added, missing, bv))
        end
    end
end

function _diff_vector_pair!(diff::DictDiff, path::DiffPath,
    a::AbstractVector, b::AbstractVector)
    n = min(length(a), length(b))
    for i in 1:n
        push!(path, i)
        _diff_walk!(diff, path, a[i], b[i])
        pop!(path)
    end
    for i in (n + 1):length(a)
        child = copy(path);
        push!(child, i)
        push!(diff.removed, DiffEntry(child, :removed, a[i], missing))
    end
    for i in (n + 1):length(b)
        child = copy(path);
        push!(child, i)
        push!(diff.added, DiffEntry(child, :added, missing, b[i]))
    end
end

@inline _scalar_equal(a, b) = isequal(a, b)

"""
    flatten_diff(diff) -> Vector{DiffEntry}

All entries (added + removed + changed) in a single chronological list,
sorted by path. Convenience for UI rendering and Markdown export.
"""
function flatten_diff(d::DictDiff)
    all = vcat(d.added, d.removed, d.changed)
    sort!(all; by=e -> _path_key(e.path))
    return all
end

_path_key(path::DiffPath) = join((p isa Int ? lpad(string(p), 6, '0') : p
                                  for p in path), ".")

"""
    path_string(path::DiffPath) -> String

Dotted-path representation used in messages and Markdown. Array indices
appear bracketed (`pipeline[1].dynamics.B.Bz`).
"""
function path_string(path::DiffPath)
    parts = String[]
    for p in path
        if p isa Int
            if isempty(parts)
                push!(parts, "[$(p)]")
            else
                parts[end] = parts[end] * "[$(p)]"
            end
        else
            push!(parts, p)
        end
    end
    join(parts, ".")
end
