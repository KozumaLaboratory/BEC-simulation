#!/usr/bin/env julia
# Compare the DIPOLAR KERNEL itself against Matsui et al.'s, on one fixed
# ground state. No dynamics, no new physics mode.
#
#     julia --project=. scripts/validation/matsui_kernel_field_compare.jl <run_dir>
#
# Adding a "reproduce their padding" arm to the propagator would not be a
# numerical knob — it would solve a different Hamiltonian, and it would put a
# knowingly-inexact kernel into the production term registry. The question does
# not need that: the kernel is a linear operator, so apply the candidates to the
# SAME density and read off the field they radiate.
#
#   (a) padded + spherical cutoff   our production default; removes the periodic
#                                   images exactly, i.e. free space
#   (b) padded, NO cutoff           their scheme: the analytic continuum kernel
#                                   sampled on the sn = 2 grid
#   (c) unpadded, no cutoff         the bare periodic kernel, for scale
#
# The dip centre is set by the density-weighted diagonal field, so that is what
# is reported, converted to nT via p = g_F µ_B B / (ħ ω_ref).

using SpinorBEC
using CodecZstd
using JLD2
using Printf

const HBAR = 1.054571817e-34
const MU_B = 9.27400949e-24
const OMEGA_REF = 691.1504
const N_ATOMS = 50_000

function main(run_dir)
    atom = Eu151
    a_ho = sqrt(HBAR / (atom.mass * OMEGA_REF))

    # point_001's top-level psi is the GROUND STATE — the scan defect, used here
    # on purpose. It is the state every field in the scan started from.
    psi = jldopen(joinpath(run_dir, "point_001.jld2"), "r") do d
        d["psi"]
    end
    n_pts = size(psi)[1:3]
    D = size(psi, 4)
    F = (D - 1) ÷ 2

    box = 16.0
    grid = make_grid(GridConfig((n_pts...,), ntuple(_ -> box, 3)))
    dV = prod(grid.dx)

    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    norm = sum(dens) * dV
    @printf("ground state: %s, ∫|ψ|² = %.6f, peak n = %.6e a_ho^-3\n",
        string(n_pts), norm, maximum(dens))

    # F_z density in the same normalisation the DDI term sees.
    fz = zeros(Float64, n_pts)
    for c in 1:D
        m = F - (c - 1)
        @views fz .+= m .* abs2.(psi[:, :, :, c])
    end
    @printf("⟨F_z⟩ = %.4f   (fully polarised would be %d)\n", sum(fz) * dV / norm, -F)

    # dipole_magnetic_field wants a magnetisation; any consistent scale works
    # because we take ratios and then convert once at the end. Use M = µ n in
    # dimensionless units and divide the µ₀ back out.
    zero3 = zeros(Float64, n_pts)
    arms = (
        ("(a) padded + cutoff  [ours, free space]", true, true),
        ("(b) padded, NO cutoff [their scheme]", true, false),
        ("(c) unpadded, no cutoff [bare periodic]", false, false),
    )

    p_per_nT = atom.g_F * MU_B * 1e-9 / (HBAR * OMEGA_REF)
    c_dd = compute_c_dd_dimless(atom; N_atoms=N_ATOMS, omega_ref=OMEGA_REF)

    results = Float64[]
    println()
    @printf("%-42s %14s %14s\n", "kernel", "⟨B_z⟩_n [nT]", "peak [nT]")
    for (label, padded, trunc) in arms
        _, _, Bz = dipole_magnetic_field(grid, zero3, zero3, fz; mu0=1.0,
            padded=padded, truncate=trunc)
        # Bz here is the Q-convolution of the F_z density; multiply by c_dd to get
        # the dimensionless field the Zeeman term competes with.
        phi = c_dd .* Bz
        mean_w = sum(phi .* dens) * dV / norm
        push!(results, mean_w / p_per_nT)
        @printf("%-42s %14.4f %14.4f\n", label,
            mean_w / p_per_nT, maximum(abs, phi) / p_per_nT)
    end

    println()
    @printf("(b) − (a)  =  %+.4f nT   ← the whole of their padding-without-cutoff choice\n",
        results[2] - results[1])
    @printf("(c) − (a)  =  %+.4f nT   ← bare periodic, which they do NOT use (sn = 2)\n",
        results[3] - results[1])
    println()
    println("measured dip centres:  ours -2.138 nT,  Matsui -2.549 nT,  gap 0.411 nT")
    println("If |(b) − (a)| ≪ 0.411 the kernel treatment is EXCLUDED as the explanation,")
    println("and the 84 %-closure seen in the dynamics factorial came from the unpadded")
    println("arm — a configuration neither code runs.")
end

isempty(ARGS) && error("usage: matsui_kernel_field_compare.jl <run_dir>")
main(ARGS[1])
