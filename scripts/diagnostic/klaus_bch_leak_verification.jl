# T57 analysis script: scripts/diagnostic/klaus_bch_leak_verification.jl
#
# Reads 8 phi-sweep JLD2 files and computes primary + secondary observables
# per Section 3/4 of runs/_loop/theorist/turn_56.md.
# Pure JLD2 read + post-processing; no SpinorBEC dependency required.
#
# Usage:
#   julia --project=. scripts/diagnostic/klaus_bch_leak_verification.jl
#
# Output:
#   - Summary table to stdout
#   - Full results dict saved to runs/_loop/sim/turn_57_results.jld2

# Pre-load CodecZstd before JLD2 to avoid world-age errors when JLD2
# tries to dynamically load it during Zstd-compressed dataset reads.
using CodecZstd
using JLD2, Statistics, Printf

const PHI_VALUES = [1.0, 2.0, 3.0, 4.524, 6.0, 8.0, 12.0, 18.0]
const BASE_PATH = "/home/suzume/workspace/BEC-simulation/runs/eu151_klaus_phi_phys"
const RESULTS_OUTPUT_PATH = "/home/suzume/workspace/BEC-simulation/runs/_loop/sim/turn_57_results.jld2"
const SPINUP_END = 21.99    # dimensionless time at end of tilt + spinup phases
const MIN_STEADY_SNAPSHOTS = 100

# Derived thresholds from theorist/turn_56.md §3
const PRIMARY_CONFIRM_THRESHOLD = 1e-8
const PRIMARY_REFUTE_THRESHOLD = 1e-5
const SECONDARY_SIGMA_THRESHOLD = 5.0

# ---------------------------------------------------------------------------
# Linear fit via closed-form normal equations (no Polynomials package needed)
# Fits y = a + b*x to minimize sum-of-squared residuals.
# Returns (intercept, slope).
# ---------------------------------------------------------------------------
function linear_fit_normal_equations(x::Vector{Float64}, y::Vector{Float64})
    n = length(x)
    @assert n == length(y) "x and y must have same length"
    @assert n >= 2 "Need at least 2 points"
    sx = sum(x)
    sy = sum(y)
    sxx = sum(xi^2 for xi in x)
    sxy = sum(x[i]*y[i] for i in 1:n)
    denom = n * sxx - sx^2
    if abs(denom) < 1e-300
        # Degenerate: all x identical — return mean, zero slope
        return (sy / n, 0.0)
    end
    b = (n * sxy - sx * sy) / denom   # slope
    a = (sy - b * sx) / n             # intercept
    return (a, b)
end

# ---------------------------------------------------------------------------
# Main per-phi loop
# ---------------------------------------------------------------------------
t_start = time()

# Storage keyed by phi (Float64)
results = Dict{Float64, NamedTuple}()
skip_log = Dict{Float64, String}()

