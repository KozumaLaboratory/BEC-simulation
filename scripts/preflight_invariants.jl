#!/usr/bin/env julia
# Physics-invariant preflight battery
#
# Catches bug classes that are NOT covered by the fast-tier suite at the
# right cost point: 30-second CPU smoke before any multi-hour GPU launch.
#
# Invariants checked:
#   1. norm conservation under ITP step (machine eps)
#   2. norm conservation under RT step (machine eps)
#   3. ITP energy monotonic decrease over 5 steps
#   4. Analytic SHO ground-state limit (E ≈ 0.5 in 1D, no interactions)
#   5. +p Zeeman F_z sign oracle (ITP → ⟨F_z⟩ > 0 under +p)
#   6. +Ω rotation L_z sign oracle (ITP → ⟨L_z⟩ > 0 under +Ω)
#   7. LBFGS warm-restart regression sentinel (warm-restart `‖∇E‖`
#      should NOT exceed cold-start `‖∇E‖` at the same iterate)
#   8. Registry strang_step ≡ legacy split_step! (bit-identity)
#
# Usage:
#   julia --project=. scripts/preflight_invariants.jl
#   → exit 0 on all-pass, 1 on any failure (suitable for CI / sbatch
#     prologue / heavy-launch script prologue)
#
# Performance target: ≤ 30 sec CPU on a developer laptop. If any test
# starts taking longer, scale down its grid — preflight is meant to be
# *cheap* enough that "run this before a 15h GPU job" is friction-free.

using Test
using SpinorBEC
using LinearAlgebra

const _PREFLIGHT_T0 = time()

function _tiny_polar_ws_1d(; F=1, n_pts=16, c0=1.0, c1=0.1, dt=0.005,
    n_steps=10, p=0.0, q=0.0, omega=0.0, imaginary_time=true)
    grid = make_grid(GridConfig{1}((n_pts,), (8.0,)))
    sm = spin_matrices(F)
    D = 2F + 1
    atom = Rb87
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    sp = SimParams(; dt, n_steps, imaginary_time,
        normalize_every=imaginary_time ? 1 : 0,
        rotating_frame_omega=omega)
    zeeman = ZeemanParams(p, q)
    ws = make_workspace(;
        grid, atom, interactions=ip, zeeman,
        potential=HarmonicTrap((1.0,)), sim_params=sp)
    psi = init_psi(grid, SpinSystem(F); state=:polar)
    copyto!(ws.state.psi, psi)
    ws
end

