# scripts/edh_vs_flower/extract_slices.jl
# ============================================================================
# HONEST full-resolution per-m cross-sections, straight from the FULL 64^3 ψ.
# No subsampling (unlike spin3d.jl's stride-2 32^3), no SpinorBEC needed
# (densities/phases are direct from the spinor components) — pure JLD2, so it
# runs fast on the login node. For every saved frame, extract the z-mid and
# y-mid slices of |ψ_m|² and arg(ψ_m) for ALL 13 m, at the centre plane.
#
# Usage: julia --project=. scripts/edh_vs_flower/extract_slices.jl <result.jld2> <out.jld2> [--tstride 1]
using JLD2, Printf
const RES=ARGS[1]; const OUT=ARGS[2]
_opt(flag,d)=(i=findfirst(==(flag),ARGS); (i===nothing||i==length(ARGS)) ? d : ARGS[i+1])
const TS=parse(Int,_opt("--tstride","1"))

function find_groups(f)
    found=String[]
    function walk(grp::JLD2.Group,path)
        ks=collect(keys(grp))
        "psi_snapshots_streamed" in ks && push!(found,path*"/psi_snapshots_streamed")
        for k in ks
            k=="psi_snapshots_streamed" && continue
            c=try grp[k] catch; nothing end
            c isa JLD2.Group && walk(c, isempty(path) ? k : path*"/"*k)
        end
    end
    for k in collect(keys(f))
        c=try f[k] catch; nothing end
        c isa JLD2.Group && walk(c,k)
    end
    found
end

jldopen(RES,"r") do f
    groups=find_groups(f)
    framerefs=Tuple{String,String}[]
    for g in groups
        fr=sort(filter(s->startswith(s,"frame_"),collect(keys(f[g]))))
        for k in fr; push!(framerefs,(g,k)); end
    end
    framerefs=framerefs[1:TS:end]; nf=length(framerefs)
    psi1=f[framerefs[1][1]][framerefs[1][2]]; nx,ny,nz,D=size(psi1)
    zc=nz÷2+1; yc=ny÷2+1                       # centre planes (x=0 within dx/2)
    @printf("[extract_slices] %d frames  grid %d×%d×%d  D=%d  zc=%d yc=%d (FULL res)\n",nf,nx,ny,nz,D,zc,yc)
    n_xy=zeros(Float32,nf,nx,ny,D); a_xy=zeros(Float32,nf,nx,ny,D)
    n_xz=zeros(Float32,nf,nx,nz,D); a_xz=zeros(Float32,nf,nx,nz,D)
    # column-integrated densities (the experimental absorption-imaging observable):
    col_z=zeros(Float32,nf,nx,ny,D)   # ∫dz  → "top view" (xy)
    col_y=zeros(Float32,nf,nx,nz,D)   # ∫dy  → "side view" (xz)
    for (k,(g,key)) in enumerate(framerefs)
        psi=f[g][key]
        sxy=@view psi[:,:,zc,:]; sxz=@view psi[:,yc,:,:]
        n_xy[k,:,:,:].=Float32.(abs2.(sxy)); a_xy[k,:,:,:].=Float32.(angle.(sxy))
        n_xz[k,:,:,:].=Float32.(abs2.(sxz)); a_xz[k,:,:,:].=Float32.(angle.(sxz))
        nm=abs2.(psi)                                  # (nx,ny,nz,D)
        col_z[k,:,:,:].=Float32.(dropdims(sum(nm;dims=3);dims=3))   # sum over z
        col_y[k,:,:,:].=Float32.(dropdims(sum(nm;dims=2);dims=2))   # sum over y
        (k%20==0||k==nf)&&(@printf("  frame %d/%d\n",k,nf);flush(stdout))
    end
    jldopen(OUT,"w") do o
        o["n_xy"]=n_xy; o["arg_xy"]=a_xy; o["n_xz"]=n_xz; o["arg_xz"]=a_xz
        o["col_z"]=col_z; o["col_y"]=col_y
        o["NX"]=nx; o["D"]=D; o["nf"]=nf
        o["m_channels"]=collect((D-1)÷2:-1:-((D-1)÷2))
    end
    @printf("[extract_slices] wrote %s (%d frames, %d×%d full res, all %d m)\n",OUT,nf,nx,ny,D)
end
