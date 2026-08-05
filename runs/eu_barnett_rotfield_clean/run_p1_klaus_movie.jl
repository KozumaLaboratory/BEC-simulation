# Movie version of the Klaus magnetostirring run: the same physics as
# run_p1_klaus.jl, reduced at EVERY saved frame instead of into one CSV row.
#
# This is the run where the things one wants to SEE are actually in the plane
# being drawn:
#
#   * the DDI deformation. Strong IN-PLANE field (gamma*B = 15) locks the spin
#     to B and magnetostriction elongates the cloud ALONG it, so the column
#     density n(x,y) is a rotating ellipse. (The m=-6 imprint run has an AXIAL
#     field, so its deformation is along z — exactly the axis n(x,y) integrates
#     over, which is why no deformation was visible there.)
#   * vortex nucleation. Above the quadrupole surface mode Omega_c ~ 0.7-0.75
#     the stirred ellipse sheds vortices; below it the ellipse just rotates.
#     Measured in the existing scan (traj_p1_O*.csv), surviving vortices at the
#     end of the run: Omega 0.40 -> 0, 0.74 -> 11, 0.85 -> 63.
#
# The three Omegas therefore bracket the threshold, which is the point of
# putting them in one movie.
#
# Vortices are found on the TOTAL density via mass-current circulation, not by
# per-component phase winding: with the spin locked to a rotating B the
# components are being rotated into each other constantly, and per-component
# winding fires on that with no flow behind it.
#
# Env: P1_N, P1_BOX, P1_DUR(30), P1_GS_NSTEPS(2500), P1_OMEGAS, P1_SAVE_EVERY,
#      SPINORBEC_STORE, P1_MOVIE_OUT, P1_TAG.
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra

CUDA.functional() || error("CUDA not functional — refusing silent CPU fallback")

const SC = get(ENV, "SPINORBEC_SCRATCH", get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/sb_p1mov"))
const OUT = "runs/eu_barnett_rotfield_clean"
const SMOKE = get(ENV, "SMOKE", "0") == "1"
const BXG = "9.216e-4 Gauss"     # gamma*B = 15 — deep scalar lock
const BAMP = 9.216e-4
_parsef(s) = parse.(Float64, split(s, ","))
const P1_N = get(ENV, "P1_N", "48,48,24")
const P1_BOX = get(ENV, "P1_BOX", "12.0,12.0,6.0")
const OMEGAS = SMOKE ? [0.85] :
               haskey(ENV, "P1_OMEGAS") ? _parsef(ENV["P1_OMEGAS"]) : [0.40, 0.74, 0.85]
const DUR = SMOKE ? 3.0 : parse(Float64, get(ENV, "P1_DUR", "30.0"))
const GS_NSTEPS = SMOKE ? 300 : parse(Int, get(ENV, "P1_GS_NSTEPS", "2500"))
const SAVE_EVERY = parse(Int, get(ENV, "P1_SAVE_EVERY", SMOKE ? "100" : "300"))
# CAS key is the spec alone and knows nothing about the source version, so a
# byte-identical config silently reuses a pre-bugfix result. Bump on any
# physics change.
const TAG = get(ENV, "P1_TAG", "movie1")
# Far-field TOF is t-independent in SHAPE (cloud and hole both scale with t),
# so this only sets the axis scale of the stored image.
const DYN_DT = parse(Float64, get(ENV, "P1_DT", "0.0004"))
const TOF_T = parse(Float64, get(ENV, "P1_TOF_T", "8.0"))
const TOF_STEPS = parse(Int, get(ENV, "P1_TOF_STEPS", "25"))
# TOF costs ~6 s/frame at 64^3 even at n_steps=25, so it runs on a stride while
# the in-situ panels stay every frame.
const TOF_EVERY = parse(Int, get(ENV, "P1_TOF_EVERY", "5"))
const STORE = get(ENV, "SPINORBEC_STORE", "runs")
const MOV = get(ENV, "P1_MOVIE_OUT", joinpath(OUT, "rebuild_movie"))
mkpath(SC)
mkpath(MOV)

gs_yaml() = """
name: p1mov_gs_$TAG
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$P1_N], box: [$P1_BOX]}
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

function dyn_yaml(gs_path, Om, tag)
    freq = Om / (2π)
    """
name: p1mov_$(tag)_$TAG
defaults: {kind: spinor, backend: gpu, interactions: {N_atoms: 30000, omega_ref: 628.3}}
pipeline:
  - ground_state:
      atom: Eu151
      grid: {n: [$P1_N], box: [$P1_BOX]}
      potential: {type: harmonic, omega: [1.0, 1.0, 2.0]}
      interactions: {N_atoms: 30000, omega_ref: 628.3, c1_ratio: -0.005}
      ddi: {enabled: true, secular: false}
      lhy: {kind: scalar}
      B: {Bx: $BXG, By: 0.0, Bz: 0.0}
      gauge_fix: false
      initial_state: from_jld2
      init_state_params: {path: $gs_path, snap: last}
      init_sigma: 1.5
      dt: 0.004
      n_steps: 1
      tol: 1.0e-9
  - dynamics:
      duration: $DUR
      dt: $DYN_DT
      ddi: {secular: false}
      B:
        Bz: 0.0
        Bx: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 1.5707963267948966}}
        By: {sinusoidal: {amplitude: $BAMP, frequency: $freq, phase: 0.0}}
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""
end

