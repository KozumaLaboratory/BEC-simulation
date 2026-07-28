# Quench-ONLY dt-check: load a saved stir end-state (vortex-laden) and run only the
# B=0 quench at a chosen dt. Isolates the TIME-discretisation contribution to the
# residual Jz on the exact stage that matters (the quench conversion), from an
# IDENTICAL start -> fast (no GS/stir re-run) and matched to the existing dt=4e-4
# quench that started from the SAME stir jld2.
#
# Env: RB_STIR_SRC (stir point_001.jld2), RB_N, RB_BOX, RB_DT, RB_QUENCH,
#      RB_SAVE_EVERY, RB_TAG. Usage on TSUBAME:
#   RB_STIR_SRC=runs/rb_stir_8315c9e8/point_001.jld2 RB_DT=0.0002 RB_QUENCH=20 \
#     julia --project=. runs/eu_barnett_rotfield_clean/run_quench_dtcheck.jl
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/spinorbec_quench_scratch"))
const OUT = "runs/eu_barnett_rotfield_clean"
const SRC = ENV["RB_STIR_SRC"]
const N = get(ENV, "RB_N", "80, 80, 40")
const BOX = get(ENV, "RB_BOX", "28.0, 28.0, 14.0")
const BHALF = parse(Float64, split(BOX, ",")[1]) / 2
const DYN_DT = parse(Float64, get(ENV, "RB_DT", "0.0002"))
const QUENCH = parse(Float64, get(ENV, "RB_QUENCH", "20.0"))
const SAVE_EVERY = parse(Int, get(ENV, "RB_SAVE_EVERY", "600"))
const TAG = let t = get(ENV, "RB_TAG", "dtcheck"); isempty(t) ? "" : t * "_" end
mkpath(SC); mkpath(joinpath(OUT, "rebuild"))

quench_yaml() = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$N], box: [$BOX]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
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
      duration: $QUENCH
      dt: $DYN_DT
      ddi: {enabled: true, secular: false}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""

function traj(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    ND = length(grid.config.n_points); D = size(rr.psi, ND + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid); xg, yg, _ = grid.x; edge = BHALF - 0.5
    rows = ["t,Fz,Fperp,Fmag,Lz,Jz,edge_frac"]
    jldopen(pj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        st = length(times) == length(frames) + 1 ? times[2:end] : times[1:min(length(frames), length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            fx, fy, fz = spin_density_vector(psi, sm, ND)
            Fx = sum(fx)*dV; Fy = sum(fy)*dV; Fz = sum(fz)*dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            n = dropdims(sum(abs2, psi; dims=ND+1); dims=ND+1); wsum = sum(n); ef = 0.0
            for k in axes(n,3), jj in axes(n,2), ii in axes(n,1)
                (abs(xg[ii]) > edge || abs(yg[jj]) > edge) && (ef += n[ii,jj,k])
            end
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f",
                t, Fz, sqrt(Fx^2+Fy^2), sqrt(Fx^2+Fy^2+Fz^2), Lz, Fz+Lz, ef/wsum))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    @printf("[dtcheck] wrote %s\n", outcsv); flush(stdout)
end

println("===== QUENCH-ONLY dt-check: src=$SRC dt=$DYN_DT quench=$QUENCH box=$BOX n=$N ====="); flush(stdout)
qy = joinpath(SC, "quench_dtcheck.yaml"); open(qy, "w") do io; write(io, quench_yaml()); end
qdir = run_yaml(qy); q_path = joinpath(qdir isa AbstractString ? qdir : "", "point_001.jld2")
traj(q_path, joinpath(OUT, "rebuild", "traj_$(TAG)quench.csv"))
println("\nQUENCH_DTCHECK_DONE quench=$q_path"); flush(stdout)
