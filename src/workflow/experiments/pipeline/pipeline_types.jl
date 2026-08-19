# --- Pipeline step types ---

export PipelineConfig

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

# Option γ rotating-basis spinor GP steps. Same isolation pattern as binary GP:
# concrete types so the spinor `_run_step(::GroundStateStep)` / `(::DynamicsStep)`
# inference world is not widened by these handlers's returns. (They run on
# the standard split-step path now; the RotatingBasisWS engine was retired.)
struct RotatingBasisGroundStateStep
    params::Dict{String, Any}
end

struct RotatingBasisDynamicsStep
    params::Dict{String, Any}
end

# Scalar eGPE under adiabatic spin elimination (Larmor-fast limit). Same
# isolation pattern again: the state is a one-component array, not a spinor, so
# letting these returns into the spinor `_run_step` inference world would widen
# it for no benefit. `docs/validation/klaus2022_primary_source.md` §4 states
# when this path is the correct model rather than a cheaper one.
struct ScalarEGPEGroundStateStep
    params::Dict{String, Any}
end

struct ScalarEGPEDynamicsStep
    params::Dict{String, Any}
end

const PipelineStep = Union{
    GroundStateStep, DynamicsStep, AnalyzeStep,
    BinaryGroundStateStep, BinaryDynamicsStep,
    RotatingBasisGroundStateStep, RotatingBasisDynamicsStep,
    ScalarEGPEGroundStateStep, ScalarEGPEDynamicsStep,
}

struct PipelineConfig
    steps::Vector{PipelineStep}
    scan::Union{Nothing, AbstractScanSpec}
    raw_data::Dict                   # full YAML dict for override re-parse
end
