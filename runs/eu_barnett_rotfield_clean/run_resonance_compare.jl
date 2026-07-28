# Chiral / one-sided excitation: co-rotating drive EXCITES, counter-rotating does NOT.
#
# Unlike the transverse-J_z=0 setup (which gives an exact ±Omega mirror — both
# excite, opposite sign), here a STATIC B_z bias sets a Larmor frequency
# omega_L and breaks the mirror. Starting fully polarised along +z (m=+F, an
# F_z eigenstate, stable under B_z alone), a transverse field rotating at
# Omega=omega_L in the CO-rotating sense is resonant -> drives the whole
# m-ladder down (spin excitation + EdH vortices); the COUNTER-rotating sense
# is detuned by 2*omega_L -> barely excites. Magnetic-resonance selection.
#
#   omega_L = |p| = 0.5  (B_z ~ 3.07e-5 G for Eu151, omega_ref=628.3)
#   drive Rabi rate p_perp = 0.1  << omega_L  (RWA clean)
#   q = 0 keeps the ladder harmonic so ONE Omega resonates the full cascade.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. run_resonance_compare.jl

import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf

const SC = "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/00662cde-2b20-4d46-95e9-97c16408370a/scratchpad"
const OMEGA_L = 0.5            # Larmor = ladder spacing = resonant drive freq
# Bz < 0 -> p = +0.5 > 0 -> m=+F is the GROUND state (stable), |p|=omega_L.
const BZ = "-3.072e-5 Gauss"
const AMP = 6.144e-6           # transverse drive amp (Gauss) -> p_perp = 0.1
# (label, drive Omega, drive amplitude)
const RUNS = [("+0.50", +OMEGA_L, AMP), ("-0.50", -OMEGA_L, AMP), ("nodrive", 0.0, 0.0)]

# fully-polarised m=+F GS along +z. With Bz<0 (p>0) m=+F is the true ground
# state, so ITP converges cleanly to it (Zeeman pins the spin to +z).
const GS_YAML = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [32, 32, 32], box: [18.0, 18.0, 18.0]}
      potential: {type: harmonic, omega: [1.0, 1.0, 1.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bz: $BZ, q: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 0.0, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.005
      n_steps: 4000
      tol: 1.0e-9
"""

function b_block(Om, amp)
    freq = Om / (2π)
    amp == 0.0 && return "      B: {Bz: $BZ, q: 0.0, Bx: 0.0, By: 0.0}"
    join([
            "      B:",
            "        Bz: $BZ",
            "        q: 0.0",
            "        Bx: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 1.5707963267948966}}",
            "        By: {sinusoidal: {amplitude: $amp, frequency: $freq, phase: 0.0}}",
        ], "\n")
end

function dyn_yaml(gs_path, Om, amp)
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
      B: {Bz: $BZ, q: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $gs_path, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: 40.0
      dt: 0.001
      ddi: {secular: false}
$(b_block(Om, amp))
      save: {every: 250, psi: true, precision: f32}
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

# 1) shared GS along +z
gsy = joinpath(SC, "reson_gs.yaml")
open(gsy, "w") do io; write(io, GS_YAML); end
println("===== GS (m=+F along +z) =====")
gs_rundir = run_yaml(gsy)
gs_path = joinpath(gs_rundir isa AbstractString ? gs_rundir : "", "point_001.jld2")
println("GS: ", gs_path)

# 2) three drives
for (tag, Om, amp) in RUNS
    ypath = joinpath(SC, "reson_$(tag).yaml")
    open(ypath, "w") do io; write(io, dyn_yaml(gs_path, Om, amp)); end
    @printf("\n===== resonance run %s (Omega=%+.2f amp=%.2e) =====\n", tag, Om, amp)
    rundir = run_yaml(ypath)
    pj = joinpath(rundir isa AbstractString ? rundir : "", "point_001.jld2")
    spin_traj(pj, "runs/eu_barnett_rotfield_clean/traj_reson_$(tag).csv")
end
println("RESONANCE_COMPARE_DONE")
