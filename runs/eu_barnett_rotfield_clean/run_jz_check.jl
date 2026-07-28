# Jz-conservation leak diagnosis (PASS-0 gate). The healthy-start quench showed
# Jz=Lz+Fz drifting 1.28->-0.5 despite norm (6e-11) + energy (2.5e-7) conserved.
# A conservation-law violation invalidates BOTH "vortex AM lost" and "net Fz=-0.44
# is real" -> must be resolved before any two-stage call.
#
# The Orszag-2/3 dealias filter DEFAULTS OFF (Ref(false)) and the quench configs
# had no dealias block -> the filter was NOT active. So the informative arm is
# dealias ON (does suppressing DDI aliasing, the other k-space rotational-symmetry
# breaker, restore Jz?). One-factor-at-a-time from baseline: filter x dt (all 48^3,
# no upsampling). If none conserves Jz -> resolution (64^3) is next.
#
# Short (t=5, the Lz collapse is in t<2), fine Jz(t) sampling. Reports Jz drift.
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/run_jz_check.jl
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/80199575-e261-4fe8-a6af-74f719f5341c/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const SRC = "runs/p1_O0.74_db0e3dfb/point_001.jld2"   # healthy P1 Omega_c state (48^3)
const DUR = 5.0
mkpath(SC)
isfile(SRC) || error("source missing: $SRC")

# (label, dt, dealias_on, ddi_on) — ddi_on=false isolates orbital/kinetic/grid leak
const JOBS = [
    ("base_dt4e4_nofilt", 0.0004, false, true),
    ("dt4e4_filt",        0.0004, true,  true),
    ("dt2e4_nofilt",      0.0002, false, true),
    ("dt2e4_filt",        0.0002, true,  true),
    ("ddioff",            0.0004, false, false),   # discriminator: no DDI
]

function yaml(dt, dealias_on, ddi_on=true)
    save_every = round(Int, 0.04 / dt)   # ~125 frames over t=5
    dealias_block = dealias_on ? "dealias: {enabled: true}\n" : ""
    ddi_s = ddi_on ? "true" : "false"
    """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
$(dealias_block)pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [48, 48, 24], box: [12.0, 12.0, 6.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: $ddi_s, secular: false}
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
      dt: $dt
      ddi: {enabled: $ddi_s, secular: false}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $save_every, psi: true, precision: f32}
"""
end

function traj_jz(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fz,Fmag,Lz,Jz"]; jz = Float64[]
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
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f", t, Fz, sqrt(Fx^2+Fy^2+Fz^2), Lz, Fz+Lz))
            push!(jz, Fz + Lz)
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    jz
end

results = String[]
for (lab, dt, dealias_on, ddi_on) in JOBS
    yp = joinpath(SC, "jzcheck_$(lab).yaml"); open(yp, "w") do io; write(io, yaml(dt, dealias_on, ddi_on)); end
    @printf("\n===== Jz-check %s (dt=%.4f dealias=%s) =====\n", lab, dt, dealias_on); flush(stdout)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    jz = traj_jz(pj, joinpath(OUT, "traj_jzcheck_$(lab).csv"))
    drift = length(jz) >= 2 ? jz[1] - jz[end] : NaN
    push!(results, @sprintf("%-18s Jz: %.3f -> %.3f  (drift %.3f)", lab, jz[1], jz[end], drift))
    @printf("[jzcheck] %s\n", results[end]); flush(stdout)
end
println("\n================ Jz-conservation summary ================")
for r in results; println(r); end
println("(drift ~0 => Jz CONSERVED = that knob was the leak; large drift => still leaking)")
println("JZ_CHECK_DONE")
