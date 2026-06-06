# --- Spin system + atomic species types ---
#
# `SpinSystem` (F + n_components + m-projection list) is the lightweight
# spin descriptor. `SpinMatrices{D,M}` packs the precomputed Fx/Fy/Fz
# generators (and Fy diagonalisation buffers) so the rotating-basis
# step can rotate via dense gemm. `AtomSpecies` carries the calibrated
# physical constants for Eu151/Dy164/Rb87/etc.

export SpinSystem, SpinMatrices, AtomSpecies

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
- `q_geometry`: dimensionless geometry factor for the quadratic Zeeman
         calculation, q = (g_J μ_B B)² · q_geometry / Δ_hf. Specific to
         the (J, I, F) manifold. Zero if unknown (q auto-derive
         requires this; missing → user must set q explicitly).
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
        q_geometry::Float64=0.0,
    )
        a_s = _compute_mean_scattering_length(F, a0, a2)
        new(name, mass, F, a0, a2, a_s, mu_mag, g_F, scattering_lengths,
            Delta_E_hf, g_J, q_geometry)
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
        q_geometry::Float64=0.0,
    )
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int, Float64}(0 => a0, 2 => a2)
        else
            Dict{Int, Float64}()
        end
        a_s = _compute_mean_scattering_length(F, a0, a2)
        new(name, mass, F, a0, a2, a_s, mu_mag, Float64(g_F), sl,
            Delta_E_hf, g_J, q_geometry)
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
        q_geometry::Float64=0.0,
    )
        a_s = _compute_mean_scattering_length(F, a0, a2)
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, scattering_lengths,
            Delta_E_hf, g_J, q_geometry)
    end

    function AtomSpecies(name, mass, F, a0, a2, mu_mag;
        Delta_E_hf::Float64=0.0, g_J::Float64=0.0, q_geometry::Float64=0.0)
        sl = if F == 1 && (a0 != 0.0 || a2 != 0.0)
            Dict{Int, Float64}(0 => a0, 2 => a2)
        else
            Dict{Int, Float64}()
        end
        a_s = _compute_mean_scattering_length(F, a0, a2)
        new(name, mass, F, a0, a2, a_s, mu_mag, 0.0, sl,
            Delta_E_hf, g_J, q_geometry)
    end
end

AtomSpecies(name, mass, F, a0, a2) = AtomSpecies(name, mass, F, a0, a2, 0.0)
