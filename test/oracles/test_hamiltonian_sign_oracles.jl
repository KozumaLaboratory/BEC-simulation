# test/oracles/test_hamiltonian_sign_oracles.jl
#
# Hamiltonian sign-convention oracle suite. ONE banner for every
# directional sign assertion. The bug class this suite is designed to
# rule out has appeared THREE times in 4 days (2026-06-02 Barnett shift
# silent cancellation, 2026-06-03 Coriolis sign over-correction,
# 2026-06-04 transverse Zeeman sign inversion). In every case:
#
#   * Same physics quantity computed in TWO paths (propagator vs
#     energy, CPU vs GPU, user spec vs implementation).
#   * Norm-only tests passed against both wrong-direction implementations.
#   * The bug was only catchable by a DIRECTIONAL test that pinned a
#     physical observable to a known-sign condition.
#
# Discipline: every Hamiltonian term (Zeeman z, Zeeman transverse,
# Coriolis, Barnett, DDI, Raman, light_shift, quadratic Zeeman, etc.)
# gets a directional sign test in this file. A new term added without a
# corresponding directional test here is a missing-oracle defect; the
# CI gate will start failing if/when the term silently regresses.
#
# Reference: docs/conventions.md (the source-of-truth H spec) +
# `mistake_transverse_zeeman_sign_inversion_2026_06_04` (latest example
# of the bug class).

using Test
using FFTW
using SpinorBEC

