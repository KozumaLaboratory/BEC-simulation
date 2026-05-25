# --- Unified `B:` block: B vector specified once per step ---
#
# Mathematical: B is a 3-vector field. Two natural parametrizations:
#
#   Cartesian:   (Bx, By, Bz)
#   Spherical:   |B| · (sin θ cos φ, sin θ sin φ, cos θ)
#
# These are mutually exclusive — picking one fully determines the vector.
# A YAML `B:` block must follow ONE form.
#
# Form A — Cartesian (most explicit, time-varying components OK):
#
#   B: {Bx: 0, By: 0, Bz: "0.819 Gauss"}
#   B: {Bx: {sinusoidal: {amplitude: "10 mG", frequency: "100 Hz"}},
#       By: 0, Bz: "1 Gauss"}
#
# Form B — Spherical (natural for rotating B̂):
#
#   B: {B_mag: "0.819 Gauss", theta: 0.611, phi: 0.0}
#   B: {B_mag: "0.819 Gauss",
#       theta: {from: 0, to: 0.611, duration: "20 ms"},
#       phi:   {rate: 4.524}}
#
# Form C — Direction only (magnitude inherited from prior step):
#
#   B: {theta: 0.611, phi: {rate: 4.524}}
#
# Form D — Static z-aligned shorthand (Form A simplified):
#
#   B: {Bz: "0.819 Gauss"}    # Bx = By = 0 implicit; direction = +ẑ
#
# `q` (quadratic Zeeman, auto-derived from |B|² if user omits) belongs in
# B too — it's a Zeeman-effect parameter tied to |B|.
#
# (The `magnitude:` alias of `B_mag:` was removed 2026-05-24; canonical-only.)
#
# === Internal mapping ===
#
# This module rewrites the user-facing unified `B:` block into the
# internal magnitude/direction dicts that pipeline_runner consumes:
#
#   {Bx, By, Bz} (+ q, p_mv, ...)    → magnitude dict, Cartesian keys
#   {B_mag, theta, phi} static       → magnitude dict, {B_mag, theta_deg, phi_deg}
#   {theta, phi} time-dependent      → direction dict, {theta, phi}

const _CARTESIAN_KEYS = ("Bx", "By", "Bz")
const _DIRECTION_KEYS = ("theta", "phi")
const _MAGNITUDE_KEYS = ("B_mag", "p", "p_mv")

"""
    apply_B_block_normalize!(data::Dict) -> Dict

Walk every pipeline step and split a unified `B:` block into the
internal magnitude dict (with q) and direction dict (theta/phi trajectory)
that pipeline_runner consumes.

Validates form mutual exclusion: `Bx/By/Bz` cannot mix with `theta/phi`.
"""
function apply_B_block_normalize!(data::Dict)
    haskey(data, "pipeline") || return data
    pipe = data["pipeline"]
    pipe isa AbstractVector || return data
    for step in pipe
        step isa AbstractDict || continue
        for (_, inner) in step
            inner isa AbstractDict || continue
            _reject_unknown_step_keys!(inner)
            _split_B_block!(inner)
        end
    end
    return data
end

"""Validate that the magnetic-field config uses the unified `B:` block
(magnitude + direction in one mapping). Internal post-normalize keys
with the same names still exist and are consumed by pipeline_runner —
the validator runs after normalize so those don't trigger this check."""
function _reject_unknown_step_keys!(step::AbstractDict)
    for key in ("zeeman", "B_hat")
        if haskey(step, key)
            throw(
                ArgumentError(
                    "step has step-level `$key:` key — not a valid " *
                    "user-facing field. Magnetic field belongs in the " *
                    "unified `B:` block: magnitude (Bz/B_mag/p) + " *
                    "direction (theta/phi) + q (auto from |B|² unless " *
                    "explicit) all live there."),
            )
        end
    end
end

function _split_B_block!(step::AbstractDict)
    haskey(step, "B") || return nothing
    B = pop!(step, "B")
    B isa AbstractDict || throw(ArgumentError(
        "B: must be a mapping, got $(typeof(B))"))

    (haskey(step, "zeeman") || haskey(step, "B_hat")) && throw(
        ArgumentError(
            "step has both `B:` and step-level `zeeman:`/`B_hat:` keys. " *
            "Use only the unified `B:` form."),
    )

    has_cartesian = any(haskey(B, k) for k in _CARTESIAN_KEYS)
    has_magnitude_explicit = any(haskey(B, k) for k in _MAGNITUDE_KEYS)
    # Drop redundant `theta: 0` / `phi: 0` (default-aligned with z-axis)
    # when Cartesian is given — these are common in ground_state and add
    # no information.
    if has_cartesian
        for k in _DIRECTION_KEYS
            if haskey(B, k) && B[k] isa Real && B[k] == 0
                delete!(B, k)
            end
        end
    end
    has_direction = any(haskey(B, k) for k in _DIRECTION_KEYS)

    has_cartesian && has_direction &&
        throw(
            ArgumentError(
                "B: Cartesian form (Bx/By/Bz) and non-zero spherical direction " *
                "(theta/phi) are mutually exclusive. Cartesian implies direction " *
                "via components; for tilted/rotating B use spherical " *
                "magnitude + theta + phi instead."),
        )

    has_magnitude_explicit && has_cartesian &&
        throw(
            ArgumentError(
                "B: explicit `magnitude:` and Cartesian (Bx/By/Bz) are " *
                "mutually exclusive — Cartesian determines magnitude from |B|."),
        )

    zeeman = Dict{Any, Any}()
    B_hat = Dict{Any, Any}()
    for (k, v) in B
        kk = String(k)
        if kk in ("Bx", "By", "Bz")
            zeeman[k] = v                              # Gauss Cartesian
        elseif kk == "magnitude"
            throw(ArgumentError(
                "B.magnitude: alias removed 2026-05-24 — use canonical `B_mag`."))
        elseif kk == "B_mag"
            zeeman["B_mag"] = v                        # Gauss spherical
        elseif kk == "p" || kk == "bx" || kk == "by"
            zeeman[k] = v                              # dimensionless Cartesian
        elseif kk == "q"
            zeeman[k] = v                              # quadratic Zeeman
        elseif kk == "p_mv" || kk == "coil_mode"
            zeeman[k] = v                              # calibration lab-units
        elseif kk == "n_samples" || kk == "omega_ref_hz"
            zeeman[k] = v                              # sample-grid / ω_ref override
        elseif kk == "sources"
            zeeman[k] = v                              # multi-source list
        elseif kk in _DIRECTION_KEYS
            B_hat[k] = v                               # theta / phi → B_direction
        else
            throw(
                ArgumentError(
                    "B.$kk: unrecognised key. Cartesian: $(_CARTESIAN_KEYS); " *
                    "Spherical magnitude: $(_MAGNITUDE_KEYS); " *
                    "Direction: $(_DIRECTION_KEYS); plus q, sources, " *
                    "p_mv/coil_mode (calibration), n_samples, omega_ref_hz."),
            )
        end
    end
    isempty(zeeman) || (step["B"] = zeeman)
    isempty(B_hat) || (step["B_direction"] = B_hat)
    return nothing
end
