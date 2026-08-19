# --- The `:evolve` Stage: what a real-time run declares ---
#
# `STAGE_KINDS` has held `:evolve` since the model layer landed and NOTHING
# produced one. `gs_stage` (`run_step_ground_state.jl:310`) was the only Stage
# producer in `src/`, and two committed tests name the consequence: three
# ambient globals that change REAL-TIME physics reach no artifact id, so two
# dynamics runs using different splittings are the same address.
#
#     MEANFIELD_MIDPOINT_ENABLED   2.2e-6 over 4 RT steps, 2.4e-4 over 200
#     COMBINED_SPIN_STEP_ENABLED   1.7e-9 over 8 RTP steps (unpadded DDI)
#     SPIN_TAYLOR_ENABLED          6.2e-14 over 4 RT steps
#
# (measured in `test/model/test_ambient_refs_vs_artifact_id.jl`, which pinned
# each as `:blind` WITH the reason "no `:evolve` Stage exists".)
#
# WHAT THIS DOES NOT DO, stated first because it is most of the design. It does
# not resolve a dynamics block into a `Model`. `resolve_gs.jl` is 725 lines for
# the ground-state block, the dynamics block resolves INLINE inside a 380-line
# `_run_step`, and extracting it is a refactor of the one path CLAUDE.md
# documents a multi-minute JIT hang on. So the model here is the PRECEDING
# ground state's, unchanged — which is only true when the dynamics block
# declares no model-level override.
#
# Hence the fail-safe, and it is `gs_stage`'s own: a step this cannot state
# faithfully gets NO id, and a stage with no id NEVER HITS. Recomputing is only
# slower; serving an artifact addressed by a key that cannot express the
# question is wrong. Coverage is therefore narrow on purpose — most production
# dynamics blocks set `B:` and are refused — and the refusal is the honest
# statement of what `resolve_dynamics` would have to close.

export evolve_stage, DYN_KEYS_MODEL_LEVEL, DYN_KEYS_STAGE, DYN_KEYS_OFF_PATH

"""
Dynamics keys that would change the `Model`, and which this producer therefore
REFUSES rather than silently drops.

Each names a `Model` field it reaches (14 fields; `fieldnames(Model)`). The
mapping is the whole argument for the refusal: `B` → `zeeman`, `sgpe` →
`reservoir`, `loss` → `loss`, and a stage that ignored any of them would give
two different Hamiltonians one address — the exact defect
`test_gs_admission_axes.jl` exists to prevent on the other path.
"""
const DYN_KEYS_MODEL_LEVEL = (
    "B",                    # → zeeman
    "B_direction",          # → zeeman (rotating-basis axis)
    "absorbing_boundary",   # → geometry
    "couplings",            # → interactions (binary path)
    "ddi",                  # → ddi
    "interactions",         # → interactions
    "lhy",                  # → lhy
    "light_shift",          # → light_shift
    "loss",                 # → loss
    "magnetic_gradient",    # → magnetic_gradient
    "photon_scattering",    # → reservoir
    "potential",            # → potential
    "projected_gp",         # → reservoir
    "pulse_sequence",       # → zeeman / raman, rewritten over time
    "raman",                # → raman
    "rotating_frame_omega", # → frame
    "sgpe",                 # → reservoir
    "twa",                  # → reservoir
)

"""
Keys that reach the `Stage` — its `backend` field or its `params`.

`save` is here and not refused because it names WHAT IS WRITTEN, not what is
computed: no save cadence changes ψ. Same call `cache` gets on the ground-state
side. The seed knobs ARE here rather than in the model, for the same reason
`initial_state` is a Stage concern there: they choose where the trajectory
starts, not what the Hamiltonian is.
"""
const DYN_KEYS_STAGE = (
    "backend", "dt", "duration", "epsilon", "hard_polarize", "integrator",
    "noise_seed", "save", "seed_amplitude", "seed_k_cut", "seed_mode",
    "spin_step", "temperature_ratio", "wigner_seed",
)

"""
Keys that reach neither, with the reason.

`kind` selects WHICH runner (binary / rotating_basis / scalar_egpe have their
own `_run_step` methods), so this one only ever sees the spinor path.
`live_monitor` is observability. `adaptive_dt` never arrives at all —
`_reject_inert_dynamics_keys` throws on it at step construction.
"""
const DYN_KEYS_OFF_PATH = ("adaptive_dt", "kind", "live_monitor")

