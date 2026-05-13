# Canonical 1/N TWA validity analysis (Round-3 follow-up).
#
# Reads the three pinned-coupling ensemble JLD2s and tests the
# leading-order 1/N predictions:
#
#   * (TWA mean − GP) / GP             ∝ 1/N      (so |Δrel| × N ≈ const)
#   * σ/μ at peak                      ∝ 1/√N     (so σ/μ × √N ≈ const)
#   * FWHM_z stays in {5, 6, 7} cells  (genuine dipolar instability)
#
# A clean linear scaling with N supports TWA validity at the N=10⁴
# baseline; departures suggest classical-thermalisation contamination
# and motivate either the Sinatra remedies (grid coarsening + k-cutoff)
# or a higher-order theory (TDHFB, full Beliaev).

using SpinorBEC, JLD2
using Printf

const ROOT = dirname(@__DIR__)
const RUNS_ROOT = joinpath(ROOT, "runs")
const DETERMINISTIC = joinpath(ROOT, "runs", "eu151_edh_postfix_local",
    ".archive_baseline", "point_001.jld2")
const N_VALUES = (1000, 10000, 100000)

function _resolve_result(N::Integer)
    isdir(RUNS_ROOT) || return nothing
    hits = String[]
    for d in readdir(RUNS_ROOT; join=true)
        isdir(d) || continue
        startswith(basename(d), "N$(N)_pinned_") || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function final_density_stats(path::String; ensemble::Bool=false)
    jldopen(path, "r") do f
        if ensemble
            mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
            var_arr = f["dynamics/ensemble/phase_02/density/variance"]
            nx, ny, nz, _ = size(mean_arr)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = mean_arr[:, :, :, end]
            varr = var_arr[:, :, :, end]
            n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        else
            psi = f["psi"]
            nx, ny, nz, _ = size(psi)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = sum(abs2.(psi); dims=4)[:, :, :, 1]
            varr = nothing
            n_traj = 1
        end
        peak = maximum(dens)
        prof_x = dens[:, cy, cz]
        prof_z = dens[cx, cy, :]
        fwhm(p) =
            let h = maximum(p) / 2
                idx = findall(>(h), p)
                isempty(idx) ? 0 : last(idx) - first(idx) + 1
            end
        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)
        sigma_over_mu = NaN
        if varr !== nothing
            peak_idx = argmax(dens)
            σ = sqrt(max(varr[peak_idx], 0.0))
            sigma_over_mu = σ / max(peak, 1e-30)
        end
        (; n_traj, peak,
            fwhm_x=fwhm(prof_x), fwhm_z=fwhm(prof_z),
            on_axis, sigma_over_mu)
    end
end

println("=== Canonical 1/N TWA validity test (pinned coupling) ===\n")

det = final_density_stats(DETERMINISTIC; ensemble=false)
@printf("Deterministic baseline (Eu N=10⁴, c_total=937.453, c_dd=42.204):\n")
@printf("  peak n = %.4f, FWHM (x,z) = (%d, %d), on-axis = %.3f\n\n",
    det.peak, det.fwhm_x, det.fwhm_z, det.on_axis)

results = []
for N in N_VALUES
    path = _resolve_result(N)
    if path === nothing
        @printf("N=%d: result missing (looked for runs/N%d_pinned_*/result.jld2)\n", N, N)
        continue
    end
    s = final_density_stats(path; ensemble=true)
    push!(results, (N=N, stats=s))
    @printf("N = %6d (%d traj):\n", N, s.n_traj)
    @printf("  peak n          = %.4f\n", s.peak)
    @printf("  FWHM (x, z)     = (%d, %d) cells\n", s.fwhm_x, s.fwhm_z)
    @printf("  on-axis ratio   = %.3f  (deterministic = %.3f)\n", s.on_axis, det.on_axis)
    @printf("  on-axis Δ/det   = %+.3f\n", (s.on_axis - det.on_axis) / det.on_axis)
    @printf("  σ_n / n at peak = %.3f\n\n", s.sigma_over_mu)
end

if length(results) >= 2
    println("=== 1/N scaling check ===")
    println("(on_axis_TWA - on_axis_det) / on_axis_det vs 1/N — should be linear in 1/N:")
    Δrel_xN = Float64[]
    for r in results
        Δrel = (r.stats.on_axis - det.on_axis) / det.on_axis
        push!(Δrel_xN, Δrel * r.N)
        @printf("  N=%6d:  1/N = %.4e,  Δrel = %+.4f,  Δrel × N = %.2f\n",
            r.N, 1.0 / r.N, Δrel, Δrel * r.N)
    end
    spread = maximum(Δrel_xN) - minimum(Δrel_xN)
    rel = spread / max(maximum(abs.(Δrel_xN)), 1e-30)
    @printf("  → Δrel × N spread = %.2f (%.0f%% of max abs)\n",
        spread, 100 * rel)
    if rel < 0.3
        println("  → 1/N scaling holds → TWA validity confirmed at the N=10⁴ baseline.")
    elseif rel < 1.0
        println("  → marginal 1/N scaling; investigate Sinatra remedies before publishing.")
    else
        println("  → 1/N scaling broken → TWA NOT a controlled approximation;")
        println("    consider full BdG / TDHFB or the Sinatra coarsening recipe.")
    end

    println()
    println("σ/μ × √N — should be roughly N-independent under 1/√N scaling:")
    σ_xsqN = Float64[]
    for r in results
        sn = r.stats.sigma_over_mu * sqrt(r.N)
        push!(σ_xsqN, sn)
        @printf("  N=%6d:  σ/μ = %.3f,  σ/μ × √N = %.2f\n", r.N, r.stats.sigma_over_mu, sn)
    end
    sp2 = maximum(σ_xsqN) - minimum(σ_xsqN)
    rl2 = sp2 / max(maximum(σ_xsqN), 1e-30)
    @printf("  → σ/μ × √N spread = %.2f (%.0f%% of max)\n", sp2, 100 * rl2)
    if rl2 < 0.3
        println("  → 1/√N scaling holds → quantum noise normalisation correct.")
    elseif rl2 < 1.0
        println("  → marginal 1/√N scaling; possibly thermalisation contamination.")
    else
        println("  → 1/√N scaling broken → spurious classical heating.")
    end
end
