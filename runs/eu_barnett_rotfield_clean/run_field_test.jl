# Diagnostic: does a LARGER Zeeman gap suppress the spontaneous relaxation of
# the field-up metastable m=+F, restoring the one-sided (chiral) excitation?
#
# At omega_L=0.5 the field-up m=+F is dynamically unstable (tau~4, relaxes on
# its own regardless of drive). Raising omega_L above the DDI energy scale
# should Zeeman-suppress the spontaneous m->m-1 relaxation (long metastable
# lifetime) while a resonant co-rotating drive at Omega=omega_L still excites.
#
# omega_L = 5 (Bz = +3.07e-4 G up), drive Rabi Omega_R ~ 1 (<< 2 omega_L=10).
# Runs: nodrive (frozen?), +Omega, -Omega.  Compare to the omega_L=0.5 case.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_field_test.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const GS_PATH = "runs/reson_gs_e4a07fbe/point_001.jld2"   # m=+F
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const BZ_UP = "3.072e-4 Gauss"    # -> |p| = omega_L = 5 (field UP)
const OMEGA_L = 5.0
const AMP = 6.144e-5              # -> Omega_R ~ 1
# (label, drive_on, Omega)
const RUNS = [("hi_nodrive", false, 0.0), ("hi_+5", true, +OMEGA_L), ("hi_-5", true, -OMEGA_L)]

function dyn_yaml(drive_on, Om)
    freq = Om / (2π)
    bb = if !drive_on
        "      B: {Bz: \"$BZ_UP\", q: 0.0, Bx: 0.0, By: 0.0}"
    else
        join([
                "      B:",
                "        Bz: \"$BZ_UP\"",
                "        q: 0.0",
                "        Bx: {sinusoidal: {amplitude: $AMP, frequency: $freq, phase: 1.5707963267948966}}",
                "        By: {sinusoidal: {amplitude: $AMP, frequency: $freq, phase: 0.0}}",
            ], "\n")
    end
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
      B: {Bz: 0.0, q: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $GS_PATH, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: 40.0
      dt: 0.0005
      ddi: {secular: false}
$bb
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 400, psi: true, precision: f32}
"""
end

function spin_traj(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fx,Fy,Fz,Fmag,Lz"]
    jldopen(pj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        nf = length(frames)
        st = length(times) == nf + 1 ? times[2:end] : times[1:min(nf, length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            fx, fy, fz = spin_density_vector(psi, sm, N)
            Fx = sum(fx) * dV; Fy = sum(fy) * dV; Fz = sum(fz) * dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f",
                                 t, Fx, Fy, Fz, sqrt(Fx^2 + Fy^2 + Fz^2), Lz))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    println("[spin-vec] wrote $outcsv")
end

for (tag, drv, Om) in RUNS
    ypath = joinpath(SC, "ftest_$(tag).yaml")
    open(ypath, "w") do io; write(io, dyn_yaml(drv, Om)); end
    @printf("\n===== field-test %s (drive=%s Omega=%+.1f) =====\n", tag, drv, Om)
    rundir = run_yaml(ypath)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    spin_traj(pj, "runs/eu_barnett_rotfield_clean/traj_$(tag).csv")
end
println("FIELD_TEST_DONE")
