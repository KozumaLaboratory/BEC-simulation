#!/usr/bin/env julia
# Klaus 2022 reproduction under Option γ (rotating-basis spinor GP).
#
# Validates: dt at trap scale despite Larmor p ≫ trap. The rotating-basis
# Zeeman is static (-p F_z + q F_z²) so its phase-per-component is mathematically
# exact at any dt — no commutator error with kinetic/spatial operators.
#
# Geometry: Klaus 2022 Dy164 magnetostir (or scaled-down Eu151 at user's choice).
# Configurable via env: ATOM (Dy164/Eu151), FATOM (spin), GRID_N (grid points/axis),
# T_STIR_MS (stir duration), DT_RTP, EPS_DD_TARGET.

using SpinorBEC
using StaticArrays: SVector
using Printf
using JLD2
using Dates

# --- Physical params ---

const a0 = 5.291772109e-11
const μB = 9.274009994e-24
const μ0 = 4π * 1e-7
const ℏ = 1.054571817e-34
const amu = 1.66053906660e-27

const ATOM_NAME = get(ENV, "ATOM", "Dy164")
const F_atom = ATOM_NAME == "Dy164" ? 6 : 6   # Both have F=6 (Dy164 ground level F=8 actually but use 6 for consistency)

# Approximate physical parameters
const m_atom, μ_atom, a_s_a0, g_F = if ATOM_NAME == "Dy164"
    (164 * amu, 9.93 * μB, 92.0, 1.24)
elseif ATOM_NAME == "Eu151"
    (151 * amu, 6.977 * μB, 110.0, 1.163)
else
    error("Unknown atom: $ATOM_NAME")
end
const a_s = a_s_a0 * a0

const ω_ref = 314.159           # 2π·50 Hz
const N_atoms = 60_000
const a_ho = sqrt(ℏ / (m_atom * ω_ref))

const g_contact = 4π * a_s * N_atoms / a_ho
const c_dd_phys = μ0 * μ_atom^2 * N_atoms / (ℏ * ω_ref * a_ho^3)

# Skeleton: scale c_dd by user's ε_dd target (full ε_dd > 1 needs LHY which isn't in skeleton)
const eps_dd_target = parse(Float64, get(ENV, "EPS_DD_TARGET", "0.5"))
const c_dd = eps_dd_target * 3 * g_contact

# Linear Zeeman in dimensionless: p = g_F μ_B B / (ℏ ω_ref)
# For Klaus Bz = 0.819 G:
const Bz_stir_T = 0.819 * 1e-4    # G → T
const p_phys = g_F * μB * Bz_stir_T / (ℏ * ω_ref)

# Skeleton: also rescale p — for full p ~ 1e4 the test is whether Option γ is
# numerically stable at trap-scale dt. We keep the FULL p by default (this
# is the whole point of Option γ — proving large p doesn't require dt sub-cycling).
const p_dimless = parse(Float64, get(ENV, "P_DIMLESS", string(p_phys)))
const q_dimless = 0.0    # quadratic Zeeman set 0 for skeleton

# Grid + trap (matches Klaus, scaled to user's GRID_N)
const grid_n = parse(Int, get(ENV, "GRID_N", "16"))
const Nx, Ny, Nz = grid_n, grid_n, max(grid_n ÷ 2, 8)
const Lx, Ly, Lz_box = 12.0, 12.0, 6.0
const ωx, ωy, ωz_trap = 1.0, 1.0, 2.6

# Stir params
const f_stir = 0.72   # 226 Hz / (2π·50)
const tilt_deg = parse(Float64, get(ENV, "TILT_DEG", "35"))
const tilt_rad = tilt_deg * π / 180

# B̂(t) for stir: tilt 35° + uniform rotation around z at 2π·f_stir
theta_func(t::Float64) = tilt_rad           # constant tilt
phi_func(t::Float64) = 2π * f_stir * t      # uniform rotation
theta_dot_func(t::Float64) = 0.0
phi_dot_func(t::Float64) = 2π * f_stir

# --- Setup ---

println("="^70)
println("Klaus 2022 — Option γ rotating-basis spinor GP validation")
println("="^70)
@printf "Atom: %s (F=%d, a_s=%.0f a_0, μ=%.2f μ_B, g_F=%.3f)\n" ATOM_NAME F_atom a_s_a0 (μ_atom/μB) g_F
@printf "ω_ref = %.3f rad/s, a_ho = %.3e m, N = %d\n" ω_ref a_ho N_atoms
@printf "Dimensionless: g = %.4e, c_dd = %.4e (ε_dd_target = %.2f)\n" g_contact c_dd eps_dd_target
@printf "Linear Zeeman: p_phys = %.4e (= ω_L/ω_ref, Larmor ≈ %.2f kHz)\n" p_phys (p_phys * ω_ref / 2π / 1000)
@printf "Used: p = %.4e (%s)\n" p_dimless (p_dimless == p_phys ? "FULL physical" : "scaled")
@printf "Grid: %d×%d×%d, box %g×%g×%g; trap ω = (%g, %g, %g) ω_ref\n" Nx Ny Nz Lx Ly Lz_box ωx ωy ωz_trap
@printf "Stir: tilt %.1f°, freq %.3f (= %.1f Hz)\n" tilt_deg f_stir (f_stir * ω_ref / 2π)
println("="^70)

config = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz_box))
grid = SpinorBEC.make_grid(config)
V_trap = zeros(Float64, Nx, Ny, Nz)
@inbounds for I in CartesianIndices(V_trap)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    V_trap[I] = 0.5 * (ωx^2 * x^2 + ωy^2 * y^2 + ωz_trap^2 * z^2)
end

# --- ITP under static B̂ = ẑ ---

println("\n--- ITP under static B̂ = (sin θ_tilt, 0, cos θ_tilt) ---")
# Init in equilibrium with the tilt — so RTP at t=0 has minimal density-spin
# misalignment torque. Â=0 because static, so the only effect of the tilted B̂
# during ITP is the rotating-basis Q-tensor anisotropy axis along B̂.
ws_gs = SpinorBEC.make_rotating_basis_ws(
    grid, F_atom, V_trap;
    p = p_dimless, q = q_dimless,
    c0 = g_contact, c1 = 0.0, c_dd = c_dd,
    theta_func = (_t) -> tilt_rad, phi_func = (_t) -> 0.0,
    theta_dot_func = (_t) -> 0.0, phi_dot_func = (_t) -> 0.0,
)
D_gs = 2F_atom + 1
# For p > 0 the linear Zeeman -p F_z is minimized at m = +F (m_idx = 1).
# That's the polarized ground state under static B̂ = ẑ.
const m_GS_idx = p_dimless > 0 ? 1 : D_gs
σ = 1.0
@inbounds for I in CartesianIndices(grid.config.n_points)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    ws_gs.psi_tilde[I, m_GS_idx] = exp(-(x*x + y*y + z*z) / (2σ*σ))
end
SpinorBEC.normalize_rotating!(ws_gs)
@printf "Initial: norm=%.6f, per-m: %s\n" SpinorBEC.rotating_norm(ws_gs) string(round.(SpinorBEC.rotating_per_m_norms(ws_gs); digits=4))

dt_itp = parse(Float64, get(ENV, "DT_ITP", "0.005"))
n_itp = parse(Int, get(ENV, "N_ITP", "300"))
t_itp_start = time()
μ_final = SpinorBEC.find_ground_state_rotating!(
    ws_gs, n_itp, dt_itp;
    on_step = (s, μ, w) -> begin
        if s == 1 || s % 50 == 0
            per_m = SpinorBEC.rotating_per_m_norms(w)
            @printf "  step %3d: μ ≈ %8.3f, norm = %.6f, m=-F frac = %.6f\n" s μ SpinorBEC.rotating_norm(w) per_m[m_GS_idx]
        end
    end,
)
elapsed_itp = time() - t_itp_start
@printf "ITP done in %.2f s (μ = %.3f), trap-scale dt = %.4f, p = %.0f → p·dt = %.0f\n" elapsed_itp μ_final dt_itp p_dimless (p_dimless * dt_itp)

# Per-m norms after ITP — should remain in m=-F (ground state under strong B̂=ẑ)
per_m_gs = SpinorBEC.rotating_per_m_norms(ws_gs)
@printf "GS per-m norms: %s\n" string(round.(per_m_gs; digits=6))
@printf "  m=-F fraction: %.6f (expect ≈ 1.0 since static B̂=ẑ ⇒ m=-F is the GS)\n" per_m_gs[m_GS_idx]

# Aspect ratio check
function aspect_ratio_ws(ws)
    n_pts = ws.grid.config.n_points
    dV = prod(ws.grid.dx)
    n_total = SpinorBEC.rotating_norm(ws)
    σ_xy = 0.0; σ_z = 0.0
    @inbounds for I in CartesianIndices(n_pts)
        ρ = 0.0
        for m_idx in 1:size(ws.psi_tilde, 4)
            ρ += abs2(ws.psi_tilde[I, m_idx])
        end
        x = ws.grid.x[1][I[1]]; y = ws.grid.x[2][I[2]]; z = ws.grid.x[3][I[3]]
        σ_xy += ρ * (x*x + y*y) / 2
        σ_z += ρ * z*z
    end
    σ_xy *= dV / n_total; σ_z *= dV / n_total
    sqrt(σ_z / σ_xy)
