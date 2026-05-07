# TWA N scan analysis (Round-2 Task 1).
# Reads the 3 ensemble JLD2 files (N=1k, 10k, 100k) and produces a table
# of (on-axis ratio, FWHM, peak n, σ/μ) vs N to test 1/N validity:
#
#   * (TWA mean - deterministic) / deterministic should ∝ 1/N
#   * σ/μ at peak should ∝ 1/√N
#   * FWHM_x × FWHM_z should be N-independent (genuine dipolar instability)

using SpinorBEC, JLD2
using Printf

const RUN_DIR = "/home/suzume/workspace/BEC-simulation/runs/twa_N_scan"
const DETERMINISTIC = "/home/suzume/workspace/BEC-simulation/runs/eu151_edh_postfix_local/.archive_baseline/point_001.jld2"

function final_density_stats(path::String; ensemble::Bool=false)
    jldopen(path, "r") do f
        if ensemble
            # Last frame of mean / variance density (TWA case)
            mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
            var_arr = f["dynamics/ensemble/phase_02/density/variance"]
            nx, ny, nz, nt = size(mean_arr)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = mean_arr[:, :, :, end]
            varr = var_arr[:, :, :, end]
            n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        else
            psi = f["psi"]
            nx, ny, nz, nc = size(psi)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = sum(abs2.(psi), dims=4)[:, :, :, 1]
            varr = nothing
            n_traj = 1
        end

        peak = maximum(dens)
        prof_x = dens[:, cy, cz]
        prof_z = dens[cx, cy, :]
        fwhm(p) = let h = maximum(p) / 2
            idx = findall(>(h), p)
            isempty(idx) ? 0 : last(idx) - first(idx) + 1
        end

        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)

        sigma_over_mu_at_peak = NaN
        if varr !== nothing
            peak_idx = argmax(dens)
            σ = sqrt(max(varr[peak_idx], 0.0))
            sigma_over_mu_at_peak = σ / max(peak, 1e-30)
        end

        return (
            n_traj=n_traj,
            peak=peak,
            fwhm_x=fwhm(prof_x),
            fwhm_z=fwhm(prof_z),
            on_axis=on_axis,
            sigma_over_mu=sigma_over_mu_at_peak,
        )
    end
end

println("=== TWA N scan analysis ===\n")

# Reference: deterministic (single trajectory, no Wigner noise)
det = final_density_stats(DETERMINISTIC; ensemble=false)
@printf("Deterministic baseline (N = 10000, no TWA):\n")
@printf("  peak n = %.4f, FWHM (x,z) = (%d, %d), on-axis ratio = %.3f\n\n",
    det.peak, det.fwhm_x, det.fwhm_z, det.on_axis)

# TWA ensembles
results = []
for N in (1000, 10000, 100000)
    path = joinpath(RUN_DIR, "N$(N)/result.jld2")
    if !isfile(path)
        @printf("N=%d: result missing (%s)\n", N, path)
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

# 1/N scaling check: collapse pattern smearing should vanish as N → ∞
println("=== 1/N validity check ===")
println("(on_axis_TWA - on_axis_det) / on_axis_det vs 1/N — should follow ∝ 1/N if TWA captures genuine quantum fluctuations correctly")
for r in results
    Δrel = (r.stats.on_axis - det.on_axis) / det.on_axis
    @printf("  N=%6d:  1/N = %.4e,  Δrel = %+.4f,  Δrel × N = %.2f\n",
        r.N, 1.0 / r.N, Δrel, Δrel * r.N)
end
println()
println("σ/μ × √N should be roughly N-independent (1/√N scaling):")
for r in results
    sn = r.stats.sigma_over_mu * sqrt(r.N)
    @printf("  N=%6d:  σ/μ = %.3f,  σ/μ × √N = %.2f\n", r.N, r.stats.sigma_over_mu, sn)
end
