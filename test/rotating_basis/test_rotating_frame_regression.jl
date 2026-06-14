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

    # `energy_gradient!` (the LBFGS gradient) was missing the Coriolis
    # −Ω·L_z·ψ term pre-2026-06-02. LBFGS in the rotating frame silently
    # minimised a wrong functional that omitted the orbital half of
    # H_rot = H_lab − Ω(L_z + F_z). The Barnett shift was folded in via
    # `_shift_zeeman_for_rotating_frame`, but the orbital piece was not
    # added to the gradient. Adding −Ω·L_z·ψ (root fix; not a script-level
    # workaround) makes LBFGS in rotating frame work for everyone. See
    # `feedback_never_patch_when_root_fix_is_available` for the anko rule
    # this fix follows.
    @testset "energy_gradient! includes Coriolis −Ω·L_z·ψ" begin
        sys = SpinSystem(1)
        grid_2d = make_grid(GridConfig((16, 16), (8.0, 8.0)))
        ip_f1 = InteractionParams(Dict{Int, Float64}(0 => 0.0, 1 => 0.0))
        pot_2d = HarmonicTrap{2}((1.0, 1.0))
        omega = 0.1

        # Compare gradient at +Ω vs −Ω with the vortex state seated in
        # the m = 0 spinor channel. This isolates the Coriolis −Ω·L_z·ψ
        # contribution from the other rotating-frame additions:
        #   * Zeeman shift (linear in Ω): zero at m = 0.
        #   * Centrifugal trap modification (quadratic in Ω): identical
        #     at ±Ω → cancels in (grad_{+Ω} − grad_{−Ω}) / 2.
        # So (grad_{+Ω} − grad_{−Ω}) / 2 isolates the Coriolis piece
        # exactly. Expected value after the grad ·= 2 final scale:
        # −2·Ω·L_z·ψ_v = −2·Ω·ψ_v for the L_z = +1 vortex eigenstate.
        sp_p = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=(+omega))
        sp_m = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=(-omega))
        ws_p = make_workspace(; grid=grid_2d, atom=Rb87, interactions=ip_f1,
            potential=pot_2d, sim_params=sp_p, fft_flags=FFTW.ESTIMATE)
        ws_m = make_workspace(; grid=grid_2d, atom=Rb87, interactions=ip_f1,
            potential=pot_2d, sim_params=sp_m, fft_flags=FFTW.ESTIMATE)

        psi_v = zeros(ComplexF64, 16, 16, 3)
        for I in CartesianIndices((16, 16))
            x = grid_2d.x[1][I[1]];
            y = grid_2d.x[2][I[2]]
            psi_v[I, 2] = (x + im * y) * exp(-(x*x + y*y) / 2)  # m = 0 channel
        end

        grad_p = similar(psi_v)
        grad_m = similar(psi_v)
        SpinorBEC.energy_gradient!(grad_p, psi_v, ws_p)
        SpinorBEC.energy_gradient!(grad_m, psi_v, ws_m)

        coriolis_isolated = (grad_p .- grad_m) ./ 2
        expected = -2 * omega * psi_v
        nrm = sqrt(sum(abs2, psi_v[:, :, 2]))
        rel_err = sqrt(sum(abs2, coriolis_isolated[:, :, 2] .- expected[:, :, 2])) / nrm
        # 16² discrete FFT loses ~5% on the vortex eigenstate at this box;
        # 32² tightens to <1%. 10% is robust against grid coarseness.
        @test rel_err < 0.1

        # Other spinor channels were not populated; Coriolis acts
        # componentwise (L_z is orbital, not spin) so they stay zero.
        @test maximum(abs, coriolis_isolated[:, :, 1]) < 1e-10
        @test maximum(abs, coriolis_isolated[:, :, 3]) < 1e-10
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
        @test linear_p(ws.zeeman) ≈ 0.8
        @test quadratic_q(ws.zeeman) ≈ 0.05
        # Ω = 0 path must NOT shift.
        sp0 = SimParams(; dt=0.01, n_steps=10, imaginary_time=true,
            rotating_frame_omega=0.0)
        ws0 = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.3, 0.05), sim_params=sp0,
            fft_flags=FFTW.ESTIMATE)
        @test linear_p(ws0.zeeman) ≈ 0.3
    end
end