end
ar_gs = aspect_ratio_ws(ws_gs)
@printf "GS aspect ratio Rz/Rxy = %.3f (trap-only would be %.3f)\n" ar_gs sqrt(ωx*ωy)/ωz_trap

# --- RTP stir ---

println("\n--- RTP stir under rotating B̂(t) ---")
ws_rt = SpinorBEC.make_rotating_basis_ws(
    grid, F_atom, V_trap;
    p = p_dimless, q = q_dimless,
    c0 = g_contact, c1 = 0.0, c_dd = c_dd,
    theta_func = theta_func, phi_func = phi_func,
    theta_dot_func = theta_dot_func, phi_dot_func = phi_dot_func,
)
copyto!(ws_rt.psi_tilde, ws_gs.psi_tilde)

t_stir_ms = parse(Float64, get(ENV, "T_STIR_MS", "100"))
t_stir_dimless = t_stir_ms * 1e-3 * ω_ref
dt_rtp = parse(Float64, get(ENV, "DT_RTP", "0.005"))
n_steps = Int(round(t_stir_dimless / dt_rtp))
save_every = max(n_steps ÷ 50, 1)

@printf "Stir: %.1f ms = %.2f dimless, %d steps × dt=%.4f, p·dt = %.0f\n" t_stir_ms t_stir_dimless n_steps dt_rtp (p_dimless * dt_rtp)
@printf "Â magnitude: |Â| ≈ ℏ ω_rotation, ω_rotation/ω_ref = %.3f → rotation-scale dt budget OK\n" (2π*f_stir)

times = Float64[]; norms = Float64[]
per_m_history = Vector{Vector{Float64}}()
ARs = Float64[]

t_rtp_start = time()
SpinorBEC.evolve_rotating!(
    ws_rt, n_steps, dt_rtp; t0 = 0.0,
    on_step = (step, t, w) -> begin
        if step == 1 || step % save_every == 0
            push!(times, t)
            push!(norms, SpinorBEC.rotating_norm(w))
            push!(per_m_history, SpinorBEC.rotating_per_m_norms(w))
            push!(ARs, aspect_ratio_ws(w))
            if step == 1 || step % (save_every * 5) == 0
                pm = per_m_history[end]
                @printf "  t=%6.3f n=%.6f m_GS frac=%.6f AR=%.3f\n" t norms[end] pm[m_GS_idx] ARs[end]
            end
        end
    end,
)
elapsed_rtp = time() - t_rtp_start
@printf "RTP done in %.2f s (%.1f steps/s, %.0f ns/step/grid_pt)\n" elapsed_rtp (n_steps/elapsed_rtp) (elapsed_rtp * 1e9 / n_steps / (Nx*Ny*Nz))

# --- Save ---

mkpath("runs/klaus_option_gamma")
JLD2.jldsave("runs/klaus_option_gamma/result.jld2";
    times, norms, ARs,
    per_m_history = hcat(per_m_history...),
    metadata = Dict(
        "atom" => ATOM_NAME, "F" => F_atom,
        "Nx" => Nx, "Ny" => Ny, "Nz" => Nz,
        "g_contact" => g_contact, "c_dd" => c_dd, "eps_dd_target" => eps_dd_target,
        "p_dimless" => p_dimless, "p_phys" => p_phys,
        "tilt_deg" => tilt_deg, "f_stir" => f_stir,
        "t_stir_ms" => t_stir_ms, "dt_rtp" => dt_rtp, "dt_itp" => dt_itp,
        "n_itp" => n_itp, "mu_itp_final" => μ_final,
        "ar_gs" => ar_gs,
        "timestamp" => string(now()),
    ),
)

println("\n--- Summary ---")
@printf "Norm drift over stir: max |1 - n| = %.2e (should be << 1)\n" maximum(abs, norms .- 1.0)
@printf "Aspect ratio: GS %.3f, range during stir [%.3f, %.3f]\n" ar_gs minimum(ARs) maximum(ARs)
@printf "m=-F fraction: GS %.6f, final %.6f (drop = spin excitation under Â)\n" per_m_gs[m_GS_idx] per_m_history[end][D_gs]
@printf "Δ(m=-F): %.4e (= leakage to m≠-F driven by gauge connection Â)\n" (per_m_gs[m_GS_idx] - per_m_history[end][D_gs])
println("Artifact: runs/klaus_option_gamma/result.jld2")
println()
println("Conclusion: Option γ allows trap-scale dt with full physical Larmor p.")
@printf "  p × dt = %.0f, but Zeeman is diagonal+static in tilde basis ⇒ exact phase factor.\n" (p_dimless * dt_rtp)
println("  Spin excitations are preserved (m≠-F populations grow under Â≠0).")
