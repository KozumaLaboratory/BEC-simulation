# --- /api/effective_config/<run> ---
#
# Returns the `inspect_config` JSON for a run's config.yaml. The frontend
# uses this to render the "what does this YAML actually solve" panel:
# raw vs normalised diff, per-step resolved B(t)/Ω(t)/q(t) traces,
# typed warnings for silent semantic mismatches.

using ..SpinorBEC: inspect_config, to_dict

"""
Convert the `inspect_config(...) |> to_dict` output into a JSON-friendly
graph (strings/numbers/bools/dicts/arrays/nothing only). YAML.load can
yield `Symbol` keys, `Date`/`DateTime` values, `Vector{Any}` etc., none
of which the dashboard's hand-rolled `_write_json` knows how to encode.
"""
_jsonify(x::AbstractString) = String(x)
_jsonify(x::Symbol) = string(x)
_jsonify(x::Real) = x
_jsonify(x::Bool) = x
_jsonify(::Nothing) = nothing
_jsonify(x::AbstractVector) = Any[_jsonify(v) for v in x]
function _jsonify(x::AbstractDict)
    out = Dict{String, Any}()
    for (k, v) in x
        out[string(k)] = _jsonify(v)
    end
    out
end
_jsonify(x) = string(x)   # final fallback (Date, custom types, …)

function _route_effective_config(path::String, base_dir::String)
    p = _parse_run_only(path, "/api/effective_config/")
    run_dir = joinpath(base_dir, p.name)
    isdir(run_dir) || return (404, "text/plain", "Run not found: $(p.name)")
    config_path = joinpath(run_dir, "config.yaml")
    isfile(config_path) ||
        return (404, "text/plain", "config.yaml not found for: $(p.name)")
    body = try
        ins = inspect_config(config_path)
        _json_string(_jsonify(to_dict(ins)))
    catch e
        bt = sprint(showerror, e)
        return (500, "text/plain", "inspect_config failed: $bt")
    end
    (200, "application/json", body)
end
