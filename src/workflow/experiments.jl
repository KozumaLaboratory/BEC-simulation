# --- Experiments subsystem umbrella ---
#
# YAML-driven pipeline runner + scenario configuration + parameter
# optimisation. The include order below is load-bearing — schema/,
# runtime/, and pipeline/ files are interleaved because their
# include-time references depend on which structs and helpers are
# defined first. (Once the dust settles on the YAML schema we may be
# able to reorder per-subdir; for now keep the proven order.)

include("experiments/runtime/adaptive_advice.jl")

# Schema parsers + auto-defaults (run before pipeline parses).
include("experiments/schema/config_override.jl")
include("experiments/schema/schema.jl")
include("experiments/schema/units_block.jl")
include("experiments/schema/templates_block.jl")
include("experiments/schema/auto_defaults.jl")
include("experiments/schema/B_block.jl")
include("experiments/schema/noise_block.jl")
include("experiments/schema/schema_defaults.jl")
include("experiments/schema/helpers_types.jl")

include("experiments/runtime/runtime_misc.jl")
include("experiments/runtime/runtime_io.jl")
include("experiments/runtime/dealias_block.jl")

# Schema parsers that depend on helpers_types + runtime_misc.
include("experiments/schema/parsing_units.jl")
include("experiments/schema/parsing_blocks.jl")
include("experiments/schema/builders_potential.jl")
include("experiments/schema/builders_phase.jl")

include("experiments/runtime/b_block_builders.jl")

# Pipeline types + analyzers (analyzers needed by run_step dispatchers).
include("experiments/pipeline/pipeline_types.jl")
include("experiments/analyzers.jl")
include("experiments/pipeline/pipeline_analyzers.jl")
include("experiments/pipeline/pipeline_dispatch.jl")
include("experiments/pipeline/pipeline_callbacks.jl")
include("experiments/pipeline/runner.jl")
include("experiments/pipeline/run_step_ground_state.jl")
include("experiments/pipeline/run_step_dynamics.jl")
include("experiments/pipeline/run_step_binary.jl")
include("experiments/pipeline/run_step_rotating.jl")

# Late-stage runtime helpers (depend on pipeline types).
include("experiments/runtime/pulse_sequence.jl")
include("experiments/runtime/sta_counter_diabatic.jl")
include("experiments/runtime/feshbach_ramp.jl")
