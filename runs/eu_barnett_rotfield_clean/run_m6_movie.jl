# Movie version of fig_m6_spatial: the SAME m=-6 imprint + quench as
# run_m6_imprint.jl, but reduced at EVERY saved frame instead of only the last.
#
# Why a separate driver rather than a flag on the old one: the old one streams
# psi to node-local scratch and pulls exactly one time out of it. The scratch is
# wiped when the job ends, so "just re-read the frames later" is not available —
# that is why this needs a re-run at all. Everything a frame contributes is
# therefore reduced INSIDE the job, and only small arrays reach /gs
# (~72 MB/arm at 312 frames vs ~8 GB/arm of psi). The group filesystem was at
# 99% (16 GB free) when this was written; do not make it write psi.
#
# WHAT IS SAVED, and why two kinds:
#
#   per-m column densities  — the panels of fig_m6_spatial. Note that the RINGS
#     in these panels are NOT vortices: a spin texture whose direction varies
#     with radius gives every m component a ring through the Wigner-d weighting,
#     with or without any flow. They cannot answer "is there a vortex".
#
#   total density + mass-current circulation — the part that can. A vortex is a
#     hole in the TOTAL density with quantised circulation of the TOTAL current
#     v = j/n, j = sum_c Im(conj(psi_c) grad psi_c). That is invariant under a
#     uniform spin rotation, so the component rings contribute exactly nothing
#     to it, while a real core still shows.
#
# Env: RB_N, RB_BOX, RB_DUR(50), RB_DT(4e-4), RB_SAVE_EVERY(400),
#      RB_GS_STEPS(2500), RB_LOSS(1), RB_TAG (goes into the config so the
#      content-addressed run CANNOT reuse a pre-bugfix cached result).
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH", get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/sb_m6mov"))
const OUT = "runs/eu_barnett_rotfield_clean"
const N = get(ENV, "RB_N", "80, 80, 40")
const BOX = get(ENV, "RB_BOX", "20.0, 20.0, 10.0")
const BZG = "9.216e-4 Gauss"
const DUR = parse(Float64, get(ENV, "RB_DUR", "50.0"))
const DYN_DT = parse(Float64, get(ENV, "RB_DT", "0.0004"))
const SAVE_EVERY = parse(Int, get(ENV, "RB_SAVE_EVERY", "400"))
const GS_STEPS = parse(Int, get(ENV, "RB_GS_STEPS", "2500"))
const LOSSY = get(ENV, "RB_LOSS", "1") == "1"
const K3_SI = get(ENV, "RB_K3_SI", "1.5e-40")
const GAMMA_DR = get(ENV, "RB_GAMMA_DR", "0.02")
# The CAS key is the config spec ONLY — it does not know the source version, so
# a byte-identical config silently reuses a result computed by pre-bugfix code.
# This tag is carried in the spec purely to break that.
const TAG = get(ENV, "RB_TAG", "movie1")
const SUF = LOSSY ? "lossy_" : ""

loss_block() = LOSSY ? join([
        "      loss:",
        "        gamma_dr: $GAMMA_DR",
        "        K3_per_m_si: [$(join(fill("\"$K3_SI m^6/s\"", 13), ", "))]",
    ], "\n") : "      # no loss (unitary)"

mkpath(SC)
const MOV = joinpath(OUT, "rebuild_movie")
mkpath(MOV)

gs_yaml() = """
name: m6mov_gs_$TAG
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

dyn_yaml(src, tag) = """
name: m6mov_$(tag)_$TAG
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

# charge-l orbital vortex imprinted on all populated components (identical to
# run_m6_imprint.jl — same physics, do not let the two drift)
function imprint(gs_path, ell, out_jld2)
    rr = open_result(gs_path)
    grid = rr.grid
    psi = ComplexF64.(rr.psi)
    ND = length(grid.config.n_points)
    xg = grid.x[1]
    yg = grid.x[2]
    if ell != 0
        @inbounds for I in CartesianIndices(size(psi)[1:ND])
            ph = cis(ell * atan(yg[I[2]], xg[I[1]]))
            for c in axes(psi, ND + 1)
                psi[I, c] *= ph
            end
        end
    end
    jldopen(out_jld2, "w") do f
        f["psi"] = psi
    end
    return out_jld2
end

