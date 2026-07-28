# Cone-angle scan for the FIELD-UP one-sided excitation, large Zeeman gap.
#
# Validated regime (run_field_test.jl): field UP, m=+F metastable, a large gap
# omega_L~5 Zeeman-suppresses spontaneous relaxation, and only the resonant
# CO-rotating drive (+Omega) flips the spin. Here we vary the cone angle theta
# of the single tilted precessing field of fixed magnitude B (gamma*B=5.1):
#   B(t) = B( sin(theta) cos(Omega t), sin(theta) sin(Omega t), cos(theta) )
#   B_par = B cos(theta) (UP) -> omega_L = 5.1 cos(theta)  (resonant Omega)
#   B_perp = B sin(theta)      -> drive Rabi  Omega_R = 5.1 sin(theta)
# Small theta: large gap (relaxation frozen) + slow, very selective flip.
# Large theta: gap shrinks (relaxation returns, more vortices) + fast, less
# selective flip. We run +Omega (resonant) and -Omega (off-resonant) per theta
# to map excitation + one-sidedness + vortices vs angle.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_angle_scan.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const GS_PATH = "runs/reson_gs_e4a07fbe/point_001.jld2"   # m=+F (prepared field-down)
const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const BTOT = 3.133e-4      # Gauss; gamma*BTOT = 5.1 -> omega_L(0)=5.1
const GAMMA_B = 5.1
const DUR = 30.0
const THETAS = [12.0, 25.0, 40.0, 55.0]
# (label, theta_deg, Omega_sign); sign +1 = resonant (co-rotating) for field-up
RUNS = Tuple{String, Float64, Int}[]
for th in THETAS
    push!(RUNS, (@sprintf("th%02d_res", round(Int, th)), th, +1))
    push!(RUNS, (@sprintf("th%02d_off", round(Int, th)), th, -1))
end

function dyn_yaml(theta_deg, sign)
    th = theta_deg * π / 180
    bz = BTOT * cos(th)                 # Gauss, +z = UP
    bperp = BTOT * sin(th)
    omega_L = GAMMA_B * cos(th)
    Om = sign * omega_L
    freq = Om / (2π)
    bblock = join([
            "      B:",
            "        Bz: \"$(bz) Gauss\"",
            "        q: 0.0",
            "        Bx: {sinusoidal: {amplitude: $(bperp), frequency: $(freq), phase: 1.5707963267948966}}",
            "        By: {sinusoidal: {amplitude: $(bperp), frequency: $(freq), phase: 0.0}}",
        ], "\n")
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
      duration: $DUR
      dt: 0.0005
      ddi: {secular: false}
$bblock
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 300, psi: true, precision: f32}
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

for (tag, th, sgn) in RUNS
    ypath = joinpath(SC, "cone_$(tag).yaml")
    open(ypath, "w") do io; write(io, dyn_yaml(th, sgn)); end
    @printf("\n===== cone run %s (theta=%.0f deg sign=%+d omega_L=%.2f) =====\n",
        tag, th, sgn, GAMMA_B * cos(th * π / 180))
    rundir = run_yaml(ypath)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    spin_traj(pj, "runs/eu_barnett_rotfield_clean/traj_cone_$(tag).csv")
end
println("CONE_SCAN_DONE")
