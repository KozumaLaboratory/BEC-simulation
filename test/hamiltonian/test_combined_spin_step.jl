# Validation tests for `split_step_combined!` (interpretation A: nested
# Strang with single combined linear-F rotation per V(dt/2)).
#
# Three checks:
# 1. Convergence: combined vs sequential agree to O(dt²) — quadratic in dt.
# 2. Norm + magnetization conservation across many steps.
# 3. ITP convergence: same ground state energy as sequential, within
#    the order-2 splitting tolerance.

using Test, SpinorBEC, LinearAlgebra

const _N = 16
const _GRID = make_grid(GridConfig((_N, _N, _N), (8.0, 8.0, 8.0)))

# Helper: build a workspace with DDI on, c1 nonzero, non-trivial psi.
function _make_ws_with_active_spin(dt::Float64; imaginary_time::Bool=false)
    sp = SimParams(; dt=dt, n_steps=1, imaginary_time=imaginary_time)
    ws = make_workspace(;
        grid=_GRID, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
        zeeman=ZeemanParams(0.5, 0.1),
        potential=HarmonicTrap(1.0, 1.0, 1.0),
        sim_params=sp,
        enable_ddi=true, c_dd=100.0,
    )
    @inbounds for I in CartesianIndices((_N, _N, _N))
        x = _GRID.x[1][I[1]]
        y = _GRID.x[2][I[2]]
        z = _GRID.x[3][I[3]]
        g = exp(-(x*x + y*y + z*z) / 2.0)
        for c in 1:13
            ws.state.psi[I, c] = g * cis(0.1 * c)
        end
    end
    SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, 13, 3)
    ws
end

