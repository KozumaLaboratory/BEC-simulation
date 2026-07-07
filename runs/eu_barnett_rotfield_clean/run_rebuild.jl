# Two-stage rebuild in a BIGGER BOX (Jz-conserving) — re-derive the physics that
# the +-6-box Jz leak contaminated. Diagnosis: the leak is a position-space square-
# box-boundary artifact (overflow), NOT dt/aliasing/kernel/measurement/high-k
# (grid-independent: box-12 dx0.25 vs dx0.125 leak identical). Fix = bigger box.
#
# Default box±10 / n80 (dx=0.25 kept; grid confirmed irrelevant). Full two-stage:
#   Stage 1a  GS at gamma*B=15 (magnetostriction, |F|~6 polarised)
#   Stage 1b  Klaus stir (rotating field Omega=0.74, DDI on) -> vortices
#   Stage 2   quench B->0 (DDI on) -> relax; re-read AM-lost/Fz=-0.44 with a
#             CLOSED Jz ledger (the whole point).
# Monitors Jz=Lz+Fz + density edge-fraction every frame (confirm Jz conserves +
# no overflow in the bigger box).
#
# Env: RB_N (default "80,80,40"), RB_BOX ("20.0,20.0,10.0"), RB_STIR (30),
#      RB_QUENCH (50), RB_GS_STEPS (2500). SMOKE=1 shrinks all.
# Usage (TSUBAME): julia --project=. runs/eu_barnett_rotfield_clean/run_rebuild.jl
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/spinorbec_rebuild_scratch"))
const OUT = "runs/eu_barnett_rotfield_clean"
const N = get(ENV, "RB_N", "80, 80, 40")
const BOX = get(ENV, "RB_BOX", "20.0, 20.0, 10.0")
const BHALF = parse(Float64, split(BOX, ",")[1]) / 2      # in-plane box half-width
const BXG = "9.216e-4 Gauss"        # gamma*B = 15 (magnetostriction, polarised)
const BAMP = 9.216e-4
const OMEGA = 0.74
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const GS_STEPS = SMOKE ? 50 : parse(Int, get(ENV, "RB_GS_STEPS", "2500"))
const STIR = SMOKE ? 1.0 : parse(Float64, get(ENV, "RB_STIR", "30.0"))
const QUENCH = SMOKE ? 1.0 : parse(Float64, get(ENV, "RB_QUENCH", "50.0"))
const DYN_DT = SMOKE ? 0.004 : parse(Float64, get(ENV, "RB_DT", "0.0004"))  # dynamics dt (dt-check knob)
const SAVE_EVERY = SMOKE ? 50 : parse(Int, get(ENV, "RB_SAVE_EVERY", "300"))  # big grids: raise so the jld2 fits node-local NVMe (Lustre mmap SIGBUSes)
const TAG = let t = get(ENV, "RB_TAG", ""); isempty(t) ? "" : t * "_" end  # output-name prefix (avoid concurrent-job collisions)
mkpath(SC); mkpath(joinpath(OUT, "rebuild"))

gs_yaml() = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$N], box: [$BOX]}
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
      n_steps: $GS_STEPS
      tol: 1.0e-9
"""

# stage: :stir (rotating gamma*B=15 field) or :quench (B=0)
function dyn_yaml(src, stage)
    if stage == :stir
        freq = OMEGA / (2π)
        bblock = join([
            "      B:",
            "        Bz: 0.0",
            "        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 1.5707963267948966}}",
            "        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}",
        ], "\n")
        dur = STIR
    else
        bblock = "      B: {Bz: 0.0, Bx: 0.0, By: 0.0}"
        dur = QUENCH
    end
    """
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
      init_state_params: {path: $src, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $dur
      dt: $DYN_DT
      ddi: {enabled: true, secular: false}
$bblock
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""
end

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
    @printf("[rebuild] wrote %s\n", outcsv); flush(stdout)
end

println("===== REBUILD Stage 1a: GS (gamma*B=15, box=$BOX n=$N) ====="); flush(stdout)
gy = joinpath(SC, "rb_gs.yaml"); open(gy, "w") do io; write(io, gs_yaml()); end
gsdir = run_yaml(gy); gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")

println("\n===== REBUILD Stage 1b: Klaus stir (Omega=$OMEGA, t=$STIR) ====="); flush(stdout)
sy = joinpath(SC, "rb_stir.yaml"); open(sy, "w") do io; write(io, dyn_yaml(gs_path, :stir)); end
stirdir = run_yaml(sy); stir_path = joinpath(stirdir isa AbstractString ? stirdir : "", "point_001.jld2")
traj(stir_path, joinpath(OUT, "rebuild", "traj_$(TAG)stir.csv"))

println("\n===== REBUILD Stage 2: quench B->0 (t=$QUENCH) ====="); flush(stdout)
qy = joinpath(SC, "rb_quench.yaml"); open(qy, "w") do io; write(io, dyn_yaml(stir_path, :quench)); end
qdir = run_yaml(qy); q_path = joinpath(qdir isa AbstractString ? qdir : "", "point_001.jld2")
traj(q_path, joinpath(OUT, "rebuild", "traj_$(TAG)quench.csv"))

println("\nREBUILD_DONE stir=$stir_path quench=$q_path"); flush(stdout)
