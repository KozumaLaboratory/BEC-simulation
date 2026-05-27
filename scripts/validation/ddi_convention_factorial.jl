#!/usr/bin/env julia
#
# DDI convention factorial — Level 5 sanity test for the dipolar
# kernel under variation of the documented convention axes.
#
# Each row of the output table is one combination of:
#   - cloud_shape  ∈ {spherical, prolate, oblate}
#   - B_axis       ∈ {:z, :x}   (changes which axis is the "long axis"
#                                from the dipole's point of view)
#   - secular      ∈ {false, true}
#   - grid_n       ∈ {16, 24}
#
# Expected physics (parameter contract §4):
#   - spherical polarised cloud → E_DDI / N → 0 as grid → ∞ (Q traceless)
#   - prolate along the B axis  → E_DDI / N < 0 (head-to-tail attractive)
#   - oblate perpendicular to B → E_DDI / N > 0 (side-by-side repulsive)
#   - axis flip (z ↔ x of the cloud + flip B) → E_DDI invariant
#     (rotational equivalence)
#   - secular vs full → agree when B ‖ z (Q_xy = Q_xz = Q_yz = 0 in both),
#                       disagree when B ‖ x (secular zeroes off-diagonals
#                       that the full kernel retains)
#
# This is the self-contained Level-5 evidence that the DDI implementation
# follows the parameter contract's convention sheet (post-2026-05-26
# pivot, see docs/validation/ueda_status.md).
#
# Output:
#   - prints a single-table summary to stdout
#   - writes `runs/ddi_convention_factorial/results.jld2` with the full
#     E_DDI matrix for later cross-reference
#
# Usage:
#   julia --project=. scripts/validation/ddi_convention_factorial.jl

using LinearAlgebra
using Printf
using JLD2
using SpinorBEC

const ATOM = Cr52   # native dipolar, c_dd ≈ μ₀·(g_F μ_B)² is meaningful
const C_DD = 10.0   # dimensionless probe value (1 Cr52 a₀-rescaled unit)
const BOX = 10.0    # box edge length (a_ho)

function _make_polarised_psi(grid::Grid{3}, F::Int; sigma::Tuple{Float64, Float64, Float64})
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    # Polarised along the m = +F axis (c=1 with this code's descending m).
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        env = exp(-x^2 / (2 * sigma[1]^2)
                  - y^2 / (2 * sigma[2]^2)
                  - z^2 / (2 * sigma[3]^2))
        psi[I, 1] = env
    end
    # Normalise to unit integral.
    nrm = sqrt(sum(abs2, psi) * cell_volume(grid))
    psi ./ nrm
end

function _make_polarised_along_x_psi(grid::Grid{3}, F::Int;
    sigma::Tuple{Float64, Float64, Float64})
    # Rotate polarisation onto +x: spinor = R_y(π/2) |m=+F⟩.
    # For a uniform spin rotation, ψ_c'(r) = Σ_c R_{c'c} ψ_c(r).
    psi_z = _make_polarised_psi(grid, F; sigma=sigma)
    sm = spin_matrices(F)
    # Rotation matrix R = exp(-i (π/2) F_y) puts |m=+F⟩_z → |m_x=+F⟩.
    # Reuse production's `apply_uniform_spin_rotation!` for parity.
    psi = copy(psi_z)
    SpinorBEC.apply_uniform_spin_rotation!(psi, sm, 0.0, π / 2, 0.0, 1.0, 3;
        imaginary_time=false)
    psi
end

function _e_ddi(shape::Symbol, B_axis::Symbol, secular::Bool, n::Int)
    F = ATOM.F
    grid = make_grid(GridConfig{3}((n, n, n), (BOX, BOX, BOX)))
    # Cloud width by shape (sigma); chosen so all variants fit comfortably
    # in the box.
    sigma_long = 2.0
    sigma_short = 1.0
    sigma = if shape === :spherical
        (1.5, 1.5, 1.5)
    elseif shape === :prolate
        # Long axis aligned with B
        if B_axis === :z
            (sigma_short, sigma_short, sigma_long)
        else
            (sigma_long, sigma_short, sigma_short)
        end
    elseif shape === :oblate
        # Short axis aligned with B (pancake perpendicular to B)
        if B_axis === :z
            (sigma_long, sigma_long, sigma_short)
        else
            (sigma_short, sigma_long, sigma_long)
        end
    else
        error("unknown shape: $shape")
    end

    psi0 = if B_axis === :z
        _make_polarised_psi(grid, F; sigma=sigma)
    else
        _make_polarised_along_x_psi(grid, F; sigma=sigma)
    end

    interactions = InteractionParams(Dict{Int, Float64}())   # DDI-only
    sp = SimParams(; dt=0.001, n_steps=1)
    ws = make_workspace(; grid, atom=ATOM, interactions,
        zeeman=ZeemanParams(0.0, 0.0),
        potential=NoPotential(),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD, secular_ddi=secular,
        psi_init=psi0,
    )
    energy_decomposition(ws).ddi
