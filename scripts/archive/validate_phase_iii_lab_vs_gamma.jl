#!/usr/bin/env julia
# Phase III: Option γ vs lab-frame at the same trap-scale dt.
#
# Both solvers are eigen-exact in their respective spin steps:
#   - Option γ: H_tilde = -p F_z + q F_z² - Â(t)
#   - Lab    : H_lab(t) = -p F·B̂(t) + q (F·B̂(t))²
#
# Lab-frame state ψ_lab is related to Option γ ψ̃ via ψ_lab = Û_B(t) ψ̃.
# After equal-dt evolution, ψ̃(T) and ψ_lab(T) must satisfy:
#   ψ_lab(T) ≈ Û_B(T) · ψ̃(T)   up to dt² Strang error from non-spin operators
#                               (both solvers have the same Strang error structure
#                                since they share kinetic/diagonal/DDI machinery).
#
# Pass criteria (loose, since Strang error is not zero):
#   density overlap > 0.99 between Σ_m |ψ̃_m|² and Σ_m |ψ_lab_m|²

using SpinorBEC
using StaticArrays: SVector
using Printf

println("="^70)
println("Phase III: Option γ vs lab-frame at trap-scale dt")
println("="^70)

# Setup: F=2, moderate p (where lab-frame is still tractable)
const Nx, Ny, Nz = 12, 12, 12
const Lx, Ly, Lz = 10.0, 10.0, 10.0
const F_test = 2
const D_test = 2F_test + 1
const g_t = 80.0
const c_t = 0.05 * 3 * g_t / F_test^2     # ε_dd_eff = 0.05
const p_t = 30.0                            # moderate Larmor
const tilt = π/6
const omega_rot = 2.0                       # moderate rotation rate

@printf "F=%d, grid %d×%d×%d, box %g×%g×%g, p=%g, ε_dd_eff=%.3f, tilt=%.1f°, ω_rot=%g\n" F_test Nx Ny Nz Lx Ly Lz p_t (c_t * F_test^2 / (3 * g_t)) (tilt * 180/π) omega_rot

config = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
grid = SpinorBEC.make_grid(config)
V = zeros(Float64, Nx, Ny, Nz)
@inbounds for I in CartesianIndices(V)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    V[I] = 0.5 * (x*x + y*y + z*z)
end

# B̂(t): tilt + uniform rotation around z
theta_f(t::Float64) = tilt
phi_f(t::Float64)   = omega_rot * t
theta_dot_f(t::Float64) = 0.0
phi_dot_f(t::Float64)   = omega_rot

# --- Build Option γ workspace ---
# gauge_fix=false: keep the F_z component of Â in the tilde-basis Hamiltonian so
# the conversion ψ_lab(T) = Û_B(T) ψ̃(T) holds without a residual χ-phase.
ws_g = SpinorBEC.make_rotating_basis_ws(
    grid, F_test, V;
    p = p_t, q = 0.0, c0 = g_t, c1 = 0.0, c_dd = c_t,
    theta_func = theta_f, phi_func = phi_f,
    theta_dot_func = theta_dot_f, phi_dot_func = phi_dot_f,
    gauge_fix = false,
)

# Initial state in m=+F (tilde basis, polarized along B̂(0))
σ = 1.0
@inbounds for I in CartesianIndices(grid.config.n_points)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    ws_g.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ*σ))
end
SpinorBEC.normalize_rotating!(ws_g)

# --- Build lab-basis workspace (initial state = Û_B(0) ψ̃(0)) ---
ws_l = SpinorBEC.make_rotating_basis_ws(
    grid, F_test, V;
    p = p_t, q = 0.0, c0 = g_t, c1 = 0.0, c_dd = c_t,
    theta_func = theta_f, phi_func = phi_f,
    theta_dot_func = theta_dot_f, phi_dot_func = phi_dot_f,
)
copyto!(ws_l.psi_tilde, ws_g.psi_tilde)
# Apply Û_B(0): tilde → lab. φ(0) = 0, θ(0) = tilt
SpinorBEC._apply_UB!(ws_l.psi_tilde, ws_l.spin_matrices, tilt, 0.0, 3; inverse=false)

println()
@printf "Initial norms: γ=%.6f lab=%.6f\n" SpinorBEC.rotating_norm(ws_g) SpinorBEC.rotating_norm(ws_l)

# --- Evolve both at the same dt ---
const dt = 0.01
const n_steps = 200       # 2 dimless time units
const T_final = n_steps * dt

println()
@printf "Evolving for %.2f dimless time (n_steps=%d, dt=%g)...\n" T_final n_steps dt

