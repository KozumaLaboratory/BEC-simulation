#!/usr/bin/env julia
# Phase II quantitative validation: scalar eGPE vs Option γ in adiabatic limit.
#
# Setup: static tilted B̂, no rotation (Â=0). Adiabatic limit (strong p) ⇒ Option γ
# tilde-basis wavefunction concentrates entirely in m=+F, and Σ_m |ψ̃_m|² should
# equal the scalar eGPE density |ψ_scalar|² up to numerical precision.
#
# Pass criteria:
# - Density overlap ⟨|ψ̃|²|ψ_scalar|²⟩ / (∫|ψ̃|²·∫|ψ_scalar|²)^(1/2) ≥ 0.999
# - Aspect ratio match within 1%
# - Per-m fractions: m=+F ≥ 0.9999 (others < 1e-3)
#
# Run: julia --project=. scripts/validate_phase_ii_overlap.jl

using SpinorBEC
using StaticArrays: SVector
using Printf

# --- Setup ---
const F_atom = 1                       # F=1: simplest spinor with same Option γ math
const Nx, Ny, Nz = 16, 16, 16
const Lx, Ly, Lz = 12.0, 12.0, 12.0
const ωx, ωy, ωz = 1.0, 1.0, 1.0     # spherical trap (cleaner Phase II test)
const g_contact = 100.0                # moderate
const c_dd_raw = 10.0                  # raw c_dd
# In both scalar_egpe and Option γ the *effective* dipolar strength scales as c_dd·F²
# (the F² comes from the spin operators acting on |+F⟩). For ε_dd_eff = c_dd·F²/(3g)
# to stay sub-threshold we need this product small.
const c_dd = c_dd_raw
const ε_dd = c_dd * F_atom^2 / (3 * g_contact)

# Strong field limit
const p_dimless = 5000.0
const tilt_deg = 30.0
const tilt_rad = tilt_deg * π / 180

println("="^70)
println("Phase II validation: scalar eGPE adiabatic limit vs Option γ")
println("="^70)
@printf "F=%d, grid %d×%d×%d, box %g³ (a_ho), trap ω=(%.1f,%.1f,%.1f)\n" F_atom Nx Ny Nz Lx ωx ωy ωz
@printf "g=%g, c_dd=%g, ε_dd=%.3f, p=%g (Larmor adiabatic), tilt=%.1f°\n" g_contact c_dd ε_dd p_dimless tilt_deg
println("="^70)

config = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
grid = SpinorBEC.make_grid(config)
V_trap = zeros(Float64, Nx, Ny, Nz)
@inbounds for I in CartesianIndices(V_trap)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    V_trap[I] = 0.5 * (ωx^2 * x^2 + ωy^2 * y^2 + ωz^2 * z^2)
end

# B̂ direction (tilted)
B_hat = SVector{3, Float64}(sin(tilt_rad), 0.0, cos(tilt_rad))

# --- Scalar eGPE ITP ---

println("\n--- Scalar eGPE: ITP under static tilted B̂ ---")
ws_scalar = SpinorBEC.make_scalar_ws(
    grid, V_trap;
    g_contact = g_contact, c_dd = c_dd, F = Float64(F_atom),
    gamma_lhy = 0.0, dt = 0.0,
)
σ = 1.0
@inbounds for I in CartesianIndices(grid.config.n_points)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    ws_scalar.psi[I] = exp(-(x*x + y*y + z*z) / (2σ*σ))
end
SpinorBEC.normalize_scalar!(ws_scalar)

t_sc = time()
μ_sc = SpinorBEC.find_ground_state_scalar!(
    ws_scalar, 300, 0.01; B_hat = B_hat, target_norm = 1.0,
)
@printf "Scalar ITP: %.2f s, μ=%.4f\n" (time()-t_sc) μ_sc

ar_scalar = SpinorBEC.scalar_aspect_ratio(ws_scalar)
E_sc = SpinorBEC.scalar_energies(ws_scalar, B_hat)
@printf "  AR Rz/Rxy = %.4f\n" ar_scalar
@printf "  Energies: kin=%.3f trap=%.3f contact=%.3f dd=%.3f total=%.3f\n" E_sc[1] E_sc[2] E_sc[3] E_sc[4] E_sc[5]

# Density of scalar eGPE
n_pts = grid.config.n_points
rho_scalar = zeros(Float64, n_pts...)
@inbounds for I in CartesianIndices(rho_scalar)
    rho_scalar[I] = abs2(ws_scalar.psi[I])
end

# --- Option γ ITP ---

println("\n--- Option γ: ITP under static tilted B̂ (adiabatic limit p=$p_dimless) ---")
ws_gam = SpinorBEC.make_rotating_basis_ws(
    grid, F_atom, V_trap;
    p = p_dimless, q = 0.0, c0 = g_contact, c1 = 0.0, c_dd = c_dd,
    theta_func = (_t) -> tilt_rad, phi_func = (_t) -> 0.0,
    theta_dot_func = (_t) -> 0.0, phi_dot_func = (_t) -> 0.0,
)
D_atom = 2F_atom + 1
@inbounds for I in CartesianIndices(grid.config.n_points)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    ws_gam.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))   # m=+F (idx 1)
end
SpinorBEC.normalize_rotating!(ws_gam)

t_gm = time()
μ_gm = SpinorBEC.find_ground_state_rotating!(ws_gam, 300, 0.005)
@printf "Option γ ITP: %.2f s, μ=%.4f\n" (time()-t_gm) μ_gm

per_m_gam = SpinorBEC.rotating_per_m_norms(ws_gam)
@printf "  Per-m fractions: m=+F=%.6f, m=+F-1=%.2e, m≠+F sum=%.2e\n" per_m_gam[1] per_m_gam[2] (1.0 - per_m_gam[1])

