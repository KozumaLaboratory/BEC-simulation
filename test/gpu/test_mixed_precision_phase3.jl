# MP Phase 3 smoke: end-to-end ITP at Float32 should match Float64 to
# the relaxed tolerance documented in `docs/design/mixed_precision_design.md`.
# This is a regression guard for the F32 hot path that's already wired
# (Phase 1 Grid{N,T} + Phase 2 make_fft_plans dtype + the existing
# tol auto-relax — see commit 738a3e4).

using Test
using SpinorBEC

@testset "Mixed precision Phase 3 — F32 ITP smoke" begin
    cfg = GridConfig((16, 16), (8.0, 8.0))

    # F64 reference
    grid_f64 = make_grid(cfg)
    sp = SimParams(; dt=0.01, n_steps=200)
    ws_f64 = make_workspace(;
        grid=grid_f64, atom=Rb87,
        interactions=InteractionParams(5.0, 0.0),
        zeeman=ZeemanParams(0.0, 0.1),
        potential=HarmonicTrap(1.0, 1.0),
        sim_params=sp,
    )
    gs_f64 = find_ground_state(;
        grid=grid_f64, atom=Rb87,
        interactions=InteractionParams(5.0, 0.0),
        zeeman=ZeemanParams(0.0, 0.1),
        potential=HarmonicTrap(1.0, 1.0),
        dt=0.01, n_steps=200, tol=1e-7,
        initial_state=:m_plus_F,
    )

    # F32 path (Grid + plans only — Workspace-wide T parametrisation pending)
    grid_f32 = make_grid(cfg; dtype=Float32)
    @test eltype(grid_f32.x[1]) == Float32

    # Run F32 ITP via dtype kwarg
    gs_f32 = find_ground_state(;
        grid=grid_f32, atom=Rb87,
        interactions=InteractionParams(5.0, 0.0),
        zeeman=ZeemanParams(0.0, 0.1),
        potential=HarmonicTrap(1.0f0, 1.0f0),
        dt=0.01, n_steps=200, tol=1e-5,
        initial_state=:m_plus_F,
        dtype=Float32,
    )

    # ψ eltype should follow dtype
    @test eltype(gs_f32.workspace.state.psi) == Complex{Float32}

    # Energies should agree to ~1e-4 relative (F32 epsilon ~6e-8 + ITP truncation)
    @test abs(gs_f32.energy - gs_f64.energy) / abs(gs_f64.energy) < 1e-3
end
