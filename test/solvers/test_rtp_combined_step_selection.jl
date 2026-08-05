# `COMBINED_SPIN_STEP_ENABLED` in the production RTP loop.
#
# `split_step_combined!` merges spin-mixing + DDI into ONE per-voxel rotation
# per half-V (3 rotations → 1). It has been tested since it was written, but
# nothing outside its own test file called it — `_run_simulation_leapfrog!` went
# through `_half_potential!` unconditionally. This file gates the wiring:
#
#   1. the toggle actually changes which splitting the loop takes;
#   2. the selector DECLINES every workspace the combined step cannot represent
#      (that is the load-bearing safety property — a wrong `true` silently
#      drops physics, e.g. a c₂ singlet channel or a tilted-field q F_z²);
#   3. the two splittings agree, and agree BETTER as dt shrinks — they are
#      different O(dt²) integrators of the same Hamiltonian, so the test is
#      convergence to a common answer, not bitwise equality.

using Test
using SpinorBEC
using SpinorBEC: _rtp_use_combined_step, COMBINED_SPIN_STEP_ENABLED,
    _combined_step_unusable_full

const _CSS_GRID = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))

function _css_ws(; c1=0.4, c2=0.0, ddi=true, bx=0.0, q=0.0, dt=2.0e-3, n_steps=1)
    ip = if c2 == 0.0
        InteractionParams(Dict(0 => 6.0, 1 => c1))
    else
        InteractionParams(Dict(0 => 6.0, 1 => c1, 2 => c2))
    end
    # A transverse arm needs the TimeDependentZeeman shape — ZeemanParams
    # carries only (p, q).
    zee = if bx == 0.0
        ZeemanParams(0.3, q)
    else
        TimeDependentZeeman(ConstantWaveform(0.3), ConstantWaveform(q),
            ConstantWaveform(bx), ConstantWaveform(0.0))
    end
    ws = make_workspace(;
        grid=_CSS_GRID, atom=Rb87, interactions=ip, zeeman=zee,
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=SimParams(; dt, n_steps, save_every=10^6),
        enable_ddi=ddi, c_dd=ddi ? 30.0 : NaN)
    psi = init_psi(_CSS_GRID, ws.spin_matrices.system;
        state=:spin_coherent, init_theta=0.7, init_phi=0.3)
    copyto!(ws.state.psi, psi)
    ws
end

@testset "RTP combined-step selector" begin
    old = COMBINED_SPIN_STEP_ENABLED[]
    try
        COMBINED_SPIN_STEP_ENABLED[] = false
        @test !_rtp_use_combined_step(_css_ws())          # off ⇒ never selected

        COMBINED_SPIN_STEP_ENABLED[] = true
        @test _rtp_use_combined_step(_css_ws())           # the eligible shape

        # Everything the combined form cannot represent must be declined.
        @test !_rtp_use_combined_step(_css_ws(; c2=0.2))  # singlet channel
        @test !_rtp_use_combined_step(_css_ws(; ddi=false))  # no Φ scratch

        # A TILTED field is declined even though `_apply_combined_spin_step!`
        # has a transverse branch: that branch folds only the LINEAR -(b⊥·F)
        # into the rotation and leaves a lab-z q F_z² in the diagonal step,
        # whereas the sequential path applies the whole tilted Zeeman
        # -(b·F) + q(b̂·F)² as one eigen-exact matrix. Same operator only when
        # the field is axial or q = 0.
        @test !_rtp_use_combined_step(_css_ws(; bx=0.2, q=0.1))
    finally
        COMBINED_SPIN_STEP_ENABLED[] = old
    end
end

@testset "dynamics.spin_step: parsing" begin
    @test SpinorBEC._parse_spin_step(nothing) == false      # default: sequential
    @test SpinorBEC._parse_spin_step("sequential") == false
    @test SpinorBEC._parse_spin_step("combined") == true
    @test SpinorBEC._parse_spin_step("COMBINED") == true
    # A typo must not silently fall back to the default splitting.
    @test_throws ArgumentError SpinorBEC._parse_spin_step("combine")
    @test_throws ArgumentError SpinorBEC._parse_spin_step("yoshida")

    # The schema accepts it on a dynamics step, and rejects a bad value there
    # rather than at run time.
    cfg = Dict{String, Any}(
        "pipeline" => [
            Dict{String, Any}(
                "dynamics" => Dict{String, Any}(
                    "duration" => 0.01, "dt" => 1.0e-3, "spin_step" => "combined"),
            ),
        ],
    )
    @test (SpinorBEC.validate_pipeline!(deepcopy(cfg)); true)
    bad = deepcopy(cfg)
    bad["pipeline"][1]["dynamics"]["spin_step"] = "combine"
    @test_throws Exception SpinorBEC.validate_pipeline!(bad)
end

@testset "combined vs sequential: same solution, converging in dt" begin
    old = COMBINED_SPIN_STEP_ENABLED[]
    # Same physical duration at each dt, so the comparison is of the SOLUTION
    # at a fixed time and the difference is the two integrators' O(dt²) errors.
    T_final = 0.02
    diffs = Float64[]
    try
        for dt in (2.0e-3, 1.0e-3, 5.0e-4)
            n_steps = round(Int, T_final / dt)
            psis = map((false, true)) do combined
                COMBINED_SPIN_STEP_ENABLED[] = combined
                ws = _css_ws(; dt, n_steps)
                @test _rtp_use_combined_step(ws) == combined
                run_simulation!(ws)
                Array(ws.state.psi)
            end
            push!(diffs, maximum(abs, psis[2] .- psis[1]) / maximum(abs, psis[1]))
        end
    finally
        COMBINED_SPIN_STEP_ENABLED[] = old
    end

    # Both are second order, so the gap between them must fall like dt².
    # Checking the RATIO rather than an absolute tolerance is what makes this a
    # statement about the integrators rather than about this particular dt.
    @test diffs[1] > diffs[2] > diffs[3]
    @test diffs[2] / diffs[3] > 2.5      # ≥ ~dt^1.3; dt² would be 4
    @test diffs[1] / diffs[2] > 2.5
    @test diffs[3] < 1e-4                # and small in absolute terms
end