for phi in PHI_VALUES
    path = joinpath(BASE_PATH, "phi_$phi", "result.jld2")
    if !isfile(path)
        msg = "result.jld2 not found at $path"
        @warn msg
        skip_log[phi] = msg
        continue
    end

    try
        jldopen(path, "r") do f
            # --- Key existence check ---
            required_keys = [
                "dynamics/norms",
                "dynamics/Fz",
                "dynamics/Lz",
                "dynamics/per_m_history",
                "dynamics/times",
                "dynamics/integrator_meta/larmor_phase_per_step",
                "dynamics/integrator_meta/dt_used",
            ]
            for k in required_keys
                if !haskey(f, k)
                    error("phi=$phi missing JLD2 key: $k")
                end
            end

            norms = read(f, "dynamics/norms")::Vector{Float64}
            Fz_tilde = read(f, "dynamics/Fz")::Vector{Float64}
            Lz = read(f, "dynamics/Lz")::Vector{Float64}
            pmh = read(f, "dynamics/per_m_history")  # Matrix{Float64} (13 × N_snapshots)
            times = read(f, "dynamics/times")::Vector{Float64}
            larmor_phase = Float64(read(f, "dynamics/integrator_meta/larmor_phase_per_step"))
            dt_used = Float64(read(f, "dynamics/integrator_meta/dt_used"))

            # --- Steady-stir window selection ---
            steady_idx = findfirst(t -> t > SPINUP_END, times)
            if steady_idx === nothing
                error(
                    "phi=$phi: no snapshot found with t > $SPINUP_END (spinup end). Check SPINUP_END or times array.",
                )
            end

            n_steady = length(times) - steady_idx + 1
            if n_steady < MIN_STEADY_SNAPSHOTS
                error(
                    "phi=$phi: only $n_steady steady snapshots (need $MIN_STEADY_SNAPSHOTS). Check phase boundaries.",
                )
            end

            steady_norms = norms[steady_idx:end]
            steady_Fz = Fz_tilde[steady_idx:end]
            steady_Lz = Lz[steady_idx:end]
            steady_times = times[steady_idx:end]

            # pmh layout: (D × N_snapshots) per T55 §1.2 + T56 §4 pseudocode
            # c=1 ↔ m=+F=+6 per CLAUDE.md spinor convention
            steady_pmh = pmh[:, steady_idx:end]

            # --- PRIMARY observable: max norm drift over steady window ---
            max_norm_drift = maximum(abs.(1.0 .- steady_norms))

            # --- SECONDARY observable: m=+F fraction drop over steady window ---
            m_plus_F_initial = Float64(steady_pmh[1, 1])
            m_plus_F_final = Float64(steady_pmh[1, end])
            m_plus_F_drop = m_plus_F_initial - m_plus_F_final

            # --- AUXILIARY: mixed-frame EdH proxy ---
            Jz_proxy = steady_Fz .+ steady_Lz
            Jz_proxy_drift = abs(Jz_proxy[end] - Jz_proxy[1])
            Jz_proxy_mean = mean(Jz_proxy)

            results[phi] = (
                max_norm_drift=max_norm_drift,
                m_plus_F_drop=m_plus_F_drop,
                m_plus_F_initial=m_plus_F_initial,
                m_plus_F_final=m_plus_F_final,
                Jz_proxy_drift=Jz_proxy_drift,
                Jz_proxy_mean=Jz_proxy_mean,
                larmor_phase=larmor_phase,
                dt_used=dt_used,
                n_steady=n_steady,
                steady_T=steady_times[end] - steady_times[1],
            )
        end
    catch e
        msg = "phi=$phi: $(sprint(showerror, e))"
        @warn msg
        skip_log[phi] = msg
    end
end

# ---------------------------------------------------------------------------
# Aggregate analysis
# ---------------------------------------------------------------------------
phi_sorted = sort([phi for phi in PHI_VALUES if haskey(results, phi)])
n_complete = length(phi_sorted)

if n_complete < 2
    error("Fewer than 2 phi points with complete data — cannot compute aggregate verdicts.")
end

norm_drifts = [results[phi].max_norm_drift for phi in phi_sorted]
drops = [results[phi].m_plus_F_drop for phi in phi_sorted]
Jz_drifts = [results[phi].Jz_proxy_drift for phi in phi_sorted]
Jz_means = [results[phi].Jz_proxy_mean for phi in phi_sorted]
larmor_phases = [results[phi].larmor_phase for phi in phi_sorted]
dt_useds = [results[phi].dt_used for phi in phi_sorted]

# PRIMARY verdict
max_norm_drift_global = maximum(norm_drifts)

# Growth ratio: phi=18 / phi=1 (only if both present)
phi1_norm = haskey(results, 1.0) ? results[1.0].max_norm_drift : NaN
phi18_norm = haskey(results, 18.0) ? results[18.0].max_norm_drift : NaN
growth_ratio = (!isnan(phi1_norm) && phi1_norm > 0.0) ? phi18_norm / phi1_norm : NaN

primary_confirm =
    max_norm_drift_global < PRIMARY_CONFIRM_THRESHOLD &&
    (!isnan(growth_ratio) && growth_ratio < 5.0)
primary_refute =
    max_norm_drift_global > PRIMARY_REFUTE_THRESHOLD ||
    (!isnan(growth_ratio) && growth_ratio > 5.0)

primary_verdict = if primary_confirm
    :CONFIRM
elseif primary_refute
    :REFUTE
