# Generate per-point YAML configs from a single scan.yaml manifest.
#
# scan.yaml schema:
#
#   name:           string
#   description:    string (free text)
#   parameter:
#     key:          string         # human label, e.g. "phi_omega"
#     values:       [number]       # scan points
#     unit:         string         # internal unit
#     display_unit: string         # for figures (optional)
#     display_factor: number       # internal × this = display (optional)
#   template:       relative path to base config.yaml
#   override_path:  dotted YAML path receiving scan value
#                   e.g. "pipeline.3.dynamics.B_hat.phi_omega"
#   extra_overrides:                 # optional, applied to every point
#     <dotted path>: <literal or "\${value}" placeholder>
#   point_dir_pattern: string         # optional, default "<scan>_p<idx>"
#                                     # supports \${value}, \${idx}
#
# Usage:
#   julia --project=. scripts/scan_expand.jl runs/phi_omega_scan/scan.yaml
#
# Result: writes runs/<scan_dir>/<point_name>/config.yaml for each value.

using YAML

length(ARGS) == 1 || error(
    "Usage: julia --project=. scripts/scan_expand.jl <path/to/scan.yaml>",
)
const SCAN_PATH = ARGS[1]
const SCAN_DIR = dirname(SCAN_PATH)
isfile(SCAN_PATH) || error("scan.yaml not found: $SCAN_PATH")

const scan = YAML.load_file(SCAN_PATH)

# Resolve template path relative to scan.yaml location.
const TEMPLATE_PATH = let p = scan["template"]
    isabspath(p) ? p : normpath(joinpath(SCAN_DIR, p))
end
isfile(TEMPLATE_PATH) || error("template not found: $TEMPLATE_PATH")
const template = YAML.load_file(TEMPLATE_PATH)

const PARAM = scan["parameter"]
const VALUES = PARAM["values"]
const OVERRIDE_PATH = scan["override_path"]
const EXTRA_OVERRIDES = get(scan, "extra_overrides", Dict{String, Any}())
const POINT_PATTERN = get(scan, "point_dir_pattern",
    "$(scan["name"])_p\${idx}")

"""Apply a dotted-path override to a YAML dict (dict or list-of-dict).
`pipeline.3.dynamics.B_hat.phi_omega` walks pipeline[3+1] (1-based in
Julia) → ["dynamics"]["B_hat"]["phi_omega"]. Numeric segments are
1-based array indices."""
function _apply_override!(d, path::String, value)
    parts = split(path, '.')
    cur = d
    for (i, part) in enumerate(parts)
        is_last = i == length(parts)
        idx = tryparse(Int, part)
        key = idx === nothing ? part : (idx + 1)  # YAML 0-based → Julia 1-based
        if is_last
            if cur isa AbstractDict
                cur[key] = value
            elseif cur isa AbstractVector
                cur[key] = value
            else
                error("override path $path: cannot index $(typeof(cur)) at '$part'")
            end
        else
            cur = idx === nothing ? cur[key] : cur[key]
        end
    end
end

"""Substitute \${value} / \${idx} placeholders. Numeric values keep their
type; other values are passed through unchanged."""
function _resolve_placeholder(literal, value, idx)
    literal isa String || return literal
    if literal == "\${value}"
        return value
    elseif literal == "\${idx}"
        return idx
    end
    s = literal
    s = replace(s, "\${value}" => string(value))
    s = replace(s, "\${idx}" => string(idx))
    s
end

function _format_point_name(pattern::String, value, idx)
    s = pattern
    s = replace(s, "\${idx}" => string(idx))
    # Stringify value with underscores so e.g. 4.524 → "4_524" works as a dir name.
    val_str = replace(string(value), "." => "_")
    s = replace(s, "\${value}" => val_str)
    s
end

_deepcopy_dict(d) = YAML.load(YAML.write(d))

println("Scan: $(scan["name"])")
println("  template:       $TEMPLATE_PATH")
println("  override_path:  $OVERRIDE_PATH")
println("  values ($(length(VALUES))): $VALUES")

function _expand_all(values, point_pattern, override_path, extra_overrides, scan_dir, template)
    n_written = 0
    for (idx, value) in enumerate(values)
        pt_name = _format_point_name(point_pattern, value, idx)
        pt_dir = joinpath(scan_dir, pt_name)
        isdir(pt_dir) || mkpath(pt_dir)

        cfg = _deepcopy_dict(template)
        _apply_override!(cfg, override_path, value)
        for (extra_path, extra_val) in extra_overrides
            resolved = _resolve_placeholder(extra_val, value, idx)
            _apply_override!(cfg, extra_path, resolved)
        end

        out_file = joinpath(pt_dir, "config.yaml")
        open(out_file, "w") do io
            YAML.write(io, cfg)
        end
        println("  → $pt_name")
        n_written += 1
    end
    return n_written
end

n = _expand_all(VALUES, POINT_PATTERN, OVERRIDE_PATH, EXTRA_OVERRIDES, SCAN_DIR, template)
println("Generated $n per-point configs.")