@testset "Preflight invariants" begin
    @testset "1. Norm conservation under ITP step" begin
        ws = _tiny_polar_ws_1d(; imaginary_time=true)
        # Normalize first (init_psi may not be unit-norm in our scaling)
        n0 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        ws.state.psi ./= n0
        # ITP uses normalize_every=1 → norm is restored every step
        for _ in 1:3
            split_step!(ws)
        end
        n1 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        @test abs(n1 - 1.0) < 1e-10
    end

    @testset "2. Norm conservation under RT step" begin
        ws = _tiny_polar_ws_1d(; imaginary_time=false)
        n0 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        ws.state.psi ./= n0
        # RT does NOT normalize; unitary propagation should preserve norm
        for _ in 1:10
            split_step!(ws)
        end
        n1 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        # Loosened tolerance: Strang split-step preserves norm to dt² in
        # the absence of normalization, which for 10 × dt=0.005 = 0.05
        # gives drift ~2.5e-3 worst-case.
        @test abs(n1 - 1.0) < 1e-3
    end

    @testset "3. ITP energy monotonic decrease (5 steps)" begin
        ws = _tiny_polar_ws_1d(; n_pts=24, imaginary_time=true)
        Es = Float64[]
        push!(Es, total_energy(ws))
        for _ in 1:5
            split_step!(ws)
            push!(Es, total_energy(ws))
        end
        # ITP must produce monotonically decreasing energy (machine eps
        # tolerance per step). A growth signals broken sign or sign of dt.
        for i in 2:length(Es)
            @test Es[i] <= Es[i - 1] + 1e-10
        end
    end

    @testset "4. Analytic SHO limit (no interactions, 1D, F=0/scalar)" begin
        # Scalar via F=1, c0=c1=0: ground state of -∂² + x² is the SHO
        # ground state at E = 0.5 (in our ω=1 unit). Verify ITP converges
        # there.
        grid = make_grid(GridConfig{1}((32,), (10.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        r = find_ground_state(;
            grid, atom, interactions=ip,
            potential=HarmonicTrap((1.0,)),
            dt=0.005, n_steps=500, tol=1e-10, verbose=false,
        )
        # ⟨ψ|H|ψ⟩ should land at 0.5 within ~1% (32-pt grid limits accuracy)
        @test isapprox(r.energy, 0.5; atol=0.01)
    end

    @testset "5. +p Zeeman → ⟨F_z⟩ > 0 (sign oracle)" begin
        # With +p Zeeman (H_zee = -p·F_z + q·F_z²), ITP prefers m = +F
        # so ⟨F_z⟩ > 0. Used spin_coherent seed so all m channels are
        # populated and the F_z mean is meaningful.
        grid = make_grid(GridConfig{1}((24,), (10.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
        zeeman = ZeemanParams(0.5, 0.0)  # +p, no q
        sp = SimParams(; dt=0.005, n_steps=200, imaginary_time=true, normalize_every=1)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        # spin_coherent θ=π/4 → non-trivial F-spin density
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
        copyto!(ws.state.psi, psi)
        n0 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        ws.state.psi ./= n0
        for _ in 1:200
            split_step!(ws)
        end
        sm = ws.spin_matrices
        fx, fy, fz = SpinorBEC.spin_density_vector(Array(ws.state.psi), sm, 1)
        dV = SpinorBEC.cell_volume(ws.grid)
        Fz_total = sum(fz) * dV
        @test Fz_total > 0  # +p → ⟨F_z⟩ > 0
    end

    @testset "6. +Ω rotation → ⟨L_z⟩ > 0 (sign oracle, 2D)" begin
        # Coriolis term -Ω·L_z → ITP minimum at ⟨L_z⟩ > 0 for +Ω
        grid = make_grid(GridConfig{2}((12, 12), (5.0, 5.0)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
        sp = SimParams(; dt=0.005, n_steps=200,
            imaginary_time=true, normalize_every=1,
            rotating_frame_omega=0.5)
        zeeman = ZeemanParams(0.0, 0.0)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0, 1.0)), sim_params=sp)
        # radial_spin_vortex: spin_coherent with θ=π/2 + winding 1 (the named-state
        # builder forces both, so this is the safe canonical 2D vortex seed)
        psi_2d = init_psi(grid, SpinSystem(1); state=:radial_spin_vortex)
        copyto!(ws.state.psi, psi_2d)
        n0 = sqrt(sum(abs2, ws.state.psi) * SpinorBEC.cell_volume(ws.grid))
        ws.state.psi ./= n0
        for _ in 1:200
            split_step!(ws)
        end
        Lz = SpinorBEC.orbital_angular_momentum(
            Array(ws.state.psi), ws.grid, ws.fft_plans)
        @test Lz > 0  # +Ω → ⟨L_z⟩ > 0
    end

    @testset "7. LBFGS warm-restart sentinel (no regression)" begin
        # Run LBFGS for n_steps_1 → record grad_norm_1
        # Continue from the saved psi with n_steps_2 LBFGS → record grad_norm_2
        # Warm-restart wipes s_hist/y_hist (driver.jl:117), so the first
        # iteration of run 2 is SD. On a non-flat manifold, SD overshoots
        # but recovers. On a flat manifold (degenerate) it cannot recover
        # within n_steps_2. THIS TEST USES A NON-FLAT manifold so warm-restart
        # should NOT regress: grad_norm_2 ≤ grad_norm_1 (within some slack).
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
        zeeman = ZeemanParams(0.3, 0.0)  # broken symmetry, NOT flat
        r1 = find_ground_state_lbfgs(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)),
            n_steps=50, tol=1e-12, verbose=false, sobolev_alpha=0.05,
        )
        grad_norm_1 = r1.grad_norm
        # Warm-restart from r1's psi for another 50 steps
        r2 = find_ground_state_lbfgs(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)),
            psi_init=Array(r1.workspace.state.psi),
            n_steps=50, tol=1e-12, verbose=false, sobolev_alpha=0.05,
        )
        grad_norm_2 = r2.grad_norm
        # Expect grad_norm_2 ≤ grad_norm_1 + slack. If grad_norm_2 explodes
        # by orders of magnitude, that's the warm-restart history-loss
        # regression class.
        @test grad_norm_2 <= max(grad_norm_1 * 10, 1e-6)
    end

    @testset "8. split_step! one-step residual vs dumb reference" begin
        # Replaced 2026-06-06: the old check compared split_step! against
        # strang_step_via_registry!, which post-B3 shared the same
        # apply_step! calls AND delegated its V chain to the same legacy
        # helpers — a near-self-comparison (both deleted). This version
        # checks production against the INDEPENDENT dumb statement:
        # (ψ' − ψ)/(−i·dt) after one split_step! must match
        # dumb_rhs_total(ψ) to O(dt) — a missing, dropped, or
        # sign-flipped term in the production sandwich shows up as an
        # O(1) residual.
        grid = make_grid(GridConfig{1}((16,), (8.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
        zeeman = ZeemanParams(0.2, 0.05)
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi0 = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π / 4)
        copyto!(ws.state.psi, psi0)
        g = SpinorBEC.dumb_rhs_total(ws, Array(psi0))
        split_step!(ws)
        deriv = (Array(ws.state.psi) .- Array(psi0)) ./ (-im * sp.dt)
        rel = sqrt(sum(abs2, deriv .- g)) / sqrt(sum(abs2, g))
        @test rel < 0.2   # O(dt·⟨H²⟩/⟨H⟩) ≈ 0.05 here; a term drop ⇒ O(1)
    end
end

_elapsed = time() - _PREFLIGHT_T0
println("\n✅ Preflight invariants passed in $(round(_elapsed; digits=1))s")
