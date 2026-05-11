# TDHFB Eu (F=6) post-quench production run — Phase 6 deliverable.
#
# Goal: measure ñ/n̄ depletion ratio and pair amplitude |κ| amplitude on a
# realistic ¹⁵¹Eu config with anti-polar initial state, validate against
# Lima-Pelster scalar prediction (~5×10⁻³ for Eu params).
#
# Uses the unified `tdhfb_evolve!` API with save_every snapshots so we can
# track time evolution of the depletion observables.
#
# Setup:
#   - F = 6, D = 13 (¹⁵¹Eu)
#   - 16³ grid (Phase 1 scope; production 32³ post-Phase 5 GPU port)
#   - Anti-polar initial (m=+6 + m=-6) — has no Mz = 0 obstruction, allows
#     ρ generation through even-S channels
#   - T_total = 0.4 (short — stays in pre-chaotic conservation regime per
#     2026-05-12 finding that drift is dt-independent and grows non-linearly
#     past T~1).
#   - dt = 0.002, n_steps = 200
#   - Strang scheme (Y4-mid wrapper would be Phase 4)
#
# Run: julia --project=. scripts/tdhfb_eu_production.jl

using SpinorBEC
using LinearAlgebra
using Printf

const F = 6
const D = 2F + 1  # = 13
const N_SPATIAL = 16
const BOX = 10.0
const DT = 0.002
const N_STEPS = 200          # T = 0.4 ω⁻¹
const SAVE_EVERY = 20         # 10 snapshots over the run
const T_TOTAL = N_STEPS * DT

# Eu g_S — scalar baseline (all channels equal). For real Eu the 7 channels
# are not well measured; use g_S = 1 as the operational normalization.
const G_S_SCALAR = Dict{Int, Float64}(
    0 => 1.0, 2 => 1.0, 4 => 1.0, 6 => 1.0, 8 => 1.0, 10 => 1.0, 12 => 1.0
)
# Eu "tilted" g_S — g_0 < g_12 by ~20% (asymmetric to drive spin mixing)
const G_S_TILTED = Dict{Int, Float64}(
    0 => 0.9, 2 => 0.95, 4 => 1.0, 6 => 1.0, 8 => 1.0, 10 => 1.05, 12 => 1.1
)

