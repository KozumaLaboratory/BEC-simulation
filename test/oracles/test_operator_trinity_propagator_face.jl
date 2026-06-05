# test/oracles/test_operator_trinity_propagator_face.jl
#
# The THIRD face of the operator trinity: propagator ↔ apply_operator.
#
# Energy↔gradient is already verified by test_operator_trinity_per_term.jl
# (the FD oracle). But the propagator (apply_step!) is a SEPARATE code
# path that exponentiates the same operator — the "same coefficient
# source" is INTENT, not VERIFIED. This file adds the verification:
#
#   For RT (imaginary_time=false): in the Δt → 0 limit,
#     ( apply_step!(Δt, ψ) − ψ ) / ( −i · Δt ) → apply_operator!(ψ)
#
#   For ITP (imaginary_time=true) the analogous limit is
#     ( apply_step!(Δτ, ψ) − ψ ) / ( −Δτ ) → apply_operator!(ψ)
#
# Catches drift between the propagator's coefficient and the
# operator's coefficient — exactly the bug class behind the
# 2026-06-04 transverse-Zeeman sign inversion.

using Test
using SpinorBEC
using SpinorBEC: apply_operator!, apply_step!, HamTerm
using SpinorBEC:
    TrapTerm, LinearZeemanZTerm, DensityC0Term,
    SpinC1Term, TransverseZeemanTerm, CoriolisTerm,
    KineticTerm, LightShiftTerm, MagneticGradientTerm
using LinearAlgebra
using Random

"""
    propagator_residual(term, ws, psi; dt=1e-5, imaginary_time=false)

Compute the propagator-↔-operator residual at small dt:
  RT:  ‖ (step!(ψ, dt) − ψ) / (−i·dt)  −  apply_operator!(ψ) ‖_L² / ‖apply_op(ψ)‖_L²
  ITP: ‖ (step!(ψ, dt) − ψ) / (−dt)    −  apply_operator!(ψ) ‖_L² / ‖apply_op(ψ)‖_L²
"""
function propagator_residual(term::HamTerm, ws, psi; dt=1e-5, imaginary_time=false)
    Hpsi = similar(psi)
    fill!(Hpsi, 0)
    apply_operator!(Hpsi, term, ws, psi)

    psi_evolved = copy(psi)
    apply_step!(term, psi_evolved, dt, imaginary_time, ws)
    Δψ = psi_evolved .- psi
    derivative_estimate = imaginary_time ? (Δψ ./ (-dt)) : (Δψ ./ (-im * dt))

    dV = SpinorBEC.cell_volume(ws.grid)
    residual_norm = sqrt(sum(abs2, derivative_estimate .- Hpsi) * dV)
    op_norm = sqrt(sum(abs2, Hpsi) * dV)
    return residual_norm / max(op_norm, 1e-30)
end

function _tiny_ws(; F=1, c0=0.5, c1=0.1, p=0.3, q=0.05)
    grid = make_grid(GridConfig{1}((8,), (6.0,)))
    atom = Rb87
    ip = InteractionParams(Dict(0 => c0, 1 => c1))
    zeeman = ZeemanParams(p, q)
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true, normalize_every=1)
    make_workspace(;
        grid, atom, interactions=ip, zeeman,
        potential=HarmonicTrap((1.0,)), sim_params=sp)
end

