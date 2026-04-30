# --- Public pipeline API ---

"""Load a YAML file and return a PipelineConfig.

Sets `ENV["SPINORBEC_YAML_DIR"]` to the YAML's directory while parsing so
that relative paths inside the config (e.g. `csv: beams.csv`) resolve
against the YAML's location rather than the caller's pwd.
"""
function load_config(path::String)
    data = YAML.load_file(path)
    apply_templates_and_mixins!(data)
    apply_units_block!(data)
    apply_auto_defaults!(data)
    apply_B_block_normalize!(data)
    apply_noise_block_normalize!(data)
    prev = get(ENV, "SPINORBEC_YAML_DIR", nothing)
    ENV["SPINORBEC_YAML_DIR"] = dirname(abspath(path))
    try
        parse_pipeline(data)
    finally
        prev === nothing ? delete!(ENV, "SPINORBEC_YAML_DIR") :
        (ENV["SPINORBEC_YAML_DIR"] = prev)
    end
end

"""Load a YAML string and return a PipelineConfig."""
function load_config_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    apply_templates_and_mixins!(data)
    apply_units_block!(data)
    apply_auto_defaults!(data)
    apply_B_block_normalize!(data)
    apply_noise_block_normalize!(data)
    parse_pipeline(data)
end

"""Run a pipeline config (alias for run_pipeline)."""
run_config(config::PipelineConfig; verbose::Bool=true) = run_pipeline(config; verbose)
