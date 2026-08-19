# --- Atom-specific Preset constructors ---
#
# The `Preset` struct lives in `src/foundation/types/preset.jl` (loaded
# with the other primary structs); this file only holds the named
# constructors that pre-fill realistic configurations for the atoms we
# run regularly. New species: add a new `<atom>_preset(...)` function
# following the Eu template.

export eu_preset, eu151_preset, eu153_preset

"""
    eu_preset(atom=Eu151; n_atoms=50_000, n_pts=(24,24,24),
              box=(30.0, 30.0, 26.0),
              trap_ratios=(1.0, 1.0, 1.1818),
              omega_ref=2π·110, c1_ratio=1/36, a_s=atom.a_s) → Preset

Europium (F=6) digital-twin configuration for either stable isotope.
`c_0` / `c_1` come from the Kawaguchi-Ueda relation
`c_0 + F² c_1 = 4π · (a_s / a_ho) · N` with `c_1 = c1_ratio · c_0`.

**The isotope enters through exactly three numbers**, all of them derived here
rather than restated: `c_total ∝ √m` (through `a_ho`), `c_dd ∝ m^{3/2}`, and — not
built here but by the Zeeman path — `q ∝ 1/Δ_hf`. ¹⁵³Eu/¹⁵¹Eu is 1.0066, 1.0200 and
2.2787 respectively. See `docs/guides/eu_isotope_q_prediction.md`.

`a_s` is overridable because **a_s(¹⁵³Eu) has never been measured** and the registry
carries ¹⁵¹Eu's 110(4) a₀ as an explicit placeholder; any quantitative ¹⁵³Eu claim has
to say which value it used.
"""
function eu_preset(
    atom::AtomSpecies=Eu151;
    n_atoms::Integer=50_000,
    n_pts::NTuple{3, Int}=(24, 24, 24),
    box::NTuple{3, Float64}=(30.0, 30.0, 26.0),
    trap_ratios::NTuple{3, Float64}=(1.0, 1.0, 1.1818),
    omega_ref::Float64=2π * 110.0,
    c1_ratio::Float64=1 / 36,
    a_s::Float64=atom.a_s,
    c_extra::Dict{Int, Float64}=Dict{Int, Float64}(),
)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    c_total = 4π * (a_s / a_ho) * n_atoms
    c0 = c_total / (1 + atom.F^2 * c1_ratio)
    c1 = c1_ratio * c0
    c_dd = compute_c_dd_dimless(atom; N_atoms=Int(n_atoms), omega_ref=omega_ref)
    grid = make_grid(GridConfig(n_pts, box))
    potential = HarmonicTrap{3}(trap_ratios)
    # Dict keys ARE the ranks, so the `c_0 + F²c_1 = c_total` constraint stated above
    # applies to the c₀/c₁ truncation only; with a nonzero higher-rank channel the
    # tensor path takes over (same caveat `interaction_params_from_constraint` warns
    # about). Eu has seven unknown even channels, so this kwarg is how their effect is
    # probed rather than assumed away.
    interactions = InteractionParams(merge(Dict{Int, Float64}(0 => c0, 1 => c1), c_extra))
    return Preset(atom, omega_ref, n_atoms, grid, potential, interactions, c_dd)
end

"""
    eu151_preset(; kwargs...) → Preset

Canonical ¹⁵¹Eu Matsui digital-twin configuration (F=6, ω_ref = 2π·110 Hz,
trap = (110, 110, 130) Hz, mean a_s = 110 a₀, `c_1 = c_0/36`).
Named wrapper over [`eu_preset`](@ref) — wrap, don't fork.
"""
eu151_preset(; kwargs...) = eu_preset(Eu151; kwargs...)

"""
    eu153_preset(; kwargs...) → Preset

The ¹⁵³Eu sibling. Same electronic structure, so `g_F`, `μ` and the q-geometry are
shared; the mass and Δ_hf are not. **`a_s` defaults to the registry placeholder
(= ¹⁵¹Eu's measured value); it has never been measured for ¹⁵³Eu.** Pass `a_s=` for
any quantitative claim, and say so beside the number.
"""
eu153_preset(; kwargs...) = eu_preset(Eu153; kwargs...)
