# omega(k) dispersion of the transverse-spin (magnon) field, from a saved 64^3 run.
#
# For each hold-phase frame: build the complex transverse spin  psi_perp(r) = <Fx> + i<Fy>,
# spatial-FFT it, and record the complex amplitude in radial |k| shells (and, separately,
# resolved into k parallel to M (z) vs k perpendicular to M (xy) — the BdG anisotropy axis).
# The time series of each shell is written out; the time-FFT is done on the laptop.
#
# If the signal is a magnon, each k-shell oscillates at its OWN frequency omega(k)
# (a dispersion). If instead everything oscillates at one frequency independent of k,
# it is a spatially-uniform oscillation, not a dispersive spin wave.
#
# Usage: julia --project=. omega_k_export.jl <point_001.jld2> <out.json>
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
Fxm = (Sp + Sm)/2; Fym = (Sp - Sm)/(2im)

function transverse_field(psi)
    nx,ny,nz,_ = size(psi)
    fx = zeros(nx,ny,nz); fy = zeros(nx,ny,nz)
    @inbounds for c in 1:D, cp in 1:D
        if Fxm[c,cp] != 0
            pc = @view psi[:,:,:,c]; pcp = @view psi[:,:,:,cp]
            @. fx += real(conj(pc)*Fxm[c,cp]*pcp)
            @. fy += real(conj(pc)*Fym[c,cp]*pcp)
        end
    end
    complex.(fx, fy)
end

jldopen(p, "r") do d
    times = Float64.(d["dynamics/times"])
    g = d["dynamics/psi_snapshots_streamed"]
    fkeys = sort([k for k in keys(g) if startswith(k, "frame_")])
    nfr = length(fkeys)
    sz = size(g[fkeys[1]]); nx,ny,nz = sz[1],sz[2],sz[3]
    box = 18.0
    hold = collect(max(1, nfr-58):nfr)
    println("frames=$nfr grid=($nx,$ny,$nz) hold=$(length(hold))")

    # integer wavevector grids (units of 2pi/box)
    kk(n) = [ i <= n÷2 ? i-1 : i-1-n for i in 1:n ]
    KX = kk(nx); KY = kk(ny); KZ = kk(nz)

    KMAX = 8
    # radial shells
    shells = 1:KMAX
    # anisotropy split: k mostly along z (|kz| dominant) vs mostly in xy plane
    amp_rad  = [ComplexF64[] for _ in shells]     # per shell, time series (dominant mode amp)
    amp_par  = [ComplexF64[] for _ in shells]     # k ∥ M (z)
    amp_perp = [ComplexF64[] for _ in shells]     # k ⊥ M (xy)
    tt = Float64[]

    for fi in hold
        psi = ComplexF64.(g[fkeys[fi]])
        P = fft(transverse_field(psi))
        push!(tt, fi <= length(times) ? times[fi] : Float64(fi))
        # accumulate, per shell, the complex amplitude summed over the shell
        accR = zeros(ComplexF64, KMAX); accPar = zeros(ComplexF64, KMAX); accPerp = zeros(ComplexF64, KMAX)
        cntPar = zeros(Int, KMAX); cntPerp = zeros(Int, KMAX)
        @inbounds for iz in 1:nz, iy in 1:ny, ix in 1:nx
            kx = KX[ix]; ky = KY[iy]; kz = KZ[iz]
            kmag = sqrt(kx^2 + ky^2 + kz^2)
            s = round(Int, kmag)
            (s < 1 || s > KMAX) && continue
            v = P[ix,iy,iz]
            accR[s] += v
            kperp2 = kx^2 + ky^2
            if kz^2 >= 2*kperp2          # mostly along z
                accPar[s] += v; cntPar[s] += 1
            elseif kperp2 >= 2*kz^2      # mostly in xy
                accPerp[s] += v; cntPerp[s] += 1
            end
        end
        for s in shells
            push!(amp_rad[s], accR[s])
            push!(amp_par[s], accPar[s])
            push!(amp_perp[s], accPerp[s])
        end
    end
    tojson(v) = Dict("re" => real.(v), "im" => imag.(v))
    open(out, "w") do io
        JSON.print(io, Dict(
            "times" => tt, "kmax" => KMAX, "box" => box, "nx" => nx,
            "amp_rad"  => [tojson(a) for a in amp_rad],
            "amp_par"  => [tojson(a) for a in amp_par],
            "amp_perp" => [tojson(a) for a in amp_perp],
        ))
    end
    @printf("wrote %s  (%d hold frames, kmax=%d)\n", out, length(tt), KMAX)
end
