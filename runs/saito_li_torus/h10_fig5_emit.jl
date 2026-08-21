# Reduce each Fig. 5 cell to a line profile + a z=0 density/spin map.
#
#   julia --project=. runs/saito_li_torus/h10_fig5_emit.jl

using SpinorBEC
using SpinorBEC:
    make_grid, GridConfig, total_density, spin_density_vector,
    spin_matrices, ATOM_REGISTRY, Units
using JLD2, Printf

const OUT = joinpath(@__DIR__, "out")
const A_HO_UM =
    sqrt(Units.HBAR / (ATOM_REGISTRY[:Eu151_f1_effective].mass * 691.15)) * 1e6

function emit(f)
    d = load(f)
    name = replace(basename(f), "fig5_" => "", ".jld2" => "")
    psi = d["psi"]
    grid = make_grid(GridConfig{3}(Tuple(d["n"]), Tuple(d["box"])))
    rho = total_density(psi, 3)
    line = vec(sum(rho; dims=(2, 3)))
    xs = collect(grid.x[1]) .* A_HO_UM
    open(joinpath(OUT, "fig5_$(name)_line.csv"), "w") do io
        println(io, "# E=$(d["E"]) contrast=$(d["contrast"]) peaks=$(d["n_peaks"])")
        println(io, "x_um,line")
        for i in eachindex(xs)
            println(io, xs[i], ",", line[i])
        end
    end
    # z = 0 map + magnetization, for the arrow figure
    iz = argmin(abs.(grid.x[3]))
    ys = collect(grid.x[2]) .* A_HO_UM
    sm = spin_matrices(1)
    fx, fy, _ = spin_density_vector(psi, sm, 3)
    sx = max(1, length(xs) ÷ 60)
    sy = max(1, length(ys) ÷ 12)
    open(joinpath(OUT, "fig5_$(name)_map.csv"), "w") do io
        println(io, "x_um,y_um,rho,fx,fy")
        for i in 1:sx:length(xs), j in 1:sy:length(ys)
            println(io, join((xs[i], ys[j], rho[i, j, iz], fx[i, j, iz],
                    fy[i, j, iz]), ","))
        end
    end
    @printf("  %-22s E=%.6f  contrast=%.4f  peaks=%d\n", name, d["E"],
        d["contrast"], d["n_peaks"])
end

function main()
    fs = sort(
        filter(f -> occursin("fig5_", basename(f)) && endswith(f, ".jld2"),
            readdir(OUT; join=true))
    )
    isempty(fs) && (println("no fig5_*.jld2 in $OUT"); return nothing)
    println("emitting $(length(fs)) Fig. 5 cells:")
    foreach(emit, fs)
end

abspath(PROGRAM_FILE) == abspath(@__FILE__) && main()
