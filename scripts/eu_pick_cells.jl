# For representative (Bz_µG, κ) cells at physical Eu (c1=+1/36), take the min-E
# ψ and save COMPACT spin-texture slices (mid-z, mid-y planes of Fx,Fy,Fz,n) into
# one small file for real-space inspection — avoids shipping the full 64³ ψ.
#
#   julia --project=. scripts/eu_pick_cells.jl <run_dir> [out.jld2]

using JLD2, Printf, SpinorBEC

run = ARGS[1]
out = length(ARGS) >= 2 ? ARGS[2] : joinpath(run, "_picks_slices.jld2")
c1_target = parse(Float64, get(ENV, "SPINORBEC_PHASE_C1", "0.0277777778"))

# references + discovered distinct phase (cluster 1) + orphans (novel candidates)
targets = [(0.0, 1.0),          # flower reference (B=0)
    (1.0e-4, 1.0),               # uniform-FM reference
    (6.2e-5, 1.6), (7.5e-5, 1.9), (1.0e-4, 2.2),   # cluster 1 (distinct phase)
    (2.5e-5, 1.3), (4.8e-5, 1.6), (7.5e-5, 2.2)]   # orphans (incl vortex-core)
_ug(s) = parse(Float64, split(String(s))[1])

results = Dict{String, Any}()
for (tb, tk) in targets
    best = nothing
    for f in readdir(run)
        (startswith(f, "point_") && endswith(f, ".jld2")) || continue
        p = joinpath(run, f)
        ov = try
            JLD2.load(p, "override")
        catch
            continue
        end
        c1 = get(ov, "pipeline.0.interactions.c1_ratio", -9.0)
        (c1 isa Number && abs(c1 - c1_target) < 1e-6) || continue
        bz = _ug(get(ov, "pipeline.0.B.Bz", "0 G"))
        k = Float64(get(ov, "pipeline.0.potential.omega.2", -9.0))
        (abs(bz - tb) < 1e-9 && abs(k - tk) < 1e-6) || continue
        E = JLD2.load(p, "energy")
        (best === nothing || E < best.E) && (best = (; E, f, p))
    end
    best === nothing && (@printf("MISS B=%.0f k=%.1f\n", tb * 1e6, tk); continue)

    psi = ComplexF64.(JLD2.load(best.p, "psi"))
    n = Int.(JLD2.load(best.p, "grid_n_points"))
    box = Float64.(JLD2.load(best.p, "grid_box_size"))
    grid = make_grid(GridConfig(Tuple(n), Tuple(box)))
    fx, fy, fz = SpinorBEC._spin_expectation_fields(psi, grid)
    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    zc = n[3] ÷ 2 + 1
    yc = n[2] ÷ 2 + 1
    key = @sprintf("B%03.0f_k%.1f", tb * 1e6, tk)
    results[key] = Dict(
        "B_uG" => tb * 1e6, "kappa" => tk, "E" => best.E, "box" => box,
        # mid-z (xy) plane
        "fx_xy" => fx[:, :, zc], "fy_xy" => fy[:, :, zc], "fz_xy" => fz[:, :, zc],
        "n_xy" => dens[:, :, zc],
        # mid-y (xz) plane
        "fx_xz" => fx[:, yc, :], "fz_xz" => fz[:, yc, :], "n_xz" => dens[:, yc, :],
    )
    @printf("OK  %s  E=%.4f\n", key, best.E)
end

jldopen(out, "w") do f
    for (k, v) in results
        for (kk, vv) in v
            f["$k/$kk"] = vv
        end
    end
end
println("wrote ", out, "  (", length(results), " cells)")
