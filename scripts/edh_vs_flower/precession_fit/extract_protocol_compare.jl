# Extract, for each of several runs, everything needed for the protocol-comparison figures:
#   times, m-component populations, <Fz>(t), <Lz>(t), <Jz>(t), norms
# <Lz> is computed from the saved psi snapshots with the audited
# SpinorBEC.orbital_angular_momentum, so both protocols are treated identically.
#
# Usage: julia --project=. extract_protocol_compare.jl out.json  tag1=dir1  tag2=dir2 ...
# CodecZstd must be loaded explicitly: the auto-saved result.jld2 stores its arrays
# Zstd-compressed, and JLD2 cannot build a decompressor unless the codec is in scope
# (fails with `MethodError: no method matching CodecZstd.ZstdDecompressor()`).
using SpinorBEC, JLD2, JSON, Printf, CodecZstd

out = Dict{String,Any}()
for spec in ARGS[2:end]
    tag, dir = split(spec, "="; limit=2)
    path = joinpath(dir, "point_001.jld2")
    println("--- $tag : $path")
    jldopen(path, "r") do d
        times = Float64.(d["dynamics/times"])
        pops  = d["dynamics/component_populations"]
        # run_yaml's point_001.jld2 calls it "magnetizations"; the auto-saved
        # result.jld2 calls it "Fz". Accept either.
        dg = d["dynamics"]
        magkey = haskey(dg, "magnetizations") ? "magnetizations" :
                 (haskey(dg, "Fz") ? "Fz" : error("no magnetization key in $path"))
        mags  = Float64.(dg[magkey])
        norms = Float64.(d["dynamics/norms"])
        g = d["dynamics/psi_snapshots_streamed"]
        fkeys = sort([k for k in keys(g) if startswith(k, "frame_")])
        nfr = length(fkeys)
        sz = size(g[fkeys[1]]); n_pts = (sz[1], sz[2], sz[3])
        grid  = SpinorBEC.make_grid(GridConfig(n_pts, (18.0, 18.0, 18.0)))
        plans = SpinorBEC.make_fft_plans(n_pts)
        dV = prod(18.0 ./ n_pts)
        # NOTE: dynamics/magnetizations is the RAW integral (normalised to the initial
        # norm), so it decays as K3 removes atoms. Lz below is PER ATOM. Mixing the two
        # fakes a Jz drift. Compute Fz per atom from psi as well, so Fz and Lz share one
        # convention and Jz = Fz + Lz is a like-for-like statement.
        F_int = 6; D_int = 2F_int + 1
        mvals = [F_int - (c - 1) for c in 1:D_int]
        Lz = Float64[]; Fz_pa = Float64[]; Npa = Float64[]; tL = Float64[]
        for (i, k) in enumerate(fkeys)
            psi = ComplexF64.(g[k])
            N = sum(abs2, psi) * dV
            fz = 0.0
            for c in 1:D_int
                fz += mvals[c] * sum(abs2, @view psi[:, :, :, c]) * dV
            end
            push!(Fz_pa, fz / max(N, 1e-30))
            push!(Npa, N)
            push!(Lz, SpinorBEC.orbital_angular_momentum(psi, grid, plans) / max(N, 1e-30))
            push!(tL, i <= length(times) ? times[i] : Float64(i))
        end
        out[String(tag)] = Dict(
            "times" => times, "norms" => norms, "Fz" => mags,
            "pops" => [collect(Float64.(pops[i, :])) for i in 1:size(pops, 1)],
            "t_Lz" => tL, "Lz" => Lz, "Fz_pa" => Fz_pa, "N_t" => Npa, "nframes" => nfr,
        )
        @printf("    frames=%d  Fz_raw[end]=%.3f  Fz_perAtom[end]=%.3f  Lz[end]=%.3f  Jz[end]=%.4f\n",
                nfr, mags[end], Fz_pa[end], Lz[end], Fz_pa[end]+Lz[end])
    end
end
open(ARGS[1], "w") do io; JSON.print(io, out); end
println("wrote ", ARGS[1])