else
    :INCONCLUSIVE
end

# SECONDARY verdict: linear fit of drops vs phi, chi-square on residuals
intercept, slope = linear_fit_normal_equations(phi_sorted, drops)
residuals = drops .- (intercept .+ slope .* phi_sorted)

# sigma_baseline from low-phi-4 residuals (phi=1.0, 2.0, 3.0, 4.524)
low_phi_indices = findall(p -> p <= 4.524 + 1e-9, phi_sorted)
if length(low_phi_indices) >= 2
    low_residuals = residuals[low_phi_indices]
    sigma_baseline_raw = std(low_residuals)
else
    sigma_baseline_raw = 0.0
    @warn "Fewer than 2 low-phi points; sigma_baseline set to 0."
end

# Guard: if sigma_baseline is 0 (e.g. residuals exactly zero), use epsilon
const SIGMA_EPSILON = 1e-12
sigma_baseline = max(sigma_baseline_raw, SIGMA_EPSILON)
max_sigma_dev = maximum(abs.(residuals)) / sigma_baseline

secondary_confirm = max_sigma_dev < SECONDARY_SIGMA_THRESHOLD
secondary_refute = max_sigma_dev > SECONDARY_SIGMA_THRESHOLD

secondary_verdict = if secondary_confirm
    :CONFIRM
elseif secondary_refute
    :REFUTE
else
    :INCONCLUSIVE
end

# OVERALL verdict
overall_verdict = if primary_verdict === :CONFIRM && secondary_verdict === :CONFIRM
    :CONFIRM
elseif primary_verdict === :REFUTE || secondary_verdict === :REFUTE
    :REFUTE
else
    :INCONCLUSIVE
end

# Larmor phase constant check (p, F, dt fixed across phi scan)
larmor_range = maximum(larmor_phases) - minimum(larmor_phases)
larmor_constant = larmor_range < 0.1   # tolerance for float round-off

wall_time = time() - t_start

# ---------------------------------------------------------------------------
# Print summary
# ---------------------------------------------------------------------------
@printf("\n=== Klaus BCH-leak verification (T57 from theorist T56) ===\n")
@printf("\nPrimary observable: max_norm_drift_T_steady\n")
@printf("%-8s | %-14s | %-10s | %-14s | %-12s | %-10s | %-8s | %s\n",
    "phi", "max_norm_drift", "m+F drop", "Jz_proxy_drift", "Jz_proxy_mean",
    "larmor_ph", "dt_used", "n_steady")
@printf("%s\n", "-"^100)
for phi in phi_sorted
    r = results[phi]
    @printf("%-8.4g | %-14.6e | %-10.6f | %-14.6e | %-12.6f | %-10.4f | %-8.5f | %d\n",
        phi, r.max_norm_drift, r.m_plus_F_drop, r.Jz_proxy_drift,
        r.Jz_proxy_mean, r.larmor_phase, r.dt_used, r.n_steady)
end

@printf("\nPrimary aggregate:\n")
@printf("  max_norm_drift_global = %.6e\n", max_norm_drift_global)
@printf("  growth ratio phi=18/phi=1 = %.4g\n", growth_ratio)
@printf("  CONFIRM threshold = %.3e, REFUTE threshold = %.3e\n",
    PRIMARY_CONFIRM_THRESHOLD, PRIMARY_REFUTE_THRESHOLD)
@printf("  PRIMARY VERDICT: %s\n", primary_verdict)

@printf("\nSecondary aggregate (m+F drop chi-square vs phi smooth trend):\n")
@printf("  drops per phi: %s\n", string(round.(drops; digits=8)))
@printf("  linear fit: intercept=%.6e, slope=%.6e\n", intercept, slope)
@printf("  residuals:  %s\n", string(round.(residuals; digits=8)))
@printf("  sigma_baseline (low-phi-4 std) = %.4e  (raw=%.4e)\n",
    sigma_baseline, sigma_baseline_raw)
@printf("  max_sigma_deviation = %.4f (threshold = %.1f)\n",
    max_sigma_dev, SECONDARY_SIGMA_THRESHOLD)
@printf("  SECONDARY VERDICT: %s\n", secondary_verdict)

