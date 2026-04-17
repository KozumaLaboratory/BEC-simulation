"""
Single-atom parameters for hyperfine + Zeeman structure.

Half-integer spins are stored as their 2j value (integer) to avoid
floating-point comparisons. All energies are in atomic units (E_h).
"""

"""
    AtomParams

Parameters of a single atom with electronic angular momentum J and
nuclear spin I, with magnetic-dipole hyperfine constant A and
(optionally) electric-quadrupole constant B.

# Fields
- `name::Symbol`          : label (e.g. :Eu151)
- `two_I::Int`            : 2I (e.g. 5 for I=5/2)
- `two_J::Int`            : 2J (e.g. 7 for J=7/2)
- `A_hfs::Float64`        : magnetic-dipole HFS constant [E_h]
- `B_hfs::Float64`        : electric-quadrupole HFS constant [E_h] (0 for S states)
- `g_J::Float64`          : electronic Landé g-factor
- `g_I::Float64`          : nuclear g-factor (in units of μ_N, sign per
                            Ramsey convention: g_I > 0 when μ_I ∥ I)
- `mass::Float64`         : atomic mass [m_e]

NB: For ¹⁵¹Eu ground state ⁸S_{7/2}, published HFS values vary in sign
convention and ppm-level precision. The defaults below are nominal; the
user should supply authoritative values via `AtomParams(; A_hfs=..., ...)`
for production work.
"""
struct AtomParams
    name::Symbol
    two_I::Int
    two_J::Int
    A_hfs::Float64
    B_hfs::Float64
    g_J::Float64
    g_I::Float64
    mass::Float64
end

"""
    Eu151(; A_hfs = -20.0523e6 × h, ...)

¹⁵¹Eu (I = 5/2, J = 7/2) in the ⁸S_{7/2} electronic ground state.

Defaults (nominal, overridable):
- A_hfs ≈ -20.0523 MHz (Sandars & Woodgate 1960 ballpark; sign per convention)
- B_hfs ≈ -0.7012 MHz
- g_J   ≈ 1.9934      (free-electron + relativistic corrections)
- g_I   ≈ +1.3887     (in units of μ_N)
- mass  ≈ 150.9198578 u
"""
function Eu151(;
    A_hfs_mhz::Real = -20.0523,
    B_hfs_mhz::Real = -0.7012,
    g_J::Real       = 1.9934,
    g_I::Real       = 1.3887,
    mass_amu::Real  = 150.9198578,
)
    AtomParams(
        :Eu151,
        5,                           # 2I, I = 5/2
        7,                           # 2J, J = 7/2
        mhz_to_au(A_hfs_mhz),
        mhz_to_au(B_hfs_mhz),
        Float64(g_J),
        Float64(g_I),
        amu_to_au(mass_amu),
    )
end

"""
    Eu153(; ...)

¹⁵³Eu (I = 5/2, J = 7/2). Nominal defaults from the same literature
band as Eu151; differs mainly in HFS constants and isotope mass.
"""
function Eu153(;
    A_hfs_mhz::Real = -8.85,
    B_hfs_mhz::Real = -1.781,
    g_J::Real       = 1.9934,
    g_I::Real       = 0.6134,
    mass_amu::Real  = 152.9212380,
)
    AtomParams(
        :Eu153,
        5, 7,
        mhz_to_au(A_hfs_mhz),
        mhz_to_au(B_hfs_mhz),
        Float64(g_J),
        Float64(g_I),
        amu_to_au(mass_amu),
    )
end

"""
    reduced_mass(atom1, atom2) [m_e]

Two-body reduced mass μ = m1 m2 / (m1 + m2) in electron-mass units.
"""
reduced_mass(a::AtomParams, b::AtomParams) = a.mass * b.mass / (a.mass + b.mass)
