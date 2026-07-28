# Offline analysis of the clean rotating-field Barnett/EdH run.
#
# The lab-frame spinor save path records dynamics/Fz but NOT dynamics/Lz,
# so we recompute BOTH from the saved psi snapshots on one grid. This
# makes ⟨L_z⟩(t), ⟨F_z⟩(t), ⟨J_z⟩=⟨L_z⟩+⟨F_z⟩(t) self-consistent for
# the EdH oracle (⟨L_z⟩ and ⟨F_z⟩ co-aligned; rotating field pumps AM
# into both sectors, sign set by rotation direction).
#
# Usage:
#   julia --project=. runs/eu_barnett_rotfield_clean/analyze_barnett.jl <result.jld2> <Omega> <out.csv> [snap_out.jld2]

using SpinorBEC
using JLD2, CodecZstd, Printf, FFTW, DelimitedFiles

# Per-component orbital angular momentum ⟨L_z⟩_m for one spinor component.
function component_Lz(psi_c::AbstractArray{<:Complex}, grid, plans)
    n_pts = size(psi_c)
    psi_k = ComplexF64.(psi_c)
    plans.forward * psi_k
    dx = similar(psi_k); dy = similar(psi_k)
    @inbounds for I in CartesianIndices(n_pts)
        dx[I] = im * grid.k[1][I[1]] * psi_k[I]
        dy[I] = im * grid.k[2][I[2]] * psi_k[I]
    end
    plans.inverse * dx; plans.inverse * dy
    dV = cell_volume(grid)
    Lz = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]
        Lz += real(conj(psi_c[I]) * (-im) * (x * dy[I] - y * dx[I])) * dV
    end
    Lz
end

# Rigorous per-component vortex census on mid-z slice: quantized plaquette
# windings and density-hole contrast at the strongest core.
function vortex_census(psi, grid, c, N)
    zc = size(psi, 3) ÷ 2 + 1
    # mask low-density edge (phase noise there fakes windings): threshold at
    # 15% of the component's peak amplitude on the mid-z slice.
    idxc = SpinorBEC._component_slice(N, ntuple(d -> size(psi, d), N), c)
    amp_peak = sqrt(maximum(abs2, view(psi, idxc...)[:, :, zc]))
    thr = 0.15 * amp_peak
    w = winding_number_field(psi, grid; component=c, threshold=thr)
    wslice = view(w, :, :, zc)
    nplus  = count(==(1), wslice) + 2 * count(==(2), wslice)
    nminus = count(==(-1), wslice) + 2 * count(==(-2), wslice)
    net = sum(wslice)
    idx = SpinorBEC._component_slice(N, ntuple(d -> size(psi, d), N), c)
    dens = abs2.(view(psi, idx...)[:, :, zc])
    core_contrast = NaN
    ci = findfirst(x -> abs(x) >= 1, wslice)
    if ci !== nothing
        peak = maximum(dens)
        core_contrast = peak > 0 ? dens[ci[1], ci[2]] / peak : NaN
    end
    (nplus=nplus, nminus=nminus, net=net, core_contrast=core_contrast)
end

