# Ensemble over noise seeds: keep the (physical) symmetry-breaking seed, but average
# over M realizations to recover rotational symmetry (the TWA / multi-shot idea).
# For each ell in {0,-1}: imprint once, run M dynamics with noise_seed=1..M, extract
# final per-m column density (m=-6..0) + N_m(t). Big snapshots reaped immediately.
# Env: RB_N, RB_BOX, RB_DUR(50), RB_DT(4e-4), RB_GS_STEPS(2500), RB_M(8), RB_ELLS("0,-1").
import CUDA
using SpinorBEC
using JLD2, CodecZstd, FFTW, Printf, LinearAlgebra, DelimitedFiles, Random

CUDA.functional() || error("CUDA not functional")
const SC = get(ENV, "SPINORBEC_SCRATCH", get(ENV, "SPINORBEC_SCRATCH_DIR", "/tmp/sb_m6ens"))
const OUT = "runs/eu_barnett_rotfield_clean"
const N = get(ENV, "RB_N", "80, 80, 40")
const BOX = get(ENV, "RB_BOX", "20.0, 20.0, 10.0")
const BZG = "9.216e-4 Gauss"
const DUR = parse(Float64, get(ENV, "RB_DUR", "50.0"))
const DYN_DT = parse(Float64, get(ENV, "RB_DT", "0.0004"))
const GS_STEPS = parse(Int, get(ENV, "RB_GS_STEPS", "2500"))
const SAVE_EVERY = parse(Int, get(ENV, "RB_SAVE_EVERY", "2500"))
const M = parse(Int, get(ENV, "RB_M", "8"))
const ELLS = [parse(Int, strip(s)) for s in split(get(ENV, "RB_ELLS", "0,-1"), ",")]
mkpath(SC); mkpath(joinpath(OUT, "rebuild", "ens"))

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
      seed_amplitude: 0.0
      save: {every: $SAVE_EVERY, psi: true, precision: f32}
"""

const NOISE = parse(Float64, get(ENV, "RB_NOISE", "1.0e-3"))  # per-seed IC noise (rel. to peak); schema-bypass
function imprint(gs_path, ell, seed, out_jld2)
    rr = open_result(gs_path); grid = rr.grid
    psi = ComplexF64.(rr.psi); ND = length(grid.config.n_points); xg = grid.x[1]; yg = grid.x[2]
    if ell != 0
        @inbounds for I in CartesianIndices(size(psi)[1:ND])
            ph = cis(ell * atan(yg[I[2]], xg[I[1]]))
            for c in axes(psi, ND + 1); psi[I, c] *= ph; end
        end
    end
    # per-seed symmetry-breaking noise added HERE (controlled RNG, bypasses schema noise_seed)
    rng = MersenneTwister(seed); pk = maximum(abs, psi)
    @inbounds for I in eachindex(psi)
        psi[I] += NOISE * pk * (randn(rng) + im * randn(rng))
    end
    jldopen(out_jld2, "w") do f; f["psi"] = psi; end
    out_jld2
end

# extract final per-m column density (m=-6..0) + N_m(t) traj from a run's jld2
function extract(pj, ell, seed)
    rr = open_result(pj); grid = rr.grid
    ND = length(grid.config.n_points); D = size(rr.psi, ND + 1); F = (D - 1) ÷ 2
    sm = spin_matrices(F); plans = make_fft_plans(Tuple(grid.config.n_points); flags=FFTW.ESTIMATE)
    dV = cell_volume(grid); pre = "ell$(ell)_s$(seed)"
    jldopen(pj, "r") do f
        g = f["dynamics/psi_snapshots_streamed"]
        frames = sort(filter(s -> startswith(s, "frame_"), collect(keys(g))))
        times = collect(Float64, f["dynamics/times"])
        st = length(times) == length(frames) + 1 ? times[2:end] : times[1:min(length(frames), length(times))]
        # N_m(t) traj
        rows = ["t,Fz,N_m6,N_m5,N_m4,Ntot"]
        for (i, fr) in enumerate(frames)
            psi = ComplexF64.(g[fr]); n2 = abs2.(psi); ntot = sum(n2) * dV
            _, _, fz = spin_density_vector(psi, sm, ND); Fz = sum(fz) * dV
            t = i <= length(st) ? st[i] : NaN
            push!(rows, @sprintf("%.4f,%.5f,%.5f,%.5f,%.5f,%.6f", t, Fz,
                sum(view(n2,:,:,:,D))*dV/ntot, sum(view(n2,:,:,:,D-1))*dV/ntot,
                sum(view(n2,:,:,:,D-2))*dV/ntot, ntot))
        end
        open(joinpath(OUT,"rebuild","ens","traj_$(pre).csv"),"w") do io; for r in rows; println(io,r); end; end
        # final per-m column density
        psi = ComplexF64.(g[frames[end]]); n2 = abs2.(psi)
        writedlm(joinpath(OUT,"rebuild","ens","col_$(pre)_tot.csv"), dropdims(sum(n2;dims=(3,4));dims=(3,4)), ',')
        for c in 1:D
            m = F-(c-1)
            (m<=0 && m>=-6) && writedlm(joinpath(OUT,"rebuild","ens","col_$(pre)_m$(m).csv"), dropdims(sum(view(n2,:,:,:,c);dims=3);dims=3), ',')
        end
    end
end

println("===== ENSEMBLE Stage 1: m=-6 GS ====="); flush(stdout)
gy = joinpath(SC, "ens_gs.yaml"); open(gy,"w") do io; write(io, gs_yaml()); end
gsdir = run_yaml(gy); gs_path = joinpath(gsdir isa AbstractString ? gsdir : "", "point_001.jld2")

for ell in ELLS
    for seed in 1:M
        println("\n===== ell=$ell seed=$seed ====="); flush(stdout)
        imp = imprint(gs_path, ell, seed, joinpath(SC, "ens_imp_ell$(ell)_s$(seed).jld2"))
        dy = joinpath(SC, "ens_dyn_ell$(ell)_s$(seed).yaml"); open(dy,"w") do io; write(io, dyn_yaml(imp)); end
        ddir = run_yaml(dy); dpath = joinpath(ddir isa AbstractString ? ddir : "", "point_001.jld2")
        extract(dpath, ell, seed)
        try; rm(ddir isa AbstractString ? ddir : ""; recursive=true, force=true); catch; end  # reap big snapshots
    end
end
println("\nM6_ENSEMBLE_DONE"); flush(stdout)