# Option γ
t1 = time()
SpinorBEC.evolve_rotating!(ws_g, n_steps, dt; t0=0.0)
println("  Option γ: ", round(time() - t1; digits=2), " s")

# Lab
t2 = time()
SpinorBEC.evolve_lab!(ws_l, n_steps, dt; t0=0.0)
println("  Lab     : ", round(time() - t2; digits=2), " s")

@printf "Final norms: γ=%.6f lab=%.6f\n" SpinorBEC.rotating_norm(ws_g) SpinorBEC.rotating_norm(ws_l)

# --- Convert ψ̃(T) → predicted ψ_lab(T) ---
psi_g_in_lab = copy(ws_g.psi_tilde)
SpinorBEC._apply_UB!(psi_g_in_lab, ws_g.spin_matrices, theta_f(T_final), phi_f(T_final), 3; inverse=false)

# --- Compare densities (Σ_m |ψ_m|²) ---
function total_density(psi)
    rho = zeros(Float64, size(psi, 1), size(psi, 2), size(psi, 3))
    @inbounds for m_idx in 1:size(psi, 4), I in CartesianIndices(rho)
        rho[I] += abs2(psi[I, m_idx])
    end
    rho
end

rho_g = total_density(psi_g_in_lab)
rho_l = total_density(ws_l.psi_tilde)

inner_g = sum(@. sqrt(rho_g * rho_l))
norm_a = sum(rho_g); norm_b = sum(rho_l)
overlap = inner_g / sqrt(norm_a * norm_b)

# --- Per-m comparison in lab basis ---
function per_m_lab(psi)
    D = size(psi, 4)
    out = zeros(Float64, D)
    @inbounds for m_idx in 1:D, I in CartesianIndices(@view psi[:, :, :, m_idx])
        out[m_idx] += abs2(psi[I, m_idx])
    end
    out * prod(grid.dx)
end
pm_g_lab = per_m_lab(psi_g_in_lab)
pm_l = per_m_lab(ws_l.psi_tilde)

println()
println("--- Comparison (lab frame) ---")
@printf "Density overlap (Σ_m |ψ_m|²): %.6f\n" overlap
println("Per-m fractions (γ→lab):  ", round.(pm_g_lab; digits=4))
println("Per-m fractions (lab):    ", round.(pm_l; digits=4))
@printf "L² state difference:      %.4e\n" sqrt(sum(abs2.(psi_g_in_lab .- ws_l.psi_tilde)) * prod(grid.dx))

# Coherent overlap |⟨ψ_lab| Û_B ψ̃⟩| (true wavefunction overlap)
@inline conj_dot(a, b) = sum(@. conj(a) * b) * prod(grid.dx)
coherent = conj_dot(ws_l.psi_tilde, psi_g_in_lab)
@printf "Coherent overlap |⟨ψ_lab|Û_Bψ̃⟩|: %.6f  (target ≥ 0.99 at dt=%.3g)\n" abs(coherent) dt

println()
if overlap > 0.99 && abs(coherent) > 0.99
    println("✅ Phase III PASS: Option γ matches lab-frame at trap-scale dt")
elseif overlap > 0.95
    println("⚠️  Phase III partial: density overlap > 0.95 (Strang error visible at this dt)")
else
    println("❌ Phase III FAIL: large discrepancy — investigate")
end

# --- dt convergence sweep ---

println()
println("="^70)
println("dt convergence sweep (T_final = 1.0 dimless, F=2, p=20)")
println("="^70)

function sweep_dt(dt_val)
    n_steps = Int(round(1.0 / dt_val))
    config2 = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
    grid2 = SpinorBEC.make_grid(config2)
    V2 = zeros(Float64, Nx, Ny, Nz)
    @inbounds for I in CartesianIndices(V2)
        x = grid2.x[1][I[1]]; y = grid2.x[2][I[2]]; z = grid2.x[3][I[3]]
        V2[I] = 0.5 * (x*x + y*y + z*z)
    end

    ws_g2 = SpinorBEC.make_rotating_basis_ws(grid2, F_test, V2;
        p=20.0, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
        theta_func=theta_f, phi_func=phi_f,
        theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f,
        gauge_fix=false)
    σ_loc = 1.0
    @inbounds for I in CartesianIndices(grid2.config.n_points)
        x = grid2.x[1][I[1]]; y = grid2.x[2][I[2]]; z = grid2.x[3][I[3]]
        ws_g2.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_loc*σ_loc))
    end
    SpinorBEC.normalize_rotating!(ws_g2)

    ws_l2 = SpinorBEC.make_rotating_basis_ws(grid2, F_test, V2;
        p=20.0, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
        theta_func=theta_f, phi_func=phi_f,
        theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f)
    copyto!(ws_l2.psi_tilde, ws_g2.psi_tilde)
    SpinorBEC._apply_UB!(ws_l2.psi_tilde, ws_l2.spin_matrices, tilt, 0.0, 3; inverse=false)

    SpinorBEC.evolve_rotating!(ws_g2, n_steps, dt_val)
    SpinorBEC.evolve_lab!(ws_l2, n_steps, dt_val)

    psi_g_lab = copy(ws_g2.psi_tilde)
    SpinorBEC._apply_UB!(psi_g_lab, ws_g2.spin_matrices, theta_f(1.0), phi_f(1.0), 3; inverse=false)

    coh = abs(sum(@. conj(ws_l2.psi_tilde) * psi_g_lab) * prod(grid2.dx))
    rg = total_density(psi_g_lab); rl = total_density(ws_l2.psi_tilde)
    ov = sum(@. sqrt(rg * rl)) / sqrt(sum(rg) * sum(rl))
    (coh, ov)
