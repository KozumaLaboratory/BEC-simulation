# Extract per-frame trajectory data from each stir_<Omega>/result.jld2.
#
# Spinor-path result.jld2 stores per-frame scalars under `dynamics/` and
# snapshots under `dynamics/psi_snapshots_streamed/`. We pull:
#   times, norms, Fz, Lz, component_populations
# plus a sampled peak density (every PEAK_SAMPLE_STRIDE frames).

using SpinorBEC   # CodecZstd world-age fix
using JLD2
using CodecZstd
using Printf

const RUN_ROOT = @__DIR__
const PEAK_SAMPLE_STRIDE = 10

function find_runs()
    out = Tuple{Float64, String}[]
    for d in sort(readdir(RUN_ROOT; join=true))
        m = match(r"stir_([+-]?\d+(\.\d+)?)$", basename(d))
        m === nothing && continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) || continue
        push!(out, (parse(Float64, m.captures[1]), rj))
    end
    sort(out; by=first)
end

function extract_one(rj::String, Omega::Float64)
    println("[extract] Omega=$Omega  $rj")
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
        (Omega=Omega, times=times, norms=norms, Fz=Fz, Lz=Lz,
         pops=pops, peak=peak)
    end
end

function main()
    runs = find_runs()
    if isempty(runs)
        @warn "no stir_*/result.jld2 found"
        return
    end
    n_comp_global = 0
    rows_per_run = String[]
    for (Omega, rj) in runs
        d = extract_one(rj, Omega)
        n_comp = size(d.pops, 2)
        n_comp > 0 && (n_comp_global = n_comp)
        for i in 1:length(d.times)
            row = String[
                @sprintf("%.4f", d.Omega),
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
            push!(rows_per_run, join(row, ","))
        end
    end
    header = "Omega,frame,t,norm,Fz,Lz,peak"
    for c in 1:n_comp_global
        header *= ",pop_c$c"
    end
    out = [header; rows_per_run]
    csv_path = joinpath(RUN_ROOT, "trajectory.csv")
    open(csv_path, "w") do io
        for line in out
            println(io, line)
        end
    end
    println("[csv] wrote $csv_path ($(length(rows_per_run)) rows, $(length(runs)) runs)")
end

main()
