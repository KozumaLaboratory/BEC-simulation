# 2D optimization scan Omega x B (transverse Jz=0 start) -> heatmap of
# peak |<L_z>| and |<F_z>|. Coarse grid around the 1D optimum (Omega~0.4).
# t=12 (captures the peaks ~t=4-7) for affordability. Writes a summary CSV
# directly (Omega, B, peak_Lz, peak_Fz, meanabs_Lz).

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const OMEGAS = [0.2, 0.35, 0.5, 0.65]
const AMPS   = [1.0e-5, 2.13e-5, 4.0e-5, 8.0e-5]
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const OUTCSV = "runs/eu_barnett_rotfield_clean/summary_2d.csv"

function yaml_for(Om, amp)
    freq = Om / (2π)
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [12.0, 12.0, 12.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: "-0.01 Gauss", By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.005
      n_steps: 2000
      tol: 1.0e-9
  - dynamics:
      duration: 0.20
      dt: 0.0005
      ddi: {secular: false}
      B: {Bx: {from: 0.01, to: $amp, duration: 0.20}, By: 0.0, Bz: 0.0}
      save: {every: 400}
  - dynamics:
      duration: 12.0
      dt: 0.001
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 300, psi: true, precision: f32}
"""
end

function metrics(rj)
    rr = open_result(rj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sys = SpinSystem(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    Fzm = 0.0; Lzm = 0.0; s = 0.0; n = 0
    jldopen(rj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        for fr in filter(k -> startswith(k, "frame_"), keys(g))
            psi = ComplexF64.(g[fr])
            Fz = magnetization(psi, grid, sys); Lz = orbital_angular_momentum(psi, grid, plans)
            Fzm = max(Fzm, abs(Fz)); Lzm = max(Lzm, abs(Lz)); s += abs(Lz); n += 1
        end
    end
    (Lzm, Fzm, s / max(n, 1))
end

rows = ["Omega,B,peak_Lz,peak_Fz,meanabs_Lz"]
for Om in OMEGAS, amp in AMPS
    ypath = joinpath(SC, @sprintf("scan2d_O%.2f_A%.2e.yaml", Om, amp))
    open(ypath, "w") do io; write(io, yaml_for(Om, amp)); end
    @printf("\n=== 2D scan Omega=%.2f  B=%.2e ===\n", Om, amp)
    rundir = run_yaml(ypath)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    L, Fz, ml = metrics(pj)
    push!(rows, @sprintf("%.4f,%.6e,%.5f,%.5f,%.5f", Om, amp, L, Fz, ml))
    @printf("   peakLz=%.3f peakFz=%.3f\n", L, Fz)
    open(OUTCSV, "w") do io; for r in rows; println(io, r); end; end  # incremental
end
println("SCAN2D_DONE")