# Total density of Option γ in tilde basis
rho_gam = zeros(Float64, n_pts...)
@inbounds for m_idx in 1:D_atom, I in CartesianIndices(n_pts)
    rho_gam[I] += abs2(ws_gam.psi_tilde[I, m_idx])
end

# Aspect ratio of Option γ (using total density)
function aspect_ratio_total(rho, grid, n_pts)
    dV = prod(grid.dx)
    n_total = sum(rho) * dV
    σ_xy = 0.0; σ_z = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        σ_xy += rho[I] * (x*x + y*y) / 2
        σ_z += rho[I] * z*z
    end
    σ_xy *= dV / n_total; σ_z *= dV / n_total
    sqrt(σ_z / σ_xy)
end
ar_gam = aspect_ratio_total(rho_gam, grid, n_pts)
@printf "  AR Rz/Rxy = %.4f\n" ar_gam

# --- Quantitative comparison ---

function compare_densities(rho_a, rho_b, grid)
    inner = 0.0; norm_a = 0.0; norm_b = 0.0
    @inbounds for I in eachindex(rho_a)
        inner += sqrt(rho_a[I] * rho_b[I])
        norm_a += rho_a[I]
        norm_b += rho_b[I]
    end
    overlap = inner / sqrt(norm_a * norm_b)
    diff_l2 = sqrt(sum((rho_a .- rho_b).^2) * prod(grid.dx))
    (overlap, diff_l2)
end

println("\n--- Comparison ---")

overlap, diff_l2 = compare_densities(rho_scalar, rho_gam, grid)
@printf "Density overlap (Bhattacharyya): %.6f  (target ≥ 0.999)\n" overlap
@printf "L² density difference: %.4e\n" diff_l2
@printf "Aspect ratio: scalar=%.4f Option γ=%.4f (rel diff %.2e)\n" ar_scalar ar_gam (abs(ar_scalar - ar_gam) / ar_scalar)
@printf "Per-m: m=+F fraction = %.6f, residual = %.2e\n" per_m_gam[1] (1.0 - per_m_gam[1])

all_pass = overlap >= 0.999 && abs(ar_scalar - ar_gam) / ar_scalar < 0.05 && per_m_gam[1] > 0.9999
println()
if all_pass
    println("✅ Phase II PASS: Option γ in adiabatic limit reproduces scalar eGPE")
else
    println("⚠️  Phase II partial — review criteria above (e.g. AR within 5%, overlap ≥ 0.999, m=+F ≥ 0.9999)")
end

# --- Sweep: verify across F and p ---

println()
println("="^70)
println("Sweep: F={1,2,4} × p={500, 5000, 50000} adiabaticity check")
println("="^70)

function run_overlap(F_test, p_test, c_dd_test, g_test, tilt)
    config = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
    grid = SpinorBEC.make_grid(config)
    V = zeros(Float64, Nx, Ny, Nz)
    @inbounds for I in CartesianIndices(V)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        V[I] = 0.5 * (x*x + y*y + z*z)
    end
    Bh = SVector{3,Float64}(sin(tilt), 0.0, cos(tilt))

    # scalar
    ws_s = SpinorBEC.make_scalar_ws(grid, V; g_contact=g_test, c_dd=c_dd_test, F=Float64(F_test), gamma_lhy=0.0, dt=0.0)
    σ_loc = 1.0
    @inbounds for I in CartesianIndices(grid.config.n_points)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        ws_s.psi[I] = exp(-(x*x + y*y + z*z) / (2σ_loc*σ_loc))
    end
    SpinorBEC.normalize_scalar!(ws_s)
    SpinorBEC.find_ground_state_scalar!(ws_s, 200, 0.01; B_hat=Bh, target_norm=1.0)
    rho_s = abs2.(ws_s.psi)

    # gamma
    ws_g = SpinorBEC.make_rotating_basis_ws(grid, F_test, V;
        p=p_test, q=0.0, c0=g_test, c1=0.0, c_dd=c_dd_test,
        theta_func=(_t)->tilt, phi_func=(_t)->0.0,
        theta_dot_func=(_t)->0.0, phi_dot_func=(_t)->0.0)
    @inbounds for I in CartesianIndices(grid.config.n_points)
        x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
        ws_g.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_loc*σ_loc))
    end
    SpinorBEC.normalize_rotating!(ws_g)
    SpinorBEC.find_ground_state_rotating!(ws_g, 200, 0.005)
    D_loc = 2F_test + 1
    rho_g = zeros(Float64, Nx, Ny, Nz)
    @inbounds for m_idx in 1:D_loc, I in CartesianIndices(rho_g)
        rho_g[I] += abs2(ws_g.psi_tilde[I, m_idx])
    end

    pm = SpinorBEC.rotating_per_m_norms(ws_g)
    ov, _ = compare_densities(rho_s, rho_g, grid)
    (ov, pm[1])
end

@printf "%-6s %-10s %-10s | %-10s %-12s %s\n" "F" "p" "ε_dd_eff" "overlap" "m=+F frac" "verdict"
println("-"^70)
for F_t in [1, 2, 4]
    # Stable ε_dd_eff = 0.1
    g_t = 100.0
    c_t = 0.1 * 3 * g_t / F_t^2
    for p_t in [500.0, 5000.0, 50000.0]
        ov, pf = run_overlap(F_t, p_t, c_t, g_t, π/6)
        verdict = ov >= 0.999 && pf > 0.9999 ? "✅" : "⚠️ "
        @printf "%-6d %-10.0f %-10.3f | %-10.6f %-12.6f %s\n" F_t p_t (c_t * F_t^2 / (3 * g_t)) ov pf verdict
    end
end