function main()
    rj     = ARGS[1]
    Omega  = parse(Float64, ARGS[2])
    outcsv = ARGS[3]
    snapdir = length(ARGS) >= 4 ? ARGS[4] : ""   # dir for 2D field CSVs
    snapdir != "" && mkpath(snapdir)
    otag = @sprintf("%+.2f", Omega)

    rr   = open_result(rj)
    grid = rr.grid
    N    = length(grid.config.n_points)
    D    = size(rr.psi, N + 1)
    F    = (D - 1) ÷ 2
    sys  = SpinSystem(F)
    plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV   = cell_volume(grid)

    jldopen(rj, "r") do f
        times = collect(Float64, f["dynamics/times"])
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        nf = length(frames)
        # snapshot times: skip the GS frame if times has one extra
        stimes = length(times) == nf + 1 ? times[2:end] :
                 length(times) == nf ? times : times[1:min(nf, length(times))]

        rows = String[]
        hdr = "Omega,frame,t,norm,Fz,Lz,Jz,peak,vtx_plus,vtx_minus,vtx_net,core_contrast"
        for m in F:-1:-F; hdr *= ",pop_m$(m)"; end
        for m in F:-1:-F; hdr *= ",Lz_m$(m)"; end
        push!(rows, hdr)

        # snapshot dumps: several frames spanning the trajectory for vortex viz
        dump_idx = unique(clamp.(round.(Int, range(1, nf; length=8)), 1, nf))

        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            npts = ntuple(d -> size(psi, d), N)
            norm = sqrt(sum(abs2, psi) * dV)
            Fz = magnetization(psi, grid, sys)
            Lz = orbital_angular_momentum(psi, grid, plans)
            ntot = dropdims(sum(abs2, psi; dims=N+1); dims=N+1)
            peak = maximum(ntot)
            pops = Float64[]; lzm = Float64[]
            for c in 1:D
                idx = SpinorBEC._component_slice(N, npts, c)
                psic = psi[idx...]
                push!(pops, sum(abs2, psic) * dV)
                push!(lzm, component_Lz(psic, grid, plans))
            end
            t = i <= length(stimes) ? stimes[i] : NaN
            # vortex census on the MOST-VORTICAL component (max |net winding|
            # after edge masking) — EdH vortices live in transferred m, not
            # the vortex-free dominant reservoir. Require non-trivial pop.
            vc = (nplus=0, nminus=0, net=0, core_contrast=NaN)
            best_abs = -1
            for c in 1:D
                pops[c] < 0.02 && continue
                vci = vortex_census(psi, grid, c, N)
                a = abs(vci.net)
                if a > best_abs
                    best_abs = a; vc = vci
                end
            end
            row = @sprintf("%.4f,%d,%.6e,%.6e,%.6e,%.6e,%.6e,%.6e,%d,%d,%d,%.4f",
                           Omega, i, t, norm, Fz, Lz, Lz + Fz, peak,
                           vc.nplus, vc.nminus, vc.net, vc.core_contrast)
            for p in pops; row *= @sprintf(",%.6e", p); end
            for l in lzm;  row *= @sprintf(",%.6e", l); end
            push!(rows, row)

            if i in dump_idx && snapdir != "" && N == 3
                # integrate over z -> 2D column density + mid-z phase per m
                zc = size(psi, 3) ÷ 2 + 1
                writedlm(joinpath(snapdir, "O$(otag)_f$(i)_ntot2d.csv"),
                         dropdims(sum(ntot; dims=3); dims=3), ',')
                for c in 1:D
                    idx = SpinorBEC._component_slice(N, npts, c)
                    psic = psi[idx...]
                    m = sys.m_values[c]
                    writedlm(joinpath(snapdir, "O$(otag)_f$(i)_dens_m$(m).csv"),
                             dropdims(sum(abs2, psic; dims=3); dims=3), ',')
                    writedlm(joinpath(snapdir, "O$(otag)_f$(i)_phase_m$(m).csv"),
                             angle.(psic[:, :, zc]), ',')
                end
                # winding-number field (mid-z) of the most-vortical
                # component: clean ±1 vortex-core map for visualisation.
                chost = 1; bestn = -1
                for c in 1:D
                    pops[c] < 0.02 && continue
                    vci = vortex_census(psi, grid, c, N)
                    abs(vci.net) > bestn && (bestn = abs(vci.net); chost = c)
                end
                amp_pk = sqrt(maximum(abs2, psi[SpinorBEC._component_slice(N, npts, chost)...][:, :, zc]))
                wf = winding_number_field(psi, grid; component=chost, threshold=0.15 * amp_pk)
                writedlm(joinpath(snapdir, "O$(otag)_f$(i)_winding.csv"), wf[:, :, zc], ',')
                writedlm(joinpath(snapdir, "O$(otag)_f$(i)_densvtx.csv"),
                         abs2.(psi[SpinorBEC._component_slice(N, npts, chost)...][:, :, zc]), ',')
                # total probability current (mid-z) for streamlines
                jvec = probability_current(psi, grid, plans)
                writedlm(joinpath(snapdir, "O$(otag)_f$(i)_jx.csv"), jvec[1][:, :, zc], ',')
                writedlm(joinpath(snapdir, "O$(otag)_f$(i)_jy.csv"), jvec[2][:, :, zc], ',')
                open(joinpath(snapdir, "O$(otag)_f$(i)_meta.txt"), "w") do io
                    println(io, "t=$t"); println(io, "frame=$i")
                    println(io, "mvtx=$(sys.m_values[chost])")
                end
            end
        end

        open(outcsv, "w") do io
            for r in rows; println(io, r); end
        end
        println("[csv] wrote $outcsv ($(nf) frames)")
        if snapdir != ""
            writedlm(joinpath(snapdir, "grid_x.csv"), collect(grid.x[1]), ',')
            writedlm(joinpath(snapdir, "grid_y.csv"), collect(grid.x[2]), ',')
            println("[snap] wrote 2D fields to $snapdir")
        end
    end
end

main()
