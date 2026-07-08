# --- Spin system + atomic species types ---
#
# `SpinSystem` (F + n_components + m-projection list) is the lightweight
# spin descriptor. `SpinMatrices{D,M}` packs the precomputed Fx/Fy/Fz
# generators (and Fy diagonalisation buffers) so the rotating-basis
# step can rotate via dense gemm. `AtomSpecies` carries the calibrated
# physical constants for Eu151/Dy164/Rb87/etc.

export SpinSystem, SpinMatrices, AtomSpecies
export quadratic_zeeman_geometry

"""
    quadratic_zeeman_geometry(F, I, J) -> dimensionless

Closed-form geometry factor for the second-order (quadratic) Zeeman shift of a
hyperfine level `F` coupled to `F-1` via `J_z`, from degenerate PT:

    q = (g_J μ_B B)² · quadratic_zeeman_geometry(F, I, J) / |E_F - E_{F-1}|

Derived from `|⟨F-1,m|J_z|F,m⟩|² = geometry · (F² - m²)` (verified against a
direct Clebsch-Gordan evaluation):

    geometry = [F² - (I-J)²] · [(I+J+1)² - F²] / (4 F² (4F² - 1))

Cross-checks: Rb-87 (F=2, I=3/2, J=1/2) → 15/240 = 0.0625 → q/h = 71.6 Hz/G²;
¹⁵¹Eu (F=6, I=5/2, J=7/2) → 455/20592 = 0.02210 → q/h = 1.43 kHz/G².
Vanishes at the manifold edge F = |I-J|. Defined here (loaded before atoms.jl)
so atom constructors can build `q_geometry` from it instead of hard-coding.
"""
function quadratic_zeeman_geometry(F::Real, I::Real, J::Real)
    num = (F^2 - (I - J)^2) * ((I + J + 1)^2 - F^2)
    den = 4 * F^2 * (4 * F^2 - 1)
    Float64(num / den)
end

# --- Spin System ---

struct SpinSystem
    F::Int
    n_components::Int
    m_values::Vector{Int}
end

function SpinSystem(F::Int)
    F >= 0 || throw(ArgumentError("F must be non-negative"))
    n = 2F + 1
    SpinSystem(F, n, collect(F:-1:(-F)))
end

# --- Spin Matrices ---

struct SpinMatrices{D, M <: SMatrix}
    Fx::M
    Fy::M
    Fz::M
    Fp::M
    Fm::M
    F_dot_F::M
    system::SpinSystem
    Fy_eigvecs::Matrix{ComplexF64}
    Fy_eigvecs_adj::Matrix{ComplexF64}
    Fy_eigvals::SVector{D, Float64}
end

# --- Atom Species ---

# NOT GENERALIZABLE: F=1 `a_s = (a0 + 2a2)/3` two-channel reduction; F≥2 uses a0 alone.
# Reason: physics
# Why: at F=1 only S=0 and S=2 even channels exist, so the rotationally-averaged
#   s-wave length is exactly (a_0 + 2 a_2)/3 (Ohmi-Machida 1998). For F≥2 the
#   channel-resolved a_S is the right input and `a_s` is just the nominal a_0
#   placeholder; downstream `scattering_lengths` dict carries the physics.
# See: src/hamiltonian/coefficients.jl (compute_interaction_params)
@inline _compute_mean_scattering_length(F::Int, a0::Float64, a2::Float64) =
    F == 1 ? (a0 + 2a2) / 3 : a0

