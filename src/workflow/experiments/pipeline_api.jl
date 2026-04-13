# --- Public pipeline API ---

"""Load a YAML file and return a PipelineConfig."""
function load_config(path::String)
    data = YAML.load_file(path)
    parse_pipeline(data)
end

"""Load a YAML string and return a PipelineConfig."""
function load_config_from_string(yaml_str::String)
    data = YAML.load(yaml_str)
    parse_pipeline(data)
end

"""Run a pipeline config (alias for run_pipeline)."""
run_config(config::PipelineConfig; verbose::Bool = true) = run_pipeline(config; verbose)
