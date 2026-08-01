# --- Layer 1: the resolved physics as a value ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.2, §2.10, §2.11.
#
# Step 1a is PURELY ADDITIVE: nothing outside `src/model/` references `Model`,
# so this increment cannot change the behaviour of any existing run. The
# rewiring — `yaml_to_model`, `make_workspace(::Model)`, and the retirement of
# the fifteen YAML normalisation passes — is Step 1b.
#
# Loaded after `hamiltonian.jl` because `GaussianBeam`
# (`hamiltonian/terms/trap/optical_trap.jl`) is the one physics type outside
# `foundation/` that a spec embeds. It depends on nothing under `src/workflow/`,
# which is deliberate: the model layer is what `src/workflow/experiments/` will
# eventually be built on top of, not the other way round.

include("model/model_waveform.jl")    # ModelWaveform + ModelValue
include("model/specs.jl")             # grid / interactions / ddi / lhy
include("model/field_specs.jl")       # zeeman / raman / light_shift / magnetic_gradient
include("model/environment_specs.jl") # frame / geometry / reservoir
include("model/potential_spec.jl")    # PotentialSpec + its 8 trap terms
include("model/model.jl")             # Model + with + structural ==/hash
include("model/active.jl")            # every `active` method, in ONE file
include("model/io.jl")                # TOML round-trip
include("model/stage.jl")             # Stage: one computation over one Model
include("model/identity.jl")          # code_tree_hash + artifact_id
include("model/complete.jl")          # the completion marker + the one admission decision
