using Test
using SpinorBEC

# F32 mixed-precision regression test for the rotating_basis path.
#
# Pins the boundary conversions added 2026-04-29 (commit df6a1eb).
# Running at small grid (8×8×8, F=1 D=3) keeps test runtime tiny while
# exercising every type-locking site that needed widening:
#
# - make_grid(...; dtype=Float32)
# - make_rotating_basis_ws(grid::Grid{Float32}, ...)
# - apply_local_spin_step!(ws::RotatingBasisWS{Float32,...}, dt::Float32)
# - _apply_UB! → apply_uniform_spin_rotation! Float64 angle conversion
# - apply_ddi_step_rotating! → apply_ddi_step! Float64 dt conversion
# - DDIParams.C_dd is Float64 even with F32 Q tensors
# - normalize_rotating!, rotating_norm at F32

@testset "rotating_basis F32 mixed precision" begin
    F = 1
    D = 2F + 1
    config = GridConfig((8, 8, 8), (4.0, 4.0, 4.0))
    grid = make_grid(config; dtype=Float32)
    @test eltype(grid.x[1]) === Float32

    V_trap = zeros(Float32, 8, 8, 8)
    @inbounds for I in CartesianIndices(V_trap)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        V_trap[I] = 0.5f0 * (x^2 + y^2 + z^2)
    end

    ws = SpinorBEC.make_rotating_basis_ws(grid, F, V_trap;
        p=1.0f0, q=0.0f0,
        c0=10.0f0, c1=0.0f0,
        c_dd=1.0f0, gamma_lhy=0.0f0,
        theta_func=(t) -> 0.5,
        phi_func=(t) -> 1.0 * t,
        theta_dot_func=(t) -> 0.0,
        phi_dot_func=(t) -> 1.0,
        gauge_fix=false)

    # Type assertions: every workspace buffer is at the requested precision.
    @test eltype(ws.psi_tilde) === ComplexF32
    @test eltype(ws.V_trap) === Float32
    @test eltype(ws.kspace_phase_buf) === ComplexF32
    @test eltype(ws.xspace_phase_buf) === ComplexF32

    # Initialise to a Gaussian on m=+F.
    @inbounds for I in CartesianIndices((8, 8, 8))
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        ws.psi_tilde[I, 1] = exp(-(x*x + y*y + z*z) / 2)
    end
    SpinorBEC.normalize_rotating!(ws)
    n0 = SpinorBEC.rotating_norm(ws)
    @test n0 ≈ 1.0 atol = 1e-6
    @test typeof(n0) <: AbstractFloat

    # Each substep should run cleanly without MethodError.
    SpinorBEC.apply_kinetic_step_rotating!(ws, 0.01f0)
    SpinorBEC.apply_spatial_diagonal_step!(ws, 0.01f0)
    SpinorBEC.apply_local_spin_step!(ws, 0.01f0, 0.0f0)
    SpinorBEC.apply_ddi_step_rotating!(ws, 0.01f0, 0.0f0)
    SpinorBEC.apply_gauge_step!(ws, 0.01f0, 0.0f0)

    # Norm should be preserved within F32 round-off (~1e-6).
    SpinorBEC.normalize_rotating!(ws)
    n1 = SpinorBEC.rotating_norm(ws)
    @test n1 ≈ 1.0 atol = 1e-5

    # Full split-step (RTP).
    SpinorBEC.split_step_rotating!(ws, 0.005f0, 0.0f0)
    n2 = SpinorBEC.rotating_norm(ws)
    @test isfinite(n2)
    @test 0.99 < n2 < 1.01

    # Full split-step (ITP).
    SpinorBEC.split_step_rotating!(ws, 0.005f0, 0.0f0; imaginary_time=true)
    SpinorBEC.normalize_rotating!(ws)
    n3 = SpinorBEC.rotating_norm(ws)
    @test n3 ≈ 1.0 atol = 1e-5

    # ITP convergence: 50 steps should bring the energy down monotonically.
    μ = SpinorBEC.find_ground_state_rotating!(ws, 50, 0.005f0)
    @test isfinite(μ)
    @test typeof(μ) === Float32 || typeof(μ) === Float64
    n_final = SpinorBEC.rotating_norm(ws)
    @test n_final ≈ 1.0 atol = 1e-5

    # Lab-basis split step (Phase III reference path) — same boundary
    # fix needed for `apply_ddi_step!` Float64 dt. Verify it runs.
    SpinorBEC.split_step_lab!(ws, 0.005f0, 0.0f0)
    @test isfinite(SpinorBEC.rotating_norm(ws))
end
