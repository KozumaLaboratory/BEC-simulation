# scripts/edh_vs_flower/extract_psi13.jl
# ============================================================================
# FULL 13-component complex-psi extractor for spin-texture TOMOGRAPHY.
# The goto.h5 bridge keeps only m=-6,-5,-4 (88% of pop at peak; the tilt
# rotation R mixes ALL components, so 3 components is NOT enough to forward-
# model a tilted Stern-Gerlach image). This dumps the FULL spinor psi_c(r,t)
# for all 13 components so we can:
#   (1) forward-model tilted-SG absorption images  n_m^{R}(r) = |[R psi]_m|^2
#   (2) per-voxel invert -> local rho(r) -> reconstruct <F>(r) texture
#   (3) validate against the true Fx/Fy/Fz already in goto.h5
# JLD2-only (no SpinorBEC) -> runs fast on the login node.
#
# Datasets (each Julia (nf,nv,nv,nv) -> h5py (nv,nv,nv,nf), same layout as
# goto.h5 n_m6_3d, so python reads with transpose(2,1,0,3)):
#   psi_re_c01..c13, psi_im_c01..c13   (c=1 -> m=+6 ... c=13 -> m=-6)
#   n_total_3d, t, meta/
#
# Usage:
#   julia --project=. scripts/edh_vs_flower/extract_psi13.jl <point_001.jld2> <out.jld2> \
#       [--stride 2] [--tstride 2] [--box 18] [--F 6]
using JLD2, Printf

const RES = ARGS[1]; const OUT = ARGS[2]
_opt(flag, d) = (i = findfirst(==(flag), ARGS); (i === nothing || i == length(ARGS)) ? d : ARGS[i+1])
const STRIDE  = parse(Int, _opt("--stride", "1"))   # DEFAULT 1 = FULL computational grid (no subsample)
const TSTRIDE = parse(Int, _opt("--tstride", "1"))
const BOX     = parse(Float64, _opt("--box", "18"))
const F       = parse(Int, _opt("--F", "6"))
const DTYPE   = _opt("--dtype", "f64")              # f64 preserves the simulation precision for tomography
const RT      = DTYPE == "f32" ? Float32 : Float64
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
    psi1 = f[framerefs[1][1]][framerefs[1][2]]
    nx, ny, nz, dd = size(psi1)
    @assert dd == D "component count $dd != D=$D"
    sub = 1:STRIDE:nx
    nv = length(sub)
    @printf("[extract_psi13] %d frames (tstride %d)  %d^3->%d^3  D=%d\n", nf, TSTRIDE, nx, nv, D)

    pre = [zeros(RT, nf, nv, nv, nv) for _ in 1:D]
    pim = [zeros(RT, nf, nv, nv, nv) for _ in 1:D]
    ntot = zeros(RT, nf, nv, nv, nv)
    tarr = zeros(Float64, nf)

    for (k, (g, key)) in enumerate(framerefs)
        psi = ComplexF64.(f[g][key])
        ps = psi[sub, sub, sub, :]
        ntot[k, :, :, :] .= RT.(dropdims(sum(abs2, ps; dims=4); dims=4))
        for c in 1:D
            pre[c][k, :, :, :] .= RT.(real.(ps[:, :, :, c]))
            pim[c][k, :, :, :] .= RT.(imag.(ps[:, :, :, c]))
        end
        (k % 20 == 0 || k == nf) && (@printf("  frame %d/%d\n", k, nf); flush(stdout))
    end

    jldopen(OUT, "w") do o
        for c in 1:D
            o[@sprintf("psi_re_c%02d", c)] = pre[c]
            o[@sprintf("psi_im_c%02d", c)] = pim[c]
        end
        o["n_total_3d"] = ntot
        o["t"] = tarr
        o["meta/F"] = F; o["meta/NX"] = nx; o["meta/L_box"] = BOX; o["meta/vol_stride"] = STRIDE
    end
    @printf("[extract_psi13] wrote %s (%d frames, %d^3, %d comps)\n", OUT, nf, nv, D)
end
