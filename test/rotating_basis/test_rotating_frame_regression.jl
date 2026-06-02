using Test
using FFTW
using SpinorBEC
using SpinorBEC: _rebuild_workspace_with_dt

# Regression tests for the rotating-frame bug class identified in code review:
#
#  - SimParams positional reconstruction in run_simulation_checkpointed!,
#    _rebuild_workspace_with_dt, and stability_analysis.jl previously dropped
#    `rotating_frame_omega` (and `spin_rotating_frame_omega`) by truncating
#    the field list. Symptom: rotating-frame ITP / RTP silently lost the
#    Coriolis step on resume.
#
#  - energy_decomposition omitted the -Ω⟨L_z⟩ piece, so dE-based ITP
#    convergence tracked H_lab while the propagator drove toward H_rot's
#    minimum.
#
#  - DYNAMICS_SCHEMA was missing `rotating_frame_omega`, and the pipeline
#    runner did not forward it to find_ground_state. YAML keys were silently
#    dropped.

@testset "rotating-frame regression" begin
    config = GridConfig((16, 16), (10.0, 10.0))
    grid = make_grid(config)
    interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.0))

    @testset "SimParams positional 5-arg / 6-arg do NOT touch caller fields" begin
        # The 5-arg/6-arg constructors zero by design; callers must instead
        # use the kwarg form or pass all 7 positional args. This test pins
        # that contract so future refactors don't silently drop fields.
        sp_full = SimParams(; dt=0.01, n_steps=100,
            rotating_frame_omega=0.7,
            spin_rotating_frame_omega=0.3)
        sp_5arg = SimParams(0.01, 100, false, 1, 10)
        sp_6arg = SimParams(0.01, 100, false, 1, 10, 0.5)
        @test sp_5arg.rotating_frame_omega == 0.0
        @test sp_5arg.spin_rotating_frame_omega == 0.0
        @test sp_6arg.rotating_frame_omega == 0.5
        @test sp_6arg.spin_rotating_frame_omega == 0.0
        # 7-arg keeps both:
        sp_7arg = SimParams(0.01, 100, false, 1, 10, 0.5, 0.2)
        @test sp_7arg.rotating_frame_omega == 0.5
        @test sp_7arg.spin_rotating_frame_omega == 0.2
    end

    @testset "_rebuild_workspace_with_dt preserves rotating fields" begin
        omega = 0.4
        spin_omega = 0.2
        sp = SimParams(; dt=0.01, n_steps=100, imaginary_time=true,
            rotating_frame_omega=omega,
            spin_rotating_frame_omega=spin_omega)
        ws = make_workspace(; grid, atom=Rb87, interactions, sim_params=sp,
            fft_flags=FFTW.ESTIMATE)
        ws2 = _rebuild_workspace_with_dt(ws, 0.005)
        @test ws2.sim_params.dt == 0.005
        @test ws2.sim_params.rotating_frame_omega == omega
        @test ws2.sim_params.spin_rotating_frame_omega == spin_omega
    end

    @testset "energy_decomposition includes -Ω⟨L_z⟩" begin
        omega = 0.3
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=omega)
        ws = make_workspace(; grid, atom=Rb87, interactions, sim_params=sp,
            fft_flags=FFTW.ESTIMATE)
        # Initialize to a smooth real Gaussian (⟨L_z⟩ ≈ 0); no need to be
        # normalized — we're only checking the decomposition shape and that
        # coriolis is included in the total sum.
        ws.state.psi .= 0.0
        for I in CartesianIndices((16, 16))
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]]
            ws.state.psi[I, 1] = exp(-(x*x + y*y) / 4)
        end
        ed = SpinorBEC.energy_decomposition(ws)
        @test haskey(ed, :coriolis)
        @test isfinite(ed.coriolis)
        @test isfinite(ed.total)
        # Coriolis must contribute to total exactly:
        bare =
            ed.kinetic + ed.trap + ed.zeeman + ed.density + ed.spin +
            ed.ddi + ed.lhy + ed.tensor + ed.raman + ed.light_shift
        @test ed.total ≈ bare + ed.coriolis atol = 1e-10
    end

    @testset "energy_decomposition coriolis = 0 when Ω = 0" begin
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=0.0)
        ws = make_workspace(; grid, atom=Rb87, interactions, sim_params=sp,
            fft_flags=FFTW.ESTIMATE)
        ws.state.psi .= 0.0
        ws.state.psi[8, 8, 1] = 1.0
        ed = SpinorBEC.energy_decomposition(ws)
        @test ed.coriolis == 0.0
    end

    # Pre-2026-06-02 `_shift_zeeman_for_rotating_frame` used `z.p − omega`,
    # which silently *cancelled* the Barnett −Ω·F_z term instead of installing
    # it. Symptom: passing the lab-frame p (z.p = p_lab) gave a rotating-frame
    # state with ⟨F_z⟩ < 0 (anti-Barnett) instead of > 0. The half-term
    # cancellation was missed because the orbital piece −Ω·L_z worked, so
    # vortex nucleation looked correct while the spin piece was inverted.
    # sprint5_M1_barnett_test caught it; see mistake memo
    # `mistake_frame_transformation_half_term_silent_cancellation`.
    @testset "Barnett shift sign convention (post-2026-06-02 fix)" begin
        # ZeemanParams: passing z.p = p_lab → effective_p = p_lab + Ω.
        # `-effective_p · F_z` gives `-p_lab · F_z - Ω · F_z` (Barnett included).
        shifted = SpinorBEC._shift_zeeman_for_rotating_frame(
            ZeemanParams(0.3, 0.05), 0.4)
        @test shifted.p ≈ 0.7
        @test shifted.q == 0.05
        # Sign of the addend: + Ω, not − Ω.
        shifted_zero_p = SpinorBEC._shift_zeeman_for_rotating_frame(
            ZeemanParams(0.0, 0.0), 0.5)
        @test shifted_zero_p.p ≈ 0.5

        # TimeDependentZeeman: ShiftedWaveform must add Ω too.
        td = TimeDependentZeeman(
            ConstantWaveform(0.0), ConstantWaveform(0.0),
            ConstantWaveform(0.3),  # bx
            ConstantWaveform(0.0),
        )
        td_shifted = SpinorBEC._shift_zeeman_for_rotating_frame(td, 0.4)
        @test SpinorBEC.linear_p(td_shifted, 0.0) ≈ 0.4
        # Transverse components untouched by frame shift.
        bx, by = SpinorBEC.transverse_b(td_shifted, 0.0)
        @test bx ≈ 0.3
        @test by ≈ 0.0
    end

    @testset "make_workspace stores the +Ω Barnett shift" begin
        # Composition test: ensures `make_workspace` actually calls
        # `_shift_zeeman_for_rotating_frame` with the right sign convention
        # — guards against future refactors removing the call site or
        # negating the sign at the workspace boundary.
        omega = 0.5
        sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=omega)
        ws = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.3, 0.05), sim_params=sp,
            fft_flags=FFTW.ESTIMATE)
        # Effective p should be lab + Ω, not lab − Ω.
        @test ws.zeeman.p ≈ 0.8
        @test ws.zeeman.q ≈ 0.05
        # Ω = 0 path must NOT shift.
        sp0 = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=0.0)
        ws0 = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.3, 0.05), sim_params=sp0,
            fft_flags=FFTW.ESTIMATE)
        @test ws0.zeeman.p ≈ 0.3
    end
end
