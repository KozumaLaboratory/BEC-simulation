using Test
using SpinorBEC

@testset "save_state / load_state round-trip" begin
    gc = GridConfig((32,), (10.0,))
    grid = make_grid(gc)
    atom = AtomSpecies("test-io", 1.0, 1, 0.0, 0.0)
    ip = InteractionParams(Dict(0 => 100.0, 1 => -0.5, 2 => 0.0, 4 => 5.0); c_lhy=0.1)
    zee = ZeemanParams(0.3, 0.8)

    sp = SimParams(; dt=0.002, n_steps=100, imaginary_time=false, save_every=100)
    ws = make_workspace(;
        grid, atom,
        interactions=ip,
        zeeman=zee,
        potential=HarmonicTrap(1.0),
        sim_params=sp,
    )

    # Evolve a few steps so t > 0
    for _ in 1:10
        split_step!(ws)
    end

    fname = tempname() * ".jld2"
    try
        save_state(fname, ws)
        data = load_state(fname)

        @test data.atom_name == "test-io"
        @test data.grid_n_points == (32,)
        @test data.grid_box_size == (10.0,)
        @test data.t == ws.state.t
        @test data.step == ws.state.step
        @test data.psi ≈ ws.state.psi

        @test data.c0 == 100.0
        @test data.c1 == -0.5
        @test data.c_lhy == 0.1
        @test data.c_dict[4] == 5.0
        @test get(data.c_dict, 2, 0.0) == 0.0
        @test data.zeeman_p == 0.3
        @test data.zeeman_q == 0.8
        @test data.c_dd == 0.0
        @test data.dt == 0.002
        @test data.imaginary_time == false
    finally
        rm(fname; force=true)
    end
end

@testset "save_state with DDI" begin
    gc = GridConfig((32,), (10.0,))
    grid = make_grid(gc)
    atom = AtomSpecies("test-io-ddi", 1.0, 1, 0.0, 0.0)

    sp = SimParams(; dt=0.001, n_steps=10, imaginary_time=false, save_every=10)
    ws = make_workspace(;
        grid, atom,
        interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.0)),
        potential=NoPotential(),
        sim_params=sp,
        enable_ddi=true, c_dd=50.0,
    )

    fname = tempname() * ".jld2"
    try
        save_state(fname, ws)
        data = load_state(fname)
        @test data.c_dd == 50.0
    finally
        rm(fname; force=true)
    end
end

@testset "_concat_dynamics_phases boundary dedup — snapshots align with times" begin
    # Each dynamics phase produces (n+1)-length time series (incl. initial frame).
    # Phase 2+ should drop its first frame to avoid duplicating the previous
    # phase's last frame at the boundary. The dedup MUST apply to both the
    # time-aligned scalar traces AND the psi_snapshots so the saved file's
    # `dynamics/times` and `dynamics/psi_snapshots_streamed/n_snapshots`
    # agree (frontend TimeScrubber relies on this).
    function _fake_phase(n_frames::Int, t_start::Float64, dt::Float64)
        times = collect(range(t_start, step=dt, length=n_frames))
        norms = ones(Float64, n_frames)
        mags = zeros(Float64, n_frames)
        snaps = [ones(ComplexF64, 2, 2, 2, 3) for _ in 1:n_frames]
        sim = SimulationResult(times, ones(Float64, n_frames), norms, mags, snaps)
        (
            dynamics_result=sim,
            snapshot_tmp_path=nothing,
            save_psi_snapshots=true,
            snapshot_count=n_frames,
            ensemble_result=nothing,
        )
    end
    p1 = _fake_phase(5, 0.0, 0.1)   # times 0.0 .. 0.4
    p2 = _fake_phase(6, 0.0, 0.05)  # times 0.0 .. 0.25, joins phase 1's end
    p3 = _fake_phase(4, 0.0, 0.02)  # times 0.0 .. 0.06

    out = SpinorBEC._concat_dynamics_phases([p1, p2, p3])
    # First phase keeps all frames; subsequent drop first (boundary).
    expected_n = 5 + (6 - 1) + (4 - 1)   # = 13
    @test length(out[:times]) == expected_n
    @test length(out[:norms]) == expected_n
    @test length(out[:Fz]) == expected_n
    # Snapshots must agree — this was the pre-2026-05-13 mismatch
    # (snapshots used to skip the dedup and ended up 2 longer per phase
    # boundary, e.g. 17 times vs 18 snapshots on eu151_edh_k3_compare).
    @test length(out[:psi_snapshots]) == expected_n
end