# JLD2 mmaps its output and mmap on Lustre SIGBUSes, so build on node-local
# scratch and copy (the m6 movie job core-dumped on exactly this).
function reduce_frames(pj, Om, tag, outjld)
    tmp = joinpath(SC, "p1mov_tmp_$tag.jld2")
    _reduce_impl(pj, Om, tag, tmp)
    mkpath(dirname(outjld))
    cp(tmp, outjld; force=true)
    rm(tmp; force=true)
    @printf("[p1mov] %s: archive -> %s (%.1f MB)\n", tag, outjld, filesize(outjld) / 1e6)
    flush(stdout)
end

function _reduce_impl(pj, Om, tag, outjld)
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
    xs = grid.x[1]
    ys = grid.x[2]
    plans = make_fft_plans(n_pts; flags=FFTW.ESTIMATE)

    # ONE workspace for all TOF calls; psi is swapped in per frame. Building it
    # per frame would re-specialise make_workspace, which CLAUDE.md flags as the
    # multi-minute JIT hot path.
    tof_ws = make_workspace(; grid, atom=rr.atom, interactions=rr.interactions,
        potential=HarmonicTrap((1.0, 1.0, 2.0)),
        sim_params=SimParams(; dt=0.001, n_steps=1),
        psi_init=ComplexF64.(rr.psi))
    tof_frames = Int[]

    times, ar_t, ell_t, lag_t, lz_t = Float64[], Float64[], Float64[], Float64[], Float64[]
    vcount, vnet = Int[], Int[]
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

                # n(x,y): the rotating magnetostriction ellipse
                col = dropdims(sum(n_tot; dims=3); dims=3)
                o["col_"*key] = Float32.(col)
                o["nmid_"*key] = Float32.(n_tot[:, :, mid])
                # side view, so the pancake shape is on screen too
                o["side_"*key] = Float32.(dropdims(sum(n_tot; dims=2); dims=2))

                # TOF image — this is where a vortex is actually visible.
                #
                # In situ the core is xi = 0.17 against dx = 0.25-0.75, so it
                # never resolves: measured core/peak 0.63 on a TF cloud with a
                # vortex, i.e. barely a dimple.
                #
                # NOT the far field. `simulate_tof` returns |psi~(k)|^2, and on
                # a cloud with two vortices placed at x = +-1.5 it puts ONE hole
                # at the CENTRE — an interference pattern, not an image of the
                # cores. The experiment images the expanded DENSITY, which is
                # the co-expanding (scaling) frame.
                #
                # Measured on that same two-vortex cloud, core/peak:
                #   in situ 0.63 | t_tof 2 -> 0.37 | 5 -> 0.067 | 8 -> 0.016
                # with drop_interactions=true. Carrying the interaction through
                # the expansion instead holds it at ~0.53 (the core refills), so
                # this number is scheme-dependent and is quoted as such.
                #
                # n_steps=25, not the default 300: measured identical to 4
                # digits (0.0155 vs 0.0156) and 16x faster (6.2 s vs 99.9 s per
                # frame at 64^3).
                if (idx - 1) % TOF_EVERY == 0
                    # copyto!, not `.=`: make_workspace picks the CUDA backend
                    # when CUDA is loaded, and broadcasting a host Array into a
                    # CuArray fails GPU compilation. copyto! does the transfer.
                    copyto!(tof_ws.state.psi, psi)
                    r = simulate_tof_scaling(tof_ws; t_tof=TOF_T, n_steps=TOF_STEPS,
                        drop_interactions=true)
                    o["tof_"*key] = Float32.(reduce(+, values(r.chi_density)))
                    o["tof_b_"*key] = collect(r.b)
                    push!(tof_frames, idx)
                end

                # aspect ratio + principal axis of the column density
                ntot = sum(col)
                mx = sum(col[a, b] * xs[a] for a in 1:n_pts[1], b in 1:n_pts[2]) / ntot
                my = sum(col[a, b] * ys[b] for a in 1:n_pts[1], b in 1:n_pts[2]) / ntot
                Mxx = sum(col[a, b] * (xs[a] - mx)^2 for a in 1:n_pts[1], b in 1:n_pts[2]) / ntot
                Myy = sum(col[a, b] * (ys[b] - my)^2 for a in 1:n_pts[1], b in 1:n_pts[2]) / ntot
                Mxy = sum(col[a, b] * (xs[a] - mx) * (ys[b] - my)
                          for a in 1:n_pts[1], b in 1:n_pts[2]) / ntot
                tr = Mxx + Myy
                dd = sqrt(max(((Mxx - Myy) / 2)^2 + Mxy^2, 0.0))
                AR = sqrt(max((tr / 2 + dd) / max(tr / 2 - dd, 1e-12), 1.0))
                ell = 0.5 * atan(2Mxy, Mxx - Myy)
                t = i <= length(st) ? st[i] : NaN
                lag = mod(mod(Om * t, π) - ell + π / 2, π) - π / 2

                mvx, mvy, mvq, mvw, _ = SpinorBEC._mass_current_vortices(
                    psi[:, :, mid, :], n_tot[:, :, mid], dx, dy, 0.1)
                o["vx_"*key] = mvx
                o["vy_"*key] = mvy
                o["vq_"*key] = mvq
                o["vw_"*key] = mvw

                push!(times, t)
                push!(ar_t, AR)
                push!(ell_t, ell)
                push!(lag_t, lag)
                push!(lz_t, orbital_angular_momentum(psi, grid, plans))
                push!(vcount, length(mvq))
                push!(vnet, isempty(mvq) ? 0 : sum(mvq))
            end
        end
        o["n_frames"] = idx
        o["Omega"] = Om
        o["n_pts"] = collect(n_pts)
        o["tag"] = TAG
        o["box"] = collect(box)
        o["tof_t"] = TOF_T
        o["tof_frames"] = tof_frames
        o["tof_every"] = TOF_EVERY
        o["dyn_dt"] = DYN_DT
        o["dk"] = [grid.dk[1], grid.dk[2]]
        o["times"] = times
        o["AR"] = ar_t
        o["ell_angle"] = ell_t
        o["lag"] = lag_t
        o["Lz"] = lz_t
        o["vortex_counts"] = vcount
        o["vortex_net"] = vnet
    end
    @printf("[p1mov] %s: %d frames reduced (Omega=%.2f)\n", tag, idx, Om)
    flush(stdout)
