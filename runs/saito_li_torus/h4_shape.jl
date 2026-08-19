# What shape is a converged cell, actually?
#
# The bistability arm needs to distinguish a torus from a cigar, and the
# quantities `h3_cells.jl` prints (<r>, sigma_x, sigma_z) are all tied to the
# LAB axes. A torus whose symmetry axis is not z reads as neither shape in
# those numbers. The rotation-invariant statement is the sorted eigenvalue
# triple of the second-moment tensor <r_a r_b> plus the eigenvector of the odd
# one out, which IS the symmetry axis:
#
#   torus : two large equal eigenvalues + one small   (oblate)
#   cigar : one large + two small equal               (prolate)
#
# and the magnetization circulation about that axis separates a magnetic vortex
# from a plain density torus.
#
#   julia --project=. runs/saito_li_torus/h4_shape.jl [out/cell_*.jld2 ...]

using SpinorBEC
using SpinorBEC:
    make_grid, GridConfig, total_density, spin_density_vector,
    spin_matrices, ATOM_REGISTRY, Units
using JLD2, Printf, LinearAlgebra

const ATOM = ATOM_REGISTRY[:Eu151]
const A_HO_UM = sqrt(Units.HBAR / (ATOM.mass * 691.15)) * 1e6
const F = 6

function shape(file)
    d = load(file)
    psi = d["psi"]
    grid = make_grid(GridConfig{3}(Tuple(d["n"]), Tuple(d["box"])))
    rho = total_density(psi, 3)
    dV = prod(grid.x[k][2] - grid.x[k][1] for k in 1:3)
    norm = sum(rho) * dV

    M = zeros(3, 3)
    com = zeros(3)
    @inbounds for I in CartesianIndices(rho)
        r = (grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]])
        w = rho[I] * dV / norm
        for a in 1:3
            com[a] += w * r[a]
            for b in 1:3
                M[a, b] += w * r[a] * r[b]
            end
        end
    end
    for a in 1:3, b in 1:3
        M[a, b] -= com[a] * com[b]
    end
    ev = eigen(Symmetric(M))
    lam = ev.values                # ascending
    # oblate (torus): the SMALLEST moment is the unique one (thin direction)
    # prolate (cigar): the LARGEST moment is the unique one (long direction)
    # Taking the smallest eigenvector unconditionally — as the first draft did —
    # hands back an arbitrary vector in the degenerate short plane of a cigar,
    # and then <f.axis> reads 0 for a state fully polarised along its long axis.
    oblate = (lam[3] - lam[2]) / lam[3] < 0.05 && (lam[2] - lam[1]) / lam[2] > 0.3
    prolate = (lam[2] - lam[1]) / lam[2] < 0.05 && (lam[3] - lam[2]) / lam[3] > 0.3
    axis = prolate ? ev.vectors[:, 3] : ev.vectors[:, 1]

    # circulation of the magnetization about `axis`, density-weighted:
    # (1/N) int rho * (f_hat . phi_hat_axis)
    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    circ = 0.0
    wsum = 0.0
    fzax = 0.0
    @inbounds for I in CartesianIndices(rho)
        r = [grid.x[1][I[1]] - com[1], grid.x[2][I[2]] - com[2],
            grid.x[3][I[3]] - com[3]]
        f = [fx[I], fy[I], fz[I]]
        fn = norm2(f)
        fn > 1e-14 || continue
        perp = r - dot(r, axis) * axis
        pn = norm2(perp)
        pn > 1e-6 || continue
        phi_hat = cross(axis, perp) / pn
        w = rho[I] * dV
        circ += w * dot(f, phi_hat) / fn
        fzax += w * dot(f, axis) / fn
        wsum += w
    end
    circ /= wsum
    fzax /= wsum

    (; file=basename(file), lam, axis, oblate, prolate, circ, f_along_axis=fzax,
        rho_max=maximum(rho) / A_HO_UM^3, com)
end

norm2(v) = sqrt(sum(abs2, v))

function main(files)
    isempty(files) && (
        files = sort(
            filter(f -> endswith(f, ".jld2"),
                readdir(joinpath(@__DIR__, "out"); join=true)),
        )
    )
    println("="^96)
    println("second-moment eigenvalues (a_ho^2, ascending), symmetry axis, and")
    println("the magnetization circulation about it  (+-1 = perfect magnetic vortex)")
    println("="^96)
    for f in files
        s = shape(f)
        cls = if s.oblate
            "TORUS (oblate)"
        elseif s.prolate
            "CIGAR (prolate)"
        else
            "neither"
        end
        @printf("\n%s\n", s.file)
        @printf("  lambda_i     = [%.5f, %.5f, %.5f]  a_ho^2\n", s.lam...)
        @printf("  sqrt(lam_i)  = [%.5f, %.5f, %.5f]  a_ho\n", sqrt.(s.lam)...)
        @printf("  classification = %s   (lam3-lam2)/lam3=%.4f  (lam2-lam1)/lam2=%.4f\n",
            cls, (s.lam[3] - s.lam[2]) / s.lam[3], (s.lam[2] - s.lam[1]) / s.lam[2])
        @printf("  symmetry axis (smallest moment) = [%+.4f, %+.4f, %+.4f]\n", s.axis...)
        @printf("  <f_hat . phi_hat> about that axis = %+.5f   <- magnetic vortex\n", s.circ)
        @printf("  <f_hat . axis>                     = %+.5f\n", s.f_along_axis)
        @printf("  rho_max = %.5f N um^-3\n", s.rho_max)
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main(ARGS)
