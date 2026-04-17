"""
Atomic units (Hartree) conversions.

Internal convention: lengths in a_0, energies in E_h, masses in m_e,
magnetic field B in atomic units (E_h / μ_B_au where μ_B_au = 1/2 in
Gaussian-atomic, or equivalently 2.127191... × 10⁻⁶ E_h/T in SI).

All constants from CODATA 2018.
"""

# --- fundamental constants (SI) ---
const _h_Js      = 6.62607015e-34          # Planck constant [J·s] (exact)
const _hbar_Js   = 1.054571817e-34         # ℏ [J·s]
const _e_C       = 1.602176634e-19         # elementary charge [C] (exact)
const _m_e_kg    = 9.1093837015e-31        # electron mass [kg]
const _u_kg      = 1.66053906660e-27       # atomic mass unit [kg]
const _a0_m      = 5.29177210903e-11       # Bohr radius [m]
const _Eh_J      = 4.3597447222071e-18     # Hartree energy [J]
const _muB_JT    = 9.2740100783e-24        # Bohr magneton [J/T]
const _muN_JT    = 5.0507837461e-27        # nuclear magneton [J/T]
const _kB_JK     = 1.380649e-23            # Boltzmann constant [J/K]

"""
    AtomicUnits

Singleton marker type; kept for extensibility. Conversions below are
standalone functions, no instance needed.
"""
struct AtomicUnits end

# --- conversions SI → atomic units ---

"Convert a frequency [Hz] to energy in Hartree (E = h·ν)."
hz_to_au(nu_hz::Real) = _h_Js * nu_hz / _Eh_J

"Convert [MHz] to E_h."
mhz_to_au(nu_mhz::Real) = hz_to_au(1e6 * nu_mhz)

"Convert [GHz] to E_h."
ghz_to_au(nu_ghz::Real) = hz_to_au(1e9 * nu_ghz)

"Convert magnetic field [T] to atomic units (E_h / μ_B_au with μ_B_au = 1/2 (exact))."
function tesla_to_au(B_T::Real)
    # In atomic units, μ_B B has units of energy. We represent B directly in
    # SI and expose μ_B_au below; μ_B_au × B[au] = μ_B[J/T] × B[T] / E_h.
    # Here we return the dimensionless B in the convention where
    # E_Zeeman[au] = g μ_B_au B[au] m_J with μ_B_au = 1/2.
    #   ⇒ B[au] = (μ_B[J/T] / (E_h/2)) × B[T] = 2 μ_B B / E_h
    2 * _muB_JT * B_T / _Eh_J
end

"Bohr magneton in atomic units (exact: μ_B = 1/2·e·ℏ/m_e = 1/2)."
const MU_B_AU = 0.5

"Nuclear magneton in atomic units (μ_N = μ_B × m_e/m_p, m_p/m_e = 1836.15267...)."
const MU_N_AU = MU_B_AU * (_m_e_kg / (1.00727646677 * _u_kg))

"Convert atomic mass unit (u) to electron mass units (atomic units)."
amu_to_au(m_u::Real) = m_u * (_u_kg / _m_e_kg)

"Convert length [m] to Bohr radii."
m_to_bohr(L_m::Real) = L_m / _a0_m

"Convert [a_0] to m."
bohr_to_m(L_au::Real) = L_au * _a0_m

"Convert energy [E_h] to Hz (E/h)."
au_to_hz(E_au::Real) = E_au * _Eh_J / _h_Js

"Convert [E_h] to MHz."
au_to_mhz(E_au::Real) = au_to_hz(E_au) / 1e6

"Convert temperature [K] to energy [E_h]."
kelvin_to_au(T_K::Real) = _kB_JK * T_K / _Eh_J

"Speed of light [m/s] (exact)."
const _c_ms = 2.99792458e8

"Convert wavenumber [cm⁻¹] to energy [E_h]: E = h·c·ν̃, ν̃ in m⁻¹ = 100·cm⁻¹."
cm1_to_au(wn_cm1::Real) = 100 * _h_Js * _c_ms * wn_cm1 / _Eh_J

"Convert [E_h] to [cm⁻¹]."
au_to_cm1(E_au::Real) = E_au * _Eh_J / (100 * _h_Js * _c_ms)
