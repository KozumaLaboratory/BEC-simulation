# Left/right rotation comparison at the OPTIMAL vortex rotation rate.
#
# The dense Omega scan (run_dense_sweep.jl) put the vortex <L_z> peak at
# Omega=0.30 (Barnett <F_z> peaks broader at 0.40). We run the direction
# control at that optimum: +Omega (CCW), 0 (control), -Omega (CW), all from
# the SAME converged transverse (J_z=0) GS via from_jld2 -> fast, and the
# only difference between the three runs is the sign of the rotation.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_direction_compare.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const GS_PATH = "runs/transverse_gs_save_a03bae4c/point_001.jld2"
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const OMEGA = 0.30            # optimal vortex rotation rate (dense scan)
const AMP = 2.13e-5
const OMEGAS = [OMEGA, 0.0, -OMEGA]

function yaml_for(Om)
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
      B: {Bx: {from: 0.01, to: $AMP, duration: 0.20}, By: 0.0, Bz: 0.0}
      save: {every: 400}
  - dynamics:
      duration: 25.0
      dt: 0.001
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $AMP, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $AMP, frequency: $freq, phase: 0.0}}
      save: {every: 250, psi: true, precision: f32}
"""
end

# in-session spin-vector + orbital trajectory (t, Fx, Fy, Fz, |F|, Lz per frame)
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

for Om in OMEGAS
    ypath = joinpath(SC, @sprintf("dircmp_O%+.2f.yaml", Om))
    open(ypath, "w") do io; write(io, yaml_for(Om)); end
    @printf("\n===== direction-compare Omega = %+.2f =====\n", Om)
    rundir = run_yaml(ypath)
    outcsv = @sprintf("runs/eu_barnett_rotfield_clean/traj_dir_O%+.2f.csv", Om)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    spin_traj(pj, outcsv)
    println("run dir: ", rundir, " -> ", outcsv)
end
println("DIRECTION_COMPARE_DONE")
