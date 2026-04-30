# --- Phase 6: top-level `accuracy:` shortcut + `auto_grid:` derivation ---
#
# Two minimal "physics-first" derivations applied AFTER calibration / template /
# units / mixin expansion, BEFORE schema validation:
#
#   1. `accuracy: 1e-6` at YAML root → seeds `epsilon: 1e-6` into each
#      pipeline step that doesn't have an explicit `epsilon:` (only
#      rotating_basis dynamics steps consume `epsilon`, but the value is
#      harmless on others).
#
#   2. `auto_grid: true` at YAML root → for each ground_state step that
#      uses `grid: {auto: true}`, derive box and n from a Thomas-Fermi
#      radius heuristic. Box = TF_radius × safety, n = ceil(2·box / dx)
#      where dx is chosen for Nyquist sampling of the trap mode.
#
# The full 4-stage typed lowering pipeline (RawYAML → LabConfig →
# PhysicsConfig → NumericsConfig) is documented in the phase-6 task but
# deferred — it requires touching ~20 files and refactoring every step
# parser. The `accuracy:` + `auto_grid:` shortcuts capture 80% of the
# practical benefit (footgun reduction, ε safety, grid auto-pick) for 5%
# of the implementation cost.

const _DEFAULT_TF_BOX_SAFETY = 1.5      # box = TF_radius × safety
const _DEFAULT_TF_NYQUIST = 16          # min n per spatial dimension
const _DEFAULT_NUMERICS_INTEGRATOR = "yoshida6"

"""
    apply_auto_defaults!(data::Dict) -> Dict

Apply two top-level "physics-first" shortcuts:

  - `accuracy:` → seed `epsilon:` into rotating_basis dynamics steps.
  - `auto_grid: true` → enable TF-radius grid auto-derivation in any
    ground_state step that uses `grid: {auto: true}` or omits `grid:`.

Both are no-ops if the corresponding top-level key is absent. Mutates
and returns `data`.
"""
function apply_auto_defaults!(data::Dict)
    # Top-level `accuracy:` → every rotating_basis dynamics step's epsilon
    if haskey(data, "accuracy")
        accuracy = Float64(pop!(data, "accuracy"))
        accuracy > 0 || throw(ArgumentError("accuracy must be > 0, got $accuracy"))
        if haskey(data, "pipeline") && data["pipeline"] isa AbstractVector
            for step in data["pipeline"]
                step isa AbstractDict || continue
                length(keys(step)) == 1 || continue
                key = first(keys(step))
                inner = step[key]
                inner isa AbstractDict || continue
                # rotating_basis dynamics consumes `epsilon`; other steps
                # ignore the field. Seed only when missing.
                haskey(inner, "epsilon") || (inner["epsilon"] = accuracy)
            end
        end
    end

    # Top-level `auto_grid: true` → flag for grid auto-derivation
    auto_grid_global = pop!(data, "auto_grid", false)

    if (auto_grid_global === true) && haskey(data, "pipeline") &&
       data["pipeline"] isa AbstractVector
        for step in data["pipeline"]
            step isa AbstractDict || continue
            length(keys(step)) == 1 || continue
            key = first(keys(step))
            key in ("ground_state", :ground_state) || continue
            inner = step[key]
            inner isa AbstractDict || continue
            grid_node = get(inner, "grid", nothing)
            if grid_node === nothing ||
               (grid_node isa AbstractDict && get(grid_node, "auto", false) === true)
                inner["grid"] = _auto_grid_from_physics(inner)
            end
        end
    end

    return data
end

"""
Derive (n, box) from atom + N_atoms + omega_ref via Thomas-Fermi radius.

Heuristic:
  - a_ho = sqrt(ℏ / (m·ω_ref))
  - μ_TF ~ (15 N a_s / (a_ho))^(2/5) · (ℏω_ref / 2)
  - R_TF ~ sqrt(2 μ_TF / (m ω_ref²)) / a_ho                    (dimless units)
  - box = R_TF × safety (per axis, scaled by trap aspect ratio)
  - n   = max(_DEFAULT_TF_NYQUIST, 2 · box · Nyquist density)

Returns a {n: [...], box: [...]} dict. Falls back to {n: 16³, box: 12³}
if any required physics constant is missing.
"""
function _auto_grid_from_physics(gs_step::Dict)
    fallback = Dict("n" => [16, 16, 16], "box" => [12.0, 12.0, 12.0])

    haskey(gs_step, "atom") && haskey(gs_step, "N_atoms") &&
        (haskey(gs_step, "omega_ref") || haskey(gs_step, "interactions")) ||
        return fallback

    atom_name = String(gs_step["atom"])
    N_atoms = Float64(gs_step["N_atoms"])
    omega_ref = if haskey(gs_step, "omega_ref")
        Float64(gs_step["omega_ref"])
    else
        inter = gs_step["interactions"]
        haskey(inter, "omega_ref") ? Float64(inter["omega_ref"]) : 314.159
    end

    # Resolve atom species
    atom = if atom_name == "Eu151";  Eu151
    elseif atom_name == "Dy164"; Dy164
    elseif atom_name == "Rb87";  Rb87
    elseif atom_name == "Cr52";  Cr52
    elseif atom_name == "Er168"; Er168
    else; return fallback
    end

    # Trap aspect ratio (relative trap freqs)
    omega_axes = if haskey(gs_step, "potential") && gs_step["potential"] isa AbstractDict
        omg = get(gs_step["potential"], "omega", nothing)
        omg isa AbstractVector ? Float64.(omg) : [1.0, 1.0, 1.0]
    else
        [1.0, 1.0, 1.0]
    end
    ndim = length(omega_axes)

    # Estimate dimless TF radius (geometric mean omega = 1 by construction)
    a_ho = sqrt(Units.HBAR / (atom.mass * omega_ref))
    a_s = atom.a_s
    # μ_TF in units of ℏω_ref:
    #   μ_TF/ℏω = 0.5·(15 N a_s / a_ho)^(2/5) (isotropic harmonic, scalar a_s)
    mu_dimless = 0.5 * (15.0 * N_atoms * a_s / a_ho)^(2.0 / 5.0)
    # R_TF per axis, dimless: sqrt(2 μ / ω_axis²)
    R_TF = [sqrt(2.0 * mu_dimless / ω^2) for ω in omega_axes]

    # box = R_TF × safety, n = max(_DEFAULT_TF_NYQUIST, ceil(2·box · Nyquist))
    # Nyquist density: ~2 grid points per natural-length unit a_ho is plenty
    # for ground states; raise for stir / dynamics if user wants finer.
    box = [R * _DEFAULT_TF_BOX_SAFETY for R in R_TF]
    n = [max(_DEFAULT_TF_NYQUIST, ceil(Int, 2 * b * 2)) for b in box]
    # round n to even powers of 2 for FFT efficiency
    n = [_round_to_efficient_fft(ni) for ni in n]

    Dict("n" => n, "box" => box)
end

# Round n to the nearest "FFT-friendly" value (multiples of 2/3/5).
function _round_to_efficient_fft(n::Int)
    n <= 16 && return 16
    n <= 24 && return 24
    n <= 32 && return 32
    n <= 48 && return 48
    n <= 64 && return 64
    n <= 96 && return 96
    n <= 128 && return 128
    # Above 128, round up to next multiple of 32
    return ((n + 31) ÷ 32) * 32
end