end

function main()
    shapes = (:spherical, :prolate, :oblate)
    axes_ = (:z, :x)
    seculars = (false, true)
    grids = (16, 24)

    rows = Vector{NamedTuple{(:shape, :axis, :secular, :n, :E_ddi), Tuple{Symbol, Symbol, Bool, Int, Float64}}}()
    println("# DDI convention factorial — E_DDI / N (c_dd = $(C_DD), atom = $(ATOM.name))")
    @printf("%-12s %-7s %-9s %-5s %-15s\n", "shape", "B_axis", "secular", "n", "E_DDI")
    println(repeat("-", 60))
    for shape in shapes, axis in axes_, secular in seculars, n in grids
        E = _e_ddi(shape, axis, secular, n)
        push!(rows, (shape=shape, axis=axis, secular=secular, n=n, E_ddi=E))
        @printf("%-12s %-7s %-9s %-5d %-15.6e\n",
            String(shape), String(axis), string(secular), n, E)
    end

    # Self-consistency checks (the physics expectations).
    println()
    println("# Sanity checks")
    function pick(shape, axis, secular, n)
        for r in rows
            r.shape === shape && r.axis === axis && r.secular === secular && r.n === n &&
                return r.E_ddi
        end
        NaN
    end

    function check(label, condition)
        status = condition ? "PASS" : "FAIL"
        println("  [$status] $label")
        condition
    end

    pass1 = check("spherical, B=z, full: |E_DDI| ≤ |E_DDI_prolate, B=z, full|",
        abs(pick(:spherical, :z, false, 24)) ≤
        abs(pick(:prolate, :z, false, 24)))
    pass2 = check("prolate, B=z, full: E_DDI < 0 (head-to-tail attractive)",
        pick(:prolate, :z, false, 24) < 0)
    pass3 = check("oblate, B=z, full: E_DDI > 0 (side-by-side repulsive)",
        pick(:oblate, :z, false, 24) > 0)
    pass4 = check("axis flip (B=z prolate-z ↔ B=x prolate-x) under full: agree to 3%",
        abs(pick(:prolate, :z, false, 24) - pick(:prolate, :x, false, 24)) /
        max(abs(pick(:prolate, :z, false, 24)),
            abs(pick(:prolate, :x, false, 24))) < 0.03)
    # Secular vs full agree for B=z (Q_xy = Q_xz = Q_yz vanish anyway when
    # spin density is z-polarised).
    pass5 = check("secular ≡ full when B=z, polarized along z (off-diagonal Q hits zero spin)",
        abs(pick(:prolate, :z, false, 24) - pick(:prolate, :z, true, 24)) /
        abs(pick(:prolate, :z, false, 24)) < 1e-10)
    # Spherical case (traceless Q on isotropic spin density) → E_DDI = 0
    # within machine precision relative to the physically-meaningful
    # prolate scale.
    pass6 = check("|E_DDI_spherical| < 1e-10 × |E_DDI_prolate| at every (n, B_axis)",
        all(
            abs(pick(:spherical, ax, false, n)) <
            1e-10 * abs(pick(:prolate, :z, false, n))
            for ax in (:z, :x), n in (16, 24)
        ))

    all_pass = pass1 && pass2 && pass3 && pass4 && pass5 && pass6

    # Write results.
    outdir = joinpath(@__DIR__, "..", "..", "runs", "ddi_convention_factorial")
    mkpath(outdir)
    outpath = joinpath(outdir, "results.jld2")
    jldopen(outpath, "w") do f
        f["c_dd"] = C_DD
        f["box"] = BOX
        f["atom_name"] = ATOM.name
        f["atom_F"] = ATOM.F
        f["rows"] = rows
        f["all_pass"] = all_pass
        f["timestamp"] = string(Dates.now())
    end
    println("\nWrote $outpath")

    exit(all_pass ? 0 : 1)
end

using Dates
main()
