# Resolution + Sinatra-criterion utilities for spinor BEC simulation
# planning (analysis-layer diagnostics; not wired into make_workspace or
# the YAML schema — planning helpers a user calls by hand).
#
# Two diagnostics:
#   * `suggest_grid(species, n_atoms; ...)` returns a recommended
#     `(Lx, Ly, Lz, nx, ny, nz)` based on contact healing length
#     vs. target resolution, with a warning string when the
#     resulting dx is too coarse to resolve the dipolar filament
#     (the May-7 bug avoidance: dx > ξ_healing means cloud profile
#     is grid-resolution-bound, σ/μ measurements lose meaning).
#   * `sinatra_check(grid_spec, n_atoms; ...)` returns the Sinatra
#     ratio N_modes_eff × D / N_atoms with a verdict band
#     (clean / marginal / contaminated).
#
# Atom data (F, mass, scalar scattering length a0) comes from the
# canonical `ATOM_REGISTRY` via `resolve_atom`; SI constants from `Units`.

export suggest_grid, sinatra_check

# Short-name aliases onto the canonical ATOM_REGISTRY keys.
const _SINATRA_SPECIES_ALIAS = Dict{Symbol, Symbol}(
    :Eu => :Eu151, :Cr => :Cr52, :Er => :Er168, :Dy => :Dy164
)

_lookup_species(s::Symbol) = resolve_atom(get(_SINATRA_SPECIES_ALIAS, s, s))

@inline _next_pow2(n::Integer) = n <= 1 ? 1 : 2^ceil(Int, log2(n))

"""
    suggest_grid(species, n_atoms; trap_ωxy, trap_ωz, ε_dd_target,
                 target_resolution, n_peak_estimate)

Return a recommended grid + box pair for a spinor BEC of `species`
(symbol like `:Eu151` or `:Eu`) with `n_atoms` total atoms, in a
harmonic trap with radial frequency `trap_ωxy` (rad/s, default
2π·1000 Hz) and axial `trap_ωz` (rad/s, default 2π·100 Hz).

The recommendation aims for grid spacing `dx ≤ ξ / target_resolution`
where `ξ` is the contact healing length at peak density, so that the
dipolar-collapse filament (whose minimum spatial scale is set by ξ)
is sampled by at least `target_resolution` grid points across.

Optional `n_peak_estimate` overrides the Thomas-Fermi peak-density
estimate; supply this if you have a better prior, e.g. from a deterministic
GS run.

Returns `NamedTuple` with fields:
- `Lx, Ly, Lz`  box edges in `a_ho` (geometric-mean trap units)
- `nx, ny, nz` grid points per axis (next-power-of-2)
- `dx`         resulting grid spacing (a_ho)
- `xi`         contact healing length at the assumed peak density (a_ho)
- `ratio`      Sinatra ratio (N_modes × D) / N_atoms
- `warning`    `nothing` or a string flagging an issue

`ε_dd_target` is currently informational (will gate dipolar-corrections
in a future iteration).
"""
function suggest_grid(species::Symbol, n_atoms::Real;
    trap_ωxy::Real=2π * 1000,
    trap_ωz::Real=2π * 100,
    ε_dd_target::Union{Nothing, Real}=nothing,
    target_resolution::Int=4,
    n_peak_estimate::Union{Nothing, Real}=nothing,
)
    n_atoms > 0 || throw(ArgumentError("n_atoms must be positive"))
    target_resolution >= 1 || throw(ArgumentError("target_resolution must be ≥ 1"))

    sp = _lookup_species(species)
    M = sp.mass                         # kg (canonical ATOM_REGISTRY value)
    a_s = sp.a0                         # m, scalar background scattering length
    D = 2 * sp.F + 1

    # Geometric-mean trap frequency → reference oscillator
    ω_ref = (trap_ωxy^2 * trap_ωz)^(1 / 3)
    a_ho = sqrt(Units.HBAR / (M * ω_ref))   # m
    aspect_z = trap_ωz / ω_ref          # axial trap aspect ratio

    # Dimensionless coupling (4π·a_s/a_ho · N) — appears in the
    # dimensionless GP equation
    c_total = 4π * (a_s / a_ho) * n_atoms

    # Thomas-Fermi peak density (dimensionless): n_peak ≈ μ/c_total
    # with μ = (1/2)·(15·c_total·aspect_z / 8π)^(2/5) — standard 3D TF
    if n_peak_estimate === nothing
        μ_dimless = 0.5 * (15 * c_total * aspect_z / (8π))^(2 / 5)
        n_peak = μ_dimless / c_total
    else
        n_peak = Float64(n_peak_estimate)
    end
    n_peak <= 0 && (n_peak = 1.0)       # safety fallback

    # Contact healing length (dimensionless: ξ = 1/√(2·c_total·n_peak))
    ξ = 1.0 / sqrt(2.0 * c_total * n_peak)

    # Required grid spacing
    required_dx = ξ / target_resolution

    # Thomas-Fermi radius (radial), with buffer for cloud edge
    R_TF = (15 * c_total * aspect_z / (8π))^(1 / 5)
    L = 2.0 * R_TF * 1.5    # 1.5× buffer beyond R_TF on each side

    # Grid points: round up to next power of 2 of L / required_dx
    nx_raw = ceil(Int, L / required_dx)
    nx = max(_next_pow2(nx_raw), 16)    # never below 16
    actual_dx = L / nx

    # Sinatra ratio
    n_modes = nx^3
    ratio = n_modes * D / Float64(n_atoms)

    # Warning
    warning = if actual_dx > ξ
        "dx = $(round(actual_dx; digits=3)) > ξ = $(round(ξ; digits=3)) " *
        "(under-resolved — May-7 bug regime, cloud profile grid-bound)"
    elseif actual_dx > ξ / target_resolution
        "dx = $(round(actual_dx; digits=3)) above target $(round(required_dx; digits=3)) " *
        "(coarsened by power-of-2 rounding)"
    elseif ratio > 10
        "Sinatra ratio = $(round(ratio; digits=1)) > 10 " *
        "(contaminated; consider coarser grid or fewer points)"
    elseif ratio > 1
        "Sinatra ratio = $(round(ratio; digits=2)) > 1 (marginal)"
    else
        nothing
    end

    return (
        Lx=L, Ly=L, Lz=L * aspect_z,
        nx=nx, ny=nx, nz=nx,
        dx=actual_dx,
        xi=ξ,
        ratio=ratio,
        warning=warning,
    )
