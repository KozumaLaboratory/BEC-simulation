# --- Unit-aware numeric parsers ---
#
# Walk the YAML graph to convert raw Reals + Quantity strings into the
# dimensionless numbers that the solver consumes. Pulled out of the old
# helpers_parsers.jl 2026-05-01 for cohesion: every function here turns
# user-facing numeric specs (B-field strings, frequency strings, time
# specs) into Float64 in the codebase's canonical units.

# --- YAML parsing helpers ---

_zeeman_scalar(v) = v isa Dict ? Float64(v["from"]) : Float64(v)

# --- Unitful-aware numeric parsing ---------------------------------------
#
# Policy: numeric YAML fields that represent a physical quantity accept EITHER:
#   - a raw Real (legacy convention, default unit implicit per field)
#   - a unit-carrying string ("0.819 G", "50 Hz", "20 μm") parsed via
#     Units.safe_parse_quantity
#
# Keeping both paths means existing YAMLs (25+ configs) continue to work
# unchanged while new YAMLs can use physical units for experimental clarity.

"""
    _parse_bfield(node, g_F, omega_ref) -> Float64 (dimensionless p-equivalent)

Accept Real (default Gauss) or string ("0.819 G", "81.9 mT"). Returns
g_F · μ_B · B / (ℏ · ω_ref) — ready for direct use as a dimensionless
Zeeman parameter.
"""
function _parse_bfield(node, g_F::Real, omega_ref::Real)
    if node isa AbstractString
        q = Units.safe_parse_quantity(node)
        return Units.bfield_to_p(q, g_F, omega_ref)
    elseif node isa Real
        # Real → already-dimensionless Zeeman OR raw Gauss number?
        # Convention: In Level 1/2 zeeman context (caller decides), Real = Gauss.
        # This function is only called from the Gauss-context parsers, so
        # always convert as Gauss for consistency.
        return Units.bfield_to_p(Float64(node), g_F, omega_ref)
    end
    throw(ArgumentError("B-field: expected Real (Gauss) or quantity string; got $(typeof(node))"))
end

"""
    _parse_angular_frequency(node) -> Float64 (rad/s)

Accept Real (rad/s, existing convention) or string ("50 Hz", "314 rad/s").
"""
function _parse_angular_frequency(node)
    if node isa AbstractString
        return Units.freq_to_angular(Units.safe_parse_quantity(node))
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError("frequency: expected Real (rad/s) or quantity string"))
end

"""
    _parse_dimless_time(node, omega_ref) -> Float64

Accept Real (already dimensionless t·ω_ref) or string ("1 ms", "50 μs").
"""
function _parse_dimless_time(node, omega_ref::Real)
    if node isa AbstractString
        return Units.time_to_dimless(Units.safe_parse_quantity(node), omega_ref)
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError("time: expected Real (dimensionless) or quantity string"))
end

"""
    _parse_dimless_freq(node, omega_ref) -> Float64

Accept Real (already-dimensionless ω/ω_ref) or string ("226 Hz", "1.42 kHz",
"314 rad/s"). Returns the dimensionless ratio used internally.

Eliminates the documented Klaus 2022 magnetostir footgun where
`phi_omega: 4.524` was sometimes computed as `f/f_ref` instead of
`(2π·f)/ω_ref` — the 2π factor.
"""
function _parse_dimless_freq(node, omega_ref::Real)
    omega_ref > 0 ||
        throw(ArgumentError("omega_ref must be positive, got $omega_ref"))
    if node isa AbstractString
        ω_si = Units.freq_to_angular(Units.safe_parse_quantity(node))
        return ω_si / omega_ref
    elseif node isa Real
        return Float64(node)
    end
    throw(ArgumentError(
        "frequency: expected Real (dimensionless) or quantity string"))
end

_to_int_vec(v::Vector) = Int[Int(x) for x in v]
_to_int_vec(v) = Int[Int(v)]
_to_float_vec(v::Vector) = Float64[Float64(x) for x in v]
_to_float_vec(v) = Float64[Float64(v)]