"""
    AtomSpecies

Atomic species for spinor BEC simulation.

# Fields
- `name`: human-readable name (e.g. "87Rb")
- `mass`: atomic mass in kg
- `F`: total spin quantum number
- `a0`: F=1: F_tot=0 scattering length (m). F>1: mean s-wave scattering length a_s (m)
         when channel-resolved data is unavailable (e.g. Eu151). Use `a_s` for the
         unambiguous mean scattering length regardless of F.
- `a2`: F_tot=2 scattering length (m). Zero if unknown.
- `a_s`: mean s-wave scattering length (m). For F=1: (a0+2a2)/3. For F>1: same as `a0`.
- `mu_mag`: magnetic dipole moment (J/T). Zero for non-dipolar atoms.
- `g_F`: Landé g-factor
- `scattering_lengths`: Dict{Int,Float64} mapping total spin S => a_S (m).
                         Empty when channel-resolved data is unavailable.
- `Delta_E_hf`: hyperfine splitting (J). Zero if unknown/not applicable.
- `g_J`: electronic Landé g-factor for the ground manifold. Used in
         second-order Zeeman (q) — q ∝ (g_J μ_B B)² / Δ_hf · geometry.
         Zero if not provided (q auto-derive disabled).
- `nuclear_I`, `electronic_J`: nuclear spin I and electronic angular momentum J
         of the ground manifold (atom/state-specific primitives, cited). Passed
         as kwargs; from them `q_geometry` is DERIVED, never hand-entered.
- `q_geometry`: dimensionless geometry factor for the quadratic Zeeman
         calculation, q = (g_J μ_B B)² · q_geometry / Δ_hf. **Derived** in the
         constructor via `quadratic_zeeman_geometry(F, nuclear_I, electronic_J)`;
         0 when I/J are not supplied (q auto-derive disabled) or at the F=|I−J|
         edge. Not a settable field — set `nuclear_I`/`electronic_J` instead.
"""
struct AtomSpecies
    name::String
    mass::Float64
    F::Int
    a0::Float64
    a2::Float64
    a_s::Float64
    mu_mag::Float64
    g_F::Float64
    scattering_lengths::Dict{Int, Float64}
    Delta_E_hf::Float64
    g_J::Float64
    nuclear_I::Float64
    electronic_J::Float64
    q_geometry::Float64

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        g_F,
        scattering_lengths;
        Delta_E_hf::Float64=0.0,
        g_J::Float64=0.0,
        nuclear_I::Real=0.0,
        electronic_J::Real=0.0,
    )
        a_s = _compute_mean_scattering_length(F, a0, a2)
        q_geometry = _derive_q_geometry(F, nuclear_I, electronic_J)
        new(name, mass, F, a0, a2, a_s, mu_mag, g_F, scattering_lengths,
            Delta_E_hf, g_J, Float64(nuclear_I), Float64(electronic_J), q_geometry)
    end

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        g_F::Real;
        Delta_E_hf::Float64=0.0,
        g_J::Float64=0.0,
        nuclear_I::Real=0.0,
        electronic_J::Real=0.0,
    )
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int, Float64}(0 => a0, 2 => a2)
        else
            Dict{Int, Float64}()
        end
        a_s = _compute_mean_scattering_length(F, a0, a2)
        q_geometry = _derive_q_geometry(F, nuclear_I, electronic_J)
        new(name, mass, F, a0, a2, a_s, mu_mag, Float64(g_F), sl,
            Delta_E_hf, g_J, Float64(nuclear_I), Float64(electronic_J), q_geometry)
    end

    function AtomSpecies(
        name,
        mass,
        F,
        a0,
        a2,
        mu_mag,
        scattering_lengths::Dict;
        Delta_E_hf::Float64=0.0,
        g_J::Float64=0.0,
        nuclear_I::Real=0.0,
        electronic_J::Real=0.0,
    )
        a_s = _compute_mean_scattering_length(F, a0, a2)
        q_geometry = _derive_q_geometry(F, nuclear_I, electronic_J)
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, scattering_lengths,
            Delta_E_hf, g_J, Float64(nuclear_I), Float64(electronic_J), q_geometry)
    end

    function AtomSpecies(name, mass, F, a0, a2, mu_mag;
        Delta_E_hf::Float64=0.0, g_J::Float64=0.0,
        nuclear_I::Real=0.0, electronic_J::Real=0.0)
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int, Float64}(0 => a0, 2 => a2)
        else
            Dict{Int, Float64}()
        end
        a_s = _compute_mean_scattering_length(F, a0, a2)
        q_geometry = _derive_q_geometry(F, nuclear_I, electronic_J)
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, sl,
            Delta_E_hf, g_J, Float64(nuclear_I), Float64(electronic_J), q_geometry)
    end
end

# q_geometry is DERIVED from the atom/state primitives (F, I, J), never
# hand-entered. Returns 0 when I/J absent (auto-q disabled) or at the F=|I−J|
# manifold edge (quadratic_zeeman_geometry vanishes there).
_derive_q_geometry(F, I, J) =
    (I > 0 && J > 0) ? quadratic_zeeman_geometry(F, I, J) : 0.0

AtomSpecies(name, mass, F, a0, a2) = AtomSpecies(name, mass, F, a0, a2, 0.0)
