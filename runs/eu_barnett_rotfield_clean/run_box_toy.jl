# Toy confirmation of the box-size fix (PASS-0 gate, before the ~1h rebuild).
# Diagnosis says the Jz leak is a periodic-boundary artifact: the cloud (RMS 3.95)
# overflows the +-6 box (8% density at |x|>5.5). Fix = bigger box. But "diagnosis
# points to box" != "box fix actually closes Jz" -> confirm on a controlled state.
#
# SAME synthetic cloud: an ANALYTIC ORBITAL vortex (x+iy)*exp(-r^2/2σ^2) in the
# stretched m=+F component -> real orbital Lz=1 AND (σ=2.8 -> RMS=σ√2≈3.96, matching
# production's 3.95) it overflows the ±6 box the same way. (fl_vortex was WRONG: a
# SPIN winding with Lz=0 and RMS 1.72 — no disease.) box-12/n48 vs box-20/n80 (SAME
# dx=0.25). No DDI (cheap; DDI-off already leaked 0.8 -> the leak is orbital).
#
# MUST see BOTH (else the toy lacks the disease / the fix is unproven):
#   (1) box-12: cloud reaches the edge (overflow, like production) AND Lz leaks.
#   (2) box-20: SAME cloud contained AND Lz conserved.
#
# Usage: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#          runs/eu_barnett_rotfield_clean/run_box_toy.jl
# Env: TOY_SIGMA (default 2.8) — bump if box-12 doesn't overflow/leak.
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")
const SC = get(ENV, "SPINORBEC_SCRATCH",
    "/tmp/claude-1000/-home-suzume-workspace-BEC-simulation/80199575-e261-4fe8-a6af-74f719f5341c/scratchpad")
const OUT = "runs/eu_barnett_rotfield_clean"
const SIG = parse(Float64, get(ENV, "TOY_SIGMA", "2.8"))
mkpath(SC)

# build the analytic orbital vortex (x+iy)*exp(-r^2/2σ^2) on `grid`, in component 1
# (m=+F stretched -> no spin-mixing, orbital Lz stays clean), save {"psi":...}.
function write_vortex(path, n, nz, box, bz)
    g = make_grid(GridConfig((n, n, nz), (Float64(box), Float64(box), Float64(bz))))
    xg, yg, zg = g.x; D = 13
    psi = zeros(ComplexF64, n, n, nz, D)
    for k in 1:nz, j in 1:n, i in 1:n
        amp = exp(-(xg[i]^2 + yg[j]^2) / (2SIG^2) - zg[k]^2 / (2 * 1.0^2))
        psi[i, j, k, 1] = amp * (xg[i] + im * yg[j])
    end
    psi ./= sqrt(sum(abs2, psi) * cell_volume(g))
    jldopen(path, "w") do f; f["psi"] = psi; end
end

# same physical cloud at both boxes (dx=0.25 fixed): box/n = 12/48 = 20/80 = 0.25
cfg(box, n, nz, bz, vpath) = """
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$n, $n, $nz], box: [$box, $box, $bz]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: false, secular: false}
      lhy: {kind: scalar}
      B: {Bx: 0.0, By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $vpath, snap: last}
      init_sigma: $SIG
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: 5.0
      dt: 0.0004
      ddi: {enabled: false, secular: false}
      B: {Bz: 0.0, Bx: 0.0, By: 0.0}
      seed_amplitude: 1.0e-6
      seed_k_cut: 2.5
      save: {every: 100, psi: true, precision: f32}
"""

