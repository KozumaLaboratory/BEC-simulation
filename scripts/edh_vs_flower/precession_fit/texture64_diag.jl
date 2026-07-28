# 64^3 texture diagnostics for the EdH hold phase — clean collective mode vs spin turbulence.
# Reads a run's point_001.jld2 (dynamics/psi_snapshots_streamed/frame_XXXXX, 64^3x13 ComplexF32),
# computes the transverse spin field, and reduces to SMALL diagnostics (JSON):
#   - Fz(t) from component populations
#   - S_perp(k,t): radially-averaged spatial power spectrum of the transverse spin  (peak=mode / broad=turbulent)
#   - n_defect(t): transverse-spin phase-winding defect count on the mid-z slice (vortex proliferation = turbulence)
#   - texture x-z slices of <Fx> for a few hold frames
#   - <F> at 6 octahedral points
# Pure JLD2+FFTW (no SpinorBEC/CUDA).  Usage: julia texture64_diag.jl <point_001.jld2> <out.json>
using JLD2, FFTW, LinearAlgebra, Statistics, JSON, Printf
p = ARGS[1]; out = ARGS[2]
F = 6; D = 2F + 1
mvals = [F - (c - 1) for c in 1:D]
Sp = zeros(ComplexF64, D, D); Sm = zeros(ComplexF64, D, D)
for c in 1:D
    m = mvals[c]
    c-1 >= 1 && (Sp[c-1, c] = sqrt(F*(F+1) - m*(m+1)))
    c+1 <= D && (Sm[c+1, c] = sqrt(F*(F+1) - m*(m-1)))
end
Fx = (Sp + Sm)/2; Fy = (Sp - Sm)/(2im)   # tridiagonal in m

function spin_fields(psi)   # psi: (nx,ny,nz,D) complex -> Fx,Fy,Fz real fields
    nx,ny,nz,_ = size(psi)
    fx = zeros(nx,ny,nz); fy = zeros(nx,ny,nz); fz = zeros(nx,ny,nz)
    @inbounds for c in 1:D
        pc = @view psi[:,:,:,c]
        @. fz += mvals[c]*abs2(pc)
        for cp in 1:D
            if Fx[c,cp] != 0
                pcp = @view psi[:,:,:,cp]
                @. fx += real(conj(pc)*Fx[c,cp]*pcp)
                @. fy += real(conj(pc)*Fy[c,cp]*pcp)
            end
        end
    end
    fx,fy,fz
end

# radially-averaged spectrum of the complex transverse spin psi_perp = Fx + i Fy
function radial_spectrum(fx, fy, kbins)
    nx,ny,nz = size(fx)
    P = abs2.(fft(complex.(fx,fy)))
    kx = [ (i<=nx÷2 ? i-1 : i-1-nx) for i in 1:nx ]
    S = zeros(length(kbins)-1); cnt = zeros(Int, length(kbins)-1)
    @inbounds for k in 1:nz, j in 1:ny, i in 1:nx
        kk = sqrt(kx[i]^2 + kx[j]^2 + kx[k]^2)
        b = searchsortedlast(kbins, kk)
        (1 <= b <= length(S)) && (S[b]+=P[i,j,k]; cnt[b]+=1)
    end
    @. S = S / max(cnt,1)
    S
end

# transverse-spin phase-winding defects on the mid-z slice
function ndefect(fx, fy, cz)
    nx,ny,_ = size(fx)
    phi = atan.(fy[:,:,cz], fx[:,:,cz])
    wrap(d) = d > π ? d-2π : (d < -π ? d+2π : d)
    n = 0
    @inbounds for j in 1:ny-1, i in 1:nx-1
        w = wrap(phi[i+1,j]-phi[i,j]) + wrap(phi[i+1,j+1]-phi[i+1,j]) +
            wrap(phi[i,j+1]-phi[i+1,j+1]) + wrap(phi[i,j]-phi[i,j+1])
        abs(w) > π && (n += 1)
    end
    n
end

jldopen(p, "r") do d
    times = Float64.(d["dynamics/times"])
    pops  = d["dynamics/component_populations"]           # (nsnap, D)
    g = d["dynamics/psi_snapshots_streamed"]
    fkeys = sort([k for k in keys(g) if startswith(k, "frame_")])
    nfr = length(fkeys)
    sz = size(g[fkeys[1]]); nx,ny,nz = sz[1],sz[2],sz[3]
    cz = nz÷2 + 1
    box = 18.0; dx = box/nx
    println("frames=$nfr  grid=($nx,$ny,$nz)")
    hold = collect(max(1, nfr-58):nfr)                    # hold phase
    kbins = collect(0.0:1.0:20.0)
    kmid = (kbins[1:end-1] .+ kbins[2:end]) ./ 2

    Sk = Vector{Vector{Float64}}(); nd = Int[]; Fzt = Float64[]; tt = Float64[]
    sliceframes = hold[round.(Int, range(1, length(hold), length=5))]
    slices = Dict{String,Any}()
    for (idx,fi) in enumerate(hold)
        psi = ComplexF64.(g[fkeys[fi]])
        fx,fy,fz = spin_fields(psi)
        n = dropdims(sum(abs2, psi; dims=4); dims=4)
        nsum = sum(n)
        push!(tt, fi <= length(times) ? times[fi] : Float64(fi))
        push!(Fzt, sum(fz)/max(nsum,1e-30))
        push!(Sk, radial_spectrum(fx, fy, kbins))
        push!(nd, ndefect(fx, fy, cz))
        if fi in sliceframes
            slices["fx_xz_$(fi)"] = vec(Float64.(fx[:, ny÷2+1, :]))
            slices["t_$(fi)"] = fi <= length(times) ? times[fi] : Float64(fi)
        end
    end
    # peakedness of S_perp(k): ratio of peak to mean (high=coherent single-k mode, ~1=broad/turbulent)
    peakratio = [maximum(s)/mean(s) for s in Sk]
    open(out, "w") do io
        JSON.print(io, Dict(
            "times"=>tt, "Fz_t"=>Fzt, "kmid"=>kmid,
            "Sperp"=>Sk, "peakratio"=>peakratio, "ndefect"=>nd,
            "slices"=>slices, "nx"=>nx, "nz"=>nz, "box"=>box,
        ))
    end
    @printf("hold frames=%d  Fz range [%.2f,%.2f]  ndefect range [%d,%d]  peakratio [%.1f,%.1f]\n",
            length(hold), minimum(Fzt), maximum(Fzt), minimum(nd), maximum(nd),
            minimum(peakratio), maximum(peakratio))
    println("wrote ", out)
end
