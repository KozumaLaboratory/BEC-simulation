# Extract per-frame trajectory data from each phi_<rate>/result.jld2.
#
# Adapted from runs/eu151_klaus_phi_phys/extract_trajectory.jl for the
# Barnett scan: directory layout is phi_+4.524/, phi_-4.524/ to keep the
# rotation sign visible. Snapshot peak density sampled every PEAK_SAMPLE_STRIDE
# frames to keep memory bounded.

using SpinorBEC   # CodecZstd world-age fix
using JLD2
using CodecZstd
using Printf

const RUN_ROOT = @__DIR__
const PEAK_SAMPLE_STRIDE = 10

function find_phis()
    out = Tuple{Float64, String}[]
    for d in sort(readdir(RUN_ROOT; join=true))
        m = match(r"phi_([+-]?\d+(\.\d+)?)$", basename(d))
        m === nothing && continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) || continue
        push!(out, (parse(Float64, m.captures[1]), rj))
    end
    sort(out; by=first)
end

function extract_one(rj::String, phi::Float64)
    println("[extract] phi=$phi  $rj")
    jldopen(rj, "r") do f
        times = collect(f["dynamics/times"])
        norms = collect(f["dynamics/norms"])
        Fz = haskey(f, "dynamics/Fz") ? collect(f["dynamics/Fz"]) : Float64[]
        Lz = haskey(f, "dynamics/Lz") ? collect(f["dynamics/Lz"]) : Float64[]
        pops = haskey(f, "dynamics/component_populations") ?
               Array(f["dynamics/component_populations"]) : zeros(0, 0)
        n_frames = length(times)
        println("  $n_frames frames")
        peak = fill(NaN, n_frames)
        if haskey(f, "dynamics/psi_snapshots_streamed/n_snapshots")
            snap_grp = f["dynamics/psi_snapshots_streamed"]
            for i in 1:PEAK_SAMPLE_STRIDE:n_frames
                key = @sprintf("frame_%05d", i)
                if haskey(snap_grp, key)
                    psi = snap_grp[key]
                    n_tot = dropdims(sum(abs2, psi; dims=4); dims=4)
                    peak[i] = Float64(maximum(n_tot))
                end
            end
        end
        (phi=phi, times=times, norms=norms, Fz=Fz, Lz=Lz,
         pops=pops, peak=peak)
    end
end

function main()
    phis = find_phis()
    if isempty(phis)
        @warn "no phi_*/result.jld2 found"
        return
    end
    n_comp_global = 0
    rows_per_phi = String[]
    for (phi, rj) in phis
        d = extract_one(rj, phi)
        n_comp = size(d.pops, 2)
        n_comp > 0 && (n_comp_global = n_comp)
        for i in 1:length(d.times)
            row = String[
                @sprintf("%.4f", d.phi),
                string(i),
                @sprintf("%.6e", d.times[i]),
                @sprintf("%.6e", d.norms[i]),
                isempty(d.Fz) ? "" : @sprintf("%.6e", d.Fz[i]),
                isempty(d.Lz) ? "" : @sprintf("%.6e", d.Lz[i]),
                @sprintf("%.6e", d.peak[i]),
            ]
            for c in 1:n_comp
                push!(row, @sprintf("%.6e", d.pops[i, c]))
            end
            push!(rows_per_phi, join(row, ","))
        end
    end
    header = "phi,frame,t,norm,Fz,Lz,peak"
    for c in 1:n_comp_global
        header *= ",pop_c$c"
    end
    out = [header; rows_per_phi]
    csv_path = joinpath(RUN_ROOT, "trajectory.csv")
    open(csv_path, "w") do io
        for line in out
            println(io, line)
        end
    end
    println("[csv] wrote $csv_path  ($(length(rows_per_phi)) rows from $(length(phis)) phis)")
end

main()
