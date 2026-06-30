# scripts/edh_vs_flower/extract_3d.jl
# ============================================================================
# Fast 3-D extractor for the spin-texture + m-component isosurface videos.
# Reads the full-ψ result.jld2 frames with NATIVE JLD2 (fast — unlike h5py,
# which crawls on JLD2 and gets killed on the login node), subsamples to a
# coarse grid, and writes the 3-D fields the viz needs:
#   n_total_3d, Fx_3d, Fy_3d, Fz_3d           (spin texture)
#   n_m6_3d, n_m5_3d, n_m4_3d, arg_m6/5/4_3d  (m=-6,-5,-4 isosurfaces)
#   t + meta/                                  (h5py-readable, C-order natural)
#
# Usage:
#   julia --project=. scripts/edh_vs_flower/extract_3d.jl <result.jld2> <out.jld2> \
#       [--stride 2] [--tstride 2] [--box 18] [--F 6]
using SpinorBEC
using SpinorBEC: spin_matrices, spin_density_vector
using JLD2, Printf

const RES = ARGS[1]; const OUT = ARGS[2]
_opt(flag, d) = (i = findfirst(==(flag), ARGS); (i === nothing || i == length(ARGS)) ? d : ARGS[i+1])
const STRIDE  = parse(Int, _opt("--stride", "2"))
const TSTRIDE = parse(Int, _opt("--tstride", "2"))
const BOX     = parse(Float64, _opt("--box", "18"))
const F       = parse(Int, _opt("--F", "6"))
const D = 2F + 1

function find_groups(f)
    found = String[]
    function walk(grp::JLD2.Group, path)
        ks = collect(keys(grp))
        "psi_snapshots_streamed" in ks && push!(found, path * "/psi_snapshots_streamed")
        for k in ks
            k == "psi_snapshots_streamed" && continue
            c = try grp[k] catch; nothing end
            c isa JLD2.Group && walk(c, isempty(path) ? k : path * "/" * k)
        end
    end
    for k in collect(keys(f))
        c = try f[k] catch; nothing end
        c isa JLD2.Group && walk(c, k)
    end
    found
end

jldopen(RES, "r") do f
    groups = find_groups(f)
    framerefs = Tuple{String,String}[]
    for g in groups
        fr = sort(filter(s -> startswith(s, "frame_"), collect(keys(f[g]))))
        for k in fr; push!(framerefs, (g, k)); end
    end
    framerefs = framerefs[1:TSTRIDE:end]
    nf = length(framerefs)
    psi1 = f[framerefs[1][1]][framerefs[1][2]]              # (nx,ny,nz,D) spinor-last
    nx, ny, nz, _ = size(psi1)
    sub = 1:STRIDE:nx
    nv = length(sub)
    sm = spin_matrices(F)
    m6, m5, m4 = D, D-1, D-2                                # c index for m=-6,-5,-4
    @printf("[extract_3d] %d frames (tstride %d)  %d³→%d³  D=%d\n", nf, TSTRIDE, nx, nv, D)

    n_tot = zeros(Float32, nf, nv, nv, nv)
    fx3 = zeros(Float32, nf, nv, nv, nv); fy3 = similar(fx3); fz3 = similar(fx3)
    nm6 = similar(fx3); nm5 = similar(fx3); nm4 = similar(fx3)
    am6 = similar(fx3); am5 = similar(fx3); am4 = similar(fx3)
    tarr = zeros(Float64, nf)

    for (k, (g, key)) in enumerate(framerefs)
        psi = ComplexF64.(f[g][key])
        ps = psi[sub, sub, sub, :]                          # subsample first
        fx, fy, fz = spin_density_vector(ps, sm, 3)
        @inbounds for (kk, _) in enumerate(1:nv), jj in 1:nv, ii in 1:nv
        end
        n_tot[k, :, :, :] .= Float32.(dropdims(sum(abs2, ps; dims=4); dims=4))
        fx3[k, :, :, :] .= Float32.(fx); fy3[k, :, :, :] .= Float32.(fy); fz3[k, :, :, :] .= Float32.(fz)
        nm6[k, :, :, :] .= Float32.(abs2.(ps[:, :, :, m6])); am6[k, :, :, :] .= Float32.(angle.(ps[:, :, :, m6]))
        nm5[k, :, :, :] .= Float32.(abs2.(ps[:, :, :, m5])); am5[k, :, :, :] .= Float32.(angle.(ps[:, :, :, m5]))
        nm4[k, :, :, :] .= Float32.(abs2.(ps[:, :, :, m4])); am4[k, :, :, :] .= Float32.(angle.(ps[:, :, :, m4]))
        (k % 20 == 0 || k == nf) && (@printf("  frame %d/%d\n", k, nf); flush(stdout))
    end

    jldopen(OUT, "w") do o
        o["n_total_3d"] = n_tot
        o["Fx_3d"] = fx3; o["Fy_3d"] = fy3; o["Fz_3d"] = fz3
        o["n_m6_3d"] = nm6; o["n_m5_3d"] = nm5; o["n_m4_3d"] = nm4
        o["arg_psi_m6_3d"] = am6; o["arg_psi_m5_3d"] = am5; o["arg_psi_m4_3d"] = am4
        o["t"] = tarr
        o["meta/F"] = F; o["meta/NX"] = nx; o["meta/L_box"] = BOX; o["meta/vol_stride"] = STRIDE
    end
    @printf("[extract_3d] wrote %s (%d frames, %d³)\n", OUT, nf, nv)
end
