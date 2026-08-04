module Units

using Unitful
using Unitful: Quantity, @u_str, ustrip, dimension, unit

const HBAR = 1.054571817e-34      # J·s
const AMU = 1.66053906660e-27     # kg
const BOHR_RADIUS = 5.29177210903e-11  # m
const BOHR_MAGNETON = 9.2740100783e-24 # J/T
const MU_0 = 1.25663706212e-6    # N/A² (vacuum permeability)
const KB = 1.380649e-23           # J/K

# --- Dimensions for safety checks (cached for speed + clarity) ---
const DIM_BFIELD = dimension(1.0u"T")
const DIM_LENGTH = dimension(1.0u"m")
const DIM_TIME = dimension(1.0u"s")
const DIM_FREQ = dimension(1.0u"Hz")              # 𝐓^-1, also u"rad/s"

# --- Safe string parsing ---
#
# Unitful.uparse evaluates Julia expressions — raw `uparse(user_string)` is
# code injection. Restrict to Unitful's own unit context so only unit symbols
# and arithmetic on them are allowed.

const _ALLOWED_CHAR_RE = r"^[\w\d\.\s\*\/\^\+\-πμ]+$"

"""
    safe_parse_quantity(s) -> Quantity

Parse a unit-carrying string safely. Restricts characters to alphanumerics,
dots, arithmetic, π, μ. Uses `Unitful.uparse` with `unit_context = Unitful`
so only Unitful's unit symbols (G, T, Hz, m, s, μm, mW, ...) resolve.
Function calls like `rm(".")` or references to user-defined symbols will fail.
"""
function safe_parse_quantity(s::AbstractString)
    occursin(_ALLOWED_CHAR_RE, s) ||
        throw(ArgumentError("invalid characters in quantity string: '$s'"))
    # Unitful.uparse rejects "0.819 G" (space between number and unit).
    # Collapse single spaces between alphanumeric tokens into `*` so
    # "0.819 G" → "0.819*G", "50 rad/s" → "50*rad/s".
    s_clean = replace(strip(s), r"(?<=[\d\.)])\s+(?=[a-zA-Zπμ])" => "*")
    try
        return Unitful.uparse(s_clean; unit_context=Unitful)
    catch e
        throw(ArgumentError("failed to parse unit string '$s': $e"))
    end
end

# --- High-level converters ---

"""
    bfield_to_p(B, g_F, omega_ref) -> Float64

THE single source for the lab-field → dimensionless linear-Zeeman conversion.
Kawaguchi–Ueda convention:

    p = -g_F · μ_B · B / (ℏ · ω_ref)

The minus sign is physical: the atomic moment is μ = -g_F μ_B F (g_F>0 ⇒
anti-parallel to F), so the linear Zeeman operator H = -p·F_z equals
+g_F μ_B B·F_z, and +Bz on a g_F>0 atom (Eu, Cr, He*) lands the ground
state at m = -F (spin down). g_F is stored at its literature (Steck/NIST)
sign. Every B→p conversion (`_gauss_to_dimless`, `_gauss_to_dimless_factor`,
`Preset.p_per_field`) delegates here — the sign lives in ONE place. Sign
corrected 2026-06-10; see `mistake_zeeman_groundstate_direction_inverted_2026_06_10`.

`B` is a Quantity (any magnetic-flux-density unit) or a `Real` in **Gauss**.
"""
function bfield_to_p(B::Quantity, g_F::Real, omega_ref::Real)
    dimension(B) == DIM_BFIELD ||
        throw(ArgumentError("bfield_to_p expects magnetic-flux-density; got $(unit(B))"))
    B_T = ustrip(u"T", B)
    -g_F * BOHR_MAGNETON * B_T / (HBAR * omega_ref)
end
"""
    bfield_to_p_gauss(B_gauss, g_F, omega_ref) -> Float64

`bfield_to_p` for a bare number in GAUSS. The unit is in the NAME because a
bare `Real` carrying an implied unit is how a 1e4 error gets written: on
2026-08-04 `linear_zeeman_p` (`hamiltonian/coefficients.jl`) was found passing
TESLA to the un-suffixed method, which reads Gauss.

Gauss is the project's bare-number convention throughout — YAML writes
`Bz: "0.01 Gauss"`, `b_block_builders.jl` names its variable `B_gauss`, and the
per-field factor is per-Gauss. Callers holding Tesla should either attach the
unit (`B * u"T"`) or convert explicitly; there is no bare-Tesla entry point,
deliberately.
"""
bfield_to_p_gauss(B_gauss::Real, g_F::Real, omega_ref::Real) =
    bfield_to_p(Float64(B_gauss) * u"Gauss", g_F, omega_ref)

# Kept: `Real` still means Gauss, so no call site changes behaviour. New code
# should prefer the suffixed name or a `Quantity`.
bfield_to_p(B::Real, g_F::Real, omega_ref::Real) =
    bfield_to_p_gauss(B, g_F, omega_ref)

"""
    freq_to_angular(f) -> Float64 (rad/s)

Accept Hz or rad/s. Hz → ×2π; rad/s → as-is. Real input assumed rad/s
(matches existing `interactions.omega_ref` convention).
"""
function freq_to_angular(f::Quantity)
    d = dimension(f)
    if d == DIM_FREQ
        # Could be Hz or rad/s — both have dimension 𝐓^-1. Disambiguate by unit.
        u = unit(f)
        if u == u"rad/s" || u == u"rad*s^-1"
            return Float64(ustrip(u"rad/s", f))
        else
            # Any plain-Hz-dimensional unit → multiply by 2π
            return Float64(ustrip(u"Hz", f)) * 2π
        end
    end
    throw(ArgumentError("freq_to_angular expects Hz or rad/s; got $(unit(f))"))
end
freq_to_angular(f::Real) = Float64(f)  # existing convention: rad/s

"""
    time_to_dimless(t, omega_ref) -> Float64

Time in seconds → dimensionless (t · ω_ref). Quantity or Real (Real = already
dimensionless in 1/ω_ref units per existing convention).
"""
function time_to_dimless(t::Quantity, omega_ref::Real)
    dimension(t) == DIM_TIME ||
        throw(ArgumentError("time_to_dimless expects time; got $(unit(t))"))
    Float64(ustrip(u"s", t)) * omega_ref
end
time_to_dimless(t::Real, ::Real) = Float64(t)

"""
    length_to_dimless(L, a_ho) -> Float64

Length in meters → dimensionless (L / a_ho). Quantity or Real (Real = already
dimensionless in a_ho units per existing convention).
"""
function length_to_dimless(L::Quantity, a_ho::Real)
    dimension(L) == DIM_LENGTH ||
        throw(ArgumentError("length_to_dimless expects length; got $(unit(L))"))
    Float64(ustrip(u"m", L)) / a_ho
end
length_to_dimless(L::Real, ::Real) = Float64(L)

"""
    k3_si(q) -> Float64 (m^6/s)

Strip a Unitful 3-body-loss-coefficient quantity to plain Float64 in
m^6/s. Errors loudly if the dimension doesn't match.
"""
function k3_si(q::Quantity)
    dimension(q) == dimension(1.0u"m^6/s") ||
        throw(ArgumentError("k3_si expects [length]^6/[time]; got $(unit(q))"))
    Float64(ustrip(u"m^6/s", q))
end

end # module
