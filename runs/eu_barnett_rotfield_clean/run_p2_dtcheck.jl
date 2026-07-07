# P2 Task-3 follow-up: is the CW runaway depolarisation (|F| 6->2.26) PHYSICAL
# (counter-rotating drive resonance) or a dt artifact? split_step! is 1st-order
# in time with DDI + a rotating field (gotcha_split_step_first_order_with_ddi),
# so halve dt and re-check |F|(t). CCW is the converged control.
#
# Reuses the shared DDI-on GS; DDI-on dynamics at Omega=0.74, both chiralities,
# dt=0.0002 (half), duration 15 (enough to see the |F| trend). Compare |F|(t)
# against the dt=0.0004 runs (traj_p2_on_{p,m}0.74.csv) over t<15.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/run_p2_dtcheck.jl
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/80199575-e261-4fe8-a6af-74f719f5341c/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const BAMP = 2.458e-4
const BXG = "2.458e-4 Gauss"
const OMEGA = 0.74
const DUR = 15.0
const DYN_DT = 0.0002          # half of the production 0.0004
const GS = "runs/p2_gs_023c8645/point_001.jld2"
mkpath(SC)
isfile(GS) || error("shared GS missing: $GS")

function dyn_yaml(sgn)
    freq = OMEGA / (2π)
    bx_phase = sgn > 0 ? 1.5707963267948966 : -1.5707963267948966
    """
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
      initial_state: from_jld2
      init_state_params: {path: $GS, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: $DYN_DT
      ddi: {enabled: true, secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: $bx_phase}}
        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 600, psi: true, precision: f32}
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
end

for (tag, sgn) in [("ccw", +1), ("cw", -1)]
    yp = joinpath(SC, "p2dt_$(tag).yaml"); open(yp, "w") do io; write(io, dyn_yaml(sgn)); end
    @printf("\n===== dt-check %s (Omega=%.2f dt=%.4f) =====\n", tag, OMEGA, DYN_DT); flush(stdout)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    outcsv = joinpath(OUT, "traj_p2_dtcheck_$(tag).csv")
    traj(pj, outcsv)
    @printf("[dtcheck] wrote %s\n", outcsv); flush(stdout)
end
println("P2_DTCHECK_DONE")
