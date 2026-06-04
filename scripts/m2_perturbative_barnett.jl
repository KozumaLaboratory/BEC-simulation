#!/usr/bin/env julia
# scripts/m2_perturbative_barnett.jl
#
# Clean perturbative Barnett demonstration — follow-up to
# `m2_barnett_window_scan.jl` whose Δ=+0.014 was sign-correct but
# magnitude uninformative (Eu F=6 polar seed already saturated +
# Bx range overlapped Rabi-driven regime).
#
# DESIGN (per `m2_perturbative_barnett_design_notes` memory)
#
# - F=1 Rb87 (cleanest spin-coherent dynamics, well-defined ⟨F⟩=0
#   baseline at polar m=0).
# - Pure-polar seed (m=0 single component, no thermalisation).
# - Perturbative Bx ∈ [0.1, 3.0] nT (γ_F·Bx ≪ ω_ref, χ-linear regime).
# - Small Ω ∈ [0.01, 0.3] (Larmor χ_low regime: Ω ≪ Ω_Rabi=γ_F·Bx).
# - Disable c1, DDI, MG, light_shift — isolate the linear Zeeman response.
#
# ANALYTICAL ORACLE (χ_low Larmor regime)
#
#     ⟨F_z⟩ ≈ F · Ω / (γ_F · Bx)
#     χ ≡ ∂⟨F_z⟩/∂Ω|_Bx ≈ F / (γ_F · Bx)
#     ⇒  χ · Bx ≈ F / γ_F = constant  (independent of Bx)
#
# Pass criterion: χ(Bx) · Bx · γ_F ≈ F within ~10% across the Bx scan.
#
# Cost: 16 cells × ~30s (small grid, no DDI) ≈ 8 min on GPU.
#
# Run:
#   LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#     scripts/m2_perturbative_barnett.jl

import CUDA
using SpinorBEC
using Printf
using JLD2
using Random

# Inline noise helper (avoids the eu_digital_twin dependency).
function _add_noise!(psi::AbstractArray, amp::Float64, seed::Int, grid)
    Random.seed!(seed)
    psi .+= amp .* randn(ComplexF64, size(psi))
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
    return psi
end

# ============================================================================
# Dimensionless setup (ω_ref = 1, Rb87 F=1 atom).
# `p_lab` represents γ_F · Bx_nT / ω_ref ≡ dimensionless Larmor frequency.
# The actual physical conversion p_per_nT_Rb87 ≈ 0.0067 (ω_ref=2π·100 Hz,
# γ_F/2π ≈ 0.7 MHz/T for Rb87 F=1) is folded into the BX_GRID values
# below — we pick p_lab values directly so the math is unambiguous.
# ============================================================================

const F = 1                            # Rb87 F=1
const F_FLOAT = 1.0
const ATOM = Rb87

# p_lab grid in dimensionless ω_ref units (= γ_F · Bx).
# Picked Larmor-pinned regime (p_lab ≫ ω_trap=1) so the χ_low formula
# `⟨F_z⟩ = F·Ω/p_lab` is the correct limit. Initial sweep at smaller
# p_lab (≤0.2) landed in trap-dominated regime — see
# `m2_perturbative_barnett_design_notes` memory.
const PLAB_GRID = [5.0, 10.0, 30.0, 50.0]

# Ω ≪ p_lab/5 keeps the rotation a small perturbation on the
# Larmor-pinned spin.
const OMEGA_GRID = [0.05, 0.1, 0.3, 1.0]

const N_ITP = 600
const DT = 0.01
const TOL = 1e-8

const OUTPUT_JLD2 = "runs/m2_perturbative_barnett_2026_06_04.jld2"

# Analytical χ_low prediction: χ · p_lab ≈ F (with ω_ref=γ_F·Bx convention)
# Pass criterion ±tolerance:
const ORACLE_TOL = 0.15

