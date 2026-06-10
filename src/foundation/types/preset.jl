# --- Preset: frozen atom + grid + interaction bundle (struct only) ---
#
# Struct definition only — concrete builders (e.g. `eu151_preset`) live
# in `src/workflow/initialization/presets.jl` so they can call helpers
# from the hamiltonian / workflow layers (e.g. `compute_c_dd_dimless`).

export Preset

"""
    Preset

Immutable bundle of the structural inputs that every ground-state /
sweep script reconstructs from scratch.

Fields:
  * `atom`         — `AtomSpecies`
  * `omega_ref`    — reference angular frequency [rad/s]
  * `n_atoms`      — atom number
  * `grid`         — `Grid{N}` (spatial discretisation)
  * `potential`    — `AbstractPotential` (typically `HarmonicTrap`)
  * `interactions` — `InteractionParams` (c0/c1 path; tensor path
                     leaves these zero and uses `scattering_lengths`)
  * `c_dd`         — dimensionless DDI coupling
  * `a_ho`         — harmonic-oscillator length √(ℏ/(m·ω_ref))
  * `p_per_field`  — dimensionless Zeeman per Tesla
                     (= `g_F · μ_B / (ℏ · ω_ref)`)
  * `p_per_nT`     — dimensionless Zeeman per nanotesla
  * `F`, `D`       — atom.F, 2F+1
  * `c0`, `c1`     — primary spinor couplings lifted from `interactions`
"""
struct Preset{N, P <: AbstractPotential}
    atom::AtomSpecies
    omega_ref::Float64
    n_atoms::Int
    grid::Grid{N}
    potential::P
    interactions::InteractionParams
    c_dd::Float64
    a_ho::Float64
    p_per_field::Float64
    p_per_nT::Float64
    F::Int
    D::Int
    c0::Float64
    c1::Float64
end

"""
    Preset(atom, omega_ref, n_atoms, grid, potential, interactions, c_dd)

Convenience constructor: derives `a_ho`, `p_per_field`, `p_per_nT`, `F`,
`D`, `c0`, `c1` from the supplied primary fields. Use this when you
already have hand-computed `interactions` + `c_dd`; for canned configs
prefer `eu151_preset(; ...)` (defined in workflow/initialization/).
"""
function Preset(
    atom::AtomSpecies,
    omega_ref::Float64,
    n_atoms::Integer,
    grid::Grid{N},
    potential::P,
    interactions::InteractionParams,
    c_dd::Real,
) where {N, P <: AbstractPotential}
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    p_per_field = Units.bfield_to_p(1.0e4, atom.g_F, omega_ref)  # per Tesla (1e4 G = 1 T); signed SSoT
    p_per_nT = 1.0e-9 * p_per_field
    c0 = get(interactions.c, 0, 0.0)
    c1 = get(interactions.c, 1, 0.0)
    return Preset{N, P}(
        atom, omega_ref, Int(n_atoms), grid, potential, interactions,
        Float64(c_dd), a_ho, p_per_field, p_per_nT,
        atom.F, 2 * atom.F + 1, c0, c1,
    )
end
