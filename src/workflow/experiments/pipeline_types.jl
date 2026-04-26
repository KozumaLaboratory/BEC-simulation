# --- Pipeline step types ---

struct GroundStateStep
    params::Dict{String, Any}    # raw YAML dict for this step
end

struct DynamicsStep
    params::Dict{String, Any}
end

struct AnalyzeStep
    analyzers::Vector{Pair{Symbol, Dict{String, Any}}}
end

const PipelineStep = Union{GroundStateStep, DynamicsStep, AnalyzeStep}

struct PipelineConfig
    steps::Vector{PipelineStep}
    scan::Union{Nothing, AbstractScanSpec}
    raw_data::Dict                   # full YAML dict for override re-parse
end
