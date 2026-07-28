# P1 — Klaus magnetostriction-stirring reproduction (orbital / spin-less bench).
#
# Strong in-plane field (gamma*B ~ 10 >> Omega): the spin locks to B (scalar
# limit, |F|~6, single-particle M_z suppressed), and DDI magnetostriction
# elongates the cloud ALONG the in-plane field. Rotating the field stirs the
# elongated cloud; above the quadrupole surface mode Omega_c ~ 0.7-0.75 w_perp
# vortices nucleate. Pancake trap (tight z), rotation axis = z.
#
# Signatures (Klaus): aspect ratio AR(t) grows then COLLAPSES at vortex entry;
# L_z jumps; the ellipse LAGS the field (lag angle). Scan Omega across Omega_c.
#
# SMOKE=1 -> tiny GS + short single-Omega run to validate the machinery.
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_p1_klaus.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

# portable config (env overrides for TSUBAME / hi-res convergence runs)
const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad")
const OUTDIR = get(ENV, "P1_OUT", "runs/eu_barnett_rotfield_clean")
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const BXG = "9.216e-4 Gauss"   # gamma*B = 15 (deep-ish scalar lock)
const BAMP = 9.216e-4          # same, for the rotating drive
_parsef(s) = parse.(Float64, split(s, ","))
_parsei(s) = parse.(Int, split(s, ","))
const P1_N = get(ENV, "P1_N", "48,48,24")       # grid points
const P1_BOX = get(ENV, "P1_BOX", "12.0,12.0,6.0")
const OMEGAS = SMOKE ? [0.85] :
    haskey(ENV, "P1_OMEGAS") ? _parsef(ENV["P1_OMEGAS"]) : [0.4, 0.55, 0.70, 0.74, 0.85, 0.95]
const DUR = SMOKE ? 3.0 : parse(Float64, get(ENV, "P1_DUR", "30.0"))
const GS_NSTEPS = SMOKE ? 300 : parse(Int, get(ENV, "P1_GS_NSTEPS", "2500"))
mkpath(SC); mkpath(OUTDIR)

# GS: strong field along +x, spin along +x, pancake trap -> cloud elongated
# along x by magnetostriction. Prepared once, reused via from_jld2 per Omega.
const GS_YAML = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$P1_N], box: [$P1_BOX]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: $BXG, By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.004
      n_steps: $GS_NSTEPS
      tol: 1.0e-9
"""

function dyn_yaml(gs_path, Om)
    freq = Om / (2π)
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$P1_N], box: [$P1_BOX]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: $BXG, By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $gs_path, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: 0.0004
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}
      save: {every: 300, psi: true, precision: f32}
"""
end

# per-frame: aspect ratio + ellipse angle (2D column-density moment tensor),
# ellipse lag vs field angle, L_z, |F|, F_z.
function klaus_metrics(pj, Om, outcsv)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    npts = grid.config.n_points
    xs = grid.x[1]; ys = grid.x[2]
    rows = ["t,AR,ell_angle,field_angle,lag,Lz,Fmag,Fz,Nv"]
    jldopen(pj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        nf = length(frames)
        st = length(times) == nf + 1 ? times[2:end] : times[1:min(nf, length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            n = dropdims(sum(abs2, psi; dims=(3, N + 1)); dims=(3, N + 1))  # column density n(x,y)
            ntot = sum(n)
            mx = sum(n[ix, iy] * xs[ix] for ix in 1:npts[1], iy in 1:npts[2]) / ntot
            my = sum(n[ix, iy] * ys[iy] for ix in 1:npts[1], iy in 1:npts[2]) / ntot
            Mxx = sum(n[ix, iy] * (xs[ix] - mx)^2 for ix in 1:npts[1], iy in 1:npts[2]) / ntot
            Myy = sum(n[ix, iy] * (ys[iy] - my)^2 for ix in 1:npts[1], iy in 1:npts[2]) / ntot
            Mxy = sum(n[ix, iy] * (xs[ix] - mx) * (ys[iy] - my) for ix in 1:npts[1], iy in 1:npts[2]) / ntot
            tr = Mxx + Myy; dd = sqrt(max(((Mxx - Myy) / 2)^2 + Mxy^2, 0.0))
            lp = tr / 2 + dd; lm = tr / 2 - dd
            AR = sqrt(max(lp / max(lm, 1e-12), 1.0))
            ell = 0.5 * atan(2Mxy, Mxx - Myy)          # principal-axis angle
            t = i <= length(st) ? st[i] : NaN
            fang = mod(Om * t, π)                        # field axis is pi-periodic
            lag = mod(fang - ell + π / 2, π) - π / 2     # signed lag in (-pi/2, pi/2]
            fx, fy, fz = spin_density_vector(psi, sm, N)
            Fx = sum(fx) * dV; Fy = sum(fy) * dV; Fz = sum(fz) * dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            # vortex-core count: deep local minima of the column density INSIDE
            # the cloud (surrounded by high density) = vortex cores.
            pk = maximum(n); nv = 0
            @inbounds for ix in 2:npts[1]-1, iy in 2:npts[2]-1
                c = n[ix, iy]
                c < 0.3 * pk || continue
                ismin = true
                for ddx in -1:1, ddy in -1:1
                    (ddx == 0 && ddy == 0) && continue
                    if n[ix+ddx, iy+ddy] < c; ismin = false; break; end
                end
                ismin || continue
                surround = (n[ix-1, iy] + n[ix+1, iy] + n[ix, iy-1] + n[ix, iy+1]) / 4
                surround > 0.2 * pk && (nv += 1)
            end
            push!(rows, @sprintf("%.5f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%d",
                                 t, AR, ell, fang, lag, Lz, sqrt(Fx^2 + Fy^2 + Fz^2), Fz, nv))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[klaus] wrote $outcsv")
end

# 1) shared magnetostriction GS
gsy = joinpath(SC, "p1_gs.yaml"); open(gsy, "w") do io; write(io, GS_YAML); end
println("===== P1 GS (magnetostriction, field along +x) =====")
gs_rundir = run_yaml(gsy)
gs_path = joinpath(gs_rundir isa AbstractString ? gs_rundir : "", "point_001.jld2")
# report GS elongation + spin lock
let rr = open_result(gs_path)
    N = length(rr.grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); dV = cell_volume(rr.grid)
    fx, fy, fz = spin_density_vector(ComplexF64.(rr.psi), sm, N)
    @printf("GS |F|=%.3f (Fx=%.2f Fy=%.2f Fz=%.2f)\n",
        sqrt((sum(fx)*dV)^2 + (sum(fy)*dV)^2 + (sum(fz)*dV)^2), sum(fx)*dV, sum(fy)*dV, sum(fz)*dV)
end

# 2) Omega scan
for Om in OMEGAS
    ypath = joinpath(SC, @sprintf("p1_O%.2f.yaml", Om)); open(ypath, "w") do io; write(io, dyn_yaml(gs_path, Om)); end
    @printf("\n===== P1 Klaus stir Omega=%.2f =====\n", Om)
    rundir = run_yaml(ypath)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    klaus_metrics(pj, Om, joinpath(OUTDIR, @sprintf("traj_p1_O%.2f.csv", Om)))
end
println("P1_KLAUS_DONE")
