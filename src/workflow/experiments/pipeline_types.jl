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

# Two-component (binary) GP steps. These live as concrete types so the
# spinor `_run_step(::GroundStateStep)` / `_run_step(::DynamicsStep)`
# methods don't have to widen their return-type inference to cover the
# BinaryState path — a known pitfall (CLAUDE.md "Type stability
# boundaries") that previously caused multi-minute JIT hangs through
# run_pipeline's abstract dispatch over the PipelineStep union.
struct BinaryGroundStateStep
    params::Dict{String, Any}
end

struct BinaryDynamicsStep
    params::Dict{String, Any}
end

const PipelineStep = Union{
    GroundStateStep, DynamicsStep, AnalyzeStep,
    BinaryGroundStateStep, BinaryDynamicsStep,
}

struct PipelineConfig
    steps::Vector{PipelineStep}
    scan::Union{Nothing, AbstractScanSpec}
    raw_data::Dict                   # full YAML dict for override re-parse
end
