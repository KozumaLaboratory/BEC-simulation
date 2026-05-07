# TWA ε_dd scan analysis (Round-2 Task 2).
# Reads the four ε_dd ensemble JLD2s and produces a comparison table:
# species universality of dipolar collapse smearing under quantum noise.
#
#   * on-axis ratio (deterministic vs ensemble) vs ε_dd
#   * Z-elongation FWHM vs ε_dd (genuine dipolar instability strength)
#   * σ/μ at peak vs ε_dd (quantum noise amplitude)
#
# Hypothesis: as ε_dd increases, the deterministic / TWA divergence widens
# (stronger DDI-driven symmetry breaking → more noise-sensitive observable).
# Crossover near ε_dd ~ 1 (droplet boundary) would identify a
# quantum-classical regime change.

using SpinorBEC, JLD2
using Printf

const RUN_DIR = "/home/suzume/workspace/BEC-simulation/runs/twa_eps_dd_scan"
const POINTS = (
    (label="Cr_eps0.15", eps_dd=0.15),
    (label="Eu_eps0.55", eps_dd=0.55),
    (label="Er_eps0.88", eps_dd=0.88),
    (label="Dy_eps1.39", eps_dd=1.39),
)

function final_density_stats(path::String)
    jldopen(path, "r") do f
        mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
        var_arr = f["dynamics/ensemble/phase_02/density/variance"]
        n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        nx, ny, nz, nt = size(mean_arr)
        cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
        dens = mean_arr[:, :, :, end]
        varr = var_arr[:, :, :, end]

        peak = maximum(dens)
        prof_x = dens[:, cy, cz]
        prof_z = dens[cx, cy, :]
        fwhm(p) = let h = maximum(p) / 2
            idx = findall(>(h), p)
            isempty(idx) ? 0 : last(idx) - first(idx) + 1
        end
        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)

        peak_idx = argmax(dens)
        σ = sqrt(max(varr[peak_idx], 0.0))
        sigma_over_mu = σ / max(peak, 1e-30)

        z_elongation = fwhm(prof_z) / max(fwhm(prof_x), 1)
        (; n_traj, peak,
           fwhm_x=fwhm(prof_x), fwhm_z=fwhm(prof_z), z_elongation,
           on_axis, sigma_over_mu)
    end
end

println("=== TWA ε_dd scan analysis ===\n")

results = []
for p in POINTS
    path = joinpath(RUN_DIR, p.label, "result.jld2")
    if !isfile(path)
        @printf("%-14s ε_dd=%.2f: result missing (%s)\n", p.label, p.eps_dd, path)
        continue
    end
    s = final_density_stats(path)
    push!(results, (label=p.label, eps_dd=p.eps_dd, stats=s))
    @printf("%-14s ε_dd=%.2f (%d traj):\n", p.label, p.eps_dd, s.n_traj)
    @printf("  peak n          = %.4f\n", s.peak)
    @printf("  FWHM (x, z)     = (%d, %d) cells   z/x ratio = %.2f\n",
            s.fwhm_x, s.fwhm_z, s.z_elongation)
    @printf("  on-axis ratio   = %.3f\n", s.on_axis)
    @printf("  σ_n / n at peak = %.3f\n\n", s.sigma_over_mu)
end

if length(results) >= 2
    println("=== ε_dd dependence ===")
    @printf("%-14s %8s %10s %10s %10s %10s\n",
            "label", "ε_dd", "peak", "FWHM_z", "on_axis", "σ/μ")
    println("-"^76)
    for r in results
        @printf("%-14s %8.2f %10.4f %10d %10.3f %10.3f\n",
                r.label, r.eps_dd, r.stats.peak,
                r.stats.fwhm_z, r.stats.on_axis, r.stats.sigma_over_mu)
    end
    println()

    sort!(results, by=r -> r.eps_dd)
    println("Crossover diagnostic (Δ on_axis | Δ σ/μ from low to high ε_dd):")
    for i in 1:length(results)-1
        a, b = results[i], results[i+1]
        dr = b.stats.on_axis - a.stats.on_axis
        ds = b.stats.sigma_over_mu - a.stats.sigma_over_mu
        @printf("  %s → %s   Δon_axis = %+.3f   Δσ/μ = %+.3f\n",
                a.label, b.label, dr, ds)
    end
end
