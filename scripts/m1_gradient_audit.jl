#!/usr/bin/env julia
# scripts/m1_gradient_audit.jl
#
# Step 0 audit for the M1 rotating-frame sweep. Before trusting any
# convergence claim or attempting iter↑/seed↑/Sobolev↑, verify that:
#
#   (1) the analytic gradient `energy_gradient!` IS the gradient of
#       the energy `energy_decomposition(ws).total` at Ω = 0
#       — i.e. (E(ψ+εδψ) − E(ψ))/ε → Re ⟨grad*, δψ⟩ as ε → 0.
#   (2) the same identity holds at Ω = 0.4.
#       Discrepancy at (2) but not (1) ⟹ rotating-frame gradient is
#       inconsistent (failure mode (c)) — and seeds/iter cannot fix it.
#   (3) at the Ω = 0 floor, classify whether ‖grad‖² lives in
#       symmetry directions (U(1) phase + spin-axis rotations at B=0).
#       If yes ⟹ Goldstone floor; raw ‖∇E‖ < tol is artifact.
#
# See mistake_unconverged_to_new_physics_ignoring_analytical_oracle.md,
# the "Diagnostic correction (2026-06-03)" section.
#
# Run: LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#      scripts/m1_gradient_audit.jl
#
# Add `--cpu` to force CPU backend (default is CUDA when available).
# Use CPU when the GPU is busy with another job — this audit's whole
# point is "do not commit GPU time to a sweep whose gradient might be
# broken", so the CPU path matters.
#
# Cost: ~3 min on GPU, ~8 min on CPU. No psi cache required — builds
# its own from a short ITP run at one (B, Ω) cell.

const USE_CPU = "--cpu" in ARGS

# Only load CUDA when the GPU backend is actually needed. This lets the
# audit run on a workstation whose GPU is held by another process.
if !USE_CPU
    import CUDA
end
using SpinorBEC
using Random
using LinearAlgebra
using Printf

include(joinpath(@__DIR__, "lib", "eu_digital_twin.jl"))

const TW = eu_digital_twin()
const N_ITP_PREP = USE_CPU ? 80 : 200   # CPU is ~3× slower per ITP step
                                        # at 24³; smaller prep is fine.
const FD_EPS = [1e-4, 1e-5, 1e-6, 1e-7]
const N_DIRECTIONS = 4
const RNG = MersenneTwister(20260603)
const BACKEND = USE_CPU ? CPUBackend() : CUDABackend()

function prep_workspace(B_nT::Float64, Ω::Float64)
    p_lab = B_nT * TW.p_per_nT
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        ConstantWaveform(p_lab), ConstantWaveform(0.0),
    )
    r = find_ground_state(;
        grid=TW.grid, atom=TW.atom, interactions=TW.interactions,
        zeeman=zeeman, potential=TW.potential,
        dt=0.005, n_steps=N_ITP_PREP, tol=1e-7,
        initial_state=:polar, verbose=false,
        enable_ddi=true, c_dd=TW.c_dd, secular_ddi=false,
        rotating_frame_omega=Ω,
        backend=BACKEND)
    return r.workspace
end

# Compute total energy at a given psi (caller-supplied), using the
# ws.zeeman/interactions/etc. that are already wired in. Mutates
# ws.state.psi as a side effect.
function evaluate_energy(ws, psi_test::AbstractArray)
    copyto!(ws.state.psi, psi_test)
    return SpinorBEC.energy_decomposition(ws).total
end

# Snapshot grad + E0 at the current ws.state.psi. The grad is returned
# as a CPU array so subsequent inner products are easy and consistent.
# (k_squared_dev default is CPU-only — fine for the audit's CPU run,
# but pass a device-resident copy on GPU so the kinetic kernel can
# compile. Same pattern as find_ground_state_lbfgs in driver.jl L109.)
function snapshot_grad(ws)
    psi_dev = ws.state.psi
    grad_dev = similar(psi_dev)
    k_squared_dev = SpinorBEC._to_device(ws.backend, ws.grid.k_squared)
    E0 = SpinorBEC.energy_gradient!(grad_dev, psi_dev, ws; k_squared_dev)
    return Array(psi_dev), Array(grad_dev), E0
end

