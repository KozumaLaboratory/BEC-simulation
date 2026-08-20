# Does the Fig. 5 array alternate its circulation?
#
#   "multiple droplets with magnetic vortices are aligned along the x axis with
#    ALTERNATE circulations of the magnetic vortices"
#
# That is the paper's specific structural claim and it is a DISCRETE
# observable: a sequence of signs, no error bar and no calibration. The
# modulation contrast in `h9_supersolid.jl` says the density is periodic; it
# says nothing about the spin.
#
# Method: split the cloud at the minima of the integrated line density, then
# for each segment measure the density-weighted circulation of f about the z
# axis through that segment's own centre of mass,
#
#     C_k = < f_hat . phi_hat_k >     phi_hat_k = z_hat x (r - R_k) / |...|
#
# A perfect magnetic vortex gives C_k = +-1. Reporting |C_k| as well as the
# sign matters: a segment that is not a vortex at all also has no sign.
#
#   julia --project=. runs/saito_li_torus/h12_fig5_chirality.jl

using SpinorBEC
using SpinorBEC:
    make_grid, GridConfig, total_density, spin_density_vector,
    spin_matrices, ATOM_REGISTRY, Units
using JLD2, Printf, LinearAlgebra

const OUT = joinpath(@__DIR__, "out")
const A_HO_UM =
    sqrt(Units.HBAR / (ATOM_REGISTRY[:Eu151_f1_effective].mass * 691.15)) * 1e6

"Interior minima of `line` inside the region carrying the cloud."
function segment_bounds(line; frac=0.05)
    thr = frac * maximum(line)
    idx = findall(>(thr), line)
    isempty(idx) && return Int[]
    lo, hi = first(idx), last(idx)
    seg = line[lo:hi]
    mins = [i + lo - 1 for i in 2:(length(seg) - 1)
                           if seg[i] < seg[i - 1] && seg[i] < seg[i + 1]]
    vcat(lo, mins, hi)
end

function chirality(file)
    d = load(file)
    psi = d["psi"]
    grid = make_grid(GridConfig{3}(Tuple(d["n"]), Tuple(d["box"])))
    rho = total_density(psi, 3)
    dV = prod(grid.x[k][2] - grid.x[k][1] for k in 1:3)
    line = vec(sum(rho; dims=(2, 3)))
    b = segment_bounds(line)
    length(b) < 3 && return (; name=basename(file), n=0, C=Float64[], E=d["E"])

    sm = spin_matrices(1)
    fx, fy, fz = spin_density_vector(psi, sm, 3)
    C = Float64[]
    W = Float64[]
    for s in 1:(length(b) - 1)
        i0, i1 = b[s], b[s + 1]
        # centre of mass of this segment, in the xy-plane
        cx = cy = wsum = 0.0
        for i in i0:i1, j in axes(rho, 2), k in axes(rho, 3)
            w = rho[i, j, k]
            wsum += w
            cx += w * grid.x[1][i]
            cy += w * grid.x[2][j]
        end
        wsum > 0 || continue
        cx /= wsum
        cy /= wsum
        num = den = 0.0
        for i in i0:i1, j in axes(rho, 2), k in axes(rho, 3)
            x = grid.x[1][i] - cx
            y = grid.x[2][j] - cy
            r = hypot(x, y)
            r > 1e-6 || continue
            f = (fx[i, j, k], fy[i, j, k], fz[i, j, k])
            fn = sqrt(f[1]^2 + f[2]^2 + f[3]^2)
            fn > 1e-14 || continue
            # phi_hat = z_hat x r_perp / |r_perp| = (-y, x)/r
            num += rho[i, j, k] * (f[1] * (-y / r) + f[2] * (x / r)) / fn
            den += rho[i, j, k]
        end
        push!(C, num / den)
        push!(W, wsum * dV)
    end
    (; name=basename(file), n=length(C), C=C, W=W, E=d["E"])
end

function main()
    fs = sort(
        filter(f -> occursin("fig5_", basename(f)) && endswith(f, ".jld2"),
            readdir(OUT; join=true))
    )
    isempty(fs) && (println("no fig5_*.jld2 in $OUT"); return nothing)
    println("="^78)
    println("Fig. 5: per-droplet circulation about z  (+-1 = magnetic vortex)")
    println("the paper's claim is that consecutive droplets ALTERNATE")
    println("="^78)
    best = nothing
    for f in fs
        r = chirality(f)
        r.n == 0 && continue
        signs = join((c > 0 ? "+" : "-") for c in r.C)
        alt = all(r.C[i] * r.C[i + 1] < 0 for i in 1:(length(r.C) - 1))
        @printf("\n%-26s E = %.6f   %d droplets\n", r.name, r.E, r.n)
        print("   C_k :")
        for c in r.C
            @printf(" %+.3f", c)
        end
        println()
        @printf("   signs = %s   strictly alternating: %s   min|C| = %.3f\n",
            signs, alt ? "YES" : "no", minimum(abs, r.C))
        if best === nothing || r.E < best.E
            best = r
        end
    end
    if best !== nothing
        println()
        println("="^78)
        @printf("lowest-energy cell: %s  (E = %.6f)\n", best.name, best.E)
        alt = all(best.C[i] * best.C[i + 1] < 0 for i in 1:(length(best.C) - 1))
        @printf("  %d droplets, strictly alternating: %s, min|C| = %.3f\n",
            best.n, alt ? "YES" : "no", minimum(abs, best.C))
        println("  (min|C| well below 1 means some segment is not a clean")
        println("   vortex, and then its 'sign' is not a measurement)")
    end
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