@printf("\nMixed-frame EdH proxy (Jz_proxy = Fz_tilde + Lz):\n")
for phi in phi_sorted
    r = results[phi]
    @printf("  phi=%.4g: drift=%.3e, mean=%.6f\n",
        phi, r.Jz_proxy_drift, r.Jz_proxy_mean)
end

@printf("\nMetadata sanity (larmor_phase = p*F*dt should be 160.2 for all phi):\n")
@printf("  larmor_constant_across_phi: %s  (range=%.4e)\n", larmor_constant, larmor_range)
for phi in phi_sorted
    r = results[phi]
    @printf("  phi=%.4g: larmor_phase=%.4f, dt=%.5f\n",
        phi, r.larmor_phase, r.dt_used)
end

if !isempty(skip_log)
    @printf("\nSkipped phi points:\n")
    for (phi, msg) in skip_log
        @printf("  phi=%.4g: %s\n", phi, msg)
    end
end

@printf("\n=== OVERALL VERDICT: %s ===\n", overall_verdict)
@printf("  (primary=%s, secondary=%s)\n", primary_verdict, secondary_verdict)
@printf("Wall time: %.2f s\n\n", wall_time)

# ---------------------------------------------------------------------------
# Save full results dict to JLD2 for T58 Analyze
# ---------------------------------------------------------------------------

# Build ordered arrays (all 8 phi, NaN for missing)
function extract_ordered(key::Symbol, default=NaN)
    [haskey(results, phi) ? getfield(results[phi], key) : default for phi in PHI_VALUES]
end

max_norm_drift_per_phi = extract_ordered(:max_norm_drift)
m_plus_F_drops_per_phi = extract_ordered(:m_plus_F_drop)
Jz_proxy_drift_per_phi = extract_ordered(:Jz_proxy_drift)
Jz_proxy_mean_per_phi = extract_ordered(:Jz_proxy_mean)
larmor_phase_per_phi = extract_ordered(:larmor_phase)
dt_used_per_phi = extract_ordered(:dt_used)

# Residuals aligned with full phi list (NaN for missing)
residuals_per_phi = Float64[]
sorted_residual_map = Dict(phi_sorted[i] => residuals[i] for i in 1:n_complete)
for phi in PHI_VALUES
    push!(residuals_per_phi, get(sorted_residual_map, phi, NaN))
end

jldsave(RESULTS_OUTPUT_PATH;
    phi_values_analyzed=PHI_VALUES,
    n_phi_with_complete_data=n_complete,
    phi_sorted=phi_sorted,
    max_norm_drift_global=max_norm_drift_global,
    max_norm_drift_per_phi=max_norm_drift_per_phi,
    norm_drift_growth_phi18_over_phi1=growth_ratio,
    primary_verdict=string(primary_verdict),
    m_plus_F_drops_per_phi=m_plus_F_drops_per_phi,
    linear_fit_slope=slope,
    linear_fit_intercept=intercept,
    residuals_per_phi=residuals_per_phi,
    sigma_baseline_lowphi4=sigma_baseline_raw,
    max_sigma_deviation=max_sigma_dev,
    secondary_verdict=string(secondary_verdict),
    jz_proxy_drift_per_phi=Jz_proxy_drift_per_phi,
    jz_proxy_mean_per_phi=Jz_proxy_mean_per_phi,
    larmor_phase_metadata_per_phi=larmor_phase_per_phi,
    larmor_phase_constant_across_phi=larmor_constant,
    dt_used_per_phi=dt_used_per_phi,
    overall_verdict=string(overall_verdict),
    wall_time_sec=wall_time,
    y4_truncation_floor_estimate_from_t56=3.14e-10,
    rotating_basis_bch_param_phi18=0.108,
    investigation_id="klaus-magnetostir-bch-leak-2026-05-13",
    stage_advancing_to="Execute",
    flow_template="verify-claim",
    falsifier_id="klaus-bch-leak-option-gamma-p2-plus-pop-discriminator",
    per_phi_results=results,
    skip_log=skip_log,
)

@printf("Results saved to %s\n", RESULTS_OUTPUT_PATH)
