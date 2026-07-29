# Extract equilibrium <L_z>, <F_z>, per-m populations, per-m L_z, and a
# 2D density/phase snapshot from each rotating-frame GS scan point.
#
# Usage: julia --project=. analyze_rotframe_gs.jl <scan_dir> <out.csv> <snapdir>

using SpinorBEC
using JLD2, CodecZstd, Printf, FFTW, DelimitedFiles

function component_Lz(psi_c, grid, plans)
    n_pts = size(psi_c)
    psi_k = ComplexF64.(psi_c); plans.forward * psi_k
    dx = similar(psi_k); dy = similar(psi_k)
    @inbounds for I in CartesianIndices(n_pts)
        dx[I] = im * grid.k[1][I[1]] * psi_k[I]
        dy[I] = im * grid.k[2][I[2]] * psi_k[I]
    end
    plans.inverse * dx; plans.inverse * dy
    dV = cell_volume(grid); Lz = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]
        Lz += real(conj(psi_c[I]) * (-im) * (x * dy[I] - y * dx[I])) * dV
    end
    Lz
end

# Read the scanned Omega from a point's stored config/override, else NaN.
function point_omega(f)
    for k in ("rotating_frame_omega", "scan_value", "omega")
        haskey(f, k) && return Float64(f[k])
    end
    # fall back: parse from override metadata if present
    NaN
end

function main()
    scandir = ARGS[1]; outcsv = ARGS[2]
    snapdir = length(ARGS) >= 3 ? ARGS[3] : ""
    snapdir != "" && mkpath(snapdir)

    pts = sort(filter(p -> occursin(r"point_\d+\.jld2$", p), readdir(scandir; join=true)))
    rows = String[]

    # header built after we know F
    Fref = nothing
    for (pi, pj) in enumerate(pts)
        rr   = open_result(pj)
        grid = rr.grid
        N    = length(grid.config.n_points)
        D    = size(rr.psi, N + 1)
        F    = (D - 1) ÷ 2
        sys  = SpinSystem(F)
        plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
        dV   = cell_volume(grid)
        psi  = ComplexF64.(rr.psi)
        npts = ntuple(d -> size(psi, d), N)

        Om = jldopen(pj, "r") do f
            ov = haskey(f, "override") ? f["override"] : Dict{String,Any}()
            k = "pipeline.0.ground_state.rotating_frame_omega"
            haskey(ov, k) ? Float64(ov[k]) : NaN
        end

        Fz = magnetization(psi, grid, sys)
        Lz = orbital_angular_momentum(psi, grid, plans)
        E  = jldopen(pj, "r") do f; haskey(f, "energy") ? Float64(f["energy"]) : NaN; end
        conv = jldopen(pj, "r") do f; haskey(f, "converged") ? f["converged"] : missing; end
        pops = Float64[]; lzm = Float64[]
        for c in 1:D
            idx = SpinorBEC._component_slice(N, npts, c)
            psic = psi[idx...]
            push!(pops, sum(abs2, psic) * dV)
            push!(lzm, component_Lz(psic, grid, plans))
        end

        if Fref === nothing
            Fref = F
            hdr = "point,Omega,energy,conv,Fz,Lz,Jz"
            for m in F:-1:-F; hdr *= ",pop_m$(m)"; end
            for m in F:-1:-F; hdr *= ",Lz_m$(m)"; end
            push!(rows, hdr)
        end
        row = @sprintf("%d,%.4f,%.6e,%s,%.6e,%.6e,%.6e", pi, Om, E, string(conv), Fz, Lz, Lz + Fz)
        for p in pops; row *= @sprintf(",%.6e", p); end
        for l in lzm;  row *= @sprintf(",%.6e", l); end
        push!(rows, row)
        println("point $pi: Omega=$(round(Om,digits=3)) Fz=$(round(Fz,digits=4)) Lz=$(round(Lz,digits=4)) conv=$conv")

        # 2D column density + total-density mid-z phase (dominant m) for viz
        if snapdir != "" && N == 3
            zc = size(psi, 3) ÷ 2 + 1
            ntot = dropdims(sum(abs2, psi; dims=N+1); dims=N+1)
            writedlm(joinpath(snapdir, @sprintf("p%d_O%+.2f_ntot2d.csv", pi, Om)),
                     dropdims(sum(ntot; dims=3); dims=3), ',')
            # dominant transferred m (max pop among m != -F initial)
            cmax = argmax(pops)
            mdom = sys.m_values[cmax]
            idx = SpinorBEC._component_slice(N, npts, cmax)
            writedlm(joinpath(snapdir, @sprintf("p%d_O%+.2f_phase_mdom.csv", pi, Om)),
                     angle.(psi[idx...][:, :, zc]), ',')
            open(joinpath(snapdir, @sprintf("p%d_O%+.2f_meta.txt", pi, Om)), "w") do io
                println(io, "Omega=$Om"); println(io, "mdom=$mdom"); println(io, "Fz=$Fz"); println(io, "Lz=$Lz")
            end
        end
        if snapdir != "" && pi == 1
            writedlm(joinpath(snapdir, "grid_x.csv"), collect(grid.x[1]), ',')
            writedlm(joinpath(snapdir, "grid_y.csv"), collect(grid.x[2]), ',')
        end
    end

    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[csv] wrote $outcsv")
end

main()
