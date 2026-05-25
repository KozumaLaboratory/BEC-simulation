# --- Public pipeline API ---

export load_config, load_config_from_string, run_config

"""Load a YAML file and return a PipelineConfig.

Sets `ENV["SPINORBEC_YAML_DIR"]` to the YAML's directory while parsing so
that relative paths inside the config (e.g. `csv: beams.csv`) resolve
against the YAML's location rather than the caller's pwd.

Schema validation runs in strict mode by default — unknown keys raise
`ArgumentError` instead of `@warn` (silent-drop guard; see the 2026-04-27
`trap:` incident). Pass `strict=false` for exploratory REPL work where
you want a permissive parse.
"""
function load_config(path::String; strict::Bool=true)
    data = YAML.load_file(path)
    _normalize_and_validate!(data; strict)
    prev = get(ENV, "SPINORBEC_YAML_DIR", nothing)
    ENV["SPINORBEC_YAML_DIR"] = dirname(abspath(path))
    try
        parse_pipeline(data)
    finally
        prev === nothing ? delete!(ENV, "SPINORBEC_YAML_DIR") :
        (ENV["SPINORBEC_YAML_DIR"] = prev)
    end
end

"""Load a YAML string and return a PipelineConfig.

Schema validation runs in strict mode by default; see `load_config`."""
function load_config_from_string(yaml_str::String; strict::Bool=true)
    data = YAML.load(yaml_str)
    _normalize_and_validate!(data; strict)
    parse_pipeline(data)
end

function _normalize_and_validate!(data::Dict; strict::Bool)
    apply_templates_and_mixins!(data)
    apply_schema_defaults!(data)
    apply_units_block!(data)
    apply_auto_defaults!(data)
    apply_B_block_normalize!(data)
    apply_noise_block_normalize!(data)
    validate_pipeline!(data; strict)
    return data
end

"""Run a pipeline config (alias for run_pipeline)."""
run_config(config::PipelineConfig; verbose::Bool=true) = run_pipeline(config; verbose)