function _make_anti_polar_phi()
    phi = zeros(ComplexF64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    sigma = 2.0
    # m index for F=6: c=1 → m=+F=+6, c=D=13 → m=-F=-6
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        r2 = (i - center)^2 + (j - center)^2 + (k - center)^2
        g = exp(-r2 / (2 * sigma^2))
        phi[i, j, k, 1] = g / sqrt(2.0)   # |+6⟩
        phi[i, j, k, D] = g / sqrt(2.0)   # |-6⟩
    end
    phi ./= sqrt(sum(abs2, phi))
    phi
end

function _make_harmonic_trap()
    V_ext = zeros(Float64, N_SPATIAL, N_SPATIAL, N_SPATIAL, D)
    center = N_SPATIAL ÷ 2 + 1
    dx = BOX / N_SPATIAL
    @inbounds for i in 1:N_SPATIAL, j in 1:N_SPATIAL, k in 1:N_SPATIAL
        x = (i - center) * dx
        y = (j - center) * dx
        z = (k - center) * dx
        # 1.4² anisotropy on z (Eu trap shape)
        v = 0.5 * (x^2 + y^2 + 1.4^2 * z^2)
        for m in 1:D
            V_ext[i, j, k, m] = v
        end
    end
    V_ext
end

# Mean density (total particle density per voxel)
function _mean_density(state::TDHFBState)
    phi = state.phi
    rho = state.rho
    n_voxels = prod(size(phi)[1:end-1])
    n_total = 0.0
    n_thermal = 0.0
    @inbounds for I in CartesianIndices(size(phi)[1:end-1])
        n_phi = 0.0
        n_rho = 0.0
        for c in 1:D
            n_phi += abs2(phi[I, c])
            n_rho += real(rho[I, c, c])
        end
        n_total += n_phi + n_rho
        n_thermal += n_rho
    end
    (mean_total = n_total / n_voxels, mean_thermal = n_thermal / n_voxels,
     ratio = n_thermal / max(n_total, 1e-30))
end

# RMS pair amplitude (κ Frobenius norm over voxels, normalised by sqrt(n_voxels))
function _mean_kappa(state::TDHFBState)
    kappa = state.kappa
    n_voxels = prod(size(kappa)[1:end-2])
    s = 0.0
    @inbounds for I in CartesianIndices(size(kappa)[1:end-2])
        for a in 1:D, b in 1:D
            s += abs2(kappa[I, a, b])
        end
    end
    sqrt(s / n_voxels)
end

function _run(label::String, g_S::Dict{Int, Float64})
    @printf("\n%s\n", "─"^72)
    @printf("%s — F=%d, %d³, T=%.3f, dt=%.4f, %d steps\n",
        label, F, N_SPATIAL, T_TOTAL, DT, N_STEPS)
    @printf("%s\n", "─"^72)

    phi0 = _make_anti_polar_phi()
    V_ext = _make_harmonic_trap()
    state = init_tdhfb_vacuum(phi0)

    N_init = tdhfb_total_particle_number(state)
    E_init = tdhfb_energy(state, F, g_S, V_ext)
    @printf("Init: N = %.6f, E = %.6f\n", N_init, E_init)
    @printf("Initial state: anti-polar |+6⟩+|−6⟩\n")

    @printf("\n%-5s %-7s %-12s %-12s %-12s %-12s %-12s\n",
        "step", "t", "‖ρ‖", "‖κ‖", "ñ/n̄", "ΔN/N", "ΔE/|E|")
    @printf("%-5d %-7.3f %-12.4e %-12.4e %-12.4e %-12s %-12s\n",
        0, 0.0, norm(state.rho), norm(state.kappa), 0.0, "—", "—")

    t_start = time()
    _, history = tdhfb_evolve!(state, F, g_S, V_ext, DT, N_STEPS;
        scheme=:strang, save_every=SAVE_EVERY,
        on_step=(s, step) -> begin
            if step % SAVE_EVERY == 0
                meas = _mean_density(s)
                k_rms = _mean_kappa(s)
                N_now = tdhfb_total_particle_number(s)
                E_now = tdhfb_energy(s, F, g_S, V_ext)
                @printf("%-5d %-7.3f %-12.4e %-12.4e %-12.4e %+10.3e   %+10.3e\n",
                    step, s.t, norm(s.rho), norm(s.kappa), meas.ratio,
                    (N_now - N_init) / N_init,
                    (E_now - E_init) / max(abs(E_init), 1e-12))
            end
        end,
    )
    elapsed = time() - t_start
    @printf("\nWall: %.1fs (%.1f ms/step). History: %d snapshots\n",
        elapsed, 1000 * elapsed / N_STEPS, length(history))

    # Final diagnostics
    rho_dev, kappa_dev = tdhfb_hermiticity_check(state)
    final = _mean_density(state)
    k_rms = _mean_kappa(state)
    @printf("\nFinal:\n")
    @printf("  ‖ρ‖ = %.6e,   ‖κ‖ = %.6e\n", norm(state.rho), norm(state.kappa))
    @printf("  ⟨n̄_total⟩ = %.6e,   ⟨n̄_thermal⟩ = %.6e\n",
        final.mean_total, final.mean_thermal)
    @printf("  Depletion ratio ñ/n̄ = %.6e (Lima-Pelster Eu scalar ~ 5e-3)\n",
        final.ratio)
    @printf("  κ RMS per voxel = %.6e\n", k_rms)
    @printf("  Hermiticity dev: ρ=%.2e, κ=%.2e\n", rho_dev, kappa_dev)

    return (
        label = label,
        rho_final = norm(state.rho),
        kappa_final = norm(state.kappa),
        depletion_ratio = final.ratio,
        kappa_rms = k_rms,
        rho_dev = rho_dev,
        kappa_dev = kappa_dev,
        elapsed = elapsed,
    )
end

@printf("=== TDHFB Eu (F=6) post-quench production (Phase 6 deliverable) ===\n")
@printf("Total simulation: T = %.3f ω⁻¹ at dt = %.4f (N_steps = %d)\n",
    T_TOTAL, DT, N_STEPS)
@printf("Save snapshots every %d steps (= %.3f ω⁻¹ cadence)\n",
    SAVE_EVERY, SAVE_EVERY * DT)
@printf("Note: T_total kept short (< 1 ω⁻¹) to stay in the regime where\n")
@printf("TDHFB Strang energy drift is bounded (per 2026-05-12 finding).\n")

result_scalar = _run("A: Eu scalar baseline (g_S all = 1)", G_S_SCALAR)
result_tilted = _run("B: Eu tilted (g_0=0.9 ... g_12=1.1, asymmetric)", G_S_TILTED)

@printf("\n%s\n=== Summary ===\n%s\n", "="^72, "="^72)
@printf("%-40s  %-12s  %-12s  %-12s\n",
    "regime", "ñ/n̄", "|κ|_rms", "‖ρ‖")
for r in (result_scalar, result_tilted)
    @printf("%-40s  %-12.4e  %-12.4e  %-12.4e\n",
        r.label, r.depletion_ratio, r.kappa_rms, r.rho_final)
end

@printf("\nLima-Pelster scalar prediction for ¹⁵¹Eu: ñ/n̄ ~ (na³)^{1/2} ~ 5×10⁻³\n")
@printf("Observed ratio in the simulation timescale reflects the *transient*\n")
@printf("buildup, not the equilibrium depletion. Long-T steady-state is\n")
@printf("blocked on Phase 4 Y4-mid palindrome substep + thermal initial state.\n")