end

"""
    sinatra_check(grid_spec, n_atoms; F, k_cutoff_method, c_total, n_peak,
                  k_cutoff_value)

Compute the Sinatra ratio for a given grid + atom-number combination.
`grid_spec` is a NamedTuple with fields `nx, ny, nz, Lx, Ly, Lz` (or any
object exposing those — duck-typed via `getproperty`).

`k_cutoff_method` is one of:
- `:full`             count all `nx · ny · nz` modes (no cutoff)
- `:healing_length`   count modes with `|k| ≤ 2 / ξ`, where
                      `ξ = 1/√(2·c_total·n_peak)` (caller supplies
                      `c_total` and `n_peak`)
- `:fixed`            count modes with `|k| ≤ k_cutoff_value` (caller
                      supplies `k_cutoff_value`)

`F` is the spinor magnitude (default 6 for Eu); the spinor-component
factor `D = 2F + 1` multiplies the mode count.

Returns `NamedTuple`:
- `n_modes`     effective mode count (×D not yet applied)
- `n_modes_eff` n_modes × D
- `ratio`       n_modes_eff / n_atoms (the Sinatra ratio)
- `verdict`     `:clean` (< 1), `:marginal` (1 ≤ ratio ≤ 10), or
                `:contaminated` (> 10)
"""
function sinatra_check(grid_spec, n_atoms::Real;
    F::Int=6,
    k_cutoff_method::Symbol=:healing_length,
    c_total::Union{Nothing, Real}=nothing,
    n_peak::Union{Nothing, Real}=nothing,
    k_cutoff_value::Union{Nothing, Real}=nothing,
)
    n_atoms > 0 || throw(ArgumentError("n_atoms must be positive"))
    nx = Int(getproperty(grid_spec, :nx))
    ny = Int(getproperty(grid_spec, :ny))
    nz = Int(getproperty(grid_spec, :nz))
    Lx = Float64(getproperty(grid_spec, :Lx))
    Ly = Float64(getproperty(grid_spec, :Ly))
    Lz = Float64(getproperty(grid_spec, :Lz))
    D = 2F + 1

    n_total = nx * ny * nz

    n_modes = if k_cutoff_method === :full
        n_total
    elseif k_cutoff_method === :healing_length
        c_total === nothing &&
            throw(ArgumentError(":healing_length requires `c_total`"))
        n_peak === nothing &&
            throw(ArgumentError(":healing_length requires `n_peak`"))
        ξ = 1.0 / sqrt(2.0 * Float64(c_total) * Float64(n_peak))
        k_cut = 2.0 / ξ
        _count_modes_below(nx, ny, nz, Lx, Ly, Lz, k_cut)
    elseif k_cutoff_method === :fixed
        k_cutoff_value === nothing &&
            throw(ArgumentError(":fixed requires `k_cutoff_value`"))
        _count_modes_below(nx, ny, nz, Lx, Ly, Lz, Float64(k_cutoff_value))
    else
        throw(ArgumentError(
            "k_cutoff_method must be :full / :healing_length / :fixed"))
    end

    n_modes_eff = n_modes * D
    ratio = n_modes_eff / Float64(n_atoms)
    verdict = if ratio < 1.0
        :clean
    elseif ratio <= 10.0
        :marginal
    else
        :contaminated
    end

    return (n_modes=n_modes, n_modes_eff=n_modes_eff,
        ratio=ratio, verdict=verdict)
end

# --- Helpers ----------------------------------------------------------------

# Count plane-wave modes (kx, ky, kz) with √(kx² + ky² + kz²) ≤ k_cut.
# Uses the standard fftfreq layout `2π·m/L` for `m ∈ {-n/2, ..., n/2-1}`.
function _count_modes_below(nx, ny, nz, Lx, Ly, Lz, k_cut::Real)
    k_cut_sq = Float64(k_cut)^2
    dkx = 2π / Lx
    dky = 2π / Ly
    dkz = 2π / Lz
    count = 0
    @inbounds for ix in 0:(nx - 1)
        mx = ix < nx ÷ 2 ? ix : ix - nx
        kx = mx * dkx
        kx2 = kx * kx
        kx2 > k_cut_sq && continue
        for iy in 0:(ny - 1)
            my = iy < ny ÷ 2 ? iy : iy - ny
            ky = my * dky
            ky2 = ky * ky
            kx2 + ky2 > k_cut_sq && continue
            for iz in 0:(nz - 1)
                mz = iz < nz ÷ 2 ? iz : iz - nz
                kz = mz * dkz
                kz2 = kz * kz
                if kx2 + ky2 + kz2 <= k_cut_sq
                    count += 1
                end
            end
        end
    end
    count
end
