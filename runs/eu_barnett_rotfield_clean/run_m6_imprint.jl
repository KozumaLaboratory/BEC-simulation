# FLOOR-RECTIFICATION test (anko's idea): from the AXIAL m=-6 ground state, imprint
# a charge-l ORBITAL vortex (e^{i*l*phi}) on the m=-6 component (spin stays axial,
# F_z=-6, L_z=l) then quench B->0 and let DDI convert orbital->spin. F_z can only go
# UP from the -6 floor: one vortex sign -> m=-5,-4 appear; the other is blocked at -6.
# Observable = Stern-Gerlach populations N_{-6}, N_{-5}, N_{-4}. Runs l=+1,-1,0 from
# ONE shared m=-6 GS (no rotating field -> no Larmor tip, unlike the stir protocol).
#
# Env: RB_N, RB_BOX, RB_DUR(50), RB_DT(4e-4), RB_SAVE_EVERY(1000), RB_GS_STEPS(2500).
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH", get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/sb_m6"))
const OUT = "runs/eu_barnett_rotfield_clean"
const N = get(ENV, "RB_N", "80, 80, 40")
const BOX = get(ENV, "RB_BOX", "20.0, 20.0, 10.0")
const BHALF = parse(Float64, split(BOX, ",")[1]) / 2
const BZG = "9.216e-4 Gauss"     # +Bz -> m=-6 axial GS (g_F>0)
const DUR = parse(Float64, get(ENV, "RB_DUR", "50.0"))
const DYN_DT = parse(Float64, get(ENV, "RB_DT", "0.0004"))
const SAVE_EVERY = parse(Int, get(ENV, "RB_SAVE_EVERY", "1000"))
const GS_STEPS = parse(Int, get(ENV, "RB_GS_STEPS", "2500"))
# Loss (experiment-consistent): K3=1.5e-40 m^6/s (Matsui-calibrated, ~40% loss @40ms)
# + gamma_dr=0.02 (m-dependent dipolar relaxation: m=-6 protected, high m lost).
# RB_LOSS=1 turns it on; RB_K3_SI / RB_GAMMA_DR override the values.
const LOSSY = get(ENV, "RB_LOSS", "0") == "1"
const K3_SI = get(ENV, "RB_K3_SI", "1.5e-40")
const GAMMA_DR = get(ENV, "RB_GAMMA_DR", "0.02")
const SUF = LOSSY ? "lossy_" : ""
loss_block() = LOSSY ? join([
    "      loss:",
    "        gamma_dr: $GAMMA_DR",
    "        K3_per_m_si: [$(join(fill("\"$K3_SI m^6/s\"", 13), ", "))]",
], "\n") : "      # no loss (unitary)"
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
      B: {Bz: $BZG, Bx: 0.0, By: 0.0}
      gauge_fix: false
      initial_state: spin_coherent
      init_state_params: {init_theta: 3.141592653589793, init_phi: 0.0}
      init_sigma: 1.5
      dt: 0.004
      n_steps: $GS_STEPS
      tol: 1.0e-9
"""

dyn_yaml(src) = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$N], box: [$BOX]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $src, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: $DYN_DT
      ddi: {enabled: true, secular: false}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
$(loss_block())
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""

# write imprinted psi (charge-l orbital vortex on all populated comps) to a from_jld2 file
function imprint(gs_path, ell, out_jld2)
    rr = open_result(gs_path); grid = rr.grid
    psi = ComplexF64.(rr.psi)
    ND = length(grid.config.n_points); xg = grid.x[1]; yg = grid.x[2]
    if ell != 0
        @inbounds for I in CartesianIndices(size(psi)[1:ND])
            ph = cis(ell * atan(yg[I[2]], xg[I[1]]))
            for c in axes(psi, ND + 1)
                psi[I, c] *= ph
            end
        end
    end
    jldopen(out_jld2, "w") do f; f["psi"] = psi; end
    return out_jld2
end

function traj(pj, outcsv)
    rr = open_result(pj); grid = rr.grid
    ND = length(grid.config.n_points); D = size(rr.psi, ND + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)
    rows = ["t,Fz,Fmag,Lz,Jz,N_m6,N_m5,N_m4,Ntot"]  # N_m as fraction of SURVIVING total; Ntot = surviving norm
    jldopen(pj, "r") do f
        times = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        st = length(times) == length(frames) + 1 ? times[2:end] : times[1:min(length(frames), length(times))]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            fx, fy, fz = spin_density_vector(psi, sm, ND)
            Fx = sum(fx)*dV; Fy = sum(fy)*dV; Fz = sum(fz)*dV
            Lz = orbital_angular_momentum(psi, grid, plans)
            ntot = sum(abs2, psi) * dV
            nm6 = sum(abs2, selectdim(psi, ND + 1, D)) * dV / ntot        # m=-6 (c=D)
            nm5 = sum(abs2, selectdim(psi, ND + 1, D - 1)) * dV / ntot    # m=-5
            nm4 = sum(abs2, selectdim(psi, ND + 1, D - 2)) * dV / ntot    # m=-4
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.5f,%.6f",
                t, Fz, sqrt(Fx^2+Fy^2+Fz^2), Lz, Fz+Lz, nm6, nm5, nm4, ntot))
        end
    end
    open(outcsv, "w") do io; for r in rows; println(io, r); end; end
    @printf("[m6] wrote %s\n", outcsv); flush(stdout)
end

println("===== M6 Stage 1: axial m=-6 GS (Bz=$BZG, box=$BOX n=$N) ====="); flush(stdout)
gy = joinpath(SC, "m6_gs.yaml"); open(gy, "w") do io; write(io, gs_yaml()); end
gsdir = run_yaml(gy); gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")

for ell in (1, -1, 0)
    tag = ell >= 0 ? "ellp$(ell)" : "ellm$(abs(ell))"
    println("\n===== M6 imprint l=$ell + quench ====="); flush(stdout)
    imp = imprint(gs_path, ell, joinpath(SC, "m6_imp_$tag.jld2"))
    dy = joinpath(SC, "m6_dyn_$tag.yaml"); open(dy, "w") do io; write(io, dyn_yaml(imp)); end
    ddir = run_yaml(dy); dpath = joinpath(ddir isa AbstractString ? ddir : "", "point_001.jld2")
    traj(dpath, joinpath(OUT, "rebuild", "traj_m6_$(SUF)$tag.csv"))
end
println("\nM6_IMPRINT_DONE"); flush(stdout)
