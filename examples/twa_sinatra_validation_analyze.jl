# TWA Sinatra criterion validation analysis (Round-3 Task 2).
#
# Reads the three ensemble JLD2s (baseline_32g, coarse_16g, cutoff_16g)
# and produces the σ/μ-vs-Sinatra-ratio comparison table. The user's
# acceptance test:
#
#   σ/μ at peak roughly N-independent across configs → real quantum noise.
#   σ/μ shrinks dramatically from baseline → cutoff → spurious heating.

using SpinorBEC, JLD2
using Printf

const ROOT = dirname(@__DIR__)
const RUNS_ROOT = joinpath(ROOT, "runs")

const POINTS = (
    (label="baseline_32g", grid=32, cutoff_energy=6.0),
    (label="coarse_16g", grid=16, cutoff_energy=6.0),
    (label="cutoff_16g", grid=16, cutoff_energy=1.0),
)

function _resolve_result(label::AbstractString)
    isdir(RUNS_ROOT) || return nothing
    hits = String[]
    for d in readdir(RUNS_ROOT; join=true)
        isdir(d) || continue
        startswith(basename(d), label * "_") || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function ensemble_stats(path::AbstractString)
    jldopen(path, "r") do f
        mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
        var_arr = f["dynamics/ensemble/phase_02/density/variance"]
        n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        nx, ny, nz, _ = size(mean_arr)
        cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
        dens = mean_arr[:, :, :, end]
        varr = var_arr[:, :, :, end]
        peak = maximum(dens)
        peak_idx = argmax(dens)
        σ = sqrt(max(varr[peak_idx], 0.0))
        sigma_over_mu = σ / max(peak, 1e-30)
        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)
        # σ/μ averaged over voxels above 1% of peak (broader stat than just peak)
        threshold = 0.01 * peak
        σ_voxels = Float64[]
        for I in eachindex(dens)
            μ = dens[I]
            μ > threshold || continue
            push!(σ_voxels, sqrt(max(varr[I], 0.0)) / μ)
        end
        sigma_over_mu_mean = isempty(σ_voxels) ? NaN : sum(σ_voxels) / length(σ_voxels)
        (; n_traj, peak, on_axis, sigma_over_mu, sigma_over_mu_mean,
            grid_pts=nx, n_voxels_kept=length(σ_voxels))
    end
end

println("=== TWA Sinatra validation ===\n")

results = []
for p in POINTS
    path = _resolve_result(p.label)
    if path === nothing
        @printf("%-14s grid=%d cutoff=%.1f: result missing\n",
            p.label, p.grid, p.cutoff_energy)
        continue
    end
    s = ensemble_stats(path)
    push!(results, (label=p.label, grid=p.grid, cutoff=p.cutoff_energy, stats=s))
    n_modes = p.grid^3 * 13
    sinatra = n_modes / 10_000.0
    @printf("%-14s grid=%d^3, cutoff=%.1f, Sinatra ratio = %.1f\n",
        p.label, p.grid, p.cutoff_energy, sinatra)
    @printf("  peak n            = %.4f\n", s.peak)
    @printf("  on-axis ratio     = %.3f\n", s.on_axis)
    @printf("  σ/μ at peak       = %.3f\n", s.sigma_over_mu)
    @printf("  σ/μ across voxels = %.3f  (n_voxels = %d)\n\n",
        s.sigma_over_mu_mean, s.n_voxels_kept)
end

if length(results) >= 2
    println("=== Sinatra check verdict ===")
    σs = [r.stats.sigma_over_mu for r in results]
    σ_min, σ_max = extrema(σs)
    spread = σ_max - σ_min
    rel = spread / max(σ_max, 1e-30)
    @printf("σ/μ at peak ranges %.3f → %.3f (spread = %.3f, %.1f%% of max)\n",
        σ_min, σ_max, spread, 100 * rel)
    if rel < 0.2
        println("  → σ/μ is grid/cutoff-independent → REAL quantum noise (publishable).")
    elseif rel < 0.5
        println("  → moderate dependence; suggestive of partial spurious heating.")
    else
        println("  → strong dependence on grid/cutoff → SPURIOUS classical thermalisation;")
        println("    TWA at the baseline 32³ setup is not a controlled approximation.")
    end
end
