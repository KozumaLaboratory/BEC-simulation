# POSITIVE CONTROL: can this grid hold a vortex at all?
#
# Nucleation was being hunted for at dx = 0.375 against a healing length
# xi = 0.173, i.e. dx/xi = 2.2. Standard GP practice wants dx <~ xi. If an
# IMPRINTED vortex does not survive on this grid, then no stirring protocol can
# make one, and the whole Omega scan was searching a space where the answer is
# structurally unavailable.
#
# Protocol: relax the Klaus ground state, imprint a single charge-1 phase
# winding, evolve with NO stirring, and track the circulation. A vortex in a
# trapped condensate should sit there (it drifts slowly, it does not vanish).
#
# Env: VS_N (grid), VS_BOX, VS_DUR, VS_DT, VS_GS_NSTEPS, VS_TAG.
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional")

const SC = get(ENV, "SPINORBEC_SCRATCH", get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/sb_vs"))
const OUT = "runs/eu_barnett_rotfield_clean"
const N = get(ENV, "VS_N", "64,64,32")
const BOX = get(ENV, "VS_BOX", "24.0,24.0,12.0")
const DUR = parse(Float64, get(ENV, "VS_DUR", "10.0"))
const DT = parse(Float64, get(ENV, "VS_DT", "0.0004"))
const GS_NSTEPS = parse(Int, get(ENV, "VS_GS_NSTEPS", "2500"))
const TAG = get(ENV, "VS_TAG", "vs1")
const STORE = get(ENV, "SPINORBEC_STORE", "runs")
const BXG = "9.216e-4 Gauss"
mkpath(SC); mkpath(joinpath(OUT, "rebuild_movie"))

gs_yaml() = """
name: vs_gs_$TAG
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
      n_steps: $GS_NSTEPS
      tol: 1.0e-9
"""

dyn_yaml(src) = """
name: vs_dyn_$TAG
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
      initial_state: from_jld2
      init_state_params: {path: $src, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: $DT
      ddi: {secular: false}
      B: {Bx: $BXG, By: 0.0, Bz: 0.0}
      save: {every: 250, psi: true, precision: f32}
"""

function imprint!(path, out)
    rr = open_result(path); grid = rr.grid
    psi = ComplexF64.(rr.psi)
    xg, yg = grid.x[1], grid.x[2]
    ND = length(grid.config.n_points)
    @inbounds for I in CartesianIndices(size(psi)[1:ND])
        ph = cis(atan(yg[I[2]], xg[I[1]]))
        for c in axes(psi, ND + 1)
            psi[I, c] *= ph
        end
    end
    jldopen(out, "w") do f; f["psi"] = psi; end
    out
end

println("===== VORTEX SURVIVAL n=$N box=$BOX dt=$DT tag=$TAG =====" ); flush(stdout)
gy = joinpath(SC, "vs_gs.yaml"); open(gy,"w") do io; write(io, gs_yaml()); end
gsdir = run_yaml(gy; base_dir=STORE)
gs = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")
imp = imprint!(gs, joinpath(SC, "vs_imp_$TAG.jld2"))
dy = joinpath(SC, "vs_dyn.yaml"); open(dy,"w") do io; write(io, dyn_yaml(imp)); end
ddir = run_yaml(dy; base_dir=STORE)
dp = joinpath(ddir isa AbstractString ? ddir : "", "point_001.jld2")

rr = open_result(dp); grid = rr.grid
n_pts = Tuple(grid.config.n_points); box = Tuple(grid.config.box_size)
dx = box[1]/n_pts[1]; dy2 = box[2]/n_pts[2]; mid = n_pts[3]÷2+1
plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
mu_xi = 1/sqrt(2*16.65)
@printf("grid dx=%.3f  xi=%.3f  dx/xi=%.2f\n", dx, mu_xi, dx/mu_xi)
println("   t     Lz     n_circ(|w-n|<0.25)   sum_w   core/ring")
jldopen(dp, "r") do f
    ts = collect(Float64, f["dynamics/times"]); g = f["dynamics/psi_snapshots_streamed"]
    frames = sort(filter(s->startswith(s,"frame_"), collect(keys(g))))
    st = length(ts)==length(frames)+1 ? ts[2:end] : ts[1:min(length(frames),length(ts))]
    for (i,fr) in enumerate(frames)
        psi = ComplexF64.(g[fr])
        n_tot = dropdims(sum(abs2,psi; dims=4); dims=4)
        vx,vy,vq,vw,worst = SpinorBEC._mass_current_vortices(psi[:,:,mid,:], n_tot[:,:,mid], dx, dy2, 0.1)
        near = count(k->abs(vw[k]-vq[k])<0.25, eachindex(vq))
        lz = orbital_angular_momentum(psi, grid, plans)
        m = n_tot[:,:,mid]; c1,c2 = n_pts[1]÷2+1, n_pts[2]÷2+1
        ring = mean([m[c1+3,c2],m[c1-3,c2],m[c1,c2+3],m[c1,c2-3]])
        @printf("%6.2f %+7.3f        %3d            %+6.2f    %.3f\n",
            i<=length(st) ? st[i] : NaN, lz, near, sum(Float64.(vw)), m[c1,c2]/max(ring,1e-30))
    end
end
println("VS_DONE"); flush(stdout)