function fd_check(ws, label::String, dV::Float64)
    println("\n--- (FD vs analytic) at $label ---")
    psi_cpu, grad_cpu, E0 = snapshot_grad(ws)
    grad_norm² = sum(abs2, grad_cpu) * dV
    @printf "E0 = %.10f   ‖grad‖² (L²) = %.6e   ‖grad‖ = %.6e\n" E0 grad_norm² sqrt(grad_norm²)

    # `min_err_per_dir[d]` records the err at the SMALLEST ε for each
    # direction. The FD truncation error scales as ε·|f''/f'|, so the
    # err at large ε is naturally O(1) and is NOT a gradient bug; the
    # asymptotic ε→0 ratio is the signal.
    min_err_per_dir = fill(Inf, N_DIRECTIONS)
    for d in 1:N_DIRECTIONS
        # Random unit-norm complex direction in psi-space
        δψ = randn(RNG, ComplexF64, size(psi_cpu))
        δψ ./= sqrt(sum(abs2, δψ) * dV)   # ‖δψ‖_L² = 1

        # Analytic directional derivative.
        # Convention from energy_gradient.jl L86-88:
        #   grad = 2 · δE/δψ*  such that  δE = Re ∫ grad* · δψ dV.
        D_analytic = real(sum(conj.(grad_cpu) .* δψ)) * dV
        @printf "\ndir %d  analytic dE/dε = %+.6e\n" d D_analytic
        for (ε_idx, ε) in enumerate(FD_EPS)
            psi_eps = psi_cpu .+ ε .* δψ
            E_eps = evaluate_energy(ws, psi_eps)
            D_fd = (E_eps - E0) / ε
            ratio = D_fd / D_analytic
            err = abs(ratio - 1)
            tag = err < 0.01 ? "✓" : err < 0.1 ? "△" : "✗"
            @printf "  ε=%.0e  FD dE/dε = %+.6e  ratio = %.6f  err = %.2e  %s\n" ε D_fd ratio err tag
            ε_idx == length(FD_EPS) && (min_err_per_dir[d] = err)
        end
    end
    asymptotic_err = maximum(min_err_per_dir)
    @printf "\nAsymptotic err (max over %d directions at ε=%.0e): %.2e\n" N_DIRECTIONS FD_EPS[end] asymptotic_err
    # Restore ws.state.psi to the unperturbed value so a subsequent
    # check on the same ws works.
    copyto!(ws.state.psi, psi_cpu)
    return asymptotic_err
end

# REAL-coefficient projection of grad onto direction `δψ_dir`. The
# directional derivative `Re ⟨grad, δψ_dir⟩` is the signed real
# coefficient; squaring it (and dividing by the real squared norm of
# the direction) gives the squared real projection — the contribution
# of that 1-dim real subspace to ‖grad‖²_R.
#
# This is the correct operation for Goldstone diagnosis: each generator
# (iψ for U(1), i·F_α·ψ for spin rotations) spans a 1-dim REAL subspace,
# NOT a complex line. The earlier complex-line projection conflated
# `ψ` (chemical potential, non-zero mode) with `iψ` (gauge, zero mode)
# and inflated the "Goldstone fraction" to 99.97% in the prior run.
function proj_real²(grad_cpu::AbstractArray, δψ_dir::AbstractArray, dV::Float64)
    nrm²_R = sum(abs2, δψ_dir) * dV   # = ‖δψ_dir‖²_C = ‖δψ_dir‖²_R
    nrm²_R < eps() && return 0.0
    # Directional derivative D = Re ⟨grad, δψ_dir⟩ · dV
    D = real(sum(conj.(grad_cpu) .* δψ_dir)) * dV
    return D^2 / nrm²_R
end

# Apply spin matrix F_α (n_comp × n_comp Hermitian) to psi (..., n_comp)
# pointwise in real space. Returns (..., n_comp).
function apply_spin_matrix(F::AbstractMatrix, psi::AbstractArray)
    n_comp = size(F, 1)
    n_comp == size(psi)[end] || error("spin-matrix / psi shape mismatch")
    spatial = size(psi)[1:end-1]
    psi_flat = reshape(psi, prod(spatial), n_comp)
    out_flat = psi_flat * transpose(F)   # element c: Σ_c' F[c,c'] ψ[c']
    return reshape(out_flat, spatial..., n_comp)
end