end

println("===== P1-KLAUS-MOVIE GS (Bx=$BXG, box=$P1_BOX n=$P1_N, tag=$TAG) =====")
println("  store=$STORE  movie_out=$MOV  omegas=$OMEGAS  save_every=$SAVE_EVERY")
flush(stdout)
gy = joinpath(SC, "p1mov_gs.yaml")
open(gy, "w") do io
    write(io, gs_yaml())
end
gsdir = run_yaml(gy; base_dir=STORE)
gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")

for Om in OMEGAS
    tag = "O" * replace(@sprintf("%.2f", Om), "." => "p")
    println("\n===== P1-KLAUS-MOVIE Omega=$Om =====")
    flush(stdout)
    dy = joinpath(SC, "p1mov_dyn_$tag.yaml")
    open(dy, "w") do io
        write(io, dyn_yaml(gs_path, Om, tag))
    end
    ddir = run_yaml(dy; base_dir=STORE)
    dpath = joinpath(ddir isa AbstractString ? ddir : "", "point_001.jld2")
    # TAG in the FILENAME, not just the config spec. Three jobs at different
    # resolutions were run in parallel and every one of them wrote
    # p1mov_O0p85.jld2 — they silently overwrote each other, and the archives
    # carry no resolution field to tell them apart afterwards.
    reduce_frames(dpath, Om, tag, joinpath(MOV, "p1mov_$(TAG)_$tag.jld2"))
end
println("\nP1_KLAUS_MOVIE_DONE")
flush(stdout)
