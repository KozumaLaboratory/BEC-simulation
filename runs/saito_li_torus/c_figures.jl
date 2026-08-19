# Emit the comparison data for issue #336 as CSV, from the jld2 that
# `b_cells.jl` writes. Plotting is `c_plot.py` (matplotlib); this side only
# reduces the wave function, so the numbers in the figure and the numbers in
# the report come from one place.
#
#   julia --project=. runs/saito_li_torus/c_figures.jl
#
# Emits, per cell, into runs/saito_li_torus/out/:
#   profile_<cell>.csv    rho(r, z=0) azimuthally averaged, in N um^-3
#   slice_z0_<cell>.csv   rho(x, y, z=0) map
#   slice_y0_<cell>.csv   rho(x, z, y=0) map
#   spin_z0_<cell>.csv    f(x,y) on z=0, decimated, for the arrow overlay
#   variational.csv       the paper's ansatz on the same radial grid

using SpinorBEC
using SpinorBEC: make_grid, GridConfig, total_density, spin_density_vector,
    spin_matrices, ATOM_REGISTRY, Units, compute_a_dd
using JLD2
using Printf
using SpecialFunctions: loggamma

include(joinpath(@__DIR__, "..", "yls_barnett_f6", "a2_variational_stability.jl"))

const OUT = joinpath(@__DIR__, "out")
const ATOM = ATOM_REGISTRY[:Eu151]
const A_HO_UM = sqrt(Units.HBAR / (ATOM.mass * 691.15)) * 1e6
const F = 6

writecsv(path, header, cols) = open(path, "w") do io
    println(io, header)
    for i in eachindex(cols[1])
        println(io, join((c[i] for c in cols), ","))
    end
end

"Paper's variational rho(r, z) in N um^-3, r and z in um."
function variational_rho(r_um, z_um; N=15000, eps_dd=1.3)
    a_s = compute_a_dd(ATOM) / eps_dd
    L0 = a_s * N * 1e6
    D0 = 1 / ((a_s * 1e6)^3 * N^2)
    d = droplet(; eps_dd=eps_dd, N=N, F=F, l=0)
    sr, sz, lam = d.sigma_r * L0, d.sigma_z * L0, d.lambda
    A = exp(-(1.5log(π) + (2lam + 2)log(sr) + log(sz) + loggamma(lam + 1)))
    # A is in units of 1/L0^3 with rho = N * A * r^(2lam) exp(...); D0 folds N out
    [A * r^(2lam) * exp(-r^2 / sr^2 - z_um^2 / sz^2) for r in r_um]
end

function emit(cellfile)
    name = replace(basename(cellfile), "cell_" => "", ".jld2" => "")
    d = load(cellfile)
    psi = d["psi"]
    box = d["box"]
    n = d["n"]
    grid = make_grid(GridConfig{3}(Tuple(n), Tuple(box)))
    rho = total_density(psi, 3)
    iz = argmin(abs.(grid.x[3]))
    iy = argmin(abs.(grid.x[2]))

    # radial profile (already computed in b_cells, recomputed here so the CSV
    # and the report cannot drift apart)
    p = d["profile"]
    writecsv(joinpath(OUT, "profile_$name.csv"),
        "r_um,r_aho,rho_N_um3,n_voxels",
        (p.r_um, p.r_aho, p.rho_N_um3, p.counts))

    xs = collect(grid.x[1]) .* A_HO_UM
    ys = collect(grid.x[2]) .* A_HO_UM
    zs = collect(grid.x[3]) .* A_HO_UM
    open(joinpath(OUT, "slice_z0_$name.csv"), "w") do io
        println(io, "# rho(x,y,z=0) in N um^-3; first row = y [um], first col = x [um]")
        println(io, "x_um," * join(ys, ","))
        for i in eachindex(xs)
            println(io, xs[i], ",",
                join((rho[i, j, iz] / A_HO_UM^3 for j in eachindex(ys)), ","))
        end
    end
    open(joinpath(OUT, "slice_y0_$name.csv"), "w") do io
        println(io, "# rho(x,z,y=0) in N um^-3; first row = z [um], first col = x [um]")
        println(io, "x_um," * join(zs, ","))
        for i in eachindex(xs)
            println(io, xs[i], ",",
                join((rho[i, iy, k] / A_HO_UM^3 for k in eachindex(zs)), ","))
        end
    end

    sm = spin_matrices(F)
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    stride = max(1, length(xs) ÷ 24)
    ix = 1:stride:length(xs)
    jy = 1:stride:length(ys)
    writecsv(joinpath(OUT, "spin_z0_$name.csv"), "x_um,y_um,fx,fy,fz,rho_N_um3",
        ([xs[i] for i in ix for _ in jy],
            [ys[j] for _ in ix for j in jy],
            [fx[i, iy0, iz] for i in ix for iy0 in jy],
            [fy[i, iy0, iz] for i in ix for iy0 in jy],
            [fz[i, iy0, iz] for i in ix for iy0 in jy],
            [rho[i, iy0, iz] / A_HO_UM^3 for i in ix for iy0 in jy]))

    @printf("  %-16s n=%s box=%s  rho_max=%.5f N/um3  git=%s\n", name, n, box,
        maximum(rho) / A_HO_UM^3, get(d, "git_hash", "?"))
    (name, p)
end

function main()
    mkpath(OUT)
    files = sort(
        filter(f -> startswith(basename(f), "cell_") && endswith(f, ".jld2"),
            readdir(OUT; join=true)),
    )
    isempty(files) && (println("no cell_*.jld2 in $OUT — run b_cells.jl first"); return nothing)
    println("emitting figure data from $(length(files)) cells:")
    out = [emit(f) for f in files]

    # variational curve on a fine radial grid, for overlay
    rs = collect(range(0.0, 2.6; length=400))
    writecsv(joinpath(OUT, "variational.csv"), "r_um,rho_N_um3",
        (rs, variational_rho(rs, 0.0)))
    println("  variational.csv (paper's ansatz, same units)")
    out
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
