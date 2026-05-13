# Transient T-sweep — falsifier for the "vacuum κ-buildup transient"
# hypothesis. Measure Strang plain global order as a function of integration
# time T, at vacuum initial state.
#
# Hypothesis-A prediction (left/right φ-half generator asymmetry × κ
# linear build-up): slope_strang_plain ≈ 1 across all T (asymmetry is
# state-symmetric, not a transient). Empirically already confirmed at
# pre-evolved state in B-2 v2.
#
# Hypothesis-B prediction (vacuum-T transient): slope rises to ~2 as T
# grows past the κ-saturation timescale.
#
# Three T values bracket the regime:
#   T = 0.05 (well inside transient if it exists)
#   T = 0.2  (B-2 baseline)
#   T = 1.0  (well past trap period — asymptotic if transient)
#
# GPU is essential: F=1 16³ TDHFB ref @ dt=0.0005, T=1.0 = 2000 steps
# × 750ms/step on CPU = 25 min just for ONE reference. On GPU F64
# (~15× speedup per memory `tdhfb_gpu_port_status.md`) it drops to ~2 min.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/diagnostic/transient_T_sweep_gpu.jl

import CUDA
using SpinorBEC
using Printf
using LinearAlgebra

const F = 1
const D = 2F + 1
const N_SPATIAL = 16
const BOX = 10.0
const DT_REF = 0.0005

function _initial_state_anti_polar_gpu()
    phi_h = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2)) + 0im
        phi_h[i, j, k, 1] = g / sqrt(2)
        phi_h[i, j, k, 3] = g / sqrt(2)
    end
    phi_h ./= sqrt(sum(abs2, phi_h))
    init_tdhfb_vacuum(CUDA.CuArray(phi_h))
end

function _harmonic_trap_gpu()
    V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    dx = BOX / N_SPATIAL
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        v = 0.5 * (((i - center) * dx)^2 + ((j - center) * dx)^2
                   + 1.4^2 * ((k - center) * dx)^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    return CUDA.CuArray(V_ext)
end

function _run(scheme::Symbol, picard_midpoint::Bool, dt::Float64, T::Float64,
    state0, g_S, V_ext)
    n_steps = round(Int, T / dt)
    state = deepcopy(state0)
    if scheme === :strang
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps; scheme=:strang)
    elseif scheme === :strang_pm
        for _ in 1:n_steps
            tdhfb_strang_step!(state, F, g_S, V_ext, dt;
                picard_midpoint=true, picard_tol=1e-14, picard_max_iter=100)
        end
    else  # :y4_midpoint
        tdhfb_evolve!(state, F, g_S, V_ext, dt, n_steps;
            scheme=:y4_midpoint,
            picard_midpoint=picard_midpoint,
            picard_midpoint_tol=1e-14,
            picard_midpoint_max_iter=100,
        )
    end
    return state
end

function _state_err(state, state_ref)
    phi_e = maximum(abs.(state.phi .- state_ref.phi))
    rho_e = maximum(abs.(state.rho .- state_ref.rho))
    kappa_e = maximum(abs.(state.kappa .- state_ref.kappa))
    (phi=phi_e, rho=rho_e, kappa=kappa_e)
end

function _fit_slope(log_dts, log_err)
    n = length(log_dts)
    mean_x = sum(log_dts) / n
    mean_y = sum(log_err) / n
    sum((log_dts[i] - mean_x) * (log_err[i] - mean_y) for i in 1:n) /
    sum((log_dts[i] - mean_x)^2 for i in 1:n)
end

function _sweep_at_T(T::Float64, state0, g_S, V_ext, dts)
    @printf("\n%s\n=== T = %.2f ===\n%s\n", "─"^72, T, "─"^72)
    @printf("Building reference (Y4-mid @ dt=%.5f, %d steps)...\n",
        DT_REF, round(Int, T / DT_REF))
    t0 = time()
    state_ref = _run(:y4_midpoint, true, DT_REF, T, state0, g_S, V_ext)
    CUDA.synchronize()
    @printf("    wall=%.1fs\n", time() - t0)

    schemes = [
        ("Strang plain", :strang, false),
        ("Strang picard", :strang_pm, true),
        ("Y4 plain", :y4_midpoint, false),
        ("Y4 picard (A4)", :y4_midpoint, true),
    ]
    @printf("\n%-18s  %-10s  %-10s  %-10s  %-8s\n",
        "scheme", "slope(φ)", "slope(ρ)", "slope(κ)", "wall(s)")
    out = Dict{String, Any}()
    for (sname, scheme, pm) in schemes
        results = NamedTuple[]
        t_total = 0.0
        for dt in dts
            t1 = time()
            state = _run(scheme, pm, dt, T, state0, g_S, V_ext)
            CUDA.synchronize()
            t_total += time() - t1
            push!(results, (dt=dt, _state_err(state, state_ref)...))
        end
        log_dts = log.([r.dt for r in results])
        sφ = _fit_slope(log_dts, log.([r.phi for r in results]))
        sρ = _fit_slope(log_dts, log.([r.rho for r in results]))
        sκ = _fit_slope(log_dts, log.([r.kappa for r in results]))
        @printf("%-18s  %-10.3f  %-10.3f  %-10.3f  %-8.1f\n",
            sname, sφ, sρ, sκ, t_total)
        out[sname] = (slope_phi=sφ, slope_rho=sρ, slope_kappa=sκ)
    end
    return out
end

@printf("=== Transient T-sweep (GPU, vacuum initial) ===\n")
@printf("F=%d, %d³, g_S=(0=>1.0, 2=>1.2)\n", F, N_SPATIAL)

state0 = _initial_state_anti_polar_gpu()
V_ext = _harmonic_trap_gpu()
g_S = Dict{Int, Float64}(0 => 1.0, 2 => 1.2)
dts = [0.02, 0.01, 0.005, 0.0025]

T_values = [0.05, 0.2, 1.0]
results = Dict{Float64, Any}()
for T in T_values
    results[T] = _sweep_at_T(T, state0, g_S, V_ext, dts)
end

# Final summary
@printf("\n%s\n=== Slope vs T (φ component) ===\n%s\n", "═"^80, "═"^80)
@printf("%-18s  %s\n", "scheme",
    join([@sprintf("T=%.2f", T) for T in T_values], "      "))
for sname in ("Strang plain", "Strang picard", "Y4 plain", "Y4 picard (A4)")
    @printf("%-18s  ", sname)
    for T in T_values
        @printf("%-10.3f", results[T][sname].slope_phi)
    end
    @printf("\n")
end

@printf("\n── Hypothesis tests ──\n")
@printf("Hypothesis A (asymmetry × build-up, NOT transient):\n")
@printf("  Strang plain slope is ~1 ACROSS all T. Picard fixes to ~2.\n")
@printf("Hypothesis B (vacuum transient):\n")
@printf("  Strang plain slope rises 1 → 2 as T crosses κ-saturation timescale.\n")