end

@printf "%-10s %-15s %-15s\n" "dt" "coherent_overlap" "density_overlap"
println("-"^50)
for dt_val in [0.04, 0.02, 0.01, 0.005, 0.0025]
    coh, ov = sweep_dt(dt_val)
    @printf "%-10g %-15.6f %-15.6f\n" dt_val coh ov
end

println()
println("="^70)
println("Klaus regime sweep: p={100, 1000, 28428} at dt=0.005, T=1.0")
println("("*"the full Klaus Larmor p=28428 with eigen-exact spin step on both sides"*")")
println("="^70)

function klaus_sweep(p_val)
    config_k = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
    grid_k = SpinorBEC.make_grid(config_k)
    V_k = zeros(Float64, Nx, Ny, Nz)
    @inbounds for I in CartesianIndices(V_k)
        x = grid_k.x[1][I[1]]; y = grid_k.x[2][I[2]]; z = grid_k.x[3][I[3]]
        V_k[I] = 0.5 * (x*x + y*y + z*z)
    end

    ws_g3 = SpinorBEC.make_rotating_basis_ws(grid_k, F_test, V_k;
        p=p_val, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
        theta_func=theta_f, phi_func=phi_f,
        theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f,
        gauge_fix=false)
    σ_loc = 1.0
    @inbounds for I in CartesianIndices(grid_k.config.n_points)
        x = grid_k.x[1][I[1]]; y = grid_k.x[2][I[2]]; z = grid_k.x[3][I[3]]
        ws_g3.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / (2σ_loc*σ_loc))
    end
    SpinorBEC.normalize_rotating!(ws_g3)

    ws_l3 = SpinorBEC.make_rotating_basis_ws(grid_k, F_test, V_k;
        p=p_val, q=0.0, c0=g_t, c1=0.0, c_dd=c_t,
        theta_func=theta_f, phi_func=phi_f,
        theta_dot_func=theta_dot_f, phi_dot_func=phi_dot_f,
        gauge_fix=false)
    copyto!(ws_l3.psi_tilde, ws_g3.psi_tilde)
    SpinorBEC._apply_UB!(ws_l3.psi_tilde, ws_l3.spin_matrices, tilt, 0.0, 3; inverse=false)

    n_steps_k = 200
    dt_k = 0.005

    t1 = time(); SpinorBEC.evolve_rotating!(ws_g3, n_steps_k, dt_k); tg = time() - t1
    t1 = time(); SpinorBEC.evolve_lab!(ws_l3, n_steps_k, dt_k); tl = time() - t1

    psi_g_lab = copy(ws_g3.psi_tilde)
    SpinorBEC._apply_UB!(psi_g_lab, ws_g3.spin_matrices,
        theta_f(n_steps_k * dt_k), phi_f(n_steps_k * dt_k), 3; inverse=false)

    coh = abs(sum(@. conj(ws_l3.psi_tilde) * psi_g_lab) * prod(grid_k.dx))
    rg = total_density(psi_g_lab); rl = total_density(ws_l3.psi_tilde)
    ov = sum(@. sqrt(rg * rl)) / sqrt(sum(rg) * sum(rl))
    (coh, ov, tg, tl)
end

@printf "%-10s %-15s %-15s %-10s %-10s\n" "p" "coherent" "density_ov" "γ_time" "lab_time"
println("-"^65)
for p_val in [100.0, 1000.0, 28428.0]
    coh, ov, tg, tl = klaus_sweep(p_val)
    @printf "%-10g %-15.6f %-15.6f %-10.2f %-10.2f\n" p_val coh ov tg tl
end