function analyze(pj, box)
    rr = open_result(pj); grid = rr.grid
    N = length(grid.config.n_points); D = size(rr.psi, N + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid); xg, yg, zg = grid.x
    half = box / 2; edge = half - 0.5
    lz = Float64[]; ext_start = 0.0; ext_end = 0.0; rms_start = 0.0
    jldopen(pj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        for (idx, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr])
            push!(lz, orbital_angular_momentum(psi, grid, plans))
            if idx == 1 || idx == length(frames)
                n = dropdims(sum(abs2, psi; dims = N + 1); dims = N + 1)
                wsum = sum(n); ef = 0.0; r2 = 0.0
                for k in axes(n,3), j in axes(n,2), i in axes(n,1)
                    (abs(xg[i]) > edge || abs(yg[j]) > edge) && (ef += n[i,j,k])
                    r2 += n[i,j,k] * (xg[i]^2 + yg[j]^2)
                end
                if idx == 1; ext_start = ef/wsum; rms_start = sqrt(r2/wsum); else; ext_end = ef/wsum; end
            end
        end
    end
    (lz=lz, drift=lz[1]-lz[end], edge_start=ext_start, edge_end=ext_end, rms=rms_start)
end

const ALLBOXES = Dict(12 => (12.0, 48, 24, 6.0), 20 => (20.0, 80, 40, 10.0))
const BOXES = [ALLBOXES[parse(Int, b)] for b in split(get(ENV, "TOY_BOXES", "12,20"), ",")]
results = Dict{Int,Any}()
for (box, n, nz, bz) in BOXES
    vpath = joinpath(SC, "boxtoy_vortex_$(Int(box)).jld2"); write_vortex(vpath, n, nz, box, bz)
    yp = joinpath(SC, "boxtoy_$(Int(box)).yaml"); open(yp, "w") do io; write(io, cfg(box, n, nz, bz, vpath)); end
    @printf("\n===== box=%.0f (n=%d, dx=%.3f) sigma=%.1f =====\n", box, n, box/n, SIG); flush(stdout)
    rd = run_yaml(yp); pj = joinpath(rd isa AbstractString ? rd : "", "point_001.jld2")
    r = analyze(pj, box); results[Int(box)] = r
    traj = joinpath(OUT, "traj_boxtoy_$(Int(box)).csv")
    open(traj, "w") do io; println(io, "i,Lz"); for (i,v) in enumerate(r.lz); println(io, "$i,$v"); end; end
    @printf("[boxtoy box=%.0f] RMS r_xy=%.2f  edge-frac start=%.3f end=%.3f  Lz %.3f->%.3f (drift %.3f)\n",
        box, r.rms, r.edge_start, r.edge_end, r.lz[1], r.lz[end], r.drift); flush(stdout)
end
if !(haskey(results, 12) && haskey(results, 20))
    r = first(values(results))
    @printf("\n[single-box run sigma=%.1f] edge-frac=%.3f Lz drift=%.3f -> %s\n", SIG,
        first(values(results)).edge_start, first(values(results)).drift,
        abs(first(values(results)).drift) > 0.1 ? "LEAKS (overflow drives it)" : "conserved (no leak at this overflow)")
    println("BOX_TOY_DONE"); exit()
end
println("\n================ box-size toy verdict ================")
r12 = results[12]; r20 = results[20]
@printf("box-12: overflow edge-frac=%.3f (need >~0.03 = has disease), Lz drift=%.3f\n", r12.edge_start, r12.drift)
@printf("box-20: overflow edge-frac=%.3f (need ~0 = contained),       Lz drift=%.3f\n", r20.edge_start, r20.drift)
leaks12 = abs(r12.drift) > 0.1; overflows12 = r12.edge_start > 0.03
conserves20 = abs(r20.drift) < 0.05
if overflows12 && leaks12 && conserves20
    println("=> CONFIRMED: box-12 has the disease (overflow+leak) AND box-20 cures it. Bigger box is the fix.")
elseif !overflows12
    println("=> TOY LACKS DISEASE: box-12 doesn't overflow (edge-frac low). Bump TOY_SIGMA and re-run.")
elseif overflows12 && leaks12 && !conserves20
    println("=> box-20 STILL LEAKS: box is not the (only) fix. Rethink before rebuild.")
else
    println("=> INCONCLUSIVE: inspect the numbers.")
end
println("BOX_TOY_DONE")
