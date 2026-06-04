# test/oracles/test_registry_strang_step_equivalence.jl
#
# B1 proof-of-concept: `strang_step_via_registry!` reproduces the
# legacy `split_step!` for the minimal Strang configuration (only
# diagonal V + kinetic K, no DDI/c1/raman/...). Bit-identity gate at
# F64 machine precision.

using Test
using FFTW
using SpinorBEC
using Random

@testset "strang_step_via_registry! ≡ split_step! (diagonal-only)" begin
    # Minimal workspace: F=1 Rb87, no DDI, no c1, no transverse Zeeman.
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    zeeman = ZeemanParams(0.5, 0.1)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws_legacy = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
        enable_ddi=false,
    )
    ws_registry = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
        enable_ddi=false,
    )

    Random.seed!(42)
    psi_ref = randn(ComplexF64, 8, 8, 8, 3)
    psi_ref ./= sqrt(sum(abs2, psi_ref) * cell_volume(grid))

    copyto!(ws_legacy.state.psi, psi_ref)
    copyto!(ws_registry.state.psi, psi_ref)

    # One step via each path
    SpinorBEC.split_step!(ws_legacy)
    SpinorBEC.strang_step_via_registry!(ws_registry, 0.01)

    diff = maximum(abs, Array(ws_registry.state.psi) .- Array(ws_legacy.state.psi))

    # The registry-based version uses the simple `V(dt/2) K(dt) V(dt/2)`
    # Strang pattern. The legacy `split_step!` uses the NESTED Strang
    # pattern: `V(dt/2) Coriolis(dt/2) K(dt) Coriolis(dt/2) V(dt/2)`
    # with V itself being a nested sandwich
    # (diag → SM → singlet_pair → tensor → raman → DDI → ...).
    #
    # For the minimal configuration here (no DDI, no SM, no Coriolis,
    # no transverse), the inner V sandwich collapses to just `diag`.
    # The Coriolis substep is a no-op when rotating_frame_omega = 0.
    # So both paths reduce to V(dt/2) K(dt) V(dt/2) and the legacy
    # call factorises the diag step the same way the registry does.
    #
    # Expected: bit-identity to F64 machine precision. (Note: the
    # 'diag' in the legacy path means the combined-density step which
    # absorbs zeeman + trap + c0_density + light_shift + LHY into one
    # exp() per voxel; the registry applies them sequentially. For
    # this configuration where only zeeman + trap are active, the
    # exponential of the SUM equals the PRODUCT of exponentials
    # because they commute (both diagonal in m AND in r), so bit
    # identity holds.)
    @info "max |Δ| between registry strang_step and legacy split_step (diag-only):" diff
    # Bit-identity: `strang_step_via_registry!` delegates the
    # nested-sandwich scheduler to `_half_potential_step!` (same
    # function as legacy), so per-operator output is identical.
    @test diff == 0.0
end

@testset "strang_step_via_registry! ≡ split_step! (full config: c1+transverse+rotation)" begin
    # Heavier config: c1 ≠ 0 (spin-mixing), bx,by ≠ 0 (transverse Zeeman),
    # Ω ≠ 0 (Coriolis+Barnett). Exercises the full nested sandwich.
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict(0 => 5.0, 1 => 0.5))
    zeeman = TimeDependentZeeman(
        ConstantWaveform(0.5), ConstantWaveform(0.1),
        ConstantWaveform(0.3), ConstantWaveform(0.2),
    )
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true, rotating_frame_omega=0.4)
    ws_a = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE, enable_ddi=false,
    )
    ws_b = make_workspace(;
        grid, atom=Rb87, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE, enable_ddi=false,
    )
    Random.seed!(42)
    psi_ref = randn(ComplexF64, 8, 8, 8, 3)
    psi_ref ./= sqrt(sum(abs2, psi_ref) * cell_volume(grid))
    copyto!(ws_a.state.psi, psi_ref)
    copyto!(ws_b.state.psi, psi_ref)

    SpinorBEC.split_step!(ws_a)
    SpinorBEC.strang_step_via_registry!(ws_b, 0.01)

    diff = maximum(abs, Array(ws_b.state.psi) .- Array(ws_a.state.psi))
    @info "max |Δ| (full config: c1+transverse+rotation):" diff
    @test diff == 0.0
end