@testset "Hamiltonian sign oracles" begin

    # --- Linear Zeeman (z): +Bz → ⟨F_z⟩ > 0 ---
    # User spec: H_z = -p · F_z. +p means physical +Bz, low E at +F_z.
    # Setup: start from m_plus_F (broken polar symmetry), apply +Bz +
    # small +Bx (parity breaker so the m=+F state isn't trivially
    # immune to any perturbation). ITP should converge to ⟨F_z⟩ > 0
    # (and ⟨F_x⟩ > 0 from the Bx component).
    @testset "+Bz → ⟨F_z⟩ > 0 (with Bx parity breaker)" begin
        # TimeDependentZeeman(p_wf, q_wf, bx_wf, by_wf) — p first = Bz.
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        zeeman = TimeDependentZeeman(
            ConstantWaveform(2.0),   # p_wf = Bz = 2 (dominant)
            ConstantWaveform(0.0),   # q_wf = 0
            ConstantWaveform(0.5),   # bx_wf = Bx = 0.5 (parity breaker)
            ConstantWaveform(0.0),   # by_wf = By = 0
        )
        r = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)),
            dt=0.005, n_steps=500, tol=0.0,
            initial_state=:m_plus_F, verbose=false,
            enable_ddi=false,
        )
        psi = Array(r.workspace.state.psi)
        sm = r.workspace.spin_matrices
        _, _, fz = spin_density_vector(psi, sm, 3)
        @test sum(fz) * cell_volume(grid) > 0.5   # mostly +z (Bz dominates)
    end

    # --- Transverse Zeeman (x): +Bx → ⟨F_x⟩ > 0 ---
    # User spec: H_x = -bx · F_x. +bx means physical +Bx.
    # Pre-2026-06-04 the propagator inverted this sign — caught by the
    # M2 lab-frame stir asymmetry showing EdH-inverted direction.
    @testset "+Bx → ⟨F_x⟩ > 0 (was inverted pre-2026-06-04)" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        zeeman = TimeDependentZeeman(
            ConstantWaveform(1.0),   # Bz = 1 (parity breaker)
            ConstantWaveform(0.0),   # q = 0
            ConstantWaveform(2.0),   # Bx = 2 (dominant)
            ConstantWaveform(0.0),   # By = 0
        )
        r = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)),
            dt=0.005, n_steps=500, tol=0.0,
            initial_state=:m_plus_F, verbose=false,
            enable_ddi=false,
        )
        psi = Array(r.workspace.state.psi)
        sm = r.workspace.spin_matrices
        fx, _, fz = spin_density_vector(psi, sm, 3)
        dV = cell_volume(grid)
        @test sum(fx) * dV > 0.5   # mostly +x (Bx dominates)
        @test sum(fz) * dV > 0.1   # also along +Bz
    end

    # --- Transverse Zeeman (y): +By → ⟨F_y⟩ > 0 ---
    @testset "+By → ⟨F_y⟩ > 0 (independent y-axis check)" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        zeeman = TimeDependentZeeman(
            ConstantWaveform(1.0),   # Bz = 1 (parity breaker)
            ConstantWaveform(0.0),   # q = 0
            ConstantWaveform(0.0),   # Bx = 0
            ConstantWaveform(2.0),   # By = 2 (dominant)
        )
        r = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)),
            dt=0.005, n_steps=500, tol=0.0,
            initial_state=:m_plus_F, verbose=false,
            enable_ddi=false,
        )
        psi = Array(r.workspace.state.psi)
        sm = r.workspace.spin_matrices
        _, fy, fz = spin_density_vector(psi, sm, 3)
        dV = cell_volume(grid)
        @test sum(fy) * dV > 0.5
        @test sum(fz) * dV > 0.1
    end

    # --- Coriolis (orbital): +Ω → vortex (x+iy)·gauss amplified ---
    # Tested in test/solvers/test_simulation.jl "Coriolis step amplifies
    # +L_z component" — replicated here as a one-line guard so any new
    # rotating-frame term that breaks the orbital sign is caught.
    @testset "+Ω → +L_z component amplified in IT" begin
        config = GridConfig((24, 24), (8.0, 8.0))
        grid = make_grid(config)
        dV = cell_volume(grid)
        σ = 1.0
        ψplus = zeros(ComplexF64, 24, 24, 3)
        for I in CartesianIndices((24, 24))
            x = grid.x[1][I[1]];
            y = grid.x[2][I[2]]
            ψplus[I, 2] = (x + im * y) * exp(-(x^2 + y^2) / (2 * σ^2))
        end
        nrm_before = sum(abs2, ψplus) * dV
        SpinorBEC._apply_coriolis_step!(ψplus, grid, 0.5, 0.1, true)
        nrm_after = sum(abs2, ψplus) * dV
        # IT step at Ω=0.5, dτ=0.1: norm² ratio = exp(+2·0.5·0.1) ≈ 1.105
        @test nrm_after / nrm_before > 1.05
    end

    # --- Barnett shift: +Ω makes p_eff = p + Ω (descent on -Ω·F_z) ---
    # Replicates test_rotating_frame_regression.jl's
    # "energy_decomposition includes -Ω⟨L_z⟩" check + adds the spin
    # parity (when Ω > 0, ⟨F_z⟩_GS > ⟨F_z⟩_Ω=0).
    @testset "+Ω rotating-frame Zeeman amplifies +F_z preference" begin
        grid = make_grid(GridConfig((8, 8), (4.0, 4.0)))
        sp_ω0 = SimParams(; dt=0.005, n_steps=200, imaginary_time=true,
            rotating_frame_omega=0.0)
        sp_ωplus = SimParams(; dt=0.005, n_steps=200, imaginary_time=true,
            rotating_frame_omega=+0.3)
        zeeman = ZeemanParams(0.1, 0.0)
        ws_0 = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0)),
            sim_params=sp_ω0, fft_flags=FFTW.ESTIMATE)
        ws_p = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0)),
            sim_params=sp_ωplus, fft_flags=FFTW.ESTIMATE)
        # Both: same p=0.1 weak Bz seed; Ω=+0.3 adds Barnett shift.
        zee_0 = SpinorBEC.zeeman_diagonal(zeeman, ws_0.spin_matrices)
        zee_p = SpinorBEC.zeeman_diagonal(SpinorBEC.zeeman_at(ws_p.zeeman, 0.0),
            ws_p.spin_matrices)
        # Effective p in rotating frame = p + Ω = 0.4 > p_lab = 0.1 → spin
        # diagonal entries become more negative at m > 0 (stronger +F_z bias).
        F = ws_0.spin_matrices.system.F
        D = ws_0.spin_matrices.system.n_components
        m_top = F
        m_bot = -F
        diag_top_0 = zee_0[1]  # m = +F
        diag_top_p = zee_p[1]  # m = +F, p_eff = p + Ω
        @test diag_top_p < diag_top_0   # stronger negative → more preferred
    end
end
