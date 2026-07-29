# Dipolar magnetic field radiated by a spin-polarised ¹⁵¹Eu cloud.
#
# End-to-end analogue of the MATLAB DBEC-GP post-processing, but the density
# comes from this project's own ground state instead of imag3d-den.txt:
#
#   density n(r)  →  magnetisation M = μ_atom·n·ẑ  →  B(r) = -μ₀ ℱ⁻¹{Σ Q·M̃}
#
# Produces the x–z slice (|B| heatmap + in-plane quiver + density contour),
# the same view with an external bias field added, and the local tilt-angle
# map (angle between B and ẑ) that the rotation/Larmor analysis builds on.
#
# Run:  julia --project=. scripts/dipole_field_demo.jl [outdir]
# A real ITP ground state can be swapped in where noted; the Thomas-Fermi seed
# keeps the demo to a few seconds on CPU.

using SpinorBEC
using SpinorBEC: Units
using JLD2

const OUTDIR = get(ARGS, 1, joinpath(@__DIR__, "..", "runs", "dipole_field_demo"))
mkpath(OUTDIR)

# Plotting is optional: it needs a Makie backend (CairoMakie / GLMakie) on top
# of the SpinorBECMakieExt. When none is installed we still compute the field,
# write the slice data, and print the physics summary — plot from the JLD2 with
# any tool, or `plot_dipole_field(...)` once a backend is loaded.
const _MAKIE_BACKEND = something(
    Base.find_package("CairoMakie") === nothing ? nothing : :CairoMakie,
    Base.find_package("GLMakie") === nothing ? nothing : :GLMakie,
    Some(nothing),
)

# --- Physical scale (¹⁵¹Eu, ω = 2π·110 Hz horizontal trap) ---
atom = SpinorBEC.Eu151
ω_ref = 2π * 110.0                                   # rad/s
a_ho = sqrt(Units.HBAR / (atom.mass * ω_ref))        # m
n_atoms = 5.0e4

@info "scale" a_ho_um = a_ho * 1e6 n_atoms

# --- Grid + spin system ---
F = atom.F
sys = SpinSystem(F)
nx = 48
L = 16.0                                             # box half-width 8 a_ho
grid = make_grid(GridConfig((nx, nx, nx), (L, L, L)))

# --- Density: oblate Gaussian cloud (ωz > ω⊥ → squashed along z), fully ---
# --- spin-polarised along z. Swap for `find_ground_state(...)` for a    ---
# --- true ground state; the field machinery is identical either way.    ---
x, y, z = grid.x
σ⊥, σz = 2.2, 1.6                                     # a_ho; oblate like the lab trap
psi_pol = zeros(ComplexF64, nx, nx, nx, sys.n_components)
amp = [exp(-(x[i]^2 + y[j]^2) / (2σ⊥^2) - z[k]^2 / (2σz^2)) for i in 1:nx, j in 1:nx, k in 1:nx]
amp ./= sqrt(sum(abs2, amp) * cell_volume(grid))     # ∫|ψ|² dV = 1
psi_pol[:, :, :, 1] .= amp                           # c=1 ↔ m=+F (stretched)
density = total_density(psi_pol, 3)

# --- Dipolar magnetic field [tesla] ---
Bx, By, Bz = magnetic_field_from_density(
    grid, density; atom, a_ho, n_atoms, polarization=(0, 0, 1), padded=true
)
Btot = @. sqrt(Bx^2 + By^2 + Bz^2)
@info "self-field" Bz_peak_G = maximum(abs, Bz) * 1e4 Btot_peak_G = maximum(Btot) * 1e4

# --- External bias field along z (matching the MATLAB reference's Bfin), ---
# --- total field + local tilt. Chosen comparable to the self-field, so   ---
# --- the local quantisation axis rotates substantially (the point of the ---
# --- rotation/Larmor analysis).                                          ---
B_ext = 126e-6 * 1e-4                                # tesla (= 1.26e-8 T ≈ 0.126 mG)
Bz_ext = Bz .+ B_ext
Btot_ext = @. sqrt(Bx^2 + By^2 + Bz_ext^2)
tilt = @. acos(clamp(Bz_ext / Btot_ext, -1, 1))      # rad, angle of B from ẑ
ic = nx ÷ 2 + 1
@info "tilt (with bias)" B_ext_mG = B_ext * 1e7 tilt_max_deg = maximum(tilt[:, ic, :]) * 180 / π

# --- Persist x–z slices (axes + field + density) for plotting by any tool ---
datafile = joinpath(OUTDIR, "dipole_field_xz.jld2")
jldsave(datafile;
    x=grid.x[1], z=grid.x[3], a_ho, n_atoms,
    density_xz=density[:, ic, :],
    Bx_xz=Bx[:, ic, :], Bz_xz=Bz[:, ic, :], Btot_xz=Btot[:, ic, :],
    Bz_ext_xz=Bz_ext[:, ic, :], Btot_ext_xz=Btot_ext[:, ic, :],
    tilt_xz=tilt[:, ic, :], B_ext=B_ext,
)
@info "slice data written" file = datafile

# --- Optional Makie figures (only if a backend is installed) ---
if _MAKIE_BACKEND === nothing
    @info "no Makie backend installed — skipping PNGs. Plot $(basename(datafile)) " *
        "with any tool, or load CairoMakie and call plot_dipole_field(...)."
else
    @eval using $_MAKIE_BACKEND
    fig1 = plot_dipole_field(grid, density, Bx, By, Bz; plane=:xz,
        title="¹⁵¹Eu self-field (x–z)")
    Main.save(joinpath(OUTDIR, "self_field_xz.png"), fig1)
    fig2 = plot_dipole_field(grid, density, Bx, By, Bz_ext; plane=:xz,
        title="with z bias (x–z)")
    Main.save(joinpath(OUTDIR, "with_bias_xz.png"), fig2)
    @info "figures written" dir = OUTDIR
end
