# --- Unified `noise:` block: ALL fluctuation/noise sources in one place ---
#
# Six different YAML keys had been used to add fluctuations / noise:
#
#   temperature_ratio    initial thermal mode population (Bose-Einstein)
#   seed_amplitude       coherent low-k perturbation amplitude
#   seed_k_cut           low-pass k cutoff for the above
#   noise_seed           RNG seed
#   twa: {...}           Truncated Wigner ensemble sampling
#   sgpe: {...}          stochastic projected GPE (FDT-driven)
#   photon_scattering    spontaneous emission noise (Gamma_sc)
#
# These all add fluctuations but at different levels — initial 1-shot
# vs continuous, single-trajectory vs ensemble — and competed for the
# same role (e.g. temperature_ratio + twa double-counts thermal).
#
# The unified `noise:` block makes the structure explicit:
#
#   - dynamics:
#       noise:
#         seed: 42                         # RNG (was noise_seed)
#         initial:                          # 1-shot at step start
#           thermal: 0.1                   # T/T_c (was temperature_ratio)
#           coherent: {amplitude: 1e-4, k_cut: 0.6}    # was seed_amp + seed_k_cut
#         twa: {n_samples: 100, ...}       # ensemble (best practice)
#         dissipative:                      # continuous stochastic forcing
#           sgpe: {gamma: 0.05, T: 0.1, ...}
#           photon_scattering: {Gamma_sc: 0.01}
#
# Mutex rules:
#   - `initial.thermal` AND `twa` both set → ArgumentError (twa already
#     samples thermal Wigner; setting initial.thermal on top double-counts)
#
# When TWA is the natural method (recommended for thesis-grade noise
# estimation), use `noise: {twa: {...}}` alone — initial.thermal is
# implicitly handled by the Wigner sampling.

const _NOISE_KEY_MAP = Dict(
    # Top-level noise: → split into internal flat fields
    "seed" => "noise_seed",
    "thermal" => "temperature_ratio",
    "twa" => "twa",
    "sgpe" => "sgpe",
    "photon_scattering" => "photon_scattering",
)

"""
    apply_noise_block_normalize!(data::Dict) -> Dict

Walk every pipeline step and split a unified `noise:` block into the
internal flat fields consumed by pipeline_runner. Mixing `noise:` with
those step-level keys raises ArgumentError.
"""
function apply_noise_block_normalize!(data::Dict)
    haskey(data, "pipeline") || return data
    pipe = data["pipeline"]
    pipe isa AbstractVector || return data
    for step in pipe
        step isa AbstractDict || continue
        for (_, inner) in step
            inner isa AbstractDict || continue
            _split_noise_block!(inner)
        end
    end
    return data
end

const _NOISE_INTERNAL_KEYS = ("temperature_ratio", "seed_amplitude", "seed_k_cut",
    "noise_seed", "twa", "sgpe", "photon_scattering")

function _split_noise_block!(step::AbstractDict)
    haskey(step, "noise") || return nothing
    n = pop!(step, "noise")
    n isa AbstractDict || throw(ArgumentError(
        "noise: must be a mapping, got $(typeof(n))"))

    for k in _NOISE_INTERNAL_KEYS
        haskey(step, k) && throw(
            ArgumentError(
                "step has both `noise:` block and step-level `$k` — pick one form."),
        )
    end

    # Mutex: initial.thermal + twa double-counts thermal fluctuations.
    initial = get(n, "initial", nothing)
    has_twa = haskey(n, "twa")
    if has_twa && initial isa AbstractDict && haskey(initial, "thermal")
        throw(
            ArgumentError(
                "noise: `initial.thermal` and `twa` are mutually exclusive — " *
                "TWA already samples thermal fluctuations via Wigner. " *
                "Pick one: drop initial.thermal OR drop twa."),
        )
    end

    # Top-level keys (seed, twa, sgpe, photon_scattering)
    haskey(n, "seed") && (step["noise_seed"] = pop!(n, "seed"))
    haskey(n, "twa") && (step["twa"] = pop!(n, "twa"))
    haskey(n, "sgpe") && (step["sgpe"] = pop!(n, "sgpe"))
    haskey(n, "photon_scattering") && (step["photon_scattering"] = pop!(n, "photon_scattering"))

    # initial: {thermal, coherent: {amplitude, k_cut}}
    if haskey(n, "initial")
        ini = pop!(n, "initial")
        ini isa AbstractDict || throw(ArgumentError(
            "noise.initial: must be a mapping, got $(typeof(ini))"))
        haskey(ini, "thermal") && (step["temperature_ratio"] = pop!(ini, "thermal"))
        if haskey(ini, "coherent")
            coh = pop!(ini, "coherent")
            coh isa AbstractDict || throw(ArgumentError(
                "noise.initial.coherent: must be a mapping"))
            haskey(coh, "amplitude") && (step["seed_amplitude"] = pop!(coh, "amplitude"))
            haskey(coh, "k_cut") && (step["seed_k_cut"] = pop!(coh, "k_cut"))
            isempty(coh) || throw(ArgumentError(
                "noise.initial.coherent: unknown keys $(collect(keys(coh)))"))
        end
        isempty(ini) || throw(
            ArgumentError(
                "noise.initial: unknown keys $(collect(keys(ini))). " *
                "Recognised: thermal, coherent."),
        )
    end

    # dissipative: alternative grouping for sgpe/photon_scattering
    if haskey(n, "dissipative")
        d = pop!(n, "dissipative")
        d isa AbstractDict || throw(ArgumentError(
            "noise.dissipative: must be a mapping"))
        haskey(d, "sgpe") && (step["sgpe"] = pop!(d, "sgpe"))
        haskey(d, "photon_scattering") && (step["photon_scattering"] = pop!(d, "photon_scattering"))
        isempty(d) || throw(ArgumentError(
            "noise.dissipative: unknown keys $(collect(keys(d)))"))
    end

    isempty(n) || throw(
        ArgumentError(
            "noise: unknown keys $(collect(keys(n))). " *
            "Recognised top-level: seed, initial, twa, dissipative, " *
            "sgpe, photon_scattering."),
    )
    return nothing
end
