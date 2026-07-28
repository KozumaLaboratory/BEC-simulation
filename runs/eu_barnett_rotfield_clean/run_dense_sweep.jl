# Dense optimization sweep, reusing a precomputed transverse GS.
#
# The GS (spin along +x, <F_z>=0) is identical for every point, so we load
# it via `initial_state: from_jld2` with n_steps=1 (skip the expensive ITP)
# and only run the dynamics. One julia session -> JIT amortised -> each
# point is just a short dynamics run. Lets us take many more points than
# the 6-point sweeps.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_dense_sweep.jl <mode>
#   mode = omega | field   (which axis to densely scan)

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const GS_PATH = "runs/transverse_gs_save_a03bae4c/point_001.jld2"
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const MODE = length(ARGS) >= 1 ? ARGS[1] : "omega"

# dense axes
const OMEGAS = collect(range(0.0, 1.0; length=41))          # 41 points
const AMPS = [a * 1e-5 for a in range(0.3, 20.0; length=30)] # 30 points (log-ish below)
const FIXED_AMP = 2.13e-5
const FIXED_OMEGA = 0.5

function yaml_for(Om, amp)
    freq = Om / (2π)
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [18.0, 18.0, 18.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: "-0.01 Gauss", By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $GS_PATH, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
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
      save: {every: 250, psi: true, precision: f32}
"""
end

function metrics(rundir)
    pj = joinpath(rundir, "point_001.jld2")
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sys = SpinSystem(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    Fzm = 0.0; Lzm = 0.0; s = 0.0; n = 0
    jldopen(pj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        for fr in filter(k -> startswith(k, "frame_"), keys(g))
            psi = ComplexF64.(g[fr])
            Fz = magnetization(psi, grid, sys); Lz = orbital_angular_momentum(psi, grid, plans)
            Fzm = max(Fzm, abs(Fz)); Lzm = max(Lzm, abs(Lz)); s += abs(Lz); n += 1
        end
    end
    (Lzm, Fzm, s / max(n, 1))
end

vals = MODE == "omega" ? OMEGAS : AMPS
outcsv = "runs/eu_barnett_rotfield_clean/summary_dense_$(MODE).csv"
rows = MODE == "omega" ? ["param,peak_Lz,peak_Fz,meanabs_Lz"] : ["param,peak_Lz,peak_Fz,meanabs_Lz"]
for (i, v) in enumerate(vals)
    Om = MODE == "omega" ? v : FIXED_OMEGA
    amp = MODE == "omega" ? FIXED_AMP : v
    ypath = joinpath(SC, @sprintf("dense_%s_%03d.yaml", MODE, i))
    open(ypath, "w") do io; write(io, yaml_for(Om, amp)); end
    rundir = run_yaml(ypath)
    L, Fz, ml = metrics(rundir isa AbstractString ? rundir : "")
    param = MODE == "omega" ? Om : amp
    push!(rows, @sprintf("%.6g,%.5f,%.5f,%.5f", param, L, Fz, ml))
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    @printf("[%d/%d] %s=%.4g  peakLz=%.3f peakFz=%.3f\n", i, length(vals), MODE, param, L, Fz)
end
println("DENSE_$(uppercase(MODE))_DONE")
