# --- Layer 1: the resolved physics as a value ---
#
# `docs/design/research_spec_and_provenance_architecture.md` §2.2, §2.10, §2.11.
#
# Step 1a was PURELY ADDITIVE: nothing outside `src/model/` referenced `Model`,
# so that increment could not change the behaviour of any existing run.
#
# Step 1b added the first consumer: `yaml_to_model`
# (`workflow/experiments/pipeline/resolve_gs.jl`), which resolves a
# `ground_state:` block to a `Model`. It shares ONE resolver with
# `_run_step(::GroundStateStep, …)` rather than re-reading the YAML — a second
# reader of `potential:` / `B:` / `lhy:` / `ddi:` is a parallel declaration of
# the same physics, which is what this layer exists to delete.
#
# What that consumer reaches is measured, not assumed: `test_corpus_resolves.jl`
# resolves all 429 configs under `runs/` (351 succeed) and lists every one that
# does not, by name and reason, so step 3's scope can only change deliberately.
#
# Still to come: `make_workspace(::Model)` and the retirement of the fifteen
# YAML normalisation passes.
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
include("model/ref.jl")               # ref: the published number, re-measured
include("model/claim.jl")             # Claim: the A/B/C taxonomy, enforced
include("model/complete.jl")          # the completion marker + the one admission decision
# Separate from complete.jl on purpose: admission is a question about bytes on a
# filesystem, this is a question about physics at a state. Merging them would
# put a gradient evaluation behind `admit_payload`.
include("model/verdict_truth.jl")     # is the recorded verdict true of the payload?
