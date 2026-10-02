# --- Public pipeline API ---

export load_config, load_config_from_string

"""Load a Julia experiment definition or generated result snapshot as a PipelineConfig.

Sets `ENV["SPINORBEC_CONFIG_DIR"]` to the source directory while parsing so
that relative paths inside the config (e.g. `csv: beams.csv`) resolve
against the definition's location rather than the caller's pwd.

Schema validation runs in strict mode by default — unknown keys raise
`ArgumentError` instead of `@warn` (silent-drop guard; see the 2026-04-27
`trap:` incident). Pass `strict=false` for exploratory REPL work where
you want a permissive parse.
"""
function load_config(path::String; strict::Bool=true)
    data = _load_config_data(path)
    prev = get(ENV, "SPINORBEC_CONFIG_DIR", nothing)
    ENV["SPINORBEC_CONFIG_DIR"] = _config_source_dir(path)
    try
        _normalize_and_validate!(data; strict)
        parse_pipeline(data)
    finally
        if prev === nothing
            delete!(ENV, "SPINORBEC_CONFIG_DIR")
        else
            (ENV["SPINORBEC_CONFIG_DIR"] = prev)
        end
    end
end

"""Evaluate a Julia definition string and return a PipelineConfig.

Schema validation runs in strict mode by default; see `load_config`."""
function load_config_from_string(yaml_str::String; strict::Bool=true)
    data = _julia_config_string(yaml_str)
    _normalize_and_validate!(data; strict)
    parse_pipeline(data)
end

function _normalize_and_validate!(data::Dict; strict::Bool,
    verbose::Bool=false, dry_run::Bool=false)
    # Calibration precedes composition and unit conversion on every entry path.
    if haskey(data, "calibration") && data["calibration"] isa Dict
        _experiment_status(verbose, "applying calibration block"; comment=dry_run)
        calib = _calibration_from_dict(pop!(data, "calibration"))
        verbose && println("  applying calibration epoch=$(calib.epoch) date=$(calib.date)")
        apply_calibration!(data, calib)
    elseif haskey(data, "calibration_history")
        _experiment_status(verbose, "applying calibration history"; comment=dry_run)
        hist_raw = pop!(data, "calibration_history")
        target = if haskey(data, "target_date")
            Dates.Date(String(pop!(data, "target_date")))
        else
            Dates.today()
        end
        hist = load_calibration_history(Dict("calibration_history" => hist_raw))
        calib = interpolate_calibration(hist, target)
        verbose && println("  applying interpolated calibration → $(calib.epoch)")
        apply_calibration!(data, calib)
    end

    _experiment_status(verbose, "expanding mixins"; comment=dry_run)
    apply_mixins!(data)
    _experiment_status(verbose, "injecting schema defaults"; comment=dry_run)
    apply_schema_defaults!(data)
    _experiment_status(verbose, "applying units block"; comment=dry_run)
    apply_units_block!(data)
    _experiment_status(verbose, "applying accuracy and auto-grid defaults"; comment=dry_run)
    apply_auto_defaults!(data)
    _experiment_status(verbose, "normalizing B blocks"; comment=dry_run)
    apply_B_block_normalize!(data)
    _experiment_status(verbose, "normalizing noise blocks"; comment=dry_run)
    apply_noise_block_normalize!(data)
    _experiment_status(verbose, "validating schema"; comment=dry_run)
    validate_pipeline!(data; strict)
    return data
end