function cell_observables(p_lab::Float64, omega::Float64)
    grid = make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0)))
    ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))  # NO interactions
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0),                 # p_wf (Bz)  = 0
        ConstantWaveform(0.0),                 # q_wf       = 0
        ConstantWaveform(p_lab),               # bx_wf (Bx) = scanned
        ConstantWaveform(0.0),                 # by_wf      = 0
    )
    sp = SimParams(;
        dt=DT, n_steps=N_ITP, imaginary_time=true,
        rotating_frame_omega=omega, normalize_every=1,
    )

    # Pure-polar seed: m=0 only (F=1 → c=2 is m=0 slot)
    sys = SpinSystem(F)
    D = sys.n_components
    n_pts = grid.config.n_points
    psi_init = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        psi_init[I, 2] = exp(-(x^2 + y^2 + z^2) / 2)
    end
    psi_init ./= sqrt(sum(abs2, psi_init) * cell_volume(grid))

    # 1% symmetry-breaking noise so the small Larmor regime can pick a direction.
    _add_noise!(psi_init, 0.01, 1, grid)

    r = find_ground_state(;
        grid=grid, atom=ATOM, interactions=ip, zeeman=zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        dt=DT, n_steps=N_ITP, tol=TOL,
        initial_state=:polar, verbose=false,
        psi_init=psi_init,
        rotating_frame_omega=omega, backend=CUDABackend(),
    )

    ws = r.workspace
    psi_cpu = Array(ws.state.psi)
    N = ndims(psi_cpu) - 1
    fx, fy, fz = SpinorBEC.spin_density_vector(psi_cpu, ws.spin_matrices, N)
    dV = cell_volume(grid)
    Fz_total = sum(fz) * dV
    Fx_total = sum(fx) * dV
    Fy_total = sum(fy) * dV

    return (Fz=Fz_total, Fx=Fx_total, Fy=Fy_total,
        E=r.energy, conv=r.converged)
end

function main()
    println("=== M2 perturbative Barnett demo (F=1 Rb87, χ_low regime) ===")
    @printf "p_lab grid (γ_F·Bx): %s\n" string(PLAB_GRID)
    @printf "Ω grid: %s\n" string(OMEGA_GRID)
    @printf "Interactions: c0=c1=0, no DDI, no MG, no LS (non-interacting baseline)\n"
    @printf "Oracle: χ·p_lab ≈ F=%d (Larmor χ_low limit) within ±%.0f%%\n\n" F (ORACLE_TOL * 100)

    results = Dict{Tuple{Float64, Float64}, NamedTuple}()
    for p_lab in PLAB_GRID
        for omega in OMEGA_GRID
            t0 = time()
            obs = cell_observables(p_lab, omega)
            wall = time() - t0
            results[(p_lab, omega)] = obs
            @printf "  p_lab=%.3f Ω=%.4f → ⟨F_z⟩=%+.4e ⟨F_x⟩=%+.4e E=%.5f conv=%s (%.1fs)\n" p_lab omega obs.Fz obs.Fx obs.E string(obs.conv) wall
        end
    end

    # Linear-response fit: χ(p_lab) = ⟨F_z⟩/Ω, fit χ vs Ω at fixed p_lab
    println("\n=== Linear-response analysis ===")
    @printf "%6s %12s %12s %12s\n" "p_lab" "χ_avg" "χ·p_lab" "verdict (vs F)"
    pass_count = 0
    total_count = 0
    for p_lab in PLAB_GRID
        chi_vals = Float64[]
        for omega in OMEGA_GRID
            obs = results[(p_lab, omega)]
            push!(chi_vals, obs.Fz / omega)
        end
        chi_avg = sum(chi_vals) / length(chi_vals)
        chi_x_plab = chi_avg * p_lab
        # Pass: χ·p_lab ∈ [F·(1-tol), F·(1+tol)]
        passing = abs(chi_x_plab - F_FLOAT) < ORACLE_TOL * F_FLOAT
        passing && (pass_count += 1)
        total_count += 1
        verdict = passing ? "✓" : "✗"
        @printf "%6.3f %12.4e %12.4e %s (F=%d ±%.0f%%)\n" p_lab chi_avg chi_x_plab verdict F (ORACLE_TOL * 100)
    end

    println()
    if pass_count == total_count
        @printf "  ✓ FULL PASS — χ·p_lab = constant ≈ F across all Bx (Larmor χ_low confirmed)\n"
    elseif pass_count > 0
        @printf "  △ PARTIAL — %d/%d cells in band; check non-passing for regime breakdown\n" pass_count total_count
    else
        @printf "  ✗ FAIL — no cells in oracle band; either non-linear regime or sign-bug residual\n"
    end

    mkpath(dirname(OUTPUT_JLD2))
    @save OUTPUT_JLD2 results PLAB_GRID OMEGA_GRID
    @printf "\nSaved to %s\n" OUTPUT_JLD2
end

main()
