#!/usr/bin/env julia
# scripts/m1_clean_freeze_test.jl
#
# Clean L² projected gradient descent oracle for the M1 freeze.
#
# At an LBFGS-stalled state with `‖P_⊥∇E‖_{L²} ≈ 0.2-0.5`, Taylor
# guarantees that a SINGLE direct projected-gradient step
#
#     ψ_α = (ψ − α·P_⊥∇E) / ‖·‖
#
# at small α gives
#
#     E(ψ_α) − E(ψ) = −α·‖P_⊥∇E‖²  +  O(α²)
#
# This is splitting-error-free (unlike split-step ITP, where the
# kinetic / trap / interaction substeps add `O(dt^p·‖[A,B]‖)` noise at
# every step). If E(ψ_α) < E(ψ) for small α with the expected linear
# slope, the landscape provides a descent direction at the plateau ψ
# → freeze is OPTIMIZER (LBFGS curvature corruption or Sobolev-vs-L²
# stopping mismatch). If E(ψ_α) ≥ E(ψ) for all small α → gradient is
# wrong at this ψ; audit `energy_gradient!` evaluation pointwise.
#
# This replaces the 2026-06-03 morning `m1_freeze_diagnostic.jl` which
# used pure split-step ITP and was contaminated by splitting noise
# (`ΔE ≈ 0.5% of E_total` either direction at the stalled state — see
# `mistake_coriolis_substep_sign_2026_06_03.md`).
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_clean_freeze_test.jl
#
# Optional CLI:
#   --seed SYMBOL     plateau ψ key (default :polar)
#   --alphas A,B,...  comma-separated step sizes (default 1e-2,1e-3,1e-4,1e-5)
#   --smoke           CPU + tiny defaults
#
# Cost: a few gradient evaluations on the 24³×13 grid; ~30 s GPU.

const USE_SMOKE = "--smoke" in ARGS
const USE_CPU = USE_SMOKE

if !USE_CPU
    import CUDA
end
using SpinorBEC
using Printf
using JLD2

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

function get_arg_str(name::String, default::String)
    for (i, a) in enumerate(ARGS)
        a == name && i + 1 <= length(ARGS) && return ARGS[i + 1]
    end
    default
end

const TW = eu_digital_twin()
const SEED = Symbol(get_arg_str("--seed", "polar"))
const ALPHAS = let s = get_arg_str("--alphas", "1e-2,1e-3,1e-4,1e-5")
    parse.(Float64, split(s, ","))
end
const BACKEND = USE_CPU ? CPUBackend() : CUDABackend()

const CACHED_PATH = "runs/sprint5_M1_basin_valley_B0.0_Om0.4.jld2"
const B_NT = 0.0
const OMEGA = 0.4

"""
Compute gradient `∇E` on device, L²-project off ψ (Riemannian metric),
and return (`P_⊥∇E_host`, μ = ⟨ψ|∇E⟩/⟨ψ|ψ⟩, residual_L²_norm).
"""
function projected_gradient(ws, psi_cpu, dV)
    grad_dev = similar(ws.state.psi)
    k_squared_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    SpinorBEC.energy_gradient!(grad_dev, ws.state.psi, ws; k_squared_dev)
    grad_cpu = Array(grad_dev)
    psi_norm² = sum(abs2, psi_cpu) * dV
    μ = real(sum(conj.(grad_cpu) .* psi_cpu)) * dV / psi_norm²
    proj_cpu = grad_cpu .- μ .* psi_cpu
    return proj_cpu, μ, sqrt(sum(abs2, proj_cpu) * dV)
end

"""
Compute E(ψ) by overwriting `ws.state.psi` with `psi_cpu`, calling
`energy_decomposition(ws).total`, then restoring.
"""
function energy_at(ws, psi_cpu, psi_save)
    copyto!(ws.state.psi, psi_cpu)
    E = SpinorBEC.energy_decomposition(ws).total
    copyto!(ws.state.psi, psi_save)
    return E
end

