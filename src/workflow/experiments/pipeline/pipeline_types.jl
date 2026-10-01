# --- Pipeline step types ---

export PipelineConfig, GroundStateStep, DynamicsStep, AnalyzeStep,
    BinaryGroundStateStep, BinaryDynamicsStep, RotatingBasisGroundStateStep,
    RotatingBasisDynamicsStep, ScalarEGPEGroundStateStep, ScalarEGPEDynamicsStep

struct GroundStateStep
    params::Dict{String, Any}    # parameters consumed by the physics resolver
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
    raw_data::Dict                   # serializable specification for sweeps/provenance
end

for name in (:GroundStateStep, :DynamicsStep, :BinaryGroundStateStep, :BinaryDynamicsStep,
    :RotatingBasisGroundStateStep, :RotatingBasisDynamicsStep,
    :ScalarEGPEGroundStateStep, :ScalarEGPEDynamicsStep)
    @eval $name(; kwargs...) = $name(_native_config_data((; kwargs...)))
end

AnalyzeStep(names::Symbol...) = AnalyzeStep(
    Pair{Symbol, Dict{String, Any}}[name => Dict{String, Any}() for name in names])

function _step_config_data(step::PipelineStep)
    step isa AnalyzeStep && return Dict(
        "analyze" =>
            [Dict(string(name) => params) for (name, params) in step.analyzers],
    )
    kind, key = if step isa GroundStateStep || step isa DynamicsStep
        nothing, step isa GroundStateStep ? "ground_state" : "dynamics"
    elseif step isa BinaryGroundStateStep || step isa BinaryDynamicsStep
        "binary", step isa BinaryGroundStateStep ? "ground_state" : "dynamics"
    elseif step isa RotatingBasisGroundStateStep || step isa RotatingBasisDynamicsStep
        "rotating_basis", step isa RotatingBasisGroundStateStep ? "ground_state" : "dynamics"
    else
        "scalar_egpe", step isa ScalarEGPEGroundStateStep ? "ground_state" : "dynamics"
    end
    params = deepcopy(step.params)
    kind === nothing || (params["kind"] = kind)
    Dict(key => params)
end

"""
    PipelineConfig(steps; scan=nothing, dealias=nothing)

Define an experiment in Julia using typed steps and nested NamedTuple parameters.
Use Julia functions and loops to share definitions and construct sweeps.
"""
function PipelineConfig(steps::AbstractVector; scan=nothing, dealias=nothing)
    all(s -> s isa PipelineStep, steps) || throw(ArgumentError(
        "PipelineConfig requires typed pipeline steps"))
    data = Dict{String, Any}("pipeline" => [_step_config_data(s) for s in steps])
    scan === nothing || (data["scan"] = _native_config_data(scan))
    dealias === nothing || (data["dealias"] = _native_config_data(dealias))
    # Resolution happens at execution time, inside the run's source-directory
    # and numerical-setting scope. Construction does not mutate global settings.
    parse_pipeline(data)
end