function goldstone_check(ws, label::String, dV::Float64)
    println("\n--- (Goldstone projection) at $label ---")
    psi_cpu, grad_cpu, _ = snapshot_grad(ws)
    grad_norm² = sum(abs2, grad_cpu) * dV
    @printf "‖grad‖² (total, real) = %.6e\n" grad_norm²

    # First report the CHEMICAL POTENTIAL component (real-coef
    # projection along ψ). This is NOT a zero mode — it's the
    # constraint-violation direction (changes ‖ψ‖²). In an
    # unconstrained gradient this can be huge and dominates raw
    # ‖grad‖; the LBFGS implementation should subtract it. The
    # gauge-Goldstone projection below uses iψ (orthogonal in real
    # space to ψ).
    p_mu = proj_real²(grad_cpu, psi_cpu, dV)
    @printf "  μ·ψ (chemical pot)   : ‖proj‖²_R = %.4e   fraction = %6.2f %%   [NOT a zero mode]\n" p_mu (100*p_mu/grad_norm²)

    # U(1) global phase: δψ = i·ψ (real-coef real direction).
    # Energy is gauge-invariant under e^{iθ} ⟹ Re ⟨grad, iψ⟩ = 0
    # analytically. Numerical floor ~ machine precision · grid size.
    δψ_U1 = im .* psi_cpu
    p_U1 = proj_real²(grad_cpu, δψ_U1, dV)
    @printf "  U(1) phase i·ψ       : ‖proj‖²_R = %.4e   fraction = %6.2f %%   [should be ~0]\n" p_U1 (100*p_U1/grad_norm²)

    # Spin-axis rotations: at B=0, energy is rotation-invariant about
    # any axis. Generators δψ = i·(F_α·ψ). At B≠0 the spin-rotation
    # symmetry is broken to the axis aligned with B; only F_z (or
    # whichever component aligns with the field) is preserved.
    sm = ws.spin_matrices
    Fx = Array(sm.Fx); Fy = Array(sm.Fy); Fz = Array(sm.Fz)
    δψ_Fx = im .* apply_spin_matrix(Fx, psi_cpu)
    δψ_Fy = im .* apply_spin_matrix(Fy, psi_cpu)
    δψ_Fz = im .* apply_spin_matrix(Fz, psi_cpu)
    p_Fx = proj_real²(grad_cpu, δψ_Fx, dV)
    p_Fy = proj_real²(grad_cpu, δψ_Fy, dV)
    p_Fz = proj_real²(grad_cpu, δψ_Fz, dV)
    @printf "  spin rot i·F_x·ψ     : ‖proj‖²_R = %.4e   fraction = %6.2f %%\n" p_Fx (100*p_Fx/grad_norm²)
    @printf "  spin rot i·F_y·ψ     : ‖proj‖²_R = %.4e   fraction = %6.2f %%\n" p_Fy (100*p_Fy/grad_norm²)
    @printf "  spin rot i·F_z·ψ     : ‖proj‖²_R = %.4e   fraction = %6.2f %%\n" p_Fz (100*p_Fz/grad_norm²)

    # "Zero-mode" total — these are the directions in which the energy
    # is ANALYTICALLY flat (so they should not contribute to ‖grad‖
    # for an exact gradient at any state, converged or not).
    zero_modes = p_U1 + p_Fx + p_Fy + p_Fz
    zfrac = 100 * zero_modes / grad_norm²
    @printf "  ZERO-MODE total      : ‖proj‖²_R = %.4e   fraction = %6.2f %%\n" zero_modes zfrac

    # Residual after subtracting μ·ψ AND all zero modes — what an
    # ideally-projected LBFGS should see as the "true" gradient.
    residual² = grad_norm² - p_mu - zero_modes
    @printf "  TRUE residual (post-projection) : %.4e   fraction = %6.2f %%\n" residual² (100*residual²/grad_norm²)

    # ‖P_⊥∇E‖ — the projected residual, comparable to the LBFGS gate.
    # This is what the LBFGS optimizer's `‖∇E‖` reports (it projects
    # out chemical potential each step). Reporting it here means
    # "audit residual ~ 0.45" and "sweep residual ~ 1e-4..1e-1" can be
    # placed on the same scale. The N_ITP_PREP=80 state used by this
    # audit is far from converged; expect the projected residual here
    # to be much larger than what a finished LBFGS run reports.
    res_norm = sqrt(residual²)
    n_dof_complex = length(psi_cpu)
    res_per_dof = res_norm / sqrt(n_dof_complex)
    @printf "\n  ‖P_⊥∇E‖ (L²)         = %.4e\n" res_norm
    @printf "  ‖P_⊥∇E‖ per DOF      = %.4e\n" res_per_dof
    @printf "  (LBFGS gate is 1e-5; this audit's state has 80 ITP steps,\n"
    @printf "   so a large residual is expected — what matters is the\n"
    @printf "   fraction breakdown above, not the absolute number.)\n"

    println()
    if zfrac > 50
        println("  → READ: most of ‖grad‖ lives in **symmetry zero modes**.")
        println("    Floor is Goldstone; raw ‖∇E‖<tol is principle-unattainable.")
        println("    Gate LBFGS on the projection-subtracted residual instead.")
    elseif zfrac > 5
        println("  → READ: significant zero-mode contamination of ‖grad‖.")
        println("    Mixed signal — projection cleanup will improve effective floor.")
    else
        println("  → READ: zero modes are NOT the floor.")
        println("    Bulk of ‖grad‖ is in physical (non-symmetry) directions —")
        println("    the floor is (a) local-min trap, or LBFGS line search /")
        println("    Sobolev preconditioning hitting their effective limit.")
        println("    Triad (iter↑/α↑/seed↑) is the right next move.")
    end
    copyto!(ws.state.psi, psi_cpu)
