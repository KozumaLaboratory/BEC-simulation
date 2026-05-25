# Post-analysis for the Eu Hamiltonian-only ramp-quench probe.
#
# Loads runs/eu_ham_only_ramp_quench_24/{point_001,result}.jld2 (the
# original run that attempted to test EdH transfer via a Bz quench
# during dynamics) and reports norm + ⟨F_z⟩ + ⟨L_z⟩ + Jz drifts.
#
# Note: that run unintentionally ramped Bz linearly across the entire
# dynamics window because the YAML `Bz: {from, to, duration: 0.0}`
# inner `duration` field is ignored — see
# `memory/gotcha_bz_ramp_duration_ignored.md`. Energy "drift" of +978
# observed there reflects that ramp, not a conservation violation.
# The clean conservation audit lives in
# `eu_ham_only_conservation_analyze.jl`.

using CodecZstd                                 # Force-loads decompressor before JLD2 needs it
using SpinorBEC
using JLD2
using Printf

# --- Locate run directory ----------------------------------------------
candidates = filter(d -> startswith(d, "eu_ham_only_ramp_quench"),
                    readdir("runs"))
isempty(candidates) && error("No eu_ham_only_ramp_quench run directory found under runs/")
sort!(candidates; by=d -> stat(joinpath("runs", d)).mtime, rev=true)
run_dir = joinpath("runs", first(candidates))
println("Run dir: $run_dir")

result_path = joinpath(run_dir, "result.jld2")
isfile(result_path) || error("Missing $result_path — run not finished?")

d = JLD2.load(result_path)
println("Top-level keys (first 5): $(first(collect(keys(d)), 5))")

# --- Direct observables already in result.jld2 ------------------------
times = d["dynamics/times"]::Vector{Float64}
norms = d["dynamics/norms"]::Vector{Float64}
Fz_hist = d["dynamics/Fz"]::Vector{Float64}

println("\nLoaded time series: $(length(times)) frames")

# --- ⟨L_z⟩(t) — compute from streamed snapshots -----------------------
n_snap = d["dynamics/psi_snapshots_streamed/n_snapshots"]::Int
spatial_shape = d["dynamics/psi_snapshots_streamed/spatial_shape"]
n_components = d["dynamics/psi_snapshots_streamed/n_components"]::Int

println("Snapshots: $n_snap × shape $(Tuple(spatial_shape)) × $n_components components")

# Build grid + plans matching the config (24³, box 10³).
grid = make_grid(GridConfig((24, 24, 24), (10.0, 10.0, 10.0)))
plans = make_fft_plans((24, 24, 24); flags=SpinorBEC.FFTW.ESTIMATE)
sys = SpinSystem(6)

Lz_hist = Float64[]
for k in 1:n_snap
    key = @sprintf("dynamics/psi_snapshots_streamed/frame_%05d", k)
    haskey(d, key) || continue
    psi = ComplexF64.(d[key])    # snapshots are saved as ComplexF32; cast for Lz solver
    push!(Lz_hist, orbital_angular_momentum(psi, grid, plans))
end

# Time series length sanity: dynamics/times may include t=0; Lz frames count
# from the first save_every step.
println("Lz frames computed: $(length(Lz_hist))")

# Align — for a `save: {every: 10}` config the snapshots are at t = save_every·dt,
# 2·save_every·dt, ... and `dynamics/times` matches (no t=0 row). If sizes match,
# great. Else pad or truncate.
n_common = min(length(times), length(Fz_hist), length(Lz_hist), length(norms))
times = times[1:n_common]
norms = norms[1:n_common]
Fz_hist = Fz_hist[1:n_common]
Lz_hist = Lz_hist[1:n_common]
Jz_hist = Fz_hist .+ Lz_hist

println("\n  t          norm           ⟨F_z⟩         ⟨L_z⟩         Jz")
for i in eachindex(times)
    @printf("  %.4f   %.10f   %+.6e   %+.6e   %+.6e\n",
            times[i], norms[i], Fz_hist[i], Lz_hist[i], Jz_hist[i])
end

# --- Conservation verdict --------------------------------------------
norm_drift = maximum(abs.(norms .- norms[1]))
Jz_drift = maximum(abs.(Jz_hist .- Jz_hist[1]))
Fz_change = Fz_hist[end] - Fz_hist[1]
Lz_change = Lz_hist[end] - Lz_hist[1]

println("\n--- Diagnostics (NOT a Hamiltonian conservation test) ---")
@printf("  norm initial          : %.10f\n", norms[1])
@printf("  norm drift            : %.2e\n", norm_drift)
@printf("  ⟨F_z⟩ initial         : %+.6e\n", Fz_hist[1])
@printf("  ⟨F_z⟩ final           : %+.6e (Δ=%+.2e)\n", Fz_hist[end], Fz_change)
@printf("  ⟨L_z⟩ initial         : %+.6e\n", Lz_hist[1])
@printf("  ⟨L_z⟩ final           : %+.6e (Δ=%+.2e)\n", Lz_hist[end], Lz_change)
@printf("  Jz drift              : %.2e\n", Jz_drift)
if abs(Fz_change) > 1e-6
    @printf("  ΔL_z/(-ΔF_z) ratio    : %.3f\n", Lz_change / (-Fz_change))
end

println("""

Important: this run had a latent linear Bz ramp across the entire
dynamics window (`Bz: {from, to, duration: 0.0}` is NOT a quench — see
memory/gotcha_bz_ramp_duration_ignored.md). The Jz "drift" above mixes
true conservation error with ramp-induced ⟨L_z⟩ shift. For a clean
H_dyn-time-independent conservation check use
`eu_ham_only_conservation_analyze.jl` on
`runs/eu_ham_only_*_<nonsec|sec>_<hash>/`.""")
