# Two-stage PASS-0 diagnostic: which in-plane lock kills the single-stage net M_z?
#
#   (#1) EXTERNAL-field-following lock: spin held by the rotating B_ext -> quench
#        B->0 releases it -> spin free to relax into a z-asymmetric flux-closure
#        texture -> two-stage flux-closure bet is JUSTIFIED.
#   (#2) B_dd SELF-lock: spin held by the DDI's own in-plane field B_dd (which
#        does NOT vanish at B_ext=0) -> spin stays pinned in-plane -> flux-closure
#        relaxation blocked -> two-stage needs a different z-driving mechanism.
#
# Test = mini-quench on the SAVED P2 on end state (gamma*B=4, Omega=0.85, DDI-on):
# instantaneously set B_ext=0, keep DDI on, evolve, watch Fz / Fperp / |F| / Lz.
# Arm A = quench (B=0, DDI on). Arm B = control, DDI OFF at B=0 (free spin, must
# stay put: isolates DDI-driven relaxation from any load/precession artifact).
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/run_p2_quench.jl
# Env: SMOKE=1 shrinks to ~2 min.
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/80199575-e261-4fe8-a6af-74f719f5341c/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const SRC = "runs/p2_on_a5258bf8/point_001.jld2"   # P2 on end state, gamma*B=4, Omega=0.85
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const DUR = SMOKE ? 1.0 : 15.0
const DYN_DT = SMOKE ? 0.004 : 0.0004
const SAVE_EVERY = SMOKE ? 50 : 150
mkpath(SC)
isfile(SRC) || error("source end state missing: $SRC")

function quench_yaml(ddi_on)
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
      B: {Bx: 0.0, By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $SRC, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: $DYN_DT
      ddi: {enabled: $ddi_on, secular: false}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""
end

# trajectory with in-plane / axial spin split
function traj(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fx,Fy,Fz,Fperp,Fmag,Lz"]
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
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f",
                t, Fx, Fy, Fz, sqrt(Fx^2 + Fy^2), sqrt(Fx^2 + Fy^2 + Fz^2), Lz))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
end

# report the loaded (pre-quench) spin vector as the t=0 reference
let rr = open_result(SRC)
    N = length(rr.grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); dV = cell_volume(rr.grid)
    fx, fy, fz = spin_density_vector(ComplexF64.(rr.psi), sm, N)
    Fx = sum(fx) * dV; Fy = sum(fy) * dV; Fz = sum(fz) * dV
    @printf("[quench] LOADED end state: Fx=%.3f Fy=%.3f Fz=%.3f Fperp=%.3f |F|=%.3f\n",
        Fx, Fy, Fz, sqrt(Fx^2 + Fy^2), sqrt(Fx^2 + Fy^2 + Fz^2))
end

for (tag, ddi) in [("ddion", "true"), ("ddioff", "false")]
    yp = joinpath(SC, "p2quench_$(tag).yaml"); open(yp, "w") do io; write(io, quench_yaml(ddi)); end
    @printf("\n===== quench %s (B=0, DDI=%s) =====\n", tag, ddi); flush(stdout)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    outcsv = joinpath(OUT, "traj_p2_quench_$(tag).csv")
    traj(pj, outcsv)
    @printf("[quench] wrote %s\n", outcsv); flush(stdout)
end
println("P2_QUENCH_DONE")
