#!/usr/bin/env julia
# Klaus 2022 validation under scalar eGPE (adiabatic spin elimination).
#
# Geometry from runs/klaus2022_full/config.yaml (Dy164 magnetostir):
#   - pancake trap ω = (1, 1, 2.6) ω_ref, ω_ref = 2π·50 Hz
#   - initial Bz = 1 G (z-polarized GS)
#   - magnetostir at 226 Hz, |B_⊥| = 0.574 G with Bz = 0.819 G
#   - field tilt during stir: θ ≈ atan(0.574 / 0.819) ≈ 35°
#
# Smoke run: 32×32×16 grid, ITP for GS, then 200 ms stir; reports L_z(t),
# COM(t), and saves three density slices (start / mid / end). If physics
# stands up, scale to 64³ × 1 s.

using SpinorBEC
using StaticArrays: SVector
using Printf
using JLD2
using Dates

# --- Physical params (Dy164, Klaus 2022) ---------------------------------

const a0 = 5.291772109e-11        # Bohr radius (m)
const μB = 9.274009994e-24        # Bohr magneton (J/T)
const μ0 = 4π * 1e-7              # vacuum permeability (T·m/A)
const ℏ = 1.054571817e-34
const amu = 1.66053906660e-27
const m_Dy164 = 164 * amu
const μ_Dy = 9.93 * μB             # Dy164 magnetic moment

const ω_ref = 314.159              # rad/s = 2π·50 Hz
const N_atoms = 60_000
const a_s_a0 = 92.0                # scattering length in Bohr radii
const a_s = a_s_a0 * a0
const a_ho = sqrt(ℏ / (m_Dy164 * ω_ref))   # ω_ref oscillator length

# Dimensionless contact: g = 4π a_s N / a_ho (standard scalar GPE convention)
const g_contact = 4π * a_s * N_atoms / a_ho

# Dimensionless dipolar: c_dd = μ₀ μ² N / (a_ho³ · ℏ ω_ref)
# (note: SpinorBEC's DDI does NOT include 4π — same convention here)
const c_dd_phys = μ0 * μ_Dy^2 * N_atoms / (ℏ * ω_ref * a_ho^3)
# F² factor for full polarization: total dipolar coupling per atom is μ²
# regardless of F, so the F² in scalar_egpe absorbs the |⟨B̂|F|B̂⟩|² = F² for
# the |m=-F⟩ (or |m=+F⟩) polarized state. We set F=1 here and roll the
# physical magnitude into c_dd_phys to keep both bookkeeping schemes identical.
const F_factor = 1.0

# Skeleton-grade DDI scaling: ε_dd_target controls ε_dd = c_dd / (3 g) for
# the run. Klaus regime ε_dd > 1 needs LHY stabilization (not yet in this
# skeleton); skeleton sweep targets ε_dd ≈ 0.5 to keep mean-field bounded.
const eps_dd_target = parse(Float64, get(ENV, "EPS_DD", "0.5"))
const c_dd = eps_dd_target * 3 * g_contact

# Grid (smoke: half resolution from full Klaus)
const Nx = 32; const Ny = 32; const Nz = 16
const Lx = 20.0; const Ly = 20.0; const Lz = 8.0

# Trap (anisotropic, pancake)
const ωx = 1.0; const ωy = 1.0; const ωz = 2.6

# Magnetic field during stir (in Gauss → dimensionless via μ_Dy and ω_ref)
const Bz_stir = 0.819              # Gauss
const B⊥_stir = 0.574              # Gauss
const f_stir_yaml = 0.72            # = 226 Hz / (2π·50 Hz·rad/s)

# B̂(t) = B(t)/|B(t)| where B(t) = (Bx(t), By(t), Bz_stir)
function B_hat_stir(t::Float64)
    ω = 2π * f_stir_yaml
    bx = B⊥_stir * sin(ω * t)
    by = -B⊥_stir * cos(ω * t)         # phase = -π/2 → circular
    bz = Bz_stir
    bnorm = sqrt(bx^2 + by^2 + bz^2)
    SVector{3, Float64}(bx / bnorm, by / bnorm, bz / bnorm)
end

# --- Build workspace ------------------------------------------------------

println("="^70)
println("Klaus 2022 scalar eGPE validation (skeleton)")
println("="^70)
@printf "Atom: Dy164 (a_s=%.0f a_0, μ=%.2f μ_B, m=%g amu)\n" a_s_a0 9.93 164.0
@printf "ω_ref = %.3f rad/s = 2π·%.1f Hz, a_ho = %.3e m\n" ω_ref (ω_ref/(2π)) a_ho
@printf "N_atoms = %d\n" N_atoms
@printf "Dimensionless g_contact = %.4e, c_dd_phys = %.4e (Dy164 raw)\n" g_contact c_dd_phys
@printf "Skeleton run: c_dd = %.4e (ε_dd_target = %.2f, no LHY)\n" c_dd eps_dd_target
@printf "ε_dd = c_dd / (3·g) = %.3f\n" (c_dd / (3 * g_contact))
@printf "Grid: %d×%d×%d, box %g×%g×%g (a_ho)\n" Nx Ny Nz Lx Ly Lz
@printf "Trap: ω = (%g, %g, %g) ω_ref\n" ωx ωy ωz
println("="^70)

