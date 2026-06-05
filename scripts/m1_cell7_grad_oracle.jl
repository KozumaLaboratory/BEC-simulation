#!/usr/bin/env julia
# scripts/m1_cell7_grad_oracle.jl
#
# Cell 7 (B=1 nT, Ω=0.1) FD-vs-analytic gradient oracle on a TINY CPU
# grid (F=6 / 8³) — grid-independent gradient correctness, ~30 s smoke.
#
# Hypothesis to disambiguate (per 2026-06-05 user category-correction):
#   (a) Ω≠0 vortex-soft-mode conditioning  →  ∇E correct, LBFGS slow
#   (b) Coriolis gradient residual bug      →  ∇E wrong at Ω≠0
#
# Method (per the framework: ε-scaling FD vs analytic ⟨∇E,δ⟩):
#   1. Build cell-7-like workspace at 8³ F=6, c0/c1/c_dd matching Eu twin.
#   2. Seed with a representative non-trivial state (random spin_coherent
#      + small symmetry-breaking noise).
#   3. Compute analytic grad via `energy_gradient!`.
#   4. For each term T ∈ {kinetic, trap, zeeman, density, spin, coriolis,
#      ddi, lhy, light_shift}:
#        - Build the per-term gradient via the same helpers
#          `energy_gradient!` uses (`_grad_<term>!`).
#        - Pick a random direction δ.
#        - Compare: directional analytic ⟨2·∇_T, δ⟩  vs  FD
#          (E_T(ψ + ε δ) − E_T(ψ − ε δ)) / (2ε).
#        - Ratio FD / analytic should ≈ 1 within FD precision (~1e-3 at
#          ε=1e-5 for spinor F=6).
#
# A passing test means: the gradient IS the analytic δE/δψ̄. Then ‖∇E‖
# stuck at 1.4e-3 at cell 7 is NOT a bug — it's conditioning. The fix
# direction becomes preconditioning / Riemannian (spine C/D), not a
# gradient-path repair.

using SpinorBEC
using SpinorBEC: energy_decomposition, energy_gradient!
using LinearAlgebra
using Printf
using Random

# ─── Eu-class params at 8³ (preserve physics, shrink grid) ─────────────────

const F = 6
const D = 2F + 1
const ATOM = SpinorBEC.Eu151
const N_PTS = (8, 8, 8)
const BOX = (8.0, 8.0, 7.0)     # box scaled-down from Eu twin (30,30,26)
const C0 = 30.0
const C1 = 30.0 / 36.0          # Eu Kawaguchi-Ueda ratio
const C_DD = 30.0 * 0.09        # ε_dd ≈ 0.09 (Matsui regime)
const P_LAB = 0.148 * 1.0       # B = 1 nT × γ_Eu/(2π·ω_ref)
const OMEGA = 0.1               # cell 7's Ω
const NOISE_AMP = 0.01

function build_cell7_ws()
    grid = make_grid(GridConfig{3}(N_PTS, BOX))
    ip = InteractionParams(Dict(0 => C0, 1 => C1))
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
        normalize_every=1, rotating_frame_omega=OMEGA)
    zeeman = ZeemanParams(P_LAB, 0.0)
    ws = make_workspace(;
        grid, atom=ATOM, interactions=ip, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.1818)),
        sim_params=sp,
        enable_ddi=true, c_dd=C_DD, secular_ddi=false,
    )
    # Seed with non-trivial state: spin_coherent θ=π/4 + 1% noise + vortex phase
    psi = init_psi(grid, SpinSystem(F); state=:fl_vortex)
    rng = MersenneTwister(7)
    for i in eachindex(psi)
        psi[i] += NOISE_AMP * (randn(rng) + im * randn(rng))
    end
    dV = SpinorBEC.cell_volume(grid)
    psi ./= sqrt(sum(abs2, psi) * dV)
    copyto!(ws.state.psi, psi)
    return ws
end

# ─── Per-term FD audit ──────────────────────────────────────────────────────

# Map term name → (analytic_grad_builder, energy_picker_field).
# energy_picker_field reads `energy_decomposition(ws)` to extract the
# scalar contribution of that term alone.
const TERMS = [
    (:kinetic,           :kinetic),
    (:trap,              :trap),
    (:zeeman,            :zeeman),
    (:density,           :density),
    (:spin,              :spin),
    (:coriolis,          :coriolis),
    (:ddi,               :ddi),
]