@testset "split_step_combined!" begin
    @testset "Order-2 convergence vs split_step!" begin
        # The two splittings (sequential SM-DDI-SM vs single Combined)
        # differ at O(dt²). Halving dt should drop the per-step diff
        # by ~4×.
        diffs = Float64[]
        for dt in (0.005, 0.0025, 0.00125)
            ws = _make_ws_with_active_spin(dt)
            psi0 = copy(ws.state.psi)
            n0 = sqrt(SpinorBEC.total_norm(psi0, _GRID))

            ws.state.t = 0.0;
            ws.state.step = 0
            SpinorBEC.split_step!(ws)
            psi_seq = copy(ws.state.psi)

            copyto!(ws.state.psi, psi0);
            ws.state.t = 0.0;
            ws.state.step = 0
            SpinorBEC.split_step_combined!(ws)
            psi_comb = copy(ws.state.psi)

            push!(diffs, sqrt(sum(abs2, psi_seq .- psi_comb)) / n0)
        end
        # diff should scale as dt² → ratio ~4× per halving.
        ratio_1 = diffs[1] / diffs[2]
        ratio_2 = diffs[2] / diffs[3]
        @test 3.5 < ratio_1 < 4.5
        @test 3.5 < ratio_2 < 4.5
    end

    @testset "Norm conservation over 200 steps" begin
        ws = _make_ws_with_active_spin(0.005)
        n0 = sqrt(SpinorBEC.total_norm(ws.state.psi, _GRID))
        for _ in 1:200
            SpinorBEC.split_step_combined!(ws)
        end
        n_final = sqrt(SpinorBEC.total_norm(ws.state.psi, _GRID))
        @test isapprox(n_final, n0; atol=1e-10)
    end

    @testset "Mz drift matches standard split_step!" begin
        # Note: DDI mean-field is NOT exactly Mz-conserving (only the
        # full pair Hamiltonian is — the frozen mean-field approximation
        # leaks). So we can't test Mz constancy. Instead we check the
        # combined and sequential schemes produce the SAME drift, since
        # both use the same mean-field treatment.
        ws_seq = _make_ws_with_active_spin(0.005)
        ws_comb = _make_ws_with_active_spin(0.005)
        sys = ws_seq.spin_matrices.system

        for _ in 1:50
            SpinorBEC.split_step!(ws_seq)
            SpinorBEC.split_step_combined!(ws_comb)
        end
        Mz_seq = SpinorBEC.magnetization(ws_seq.state.psi, ws_seq.grid, sys)
        Mz_comb = SpinorBEC.magnetization(ws_comb.state.psi, ws_comb.grid, sys)
        # Both schemes drift by similar amounts due to mean-field DDI;
        # the difference between them should be small (O(dt²) per step,
        # bounded over 50 steps).
        @test isapprox(Mz_seq, Mz_comb; atol=0.01)
    end

    @testset "Transverse Zeeman alive in combined path (App. A defect-8 regression)" begin
        # `zeeman_at` collapses TimeDependentZeeman to a diagonal-only
        # value, so the old `transverse_b(zee, t)` inside
        # `_apply_combined_spin_step!` returned (0, 0) — the combined
        # path's transverse branch was structurally dead. Directional
        # gate: H ⊃ −bx·Fx gives d⟨Fy⟩/dt = bx·⟨Fz⟩ > 0 from m=+F;
        # pre-fix the combined step left ⟨Fy⟩ at exactly 0 while the
        # sequential path rotated.
        dt = 0.002
        bx = 0.4
        sp = SimParams(; dt=dt, n_steps=1, imaginary_time=false)
        zeeman = TimeDependentZeeman(
            ConstantWaveform(0.5), ConstantWaveform(0.1),
            ConstantWaveform(bx), ConstantWaveform(0.0),
        )
        function _mk_transverse_ws()
            ws = make_workspace(;
                grid=_GRID, atom=Eu151,
                interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
                zeeman, potential=HarmonicTrap(1.0, 1.0, 1.0),
                sim_params=sp,
                enable_ddi=true, c_dd=100.0,
            )
            psi0 = init_psi(_GRID, SpinSystem(6); state=:m_plus_F)
            copyto!(ws.state.psi, psi0)
            SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, 13, 3)
            ws
        end
        function _fy_total(ws)
            _, fy, _ = SpinorBEC.spin_density_vector(
                Array(ws.state.psi), ws.spin_matrices, 3
            )
            sum(fy) * SpinorBEC.cell_volume(ws.grid)
        end
        ws_seq = _mk_transverse_ws()
        SpinorBEC.split_step!(ws_seq)
        ws_comb = _mk_transverse_ws()
        SpinorBEC.split_step_combined!(ws_comb)
        fy_seq = _fy_total(ws_seq)
        fy_comb = _fy_total(ws_comb)
        @test fy_seq > 1e-4                       # sequential sees the drive
        @test fy_comb > 1e-4                      # combined does too (defect 8)
        @test isapprox(fy_comb, fy_seq; rtol=0.05)  # same physics, O(dt²) apart
    end

    @testset "Asserts on incompatible workspace" begin
        # c2 ≠ 0 should throw. Note c_extra[1] = c2, c_extra[2] = c3, ...
        # (so [1.0] sets c2=1).
        sp = SimParams(; dt=0.005, n_steps=1)
        ws_c2 = make_workspace(;
            grid=_GRID, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0, 2 => 1.0); c_lhy=0.0),  # c2=1
            zeeman=ZeemanParams(0.5, 0.1),
            potential=HarmonicTrap(1.0, 1.0, 1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=100.0,
        )
        @test_throws ArgumentError SpinorBEC.split_step_combined!(ws_c2)

        # No DDI buffers → throw
        ws_nodi = make_workspace(;
            grid=_GRID, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
            zeeman=ZeemanParams(0.5, 0.1),
            potential=HarmonicTrap(1.0, 1.0, 1.0),
            sim_params=sp,
            enable_ddi=false,
        )
        @test_throws ArgumentError SpinorBEC.split_step_combined!(ws_nodi)

        # Padded DDI: the combined path always runs the UNPADDED
        # convolution, so a configured padded context would be silently
        # ignored. Refuse loudly instead (App. A defect-9 audit).
        # Rb87 F=1 keeps the c0/c1 path (no tensor_cache) so the padded
        # guard is the ONLY incompatibility that fires.
        gridp = make_grid(GridConfig((8, 8), (6.0, 6.0)))
        ws_pad = make_workspace(;
            grid=gridp, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.5)),
            zeeman=ZeemanParams(0.5, 0.1), potential=HarmonicTrap((1.0, 1.0)),
            sim_params=SimParams(; dt=0.005, n_steps=1),
            enable_ddi=true, c_dd=10.0, ddi_padding=true,
        )
        @test ws_pad.ddi_padded !== nothing
        @test_throws ArgumentError SpinorBEC.split_step_combined!(ws_pad)
    end
end
