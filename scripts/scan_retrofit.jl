# Retrofit existing multi-dir scans into the scan.yaml format
# (docs/scan_group_redesign.md).
#
# Looks at runs/<scan_dir>/*/config.yaml, infers which axis is the
# scan parameter (the one that varies across siblings), writes a
# scan.yaml at runs/<scan_dir>/scan.yaml.
#
# Usage:
#   julia --project=. scripts/scan_retrofit.jl runs/phi_omega_scan/
#   julia --project=. scripts/scan_retrofit.jl runs/berry_crossover_scan/
#
# Result: scan.yaml lands at the scan dir root. Per-point configs left
# in place (this is read-only on the existing files).

using YAML
using Dates

length(ARGS) == 1 || error("Usage: julia --project=. scripts/scan_retrofit.jl <runs/scan_dir/>")
const SCAN_DIR = rstrip(ARGS[1], '/')
isdir(SCAN_DIR) || error("not a directory: $SCAN_DIR")

# Find subdirs with config.yaml.
const point_dirs = filter(
    e -> isdir(joinpath(SCAN_DIR, e)) && isfile(joinpath(SCAN_DIR, e, "config.yaml")),
    readdir(SCAN_DIR),
)
isempty(point_dirs) && error("no per-point config.yaml found under $SCAN_DIR")
sort!(point_dirs)

# Load all configs and collect their leaf-paths → values.
function _walk_paths(d, prefix = String[])
    out = Dict{String, Any}()
    if d isa AbstractDict
        for (k, v) in d
            sub = _walk_paths(v, vcat(prefix, string(k)))
            for (path, val) in sub
                out[path] = val
            end
        end
    elseif d isa AbstractVector
        for (i, v) in enumerate(d)
            sub = _walk_paths(v, vcat(prefix, string(i - 1)))
            for (path, val) in sub
                out[path] = val
            end
        end
    else
        out[join(prefix, ".")] = d
    end
    out
end

all_paths = [_walk_paths(YAML.load_file(joinpath(SCAN_DIR, p, "config.yaml"))) for p in point_dirs]

# A path is the scan axis if its values differ across all points and
# all values are numeric (Number). Reject if values are dicts/strings.
const COMMON_KEYS = intersect(map(keys, all_paths)...)
varying = String[]
for k in COMMON_KEYS
    vals = [get(p, k, nothing) for p in all_paths]
    all(v -> v isa Number, vals) || continue
    length(unique(vals)) >= 2 || continue
    push!(varying, k)
end
sort!(varying)

println("Scan dir:       $SCAN_DIR")
println("Points:         $(length(point_dirs))")
println("Varying axes:   $(length(varying))")
for v in varying
    vals = [get(p, v, nothing) for p in all_paths]
    println("    $v  →  $vals")
end

if length(varying) == 0
    error("no varying axis found — not a scan?")
elseif length(varying) > 1
    println()
    println("Multiple varying axes detected. Pick one for scan.yaml.parameter.key.")
    println("Set SCAN_PARAM env var to override (e.g. SCAN_PARAM=pipeline.3.dynamics.B_hat.phi_omega).")
    chosen = get(ENV, "SCAN_PARAM", nothing)
    chosen === nothing && error("aborting — too ambiguous")
    chosen ∈ varying || error("SCAN_PARAM=$chosen not in detected list")
    PRIMARY = chosen
else
    PRIMARY = first(varying)
end

const VALUES = [get(p, PRIMARY, nothing) for p in all_paths]
const NAME = basename(SCAN_DIR)

# Pick a template — first point's config; the override path will replay
# its own value. Future scan_expand calls on this file will reproduce
# the scan layout.
const TEMPLATE_REL = joinpath(point_dirs[1], "config.yaml")

# Pattern: try to extract a numeric stem from existing dir names so
# scan_expand reproduces the same names. e.g. "eu151_phi4_524_500ms"
# → "eu151_phi${value}_500ms" if we can pin the value.
function _infer_pattern(dir_names::Vector{String}, vals)
    n = length(dir_names)
    if n != length(vals)
        return "$(NAME)_p\${idx}"
    end
    # naive: replace each value's float-with-underscore in the
    # corresponding dir name with ${value}; if all replacements yield
    # the same template, use it.
    candidates = String[]
    for (d, v) in zip(dir_names, vals)
        v_str = replace(string(v), "." => "_")
        idx = findfirst(v_str, d)
        idx === nothing && continue
        push!(candidates, replace(d, v_str => "\${value}"))
    end
    if length(candidates) == n && length(unique(candidates)) == 1
        return candidates[1]
    end
    return "$(NAME)_p\${idx}"
end

const POINT_PATTERN = _infer_pattern(point_dirs, VALUES)

scan_yaml = Dict{String, Any}(
    "name" => NAME,
    "description" => "Retrofit by scan_retrofit.jl on $(string(Dates.today()))",
    "parameter" => Dict{String, Any}(
        "key" => last(split(PRIMARY, '.')),
        "values" => VALUES,
        "yaml_path" => PRIMARY,
    ),
    "template" => TEMPLATE_REL,
    "override_path" => PRIMARY,
    "point_dir_pattern" => POINT_PATTERN,
    "extra_overrides" => Dict{String, Any}(),
)

out_path = joinpath(SCAN_DIR, "scan.yaml")
open(out_path, "w") do io
    YAML.write(io, scan_yaml)
end
println()
println("→ wrote $out_path")
println("  primary axis: $PRIMARY")
println("  point pattern: $POINT_PATTERN")
println("  values: $VALUES")
