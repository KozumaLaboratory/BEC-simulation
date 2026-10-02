# Run specifications are data snapshots, independent of the authoring language.
using JSON

const _CONFIG_SNAPSHOT_FORMAT = "SpinorBEC.experiment.v1"

_config_snapshot_path(dir::AbstractString) = joinpath(dir, "config.json")

function _config_definition(value)
    data = value isa PipelineConfig ? value.raw_data : value
    data isa AbstractDict || throw(
        ArgumentError(
            "Julia experiment definitions must return a PipelineConfig or a dictionary"),
    )
    _native_config_data(data)
end

function _config_module()
    context = Module(gensym(:ExperimentDefinition))
    Core.eval(context, :(include(path) = Base.include(@__MODULE__, path)))
    Core.eval(context, :(using SpinorBEC))
    context
end

function _load_julia_config(path::AbstractString)
    lowercase(splitext(path)[2]) == ".jl" || throw(ArgumentError(
        "experiment definitions must be Julia (.jl): $path"))
    _config_definition(Base.include(_config_module(), abspath(path)))
end

function _julia_config_string(source::AbstractString)
    _config_definition(Base.include_string(_config_module(), source, "experiment.jl"))
end

function _load_config_data(path::AbstractString)
    extension = lowercase(splitext(path)[2])
    extension == ".jl" && return _load_julia_config(path)
    extension == ".json" || throw(
        ArgumentError(
            "expected a Julia experiment (.jl) or a generated result snapshot (.json): $path"),
    )
    payload = JSON.parsefile(path; use_mmap=false)
    get(payload, "format", nothing) == _CONFIG_SNAPSHOT_FORMAT ||
        throw(ArgumentError("unsupported experiment snapshot format: $path"))
    _native_config_data(payload["spec"])
end

function _config_source_dir(path::AbstractString)
    if lowercase(splitext(path)[2]) == ".json"
        payload = JSON.parsefile(path; use_mmap=false)
        source = String(get(payload, "source_dir", dirname(abspath(path))))
        return isdir(source) ? source : dirname(abspath(path))
    end
    dirname(abspath(path))
end

function _write_config_snapshot(path::AbstractString, spec::AbstractDict;
    source_dir::AbstractString=pwd(), resolved=nothing)
    payload = Dict{String, Any}("format" => _CONFIG_SNAPSHOT_FORMAT,
        "source_dir" => abspath(source_dir), "spec" => _native_config_data(spec))
    resolved === nothing || (payload["resolved"] = _native_config_data(resolved))
    if isfile(path) && isequal(JSON.parsefile(path; use_mmap=false), payload)
        return String(path)
    end
    mkpath(dirname(path))
    tmp, io = mktemp(dirname(path))
    try
        JSON.print(io, payload, 2)
        close(io)
        mv(tmp, path; force=true)
    finally
        isopen(io) && close(io)
        isfile(tmp) && rm(tmp)
    end
    String(path)
end

# Julia keyword constructors accept nested NamedTuples; the solver's existing
# parameter resolvers consume ordinary string-keyed dictionaries.
_native_config_data(x::NamedTuple) = Dict{String, Any}(
    string(k) => _native_config_data(v) for (k, v) in pairs(x))
_native_config_data(x::AbstractDict) = Dict{String, Any}(
    string(k) => _native_config_data(v) for (k, v) in pairs(x))
_native_config_data(x::Union{Tuple, AbstractVector}) = [_native_config_data(v) for v in x]
_native_config_data(x::Symbol) = String(x)
_native_config_data(x) = x