"""
Reduce every saved frame of `pj` into the small per-frame arrays the movie
needs, and write one archive per arm.
"""
function reduce_frames(pj, tag, outjld)
    rr = open_result(pj)
    grid = rr.grid
    n_pts = Tuple(grid.config.n_points)
    ND = length(n_pts)
    D = size(rr.psi, ND + 1)
    F = (D - 1) ÷ 2
    box = Tuple(grid.config.box_size)
    dx = box[1] / n_pts[1]
    dy = box[2] / n_pts[2]
    mid = n_pts[3] ÷ 2 + 1
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)
    dV = cell_volume(grid)

    times = Float64[]
    fracs = Vector{Vector{Float64}}()
    vcount = Int[]
    vnet = Int[]
    lz_t = Float64[]
    fz_t = Float64[]
    idx = 0

    jldopen(outjld, "w") do o
        jldopen(pj, "r") do f
            ts = collect(Float64, f["dynamics/times"])
            g = f["dynamics/psi_snapshots_streamed"]
            frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
            st = length(ts) == length(frames) + 1 ? ts[2:end] :
                 ts[1:min(length(frames), length(ts))]
            for (i, fr) in enumerate(frames)
                psi = ComplexF64.(g[fr])
                idx += 1
                key = lpad(string(idx), 5, '0')

                n_tot = dropdims(sum(abs2, psi; dims=ND + 1); dims=ND + 1)
                o["tot_"*key] = Float32.(dropdims(sum(n_tot; dims=3); dims=3))
                # per-m column densities: the fig_m6_spatial panels
                fr_m = Float64[]
                ntot_sum = sum(n_tot)
                for m in (-F):0
                    c = F - m + 1                       # m -> component index
                    nm = abs2.(selectdim(psi, ND + 1, c))
                    o["m$(m)_"*key] = Float32.(dropdims(sum(nm; dims=3); dims=3))
                    push!(fr_m, sum(nm) / ntot_sum)
                end
                push!(fracs, fr_m)

                # the part that can actually answer "is there a vortex"
                o["nmid_"*key] = Float32.(n_tot[:, :, mid])
                psi_mid = psi[:, :, mid, :]
                vx, vy, vq, vw, worst = SpinorBEC._mass_current_vortices(
                    psi_mid, n_tot[:, :, mid], dx, dy, 0.1)
                o["vx_"*key] = vx
                o["vy_"*key] = vy
                o["vq_"*key] = vq
                o["vw_"*key] = vw
                push!(vcount, length(vq))
                push!(vnet, isempty(vq) ? 0 : sum(vq))

                fx, fy, fz = spin_density_vector(psi, spin_matrices(F), ND)
                push!(fz_t, sum(fz) * dV / (ntot_sum * dV))
                push!(lz_t, orbital_angular_momentum(psi, grid, plans))
                push!(times, i <= length(st) ? st[i] : NaN)
            end
        end
        o["n_frames"] = idx
        o["F"] = F
        o["box"] = collect(box)
        o["times"] = times
        o["m_fracs"] = fracs
        o["vortex_counts"] = vcount
        o["vortex_net"] = vnet
        o["Lz"] = lz_t
        o["Fz"] = fz_t
        o["tag"] = tag
    end
    @printf("[m6mov] %s: %d frames -> %s\n", tag, idx, outjld)
    flush(stdout)
end

println("===== M6-MOVIE Stage 1: axial m=-6 GS (Bz=$BZG, box=$BOX n=$N, tag=$TAG) =====")
flush(stdout)
gy = joinpath(SC, "m6mov_gs.yaml")
open(gy, "w") do io
    write(io, gs_yaml())
end
gsdir = run_yaml(gy)
gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")

for ell in (1, -1, 0)
    tag = ell >= 0 ? "ellp$(ell)" : "ellm$(abs(ell))"
    println("\n===== M6-MOVIE imprint l=$ell + quench =====")
    flush(stdout)
    imp = imprint(gs_path, ell, joinpath(SC, "m6mov_imp_$tag.jld2"))
    dy = joinpath(SC, "m6mov_dyn_$tag.yaml")
    open(dy, "w") do io
        write(io, dyn_yaml(imp, tag))
    end
    ddir = run_yaml(dy)
    dpath = joinpath(ddir isa AbstractString ? ddir : "", "point_001.jld2")
    reduce_frames(dpath, tag, joinpath(MOV, "m6mov_$(SUF)$tag.jld2"))
end
println("\nM6_MOVIE_DONE")
flush(stdout)
