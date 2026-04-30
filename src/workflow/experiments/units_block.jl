# --- Top-level `units:` block: opt-in lab-unit interpretation of bare Reals ---
#
# Without `units:`, all parsers continue to treat raw Real YAML values per
# their existing per-field convention (mostly dimensionless internal units).
#
# With `units:` declared at YAML root:
#
#   units: {B: Gauss, ω: Hz, t: ms, length: μm, energy: nK}
#
#   pipeline:
#     - ground_state:
#         zeeman: {Bz: 0.819}            # ← rewritten to "0.819 Gauss"
#         duration: 500                  # ← "500 ms"
#         B_hat: {phi_omega: 226}        # ← "226 Hz"
#         init_sigma: 1.5                # ← "1.5 μm"
#
# Inline strings always win: `Bz: "0.5 mT"` overrides the units block.
#
# Recognised unit categories and the YAML keys they apply to:
#
#   B       — Bx, By, Bz, B_mag                (Gauss, mT, T, ...)
#   ω       — frequency, freq_start, freq_end,
#             phi_omega, phi_chirp.{from,to}    (Hz, kHz, rad/s, ...)
#   t       — duration, t_center, sigma         (ms, μs, s, ...)
#   length  — box, init_sigma, waist            (μm, mm, m, ...)
#   energy  — tol, mu                           (nK, ℏω_ref, ...)
#
# Implementation: pre-parse walk the YAML dict, rewrite Real values whose key
# matches a known typed field. Existing unit-aware parsers handle the
# resulting Quantity strings via `Units.safe_parse_quantity`.

const _UNITS_KEY_MAP = Dict{String, Symbol}(
    # B field — always applies in a zeeman: block context, but the keys are
    # globally unambiguous so we don't need parent-key checks.
    "Bx" => :B, "By" => :B, "Bz" => :B, "B_mag" => :B,
    # Angular frequency / waveform frequency
    "frequency" => :ω, "freq_start" => :ω, "freq_end" => :ω,
    "phi_omega" => :ω, "omega" => :ω, "omega_ref" => :ω,
    # Time
    "duration" => :t, "t_center" => :t,
    # Note: `sigma` left out of :t mapping — collides with init_sigma
    # (length, dimless / a_ho units) and gaussian_pulse.sigma (time).
    # Resolve via parent-key context if needed in a future phase.
    #
    # Length (`box`, `init_sigma`, `waist`): NOT included in phase 1.
    # They require a_ho conversion (= sqrt(ℏ / (m·ω_ref))) which depends
    # on atom + omega_ref, only known at the lowering-pipeline stage.
    # Phase 6 will extend the units block to handle length once a_ho is
    # available at the rewrite point.
    #
    # Energy: similarly deferred (requires ω_ref scale).
)

"""
    apply_units_block!(data::Dict) -> Dict

Pop a top-level `units:` block from `data` and rewrite Real values for known
typed keys to unit-bearing strings. No-op if `units:` absent. The transformed
dict can then be parsed by the standard schema with all unit-aware parsers
already handling the strings.

`from`/`to` keys (used in linear ramps + phi_chirp) inherit the unit type of
their parent key. So inside `phi_chirp: {from: 0, to: 226}`, both `from` and
`to` get the ω unit because `phi_chirp` has type ω.
"""
function apply_units_block!(data::Dict)
    haskey(data, "units") || return data
    units_raw = pop!(data, "units")
    units_raw isa Dict || throw(ArgumentError(
        "units: expected a mapping like {B: Gauss, ω: Hz}; got $(typeof(units_raw))"))

    # Normalise key→unit-string map, accept symbols too.
    units = Dict{Symbol, String}()
    for (k, v) in units_raw
        kk = k isa Symbol ? k : Symbol(string(k))
        units[kk] = String(v)
    end

    _rewrite_units!(data, units, nothing)
    return data
end

"""
Inherit-aware recursive rewrite. `parent_unit_type` is the unit type of the
parent key (used to give `from`/`to` the same type as e.g. `phi_chirp`).
"""
function _rewrite_units!(node, units::Dict{Symbol, String},
    parent_unit_type::Union{Nothing, Symbol})
    if node isa AbstractDict
        for (k, v) in node
            kk = String(k)
            unit_type = if (kk == "from" || kk == "to") && parent_unit_type !== nothing
                parent_unit_type
            else
                get(_UNITS_KEY_MAP, kk, nothing)
            end
            if v isa Real && unit_type !== nothing && haskey(units, unit_type)
                node[k] = string(v) * " " * units[unit_type]
            elseif v isa AbstractVector && unit_type !== nothing && haskey(units, unit_type)
                # e.g. `omega: [50, 50, 130]` with ω: Hz
                node[k] = Any[
                    e isa Real ? string(e) * " " * units[unit_type] : e
                    for e in v
                ]
                # Also recurse into elements that are dicts (e.g. composite list)
                _rewrite_units!(node[k], units, unit_type)
            else
                _rewrite_units!(v, units, unit_type)
            end
        end
    elseif node isa AbstractVector
        for v in node
            _rewrite_units!(v, units, parent_unit_type)
        end
    end
    return node
end