config = GridConfig((Nx, Ny, Nz), (Lx, Ly, Lz))
grid = SpinorBEC.make_grid(config)

# Anisotropic harmonic trap V = ½ (ωx² x² + ωy² y² + ωz² z²)
V_trap = zeros(Float64, Nx, Ny, Nz)
@inbounds for I in CartesianIndices(V_trap)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    V_trap[I] = 0.5 * (ωx^2 * x^2 + ωy^2 * y^2 + ωz^2 * z^2)
end

ws = SpinorBEC.make_scalar_ws(
    grid, V_trap;
    g_contact = g_contact,
    c_dd = c_dd,
    F = F_factor,
    gamma_lhy = 0.0,
    dt = 0.0,
)

# --- Initial state: TF ansatz for anisotropic harmonic trap with contact only ---

# TF radii (scalar, no DDI correction): use μ_TF estimated from g
# n0 = (μ - V) / g, ∫n0 = 1 → μ = (15 g / (8π) · ωx ωy ωz)^(2/5) (3D)
μ_TF = (15 * g_contact * sqrt(ωx * ωy * ωz) / (8π))^(2/5)
@printf "μ_TF = %.3f, R_x = %.3f, R_y = %.3f, R_z = %.3f\n" μ_TF sqrt(2μ_TF/ωx^2) sqrt(2μ_TF/ωy^2) sqrt(2μ_TF/ωz^2)

@inbounds for I in CartesianIndices(ws.psi)
    x = grid.x[1][I[1]]; y = grid.x[2][I[2]]; z = grid.x[3][I[3]]
    V_local = 0.5 * (ωx^2 * x^2 + ωy^2 * y^2 + ωz^2 * z^2)
    ρ = max(0.0, (μ_TF - V_local) / g_contact)
    ws.psi[I] = sqrt(ρ)
end
SpinorBEC.normalize_scalar!(ws)
@printf "After TF init: norm = %.6f\n" SpinorBEC.scalar_norm(ws)

# --- ITP for GS (B̂ = ẑ) -----------------------------------------------------

println("\n--- ITP ground state (B̂ = ẑ) ---")
B_hat_z = SVector{3, Float64}(0.0, 0.0, 1.0)
n_itp = 1000
dt_itp = 0.005
t0 = time()
μ_history = Float64[]
μ_last = SpinorBEC.find_ground_state_scalar!(
    ws, n_itp, dt_itp; B_hat = B_hat_z, target_norm = 1.0,
    on_step = (s, μ, w) -> begin
        push!(μ_history, μ)
        if s % 100 == 0 || s == 1
            com = SpinorBEC.scalar_com(w)
            @printf("  step %4d: μ ≈ %8.4f, COM = (%+.3f,%+.3f,%+.3f)\n", s, μ, com[1], com[2], com[3])
        end
    end,
)
@printf "ITP done in %.2f s, final μ ≈ %.4f, norm = %.6f\n" (time() - t0) μ_last SpinorBEC.scalar_norm(ws)
com_gs = SpinorBEC.scalar_com(ws)
@printf "GS COM = (%+.4f, %+.4f, %+.4f)  (should be ≈ origin)\n" com_gs[1] com_gs[2] com_gs[3]
ar_gs = SpinorBEC.scalar_aspect_ratio(ws)
@printf "GS aspect ratio Rz/Rxy = %.3f  (head-to-tail along z under B̂=ẑ → expect <1 vs trap-only %.3f)\n" ar_gs sqrt(ωx*ωy)/ωz
E_gs = SpinorBEC.scalar_energies(ws, B_hat_z)
@printf "GS energies: kin=%.3f trap=%.3f contact=%.3f dd=%.3f total=%.3f\n" E_gs[1] E_gs[2] E_gs[3] E_gs[4] E_gs[5]

# Snapshot of GS column density (z-axis projection)
function column_density(ws)
    n_pts = ws.grid.config.n_points
    cd = zeros(Float64, n_pts[1], n_pts[2])
    dz = ws.grid.dx[3]
    @inbounds for I in CartesianIndices(ws.psi)
        cd[I[1], I[2]] += abs2(ws.psi[I]) * dz
    end
    cd
end

cd_gs = column_density(ws)

# --- Real-time stir (200 ms) ----------------------------------------------

t_stir = 200.0 * 2π / ω_ref / (2π / ω_ref)  # 200 ms in dimless = 200ms · ω_ref / (1 unit / ω_ref)
# Actually: 1 dimless unit = 1/ω_ref. 200 ms = 0.2s. 0.2 / (1/ω_ref) = 0.2 · ω_ref = 62.83
t_stir_ms = parse(Float64, get(ENV, "T_STIR_MS", "500"))
t_stir_dimless = t_stir_ms * 1e-3 * ω_ref   # ms → dimless
dt_rtp = 0.002
n_steps = Int(round(t_stir_dimless / dt_rtp))
save_every = 50