# The real-time switches this Stage exists to carry. Reading them at stage
# construction is what puts them in the id; they are `Ref`s rather than fields
# because nothing declared them, which is the hole being closed.
_dyn_ambient_params() = (
    meanfield_midpoint=MEANFIELD_MIDPOINT_ENABLED[],
    combined_spin_step=COMBINED_SPIN_STEP_ENABLED[],
    spin_chain_fusion=SPIN_CHAIN_FUSION_ENABLED[],
    spin_taylor=SPIN_TAYLOR_ENABLED[],
    dealias_two_thirds=DEALIAS_2_3_ENABLED[],
)

# AN ABSENT KEY IS OMITTED, not given a sentinel. Both obvious sentinels are
# refused by the identity layer, and both refusals are right:
#
#   NaN  — `content_id`: "non-finite Float in spec (NaN); refuse to hash". An
#          address must not depend on a value that is not equal to itself.
#   nothing — `_enc`: "a value with no fields would serialise as an empty table,
#          which is indistinguishable from an empty struct".
#
# `""` and `-1` would encode, and that is worse: they make "unset" collide with
# a settable value, silently. Leaving the field out says exactly what is true —
# the declaration does not mention what was not declared — and it still
# separates the two cases, because a NamedTuple with the field and one without
# encode differently.
#
# The order is fixed by this tuple, not by `Dict` iteration, so the same config
# always produces the same params in the same order.
const _DYN_OPTIONAL = (
    ("integrator", :integrator, string),
    ("spin_step", :spin_step, string),
    ("epsilon", :epsilon, Float64),
    ("seed_amplitude", :seed_amplitude, Float64),
    ("seed_k_cut", :seed_k_cut, Float64),
    ("seed_mode", :seed_mode, string),
    ("noise_seed", :noise_seed, Float64),
    ("temperature_ratio", :temperature_ratio, Float64),
    ("hard_polarize", :hard_polarize, Float64),
    ("wigner_seed", :wigner_seed, string),
)

@noinline function _dyn_stage_params(p::Dict{String, Any})
    out = merge((duration=Float64(p["duration"]), dt=Float64(p["dt"])),
        _dyn_ambient_params())
    for (key, sym, conv) in _DYN_OPTIONAL
        haskey(p, key) || continue
        out = merge(out, NamedTuple{(sym,)}((conv(p[key]),)))
    end
    out
end

"""
    evolve_stage(from::Stage, p::Dict{String,Any}) -> Union{Nothing, Stage}

The `:evolve` Stage for a dynamics block that runs on `from`'s physics, or
`nothing` when the block declares any `DYN_KEYS_MODEL_LEVEL` key.

`from` is the preceding ground state, so `artifact_id` recurses into it and the
dynamics id carries the whole chain — which is why the model can be inherited
rather than re-resolved, and why inheriting it is only legitimate under the
refusal above.

`method` is the integrator the run will use, defaulted the way the runner
defaults it, because `Stage`'s constructor refuses an empty method symbol.
"""
function evolve_stage(from::Stage, p::Dict{String, Any})
    any(k -> haskey(p, k), DYN_KEYS_MODEL_LEVEL) && return nothing
    (haskey(p, "duration") && haskey(p, "dt")) || return nothing
    method = Symbol(get(p, "integrator", "strang"))
    method === Symbol("") && return nothing
    Stage(:evolve, from.model, method, from, _dyn_stage_params(p), from.backend)
end

"""
    dyn_artifact_id(from, p) -> Union{Nothing, String}

`artifact_id` of the `:evolve` Stage, or `nothing` — same contract and same
fail-safe as `_gs_artifact_id`: no id means never a hit, never a wrong one.
"""
@noinline function dyn_artifact_id(
    from::Union{Nothing, Stage}, p::Dict{String, Any}
)::Union{Nothing, String}
    from === nothing && return nothing
    s = evolve_stage(from, p)
    s === nothing && return nothing
    try
        artifact_id(s)
    catch err
        _warn_no_artifact_id_once(err isa ArgumentError ? err.msg : sprint(showerror, err))
        nothing
    end
end
