# scripts/edh_vs_flower/extract_rho.jl
# Global internal spin density matrix ρ̄_mn(t) = ∫ψ_m ψ_n^* dr / N  (the object a
# tilt+SG tomography measures: SG populations after an internal rotation R are
# P_m = (R ρ̄ R†)_mm). 13×13 Hermitian per frame. Pure JLD2, fast (inner products).
# Usage: julia --project=. scripts/edh_vs_flower/extract_rho.jl <result.jld2> <out.jld2> [--tstride 1]
using JLD2, Printf, LinearAlgebra
const RES=ARGS[1]; const OUT=ARGS[2]
_opt(flag,d)=(i=findfirst(==(flag),ARGS); (i===nothing||i==length(ARGS)) ? d : ARGS[i+1])
const TS=parse(Int,_opt("--tstride","1"))
function find_groups(f)
    found=String[]
    function walk(grp::JLD2.Group,path)
        ks=collect(keys(grp)); "psi_snapshots_streamed" in ks && push!(found,path*"/psi_snapshots_streamed")
        for k in ks; k=="psi_snapshots_streamed" && continue; c=try grp[k] catch; nothing end
            c isa JLD2.Group && walk(c, isempty(path) ? k : path*"/"*k); end
    end
    for k in collect(keys(f)); c=try f[k] catch; nothing end; c isa JLD2.Group && walk(c,k); end
    found
end
jldopen(RES,"r") do f
    groups=find_groups(f); refs=Tuple{String,String}[]
    for g in groups, k in sort(filter(s->startswith(s,"frame_"),collect(keys(f[g])))); push!(refs,(g,k)); end
    refs=refs[1:TS:end]; nf=length(refs)
    psi1=f[refs[1][1]][refs[1][2]]; D=size(psi1)[end]
    @printf("[extract_rho] %d frames  D=%d\n",nf,D)
    rho=zeros(ComplexF64,nf,D,D)
    for (k,(g,key)) in enumerate(refs)
        psi=ComplexF64.(f[g][key]); Np=prod(size(psi)[1:end-1])
        Psi=reshape(psi,Np,D)                 # (Npix, D)
        G = transpose(Psi)*conj(Psi)          # G_mn = Σ ψ_m ψ_n^*
        rho[k,:,:] .= G ./ real(tr(G))        # normalise Tr=1
        (k%20==0||k==nf)&&(@printf("  frame %d/%d\n",k,nf);flush(stdout))
    end
    jldopen(OUT,"w") do o
        o["rho_re"]=real.(rho); o["rho_im"]=imag.(rho); o["nf"]=nf; o["D"]=D
        o["m_channels"]=collect((D-1)÷2:-1:-((D-1)÷2))
    end
    @printf("[extract_rho] wrote %s (%d frames, %d×%d ρ̄)\n",OUT,nf,D,D)
end
