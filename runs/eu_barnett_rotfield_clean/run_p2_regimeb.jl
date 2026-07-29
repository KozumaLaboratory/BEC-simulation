# P2 — regime-B mechanical-Barnett net M_z (the decisive single-stage test).
#
# Same Klaus stirring as P1 but at a MODERATE field (gamma*B ~ 4, a few x
# omega_perp) so the spin is NOT fully locked and can respond to the vortex
# dipolar field B_dd. Measure Fz(t) with DDI ON vs OFF (same elongated GS):
#   dFz = Fz(DDI-on) - Fz(DDI-off) = the DDI/Barnett net magnetisation, with
# the single-particle -Omega/gamma tilt (present in both) subtracted. Pass-2
# predicts dFz ~ 0 (z-cancellation); this settles single-stage vs two-stage.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_p2_regimeb.jl
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const BXG = "2.458e-4 Gauss"   # gamma*B = 4 (regime-B: spin ~aligned but responsive)
const BAMP = 2.458e-4
const OMEGA = 0.85
const DUR = 30.0
mkpath(SC)

gs_yaml() = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [48, 48, 24], box: [12.0, 12.0, 6.0]}
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
      n_steps: 2500
      tol: 1.0e-9
"""

function dyn_yaml(gs_path, ddi_on)
    freq = OMEGA / (2π)
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [48, 48, 24], box: [12.0, 12.0, 6.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: $ddi_on, secular: false}
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
      ddi: {enabled: $ddi_on, secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 300, psi: true, precision: f32}
"""
end

function traj(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fz,Fmag,Lz"]
    jldopen(pj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        st = length(times) == length(frames) + 1 ? times[2:end] : times[1:min(length(frames), length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            fx, fy, fz = spin_density_vector(psi, sm, N)
            Fx = sum(fx) * dV; Fy = sum(fy) * dV; Fz = sum(fz) * dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f", t, Fz, sqrt(Fx^2 + Fy^2 + Fz^2), Lz))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[p2] wrote $outcsv")
end

gy = joinpath(SC, "p2_gs.yaml"); open(gy, "w") do io; write(io, gs_yaml()); end
println("===== P2 GS (regime-B gamma*B=4) =====")
gsdir = run_yaml(gy); gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")
let rr = open_result(gs_path)
    Nn = length(rr.grid.config.n_points); Dd = size(rr.psi, Nn + 1); Ff = (Dd - 1) ÷ 2
    sm = spin_matrices(Ff); dV = cell_volume(rr.grid)
    fx, fy, fz = spin_density_vector(ComplexF64.(rr.psi), sm, Nn)
    @printf("GS |F|=%.3f Fz=%.3f\n", sqrt((sum(fx)*dV)^2 + (sum(fy)*dV)^2 + (sum(fz)*dV)^2), sum(fz)*dV)
end

for (tag, on) in [("on", "true"), ("off", "false")]
    yp = joinpath(SC, "p2_$(tag).yaml"); open(yp, "w") do io; write(io, dyn_yaml(gs_path, on)); end
    @printf("\n===== P2 dynamics DDI=%s =====\n", tag)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    traj(pj, joinpath(OUT, "traj_p2_$(tag).csv"))
end
println("P2_DONE")