@printf "\n--- RTP stir for %.1f ms (%.2f dimless time, %d steps, dt=%.4f) ---\n" t_stir_ms t_stir_dimless n_steps dt_rtp

# Tracker: time, Lz, COM xyz, peak position, energies, aspect ratio
times = Float64[]
Lzs = Float64[]
coms = Vector{SVector{3, Float64}}()
peak_pos = Vector{SVector{3, Float64}}()
ARs = Float64[]
E_kin_t = Float64[]; E_trap_t = Float64[]; E_contact_t = Float64[]
E_dd_t = Float64[]; E_total_t = Float64[]

function find_peak(ws)
    n_pts = ws.grid.config.n_points
    max_ρ = -Inf
    Imax = (1, 1, 1)
    @inbounds for I in CartesianIndices(ws.psi)
        ρ = abs2(ws.psi[I])
        if ρ > max_ρ
            max_ρ = ρ
            Imax = (I[1], I[2], I[3])
        end
    end
    SVector{3, Float64}(ws.grid.x[1][Imax[1]], ws.grid.x[2][Imax[2]], ws.grid.x[3][Imax[3]])
end

t0 = time()
SpinorBEC.evolve_scalar!(
    ws, n_steps, dt_rtp; t0 = 0.0,
    B_hat_func = B_hat_stir,
    on_step = (step, t, w) -> begin
        if step % save_every == 0 || step == 1
            push!(times, t)
            push!(Lzs, SpinorBEC.scalar_Lz(w))
            push!(coms, SpinorBEC.scalar_com(w))
            push!(peak_pos, find_peak(w))
            push!(ARs, SpinorBEC.scalar_aspect_ratio(w))
            B_now = B_hat_stir(t)
            E = SpinorBEC.scalar_energies(w, B_now)
            push!(E_kin_t, E[1]); push!(E_trap_t, E[2])
            push!(E_contact_t, E[3]); push!(E_dd_t, E[4]); push!(E_total_t, E[5])
            if step % (save_every * 5) == 0 || step == 1
                @printf "  t=%6.3f Lz=%+7.3f AR=%.3f E_dd=%+7.3f E_tot=%+7.3f\n" t Lzs[end] ARs[end] E[4] E[5]
            end
        end
    end,
)
elapsed = time() - t0
@printf "RTP done in %.2f s (%.1f steps/s, %.0f ns/step/grid_pt)\n" elapsed (n_steps/elapsed) (elapsed * 1e9 / n_steps / (Nx*Ny*Nz))

cd_end = column_density(ws)

# --- Save artifacts -------------------------------------------------------

mkpath("runs/klaus_scalar_validation")
JLD2.jldsave("runs/klaus_scalar_validation/result.jld2";
    times, Lzs, ARs,
    coms_x = [c[1] for c in coms],
    coms_y = [c[2] for c in coms],
    coms_z = [c[3] for c in coms],
    peak_x = [p[1] for p in peak_pos],
    peak_y = [p[2] for p in peak_pos],
    peak_z = [p[3] for p in peak_pos],
    E_kin_t, E_trap_t, E_contact_t, E_dd_t, E_total_t,
    cd_gs, cd_end,
    grid_x = collect(grid.x[1]), grid_y = collect(grid.x[2]),
    metadata = Dict(
        "atom" => "Dy164", "Nx" => Nx, "Ny" => Ny, "Nz" => Nz,
        "g_contact" => g_contact, "c_dd" => c_dd, "eps_dd_target" => eps_dd_target,
        "f_stir_yaml" => f_stir_yaml,
        "Bz_stir" => Bz_stir, "B_perp_stir" => B⊥_stir,
        "t_stir_ms" => t_stir_ms, "dt_rtp" => dt_rtp,
        "timestamp" => string(now()),
    ),
)

println("\n--- Summary ---")
com_xy = [sqrt(c[1]^2 + c[2]^2) for c in coms]
peak_xy = [sqrt(p[1]^2 + p[2]^2) for p in peak_pos]
@printf "Lz: range [%+.3f, %+.3f], final %+.3f\n" minimum(Lzs) maximum(Lzs) Lzs[end]
@printf "Aspect ratio: GS %.3f, range during stir [%.3f, %.3f], final %.3f\n" ar_gs minimum(ARs) maximum(ARs) ARs[end]
@printf "|COM_xy| max: %.4f, final: %.4f\n" maximum(com_xy) com_xy[end]
@printf "Peak |xy| max: %.4f, final: %.4f\n" maximum(peak_xy) peak_xy[end]
@printf "E_dd: GS %+7.3f, range [%+7.3f, %+7.3f]  ← oscillation indicates rotating drive coupling\n" E_gs[4] minimum(E_dd_t) maximum(E_dd_t)
@printf "E_total: GS %+7.3f, range [%+7.3f, %+7.3f] (drift = work done by time-dep field)\n" E_gs[5] minimum(E_total_t) maximum(E_total_t)
println("Artifact: runs/klaus_scalar_validation/result.jld2")
