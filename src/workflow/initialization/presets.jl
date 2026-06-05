# --- Atom-specific Preset constructors ---
#
# The `Preset` struct lives in `src/foundation/types/preset.jl` (loaded
# with the other primary structs); this file only holds the named
# constructors that pre-fill realistic configurations for the atoms we
# run regularly. New species: add a new `<atom>_preset(...)` function
# following the Eu template.

export eu151_preset

"""
    eu151_preset(; n_atoms=50_000, n_pts=(24,24,24),
                  box=(30.0, 30.0, 26.0),
                  trap_ratios=(1.0, 1.0, 1.1818),
                  omega_ref=2π·110) → Preset

Canonical ¹⁵¹Eu Matsui digital-twin configuration (F=6, ω_ref = 2π·110 Hz,
trap = (110, 110, 130) Hz, mean a_s = 110 a₀). c_0 / c_1 derived from the
Kawaguchi-Ueda relation `c_0 + 36 c_1 = 4π · (a_s / a_ho) · N` with the
Eu working assumption `c_1 = c_0 / 36`.

Kwargs override geometry / atom number; the dimensionless conversion
`p_per_nT = g_F μ_B / (ℏ ω_ref) · 1e-9` is re-derived from `omega_ref`.
"""
function eu151_preset(;
    n_atoms::Integer=50_000,
    n_pts::NTuple{3, Int}=(24, 24, 24),
    box::NTuple{3, Float64}=(30.0, 30.0, 26.0),
    trap_ratios::NTuple{3, Float64}=(1.0, 1.0, 1.1818),
    omega_ref::Float64=2π * 110.0,
)
    atom = Eu151
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    c_total = 4π * (atom.a_s / a_ho) * n_atoms
    c0 = c_total / (1 + atom.F^2 / 36.0)
    c1 = c0 / 36.0
    c_dd = compute_c_dd_dimless(atom; N_atoms=Int(n_atoms), omega_ref=omega_ref)
    grid = make_grid(GridConfig(n_pts, box))
    potential = HarmonicTrap{3}(trap_ratios)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0, 1 => c1))
    return Preset(atom, omega_ref, n_atoms, grid, potential, interactions, c_dd)
end