end

function main()
    println("=== M1 gradient audit ===")
    @printf "Backend: %s\n" (USE_CPU ? "CPU" : "CUDA")
    @printf "Grid: %dD, N_ITP_PREP=%d, eps grid: %s\n" length(TW.grid.x) N_ITP_PREP join([@sprintf("%.0e", e) for e in FD_EPS], ", ")
    if !USE_CPU
        @info "Free GPU memory (GB)" CUDA.free_memory() / 1e9
    end
    dV = SpinorBEC.cell_volume(TW.grid)

    println("\n[1/3] prep workspace at (B=0, Ω=0)")
    ws_no_omega = prep_workspace(0.0, 0.0)

    println("\n[2/3] FD check at Ω = 0")
    err_Ω0 = fd_check(ws_no_omega, "Ω=0", dV)

    println("\n[3/3] Goldstone classification at (B=0, Ω=0)")
    goldstone_check(ws_no_omega, "Ω=0", dV)

    println("\n[2'] prep workspace at (B=0, Ω=0.4)")
    ws_omega = prep_workspace(0.0, 0.4)

    println("\n[3'] FD check at Ω = 0.4")
    err_Ω = fd_check(ws_omega, "Ω=0.4", dV)

    println("\n=== Verdict ===")
    # Threshold: at ε = 1e-7, the FD truncation error scales as
    # ε·|f''/f'| which for a smooth Hamiltonian is O(1e-6) — so a
    # ratio within 1e-3 of 1.0 is rock-solid "gradient matches".
    THRESH = 5e-3
    if err_Ω0 < THRESH && err_Ω < THRESH
        @printf "(c) gradient/energy mismatch: NO. Asymptotic FD err = %.2e (Ω=0), %.2e (Ω=0.4)\n" err_Ω0 err_Ω
        println("  → The gradient routine IS the gradient of the energy.")
        println("    The sweep's convergence floor is NOT a gradient bug.")
        println("    Reconcile with the Goldstone diagnostic above:")
        println("     • zero-mode fraction > 50%  → (b) Goldstone floor")
        println("     • zero-mode fraction < 5%   → (a) local-min / preconditioning")
        println("    The earlier ⟨F_z⟩=4.5 high-B flip is therefore EITHER")
        println("    a local-min artifact at insufficient LBFGS iter (cure: triad),")
        println("    OR a Goldstone-floor read of a partially-relaxed texture.")
    elseif err_Ω0 < THRESH && err_Ω >= THRESH
        @printf "(c) gradient/energy mismatch at Ω≠0: YES. Asymptotic FD err = %.2e\n" err_Ω
        println("  → **STOP** the sweep. iter↑/seed↑/α↑ are useless.")
        println("    Bug is in the rotating-frame gradient (highest prior:")
        println("    Coriolis −Ω·L_z contribution or Barnett-shift coupling).")
    elseif err_Ω0 >= THRESH
        @printf "(c) gradient mismatch even at Ω=0: YES. Asymptotic FD err = %.2e\n" err_Ω0
        println("  → STATIC gradient is inconsistent. Audit grad_kinetic /")
        println("    grad_zeeman / grad_c0 / grad_c1 etc. one by one.")
    end
end

main()
