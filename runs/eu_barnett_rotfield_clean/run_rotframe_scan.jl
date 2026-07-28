# Rotating-frame GS scan via SEPARATE per-Omega runs (avoids the
# scan-override-not-applying bug on rotating_frame_omega). One julia
# session loops Omega, runs each GS, computes <F_z>,<L_z>,per-m from psi.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_rotframe_scan.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, DelimitedFiles

const OMEGAS = [-0.85, -0.7, -0.5, -0.3, 0.0, 0.3, 0.5, 0.7, 0.85]
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const OUTCSV = "runs/eu_barnett_rotfield_clean/rotframe_scan.csv"
const SNAPDIR = "runs/eu_barnett_rotfield_clean/snaps_rf"
mkpath(SNAPDIR)

function yaml_for(Om)
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 20000, omega_ref: 691.15}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [40, 40, 20], box: [16, 16, 8]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 20000, omega_ref: 691.15, c1_ratio: 0.02778}
      ddi: {enabled: true}
      lhy: {kind: none}
      B: {Bz: "2.6e-6 Gauss"}
      rotating_frame_omega: $Om
      initial_state: m_minus_F
      init_sigma: 1.5
      n_steps: 2500
      tol: 1.0e-9
      dt: 0.004
"""
end

function component_Lz(psi_c, grid, plans)
    n_pts = size(psi_c); psi_k = ComplexF64.(psi_c); plans.forward * psi_k
    dx = similar(psi_k); dy = similar(psi_k)
    @inbounds for I in CartesianIndices(n_pts)
        dx[I] = im * grid.k[1][I[1]] * psi_k[I]; dy[I] = im * grid.k[2][I[2]] * psi_k[I]
    end
    plans.inverse * dx; plans.inverse * dy
    dV = cell_volume(grid); Lz = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]
        Lz += real(conj(psi_c[I]) * (-im) * (x * dy[I] - y * dx[I])) * dV
    end
    Lz
end

# Rigorous vortex census on the mid-z slice of a chosen component:
# count quantized plaquette windings (+1 / -1), net charge, and the
# density-hole depth at the strongest core.
function vortex_census(psi, grid, c, N)
    zc = size(psi, 3) ÷ 2 + 1
    w = winding_number_field(psi, grid; component=c)          # (nx-1,ny-1,nz)
    wslice = view(w, :, :, zc)
    nplus  = count(==(1), wslice) + 2 * count(==(2), wslice)
    nminus = count(==(-1), wslice) + 2 * count(==(-2), wslice)
    net = sum(wslice)
    # density-hole contrast at the strongest winding core (0 = full hole)
    idx = SpinorBEC._component_slice(N, ntuple(d -> size(psi, d), N), c)
    dens = abs2.(view(psi, idx...)[:, :, zc])
    core_contrast = NaN
    if net != 0 || nplus + nminus > 0
        # find a plaquette with |winding|>=1, read density at its corner
        ci = findfirst(x -> abs(x) >= 1, wslice)
        if ci !== nothing
            peak = maximum(dens)
            core = dens[ci[1], ci[2]]
            core_contrast = peak > 0 ? core / peak : NaN   # ~0 for a real vortex core
        end
    end
    (nplus=nplus, nminus=nminus, net=net, core_contrast=core_contrast)
end

rows = String[]
Fref = nothing
for (i, Om) in enumerate(OMEGAS)
    ypath = joinpath(SC, "rf_om_$(i).yaml")
    open(ypath, "w") do io; write(io, yaml_for(Om)); end
    println("\n===== Omega = $Om =====")
    rundir = run_yaml(ypath; audit=false)
    # run_yaml returns the run directory (String) or a summary; locate point_001
    pj = if rundir isa AbstractString && isfile(joinpath(rundir, "point_001.jld2"))
        joinpath(rundir, "point_001.jld2")
    else
        # fall back: newest runs/ dir containing point_001.jld2
        cands = filter(d -> isfile(joinpath(d, "point_001.jld2")), readdir("runs"; join=true))
        sort(cands; by=mtime)[end] |> d -> joinpath(d, "point_001.jld2")
    end
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sys = SpinSystem(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid); psi = ComplexF64.(rr.psi)
    npts = ntuple(d -> size(psi, d), N)
    Fz = magnetization(psi, grid, sys); Lz = orbital_angular_momentum(psi, grid, plans)
    E = jldopen(pj, "r") do f; f["energy"]; end
    conv = jldopen(pj, "r") do f; f["converged"]; end
    pops = Float64[]; lzm = Float64[]
    for c in 1:D
        idx = SpinorBEC._component_slice(N, npts, c); psic = psi[idx...]
        push!(pops, sum(abs2, psic) * dV); push!(lzm, component_Lz(psic, grid, plans))
    end
    cmax0 = argmax(pops)
    vc = vortex_census(psi, grid, cmax0, N)
    global Fref
    if Fref === nothing
        Fref = F; hdr = "Omega,energy,conv,Fz,Lz,Jz,vtx_plus,vtx_minus,vtx_net,core_contrast"
        for m in F:-1:-F; hdr *= ",pop_m$(m)"; end
        for m in F:-1:-F; hdr *= ",Lz_m$(m)"; end
        push!(rows, hdr)
    end
    row = @sprintf("%.4f,%.6e,%s,%.6e,%.6e,%.6e,%d,%d,%d,%.4f",
                   Om, E, string(conv), Fz, Lz, Lz + Fz,
                   vc.nplus, vc.nminus, vc.net, vc.core_contrast)
    for p in pops; row *= @sprintf(",%.6e", p); end
    for l in lzm; row *= @sprintf(",%.6e", l); end
    push!(rows, row)
    @printf("Omega=%+.2f  E=%.3f conv=%s  Fz=%.3f  Lz=%.3f  vtx(+%d/-%d net%d)  core=%.3f\n",
            Om, E, string(conv), Fz, Lz, vc.nplus, vc.nminus, vc.net, vc.core_contrast)

    # 2D viz: column density + dominant-m mid-z phase
    zc = size(psi, 3) ÷ 2 + 1
    ntot = dropdims(sum(abs2, psi; dims=N+1); dims=N+1)
    writedlm(joinpath(SNAPDIR, @sprintf("O%+.2f_ntot2d.csv", Om)), dropdims(sum(ntot; dims=3); dims=3), ',')
    cmax = argmax(pops); mdom = sys.m_values[cmax]
    idx = SpinorBEC._component_slice(N, npts, cmax)
    writedlm(joinpath(SNAPDIR, @sprintf("O%+.2f_phase_mdom.csv", Om)), angle.(psi[idx...][:, :, zc]), ',')
    writedlm(joinpath(SNAPDIR, @sprintf("O%+.2f_dens_mdom.csv", Om)), dropdims(sum(abs2, psi[idx...]; dims=3); dims=3), ',')
    open(joinpath(SNAPDIR, @sprintf("O%+.2f_meta.txt", Om)), "w") do io
        println(io, "Omega=$Om"); println(io, "mdom=$mdom"); println(io, "Fz=$Fz"); println(io, "Lz=$Lz")
    end
    if i == 1
        writedlm(joinpath(SNAPDIR, "grid_x.csv"), collect(grid.x[1]), ',')
        writedlm(joinpath(SNAPDIR, "grid_y.csv"), collect(grid.x[2]), ',')
    end
end

open(OUTCSV, "w") do io; for r in rows; println(io, r); end; end
println("\n[csv] wrote $OUTCSV")
println("ROTFRAME_SCAN_DONE")
