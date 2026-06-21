# First-principles analytic gate for the magnetostir pipeline under a ROTATING
# tilted field (φ̇ ≠ 0). This is the regression that arbitrated the engine
# retirement (2026-06-21): the retired rotating-basis engine carried a ~1.8e-3
# systematic error in its rotating-frame inertial term (the "frame
# transformation half-term" bug class), while the unified lab-frame
# split_step_midpoint! path reproduces the exact dynamics to ~1e-5.
#
# Construction: with c1 = c_dd = 0 the spin sector is a single-particle problem
# (the c0 density term is spin-scalar — a global per-voxel phase that cannot move
# per-m population). So the pipeline's per-m history under a rotating tilted
# field MUST equal the exact single-spin evolution of H(t) = -p (B̂(t)·F),
# transformed into the same tilde (field-following) basis the pipeline records
# in: ψ̃ = U_B(t)† ψ_lab with U_B(t) = exp(-iφ(t)F_z) exp(-iθ F_y).
#
# A φ̇-term sign/coefficient drift (the historical engine bug) shows up here as a
# per-m mismatch ~1e-3, far above the tolerance. The static-field case is bit-
# identical between the two paths (no inertial term), so this gate specifically
# pins the rotating-frame term.

using Test
using SpinorBEC
using LinearAlgebra

@testset "magnetostir rotating-field vs exact single-spin (engine-free)" begin
    F = 2
    p_zee = 8.0
    θ = 0.5
    φdot = 1.2
    T = 0.5
    dt = 0.005

    gs_params = Dict{String, Any}(
        "F" => F,
        "grid" => Dict("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
        "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
        "interactions" => Dict("c0" => 10.0, "c1" => 0.0),   # c1=0 ⇒ single-spin per-m
        "B" => Dict("p" => p_zee, "q" => 0.0),
        "B_direction" => Dict("theta" => θ, "phi" => 0.0),
        "n_steps" => 300,
        "dt" => 0.01,
        "init_m_idx" => 1,   # seed m=F; GS relaxes spin to the coherent state along B̂(0)
        "init_sigma" => 1.2,
    )
    step_gs = SpinorBEC.RotatingBasisGroundStateStep(gs_params)
    psi_gs, grid_gs, atom_gs, _, gs_result = SpinorBEC._run_step(
        step_gs, nothing, nothing, nothing, nothing; verbose=false)

    dyn_params = Dict{String, Any}(
        "duration" => T,
        "dt" => dt,
        "save_every" => 1,
        "B_direction" => Dict("theta" => θ, "phi" => Dict("rate" => φdot)),
        "save" => Dict("psi" => false),
    )
    step_dyn = SpinorBEC.RotatingBasisDynamicsStep(dyn_params)
    _, _, _, _, dyn_result = SpinorBEC._run_step(
        step_dyn, psi_gs, grid_gs, atom_gs, nothing;
        verbose=false, pipeline_results=gs_result)
    per_m_sim = dyn_result[:rotating_basis_dynamics][:per_m_history][end]::Vector{Float64}

    # --- Exact single-spin reference (fine lab-frame stepping → tilde basis) ---
    sm = SpinorBEC.spin_matrices(F)
    Fx = Matrix(sm.Fx);
    Fy = Matrix(sm.Fy);
    Fz = Matrix(sm.Fz)
    D = 2F + 1
    ψ = exp(-im * θ * Fy) * ComplexF64[i == 1 ? 1.0 : 0.0 for i in 1:D]   # GS ∥ B̂(0)
    ψ ./= norm(ψ)
    nst = 50_000
    h = T / nst
    for k in 1:nst
        t = (k - 0.5) * h
        φ = φdot * t
        H = -p_zee * (sin(θ) * cos(φ) * Fx + sin(θ) * sin(φ) * Fy + cos(θ) * Fz)
        ψ = exp(-im * H * h) * ψ
    end
    # lab → tilde: ψ̃ = U_B(T)† ψ_lab = exp(iθ F_y) exp(iφ(T) F_z) ψ_lab
    ψtilde = exp(im * θ * Fy) * exp(im * (φdot * T) * Fz) * ψ
    per_m_exact = abs2.(ψtilde)

    @test length(per_m_sim) == D
    Δ = maximum(abs.(per_m_sim .- per_m_exact))
    # The correct lab-frame path matches to ~1e-5 (limited by GS ITP + dt). The
    # retired engine's rotating-frame inertial-term error was ~1.8e-3, so a 5e-4
    # gate fails loudly on that bug class while passing the unified path.
    @test Δ < 5e-4
end