function main()
    println("=== M1 clean freeze test (direct L² projected gradient) ===")
    @printf "Cell: B=%.1f nT, Ω=%.2f   seed: :%s   backend: %s\n" B_NT OMEGA SEED (
        USE_CPU ? "CPU" : "CUDA"
    )
    @printf "α grid: %s\n\n" string(ALPHAS)
    isfile(CACHED_PATH) || error("Missing $CACHED_PATH — run discriminator first.")
    cached = JLD2.load(CACHED_PATH)
    psi_key = "psi_$(SEED)"
    if !haskey(cached, psi_key)
        avail = filter(startswith("psi_"), collect(keys(cached)))
        error("$psi_key not in $CACHED_PATH. Available: $avail")
    end
    psi_cached = cached[psi_key]
    @printf "Loaded ψ from %s (shape %s)\n" CACHED_PATH string(size(psi_cached))

    p_lab = B_NT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    dV = SpinorBEC.cell_volume(TW.grid)

    # Warm-start workspace via 1 ITP step, then snap ψ back to cached so
    # the gradient/E are evaluated AT the plateau, not at "plateau + 1 step".
    println("--- Phase A: warm-start workspace ---")
    r_warm = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=1, tol=0.0,
        initial_state=:polar, verbose=false,
        psi_init=psi_cached,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=OMEGA,
        backend=BACKEND)
    ws = r_warm.workspace
    copyto!(ws.state.psi, psi_cached)

    psi0_cpu = copy(psi_cached)
    psi_save_dev = copy(ws.state.psi)

    E0 = SpinorBEC.energy_decomposition(ws).total
    proj_cpu, μ, R = projected_gradient(ws, psi0_cpu, dV)
    @printf "  E_0           = %.8f\n" E0
    @printf "  μ             = %.6f\n" μ
    @printf "  ‖P_⊥∇E‖_L²    = %.6e\n" R
    @printf "  Taylor slope  −‖P_⊥∇E‖² = %.6e   (predicted ΔE / α)\n\n" -R^2

    # Phase B1: scan α, measure ΔE for the projected gradient step.
    println("--- Phase B1: P_⊥∇E step (Lagrange-projected, on unit sphere) ---")
    @printf "%12s  %14s  %14s  %14s  %14s\n" "α" "ΔE_meas" "ΔE_taylor" "ΔE/(−α·R²)" "slope"
    for α in ALPHAS
        psi_step = psi0_cpu .- α .* proj_cpu
        nrm² = sum(abs2, psi_step) * dV
        psi_step ./= sqrt(nrm²)
        E_step = energy_at(ws, psi_step, psi_save_dev)
        ΔE_meas = E_step - E0
        ΔE_taylor = -α * R^2
        ratio = ΔE_meas / ΔE_taylor
        slope = ΔE_meas / (-α)
        @printf "%12.2e  %+.6e  %+.6e  %+.6f  %+.6e\n" α ΔE_meas ΔE_taylor ratio slope
    end

    # Phase B2: scan α, raw gradient step (no Lagrange projection, no renorm).
    # Taylor predicts ΔE = -α·‖grad‖²_L² for ψ - α·grad with no projection.
    # If raw gradient also descends sub-Taylor → projection isn't the issue.
    grad_cpu_save = proj_cpu .+ μ .* psi0_cpu   # raw grad = projection + μ·ψ
    G² = real(sum(abs2, grad_cpu_save)) * dV
    println("\n--- Phase B2: raw ∇E step (no projection, no renormalisation) ---")
    @printf "  ‖∇E‖²_L²            = %.6e   (raw gradient norm²)\n" G²
    @printf "  ‖∇E‖_L²             = %.6e\n" sqrt(G²)
    @printf "  ‖P_⊥∇E‖² / ‖∇E‖²    = %.6f   (projection fraction)\n\n" R^2 / G²
    @printf "%12s  %14s  %14s  %14s  %14s\n" "α" "ΔE_meas" "ΔE_taylor" "ΔE/(−α·G²)" "slope"
    for α in ALPHAS
        psi_step = psi0_cpu .- α .* grad_cpu_save
        E_step = energy_at(ws, psi_step, psi_save_dev)
        ΔE_meas = E_step - E0
        ΔE_taylor = -α * G²
        ratio = ΔE_meas / ΔE_taylor
        slope = ΔE_meas / (-α)
        @printf "%12.2e  %+.6e  %+.6e  %+.6f  %+.6e\n" α ΔE_meas ΔE_taylor ratio slope
    end

    # Phase B3: FD check ∂E/∂α at α=0 against ‖∇E‖²_L² for the raw grad.
    # If FD-slope ≈ -G² → gradient routine is correct at this ψ.
    # If FD-slope ≪ G² → gradient routine is reporting an inflated norm
    # (the most plausible cause is a Sobolev/preconditioned convention
    # somewhere upstream that we're reading as L²).
    println("\n--- Phase B3: numerical sanity (raw grad slope vs ‖∇E‖²) ---")
    α_fd = 1e-6
    psi_fd = psi0_cpu .- α_fd .* grad_cpu_save
    E_fd = energy_at(ws, psi_fd, psi_save_dev)
    slope_fd = (E_fd - E0) / (-α_fd)
    @printf "  FD slope @ α=%.0e   = %+.6e\n" α_fd slope_fd
    @printf "  ‖∇E‖²_L²            = %+.6e\n" G²
    @printf "  ratio FD/G²          = %+.6e   (Taylor predicts = 1.0)\n" slope_fd / G²

    !USE_CPU && CUDA.reclaim()

    println("\n=== Verdict ===")
    println("Read the table:")
    println("  • If ΔE_meas is negative at the smallest α with slope → R² as α shrinks:")
    println("    → descent direction is available at the plateau.")
    println("    → FREEZE IS THE OPTIMIZER (LBFGS curvature / Sobolev-vs-L² stopping).")
    println("  • If ΔE_meas is positive or near-zero for all small α:")
    println("    → gradient does NOT point downhill at this ψ.")
    println("    → audit `energy_gradient!` pointwise (FD vs analytic at this ψ),")
    println("      or check for stale workspace buffers (DDI / LHY / tensor cache).")
end

main()
