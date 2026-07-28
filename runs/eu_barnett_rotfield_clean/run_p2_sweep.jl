# P2 completion, Tasks 2+3: multi-Omega Delta-Fz + CW/CCW double difference.
#
# Reuses the P2 regime-B setup (gamma*B=4 static-Bx GS -> rotating-field
# dynamics) but sweeps Omega and rotation SENSE. Chirality is set by the Bx/By
# phase relationship (each component is a cosine, so negating the frequency is a
# no-op): CCW (+Omega) = Bx phase +pi/2 ; CW (-Omega) = Bx phase -pi/2.
# noise_seed defaults to 42 (fixed) so CW and CCW share the identical
# symmetry-breaking kick -> the double difference is signal, not seed noise.
#
# Jobs (10 dynamics runs; GS for ddi on/off is content-addressed + cached):
#   Task 2  sign=+  ddi in {on,off}  Omega in {0.5,0.65,0.74,0.8}   -> 8
#   Task 3  sign=-  ddi in {on,off}  Omega = 0.74                   -> 2
# (Omega=0.85 +Omega on/off already exist as traj_p2_{on,off}.csv.)
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/run_p2_sweep.jl
# Env: SMOKE=1 shrinks everything to exercise all code paths in ~2 min.
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/80199575-e261-4fe8-a6af-74f719f5341c/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const BXG = "2.458e-4 Gauss"       # gamma*B = 4
const BAMP = 2.458e-4
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const DUR = SMOKE ? 1.0 : 30.0
const GS_STEPS = SMOKE ? 50 : 2500
const DYN_DT = SMOKE ? 0.004 : 0.0004
const SAVE_EVERY = SMOKE ? 50 : 300
mkpath(SC)

# Task list: (omega, sign, ddi). sign = +1 (CCW) or -1 (CW).
const JOBS = SMOKE ?
    [(0.74, +1, "on"), (0.74, -1, "off")] :
    vcat(
        [(Ω, +1, d) for Ω in (0.5, 0.65, 0.74, 0.8) for d in ("on", "off")],
        [(0.74, -1, "on"), (0.74, -1, "off")],
    )

gs_yaml(ddi_on) = """
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
      initial_state: spin_coherent
      init_state_params: {init_theta: 1.5707963267948966, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.004
      n_steps: $GS_STEPS
      tol: 1.0e-9
"""

# sign=+1 -> Bx phase +pi/2 (CCW) ; sign=-1 -> Bx phase -pi/2 (CW)
function dyn_yaml(gs_path, ddi_on, omega, sgn)
    freq = omega / (2π)
    bx_phase = sgn > 0 ? 1.5707963267948966 : -1.5707963267948966
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
      dt: $DYN_DT
      ddi: {enabled: $ddi_on, secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: $bx_phase}}
        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
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

# --- single DDI-on ground state for ALL dynamics (matches run_p2_regimeb.jl:
# same elongated initial state for on AND off dynamics, so DDI-off cleanly
# subtracts the single-particle -Omega/gamma tilt without changing the start).
# Reuse the existing content-addressed GS (bit-identical spec to the original
# P2 runs -> the Omega=0.85 point stays consistent); recompute only if absent.
const GS_EXISTING = "runs/p2_gs_023c8645/point_001.jld2"
const GSPATH = if isfile(GS_EXISTING)
    println("===== GS: reusing $GS_EXISTING ====="); flush(stdout)
    GS_EXISTING
else
    gy = joinpath(SC, "p2sweep_gs.yaml"); open(gy, "w") do io; write(io, gs_yaml("true")); end
    println("===== GS (DDI-on, shared by all dynamics) ====="); flush(stdout)
    gsdir = run_yaml(gy)
    joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")
end

# --- dynamics sweep ---
for (k, (omega, sgn, ddi)) in enumerate(JOBS)
    s = sgn > 0 ? "p" : "m"
    tag = @sprintf("%s_%s%.2f", ddi, s, omega)
    yp = joinpath(SC, "p2sweep_$(tag).yaml")
    open(yp, "w") do io; write(io, dyn_yaml(GSPATH, ddi == "on" ? "true" : "false", omega, sgn)); end
    @printf("\n===== [%d/%d] dynamics %s  (Omega=%.2f sign=%+d ddi=%s) =====\n",
        k, length(JOBS), tag, omega, sgn, ddi); flush(stdout)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    outcsv = joinpath(OUT, "traj_p2_$(tag).csv")
    traj(pj, outcsv)
    @printf("[p2sweep] wrote %s\n", outcsv); flush(stdout)
end
println("P2_SWEEP_DONE")