@testset "Operator-trinity propagator face: apply_step! ⇒ apply_operator (Δt→0)" begin
    rng = MersenneTwister(7)

    @testset "TrapTerm (RT)" begin
        ws = _tiny_ws()
        psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π/3)
        res = propagator_residual(TrapTerm(), ws, psi; dt=1e-5, imaginary_time=false)
        @test res < 1e-3
    end

    @testset "TrapTerm (ITP)" begin
        ws = _tiny_ws()
        psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π/3)
        res = propagator_residual(TrapTerm(), ws, psi; dt=1e-5, imaginary_time=true)
        @test res < 1e-3
    end

    @testset "LinearZeemanZTerm (RT)" begin
        ws = _tiny_ws()
        psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π/4)
        term = LinearZeemanZTerm(0.3, 0.05)
        res = propagator_residual(term, ws, psi; dt=1e-5, imaginary_time=false)
        @test res < 1e-3
    end

    @testset "DensityC0Term (RT, mean-field)" begin
        ws = _tiny_ws()
        psi = init_psi(ws.grid, SpinSystem(1); state=:spin_coherent, init_theta=π/5)
        dV = SpinorBEC.cell_volume(ws.grid)
        psi ./= sqrt(sum(abs2, psi) * dV)
        term = DensityC0Term(0.5)
        # DensityC0 propagator uses density n(ψ) which is held fixed during
        # the exp step — apply_operator returns c0·n·ψ for SAME n. The
        # Δt→0 limit reproduces this exactly.
        res = propagator_residual(term, ws, psi; dt=1e-5, imaginary_time=false)
        @test res < 1e-3
    end

    @testset "TransverseZeemanTerm (RT, off-diagonal)" begin
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        zeeman_td = TimeDependentZeeman(
            ConstantWaveform(0.0), ConstantWaveform(0.0),
            ConstantWaveform(0.3), ConstantWaveform(0.2),
        )
        sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=true,
            normalize_every=1)
        ws = make_workspace(;
            grid, atom, interactions=ip, zeeman=zeeman_td,
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π/4)
        term = TransverseZeemanTerm(0.3, 0.2)
        res = propagator_residual(term, ws, psi; dt=1e-5, imaginary_time=false)
        # The propagator uses Rodrigues rotation, apply_operator builds
        # the H matrix entry; agreement should be linear-in-dt clean.
        @test res < 1e-2
    end

    @testset "CoriolisTerm (RT, 3-shear FFT propagator)" begin
        # 2D required for L_z. The Coriolis propagator uses a 3-shear FFT
        # decomposition; apply_operator uses +iΩ·(x∂_y - y∂_x). Both must
        # agree at Δt→0. THIS IS WHERE THE 2026-06-04 SIGN BUG LIVED —
        # the 3-shear factor signs got flipped, then reverted. This oracle
        # would catch any future drift between propagator shear factors
        # and the operator's L_z action.
        grid = make_grid(GridConfig{2}((8, 8), (4.0, 4.0)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        sp = SimParams(; dt=1e-4, n_steps=1, imaginary_time=false,
            normalize_every=0, rotating_frame_omega=0.3)
        ws = make_workspace(;
            grid, atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0, 1.0)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:fl_vortex)
        dV = SpinorBEC.cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)
        term = CoriolisTerm(0.3)
        res = propagator_residual(term, ws, psi; dt=1e-4, imaginary_time=false)
        # 3-shear FFT has O(dt) leading error in the residual; tolerance 1e-2
        @test res < 1e-2
    end

    @testset "KineticTerm (RT, dt matched to cached kinetic_phase)" begin
        # `apply_kinetic_step_batched!` uses a CACHED kinetic_phase built
        # at workspace construction time with the workspace's sim_params.dt.
        # The apply_step!(::KineticTerm, ..., dt, ...) signature looks like
        # it honors dt but the cache-based implementation ignores it (perf
        # choice). For the Δt→0 oracle to be meaningful we must pass
        # dt = sim_params.dt (the cache's actual dt).
        grid = make_grid(GridConfig{1}((8,), (6.0,)))
        atom = Rb87
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        # Use small dt for the kinetic cache so Taylor truncation O(dt²) is tight.
        # CRITICAL: `imaginary_time=false` to match the RT apply_step branch —
        # the kinetic cache is also IT/RT-hardcoded at workspace build time.
        sp = SimParams(; dt=1e-4, n_steps=1, imaginary_time=false,
            normalize_every=0)
        ws = make_workspace(;
            grid, atom, interactions=ip,
            zeeman=ZeemanParams(0.0, 0.0),
            potential=HarmonicTrap((1.0,)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:spin_coherent, init_theta=π/4)
        dV = SpinorBEC.cell_volume(grid)
        psi ./= sqrt(sum(abs2, psi) * dV)
        # Pass dt MATCHING the cache (sim_params.dt = 1e-4):
        res = propagator_residual(KineticTerm(), ws, psi;
            dt=1e-4, imaginary_time=false)
        @test res < 1e-2  # O(dt) truncation at dt=1e-4 ⇒ ~1e-4 residual
    end
end