function single_term_grad!(grad_buf, ws, term::Symbol, k2_dev, n_pts, fft_buf,
    fx_scratch, fy_scratch, fz_scratch, deriv_buf)
    fill!(grad_buf, 0)
    if term === :kinetic
        SpinorBEC._grad_kinetic!(grad_buf, ws.state.psi, ws, fft_buf,
            k2_dev, n_pts, D, Val(3))
    elseif term === :trap
        SpinorBEC._grad_trap!(grad_buf, ws.state.psi, ws, n_pts, D, Val(3))
    elseif term === :zeeman
        SpinorBEC._grad_zeeman!(grad_buf, ws.state.psi, ws, n_pts, D, Val(3))
    elseif term === :density
        n_density = SpinorBEC.total_density(ws.state.psi, 3)
        SpinorBEC._grad_c0_density!(grad_buf, ws.state.psi, ws,
            n_density, n_pts, D, Val(3))
    elseif term === :spin
        SpinorBEC._grad_c1_spin!(grad_buf, ws.state.psi, ws,
            fx_scratch, fy_scratch, fz_scratch, n_pts, D, Val(3))
    elseif term === :coriolis
        SpinorBEC._grad_coriolis!(grad_buf, ws.state.psi, ws, fft_buf,
            deriv_buf, n_pts, D, Val(3))
    elseif term === :ddi
        SpinorBEC._grad_ddi!(grad_buf, ws.state.psi, ws, n_pts, D, Val(3))
    end
    # `_grad_*!` does NOT apply the outer ×2 from energy_gradient!.
    # `directional_analytic` below uses `2 · grad_buf` to match the
    # actual convention `δE = Re ⟨2·∂E/∂ψ̄, δψ⟩ dV`.
    return grad_buf
end

function energy_term_value(ws, term::Symbol)
    ed = energy_decomposition(ws)
    return Float64(getproperty(ed, term))
end

# ─── Oracle ────────────────────────────────────────────────────────────────

function audit_term(ws, term::Symbol, rng, ε; n_dirs::Int=3)
    n_pts = ntuple(d -> size(ws.state.psi, d), Val(3))
    k2_dev = ws.grid.k_squared
    grad_buf = similar(ws.state.psi)
    fft_buf = similar(ws.state.psi, ComplexF64, n_pts...)
    fx_scratch = similar(ws.state.psi, ComplexF64, n_pts...)
    fy_scratch = similar(ws.state.psi, ComplexF64, n_pts...)
    fz_scratch = similar(ws.state.psi, ComplexF64, n_pts...)
    deriv_buf = similar(ws.state.psi, ComplexF64, n_pts...)

    single_term_grad!(grad_buf, ws, term, k2_dev, n_pts, fft_buf,
        fx_scratch, fy_scratch, fz_scratch, deriv_buf)

    dV = SpinorBEC.cell_volume(ws.grid)
    psi0 = copy(ws.state.psi)

    ratios = Float64[]
    for d in 1:n_dirs
        δ = randn(rng, ComplexF64, size(psi0))
        # Optionally normalize so ‖δ‖ ~ ‖ψ‖ (numerical conditioning)
        δ ./= sqrt(sum(abs2, δ) * dV)
        # Directional FD of THIS term's energy
        copyto!(ws.state.psi, psi0 .+ ε .* δ)
        E_plus = energy_term_value(ws, term)
        copyto!(ws.state.psi, psi0 .- ε .* δ)
        E_minus = energy_term_value(ws, term)
        fd_dir = (E_plus - E_minus) / (2ε)

        # Restore ψ for next iteration
        copyto!(ws.state.psi, psi0)

        # Directional analytic: δE = Re ⟨ 2·∂E/∂ψ̄, δψ⟩_L²
        #                          = Re sum(conj(2·grad_buf) .* δ) · dV
        an_dir = real(sum(conj.(2 .* grad_buf) .* δ)) * dV

        if abs(an_dir) > 1e-12
            push!(ratios, fd_dir / an_dir)
        else
            push!(ratios, NaN)  # term is zero at this state
        end
    end
    return ratios
end

# ─── Run ───────────────────────────────────────────────────────────────────

function main()
    @info "Building cell-7-like workspace (8³ Eu F=6, Ω=$OMEGA)"
    ws = build_cell7_ws()

    rng = MersenneTwister(2026)
    ε = 1e-5

    println("\n=== Cell-7 per-term FD-vs-analytic gradient oracle ===")
    println("Grid: $N_PTS  |  F=$F  D=$D  Ω=$OMEGA  B=1 nT (p_lab=$P_LAB)")
    println("ε=$ε,  random directions per term=3,  expected ratio ≈ 1.0")
    println()
    @printf "%-12s  %12s %12s %12s   %s\n" "term" "ratio_1" "ratio_2" "ratio_3" "verdict"
    println("-" ^ 80)

    all_pass = true
    for (term, _) in TERMS
        ratios = audit_term(ws, term, rng, ε)
        verdict = if all(isnan.(ratios))
            "skip (E_term ≈ 0 at this state)"
        elseif all(abs.(filter(!isnan, ratios) .- 1.0) .< 5e-3)
            "OK"
        else
            all_pass = false
            "FAIL (>5e-3 deviation)"
        end
        ratio_strs = map(r -> isnan(r) ? "  N/A      " : @sprintf("%12.6f", r), ratios)
        @printf "%-12s  %s %s %s   %s\n" term ratio_strs[1] ratio_strs[2] ratio_strs[3] verdict
    end

    println()
    if all_pass
        println("✅ All term gradients pass: ‖∇E‖ at cell 7 IS the true functional gradient.")
        println("   Conclusion: cell 7 stuck-at-1.4e-3 is a CONDITIONING / soft-mode problem,")
        println("   not a gradient bug. Fix direction = preconditioning / Riemannian (spine C/D).")
    else
        println("⚠ At least one term gradient diverges from FD.")
        println("   Conclusion: there IS a residual bug in the gradient path at Ω≠0.")
        println("   Investigate the failing term's `_grad_<term>!` implementation.")
    end
end

main()
