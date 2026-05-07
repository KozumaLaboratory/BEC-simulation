# Sinatra-clean 1/N TWA validity analysis on 16³ × box=10 (Round-3 follow-up).
#
# Reads the three pinned-coupling 16g ensemble JLD2s and tests the
# leading-order 1/N predictions on a Sinatra-clean grid (Sinatra ratio
# 53 / 5.3 / 0.53 across the three N values, vs the contaminated 42.6
# at the original 32³ × box=20 setup).
#
# Resolution dx = 10/16 = 0.625 a_ho matches the 32³ box=20 baseline,
# so the ground-state physics is identical to the contaminated 32³
# runs — only the noise-mode count differs.
#
# Expected (clean quantum noise):
#   * (TWA mean − GP) / GP             ∝ 1/N      (Δrel × N ≈ const)
#   * σ/μ at peak                      ∝ 1/√N     (σ/μ × √N ≈ const)
#   * FWHM_z (deterministic)           N-independent

using SpinorBEC, JLD2
using Printf

const ROOT = dirname(@__DIR__)
const RUNS_ROOT = joinpath(ROOT, "runs")
const N_VALUES = (1000, 10000, 100000)

function _resolve_result(N::Integer)
    isdir(RUNS_ROOT) || return nothing
    hits = String[]
    for d in readdir(RUNS_ROOT; join=true)
        isdir(d) || continue
        startswith(basename(d), "N$(N)_pinned_16g_") || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function final_density_stats(path::String)
    jldopen(path, "r") do f
        mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
        var_arr = f["dynamics/ensemble/phase_02/density/variance"]
        n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        nx, ny, nz, _ = size(mean_arr)
        cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
        dens = mean_arr[:, :, :, end]
        varr = var_arr[:, :, :, end]
        peak = maximum(dens)
        prof_x = dens[:, cy, cz]
        prof_z = dens[cx, cy, :]
        fwhm(p) =
            let h = maximum(p) / 2
                idx = findall(>(h), p)
                isempty(idx) ? 0 : last(idx) - first(idx) + 1
            end
        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)
        peak_idx = argmax(dens)
        σ = sqrt(max(varr[peak_idx], 0.0))
        sigma_over_mu = σ / max(peak, 1e-30)
        sinatra = nx^3 * 13 / Float64(n_traj == 50 ? 50 : 1) # placeholder, see below
        (; n_traj, peak,
            fwhm_x=fwhm(prof_x), fwhm_z=fwhm(prof_z),
            on_axis, sigma_over_mu, nx)
    end
end

println("=== Sinatra-clean 1/N TWA validity test (16³ × box=10) ===\n")

results = []
for N in N_VALUES
    path = _resolve_result(N)
    if path === nothing
        @printf("N=%d: result missing (looked for runs/N%d_pinned_16g_*/result.jld2)\n",
            N, N)
        continue
    end
    s = final_density_stats(path)
    push!(results, (N=N, stats=s))
    sinatra = s.nx^3 * 13 / N
    @printf("N = %6d (%d traj, Sinatra ratio = %.2f):\n", N, s.n_traj, sinatra)
    @printf("  peak n          = %.4f\n", s.peak)
    @printf("  FWHM (x, z)     = (%d, %d) cells\n", s.fwhm_x, s.fwhm_z)
    @printf("  on-axis ratio   = %.3f\n", s.on_axis)
    @printf("  σ_n / n at peak = %.4f\n\n", s.sigma_over_mu)
end

if length(results) >= 2
    println("=== 1/√N scaling (σ/μ × √N) ===")
    σ_xsqN = Float64[]
    for r in results
        sn = r.stats.sigma_over_mu * sqrt(r.N)
        push!(σ_xsqN, sn)
        @printf("  N=%6d:  σ/μ = %.4f,  σ/μ × √N = %.3f\n",
            r.N, r.stats.sigma_over_mu, sn)
    end
    sp = maximum(σ_xsqN) - minimum(σ_xsqN)
    rel = sp / max(maximum(σ_xsqN), 1e-30)
    @printf("  → spread = %.3f (%.0f%% of max)\n", sp, 100 * rel)
    if rel < 0.3
        println("  → 1/√N scaling holds → quantum noise normalisation correct.")
        println("    Sinatra-clean baseline σ/μ × √N ≈ ",
            round(sum(σ_xsqN) / length(σ_xsqN); digits=3),
            " (universal Wigner amplitude).")
    elseif rel < 1.0
        println("  → marginal 1/√N scaling; possibly residual contamination at low N.")
    else
        println("  → 1/√N scaling broken even on Sinatra-clean grid;")
        println("    the σ/μ signal is dominated by something other than Wigner noise.")
    end

    println()
    println("=== Sinatra-cleanliness check (vs 32³ contamination) ===")
    println("At Sinatra ratio < 1, σ/μ should be the genuine quantum-noise level.")
    last = results[end]   # highest N → cleanest Sinatra
    sinatra_last = last.stats.nx^3 * 13 / last.N
    @printf("  N = %d (Sinatra ratio = %.2f):  σ/μ = %.4f\n",
        last.N, sinatra_last, last.stats.sigma_over_mu)
    @printf("  (32³ box=20 N=10⁴ contaminated value was σ/μ = 0.423)\n")
end
