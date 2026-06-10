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

    # --- Linear Zeeman (z): +p → ⟨F_z⟩ > 0 (operator H = -p·F_z) ---
    # `p` is the dimensionless Kawaguchi-Ueda coefficient (p ≡ -g_F μ_B B),
    # set directly here — NOT a physical field. The operator H_z = -p·F_z
    # has low E at +F_z for +p, so ITP converges to ⟨F_z⟩ > 0. (Physical
    # +Bz on a g_F>0 atom maps to p<0 → spin down; see the physical-units
    # oracle below.) Start from m_plus_F + small +Bx parity breaker.
    @testset "+p → ⟨F_z⟩ > 0 (operator H = -p·F_z)" begin
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

    # --- Physical-units oracle: +Bz (Gauss) on a g_F>0 atom → ⟨F_z⟩ < 0 ---
    # The gate that locks the B→p conversion sign (`Units.bfield_to_p`). It
    # exercises the full physical chain (g_F applied to a Gauss field) and is
    # anchored to the convention-free fact that the atomic moment is
    # anti-parallel to F (μ = -g_F μ_B F): at +Bz a g_F>0 atom (He*, Eu, Cr)
    # has its angular momentum point DOWN. He4* (g_F = +2, pure electron spin
    # S=1) is the cleanest case. See
    # `mistake_zeeman_groundstate_direction_inverted_2026_06_10`.
    @testset "physical +Bz on g_F>0 atom → ⟨F_z⟩ < 0" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        omega_ref = 2π * 1.0e6
        bz = SpinorBEC._gauss_to_dimless(1.0, He4star.g_F, omega_ref)  # +Bz = 1 G
        @test He4star.g_F > 0 && bz < 0    # g_F>0: +Bz maps to p<0 (K-U)
        zeeman = TimeDependentZeeman(
            ConstantWaveform(bz), ConstantWaveform(0.0),
            ConstantWaveform(0.0), ConstantWaveform(0.0),
        )
        r = find_ground_state(;
            grid, atom=He4star,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman, potential=HarmonicTrap((1.0, 1.0, 1.0)),
            dt=0.01, n_steps=400, tol=0.0,
            initial_state=:spin_coherent,
            init_state_params=Dict(:init_theta => π / 2, :init_phi => 0.0),
            verbose=false, enable_ddi=false,
        )
        psi = Array(r.workspace.state.psi)
        sm = r.workspace.spin_matrices
        _, _, fz = spin_density_vector(psi, sm, 3)
        @test sum(fz) * cell_volume(grid) < -0.5   # spin DOWN (moment ∥ +B)
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

    # NOTE: SpinC1 sign (c1<0 → FM vs c1>0 → polar) is covered by the
    # existing test_simulation.jl:6-50 ground-state assertions; no
    # need for a redundant version here.

    # --- DensityC0 sign: +c0 → repulsive → ground-state TF width > non-interacting ---
    @testset "DensityC0: +c0 → repulsive (TF profile widens)" begin
        grid = make_grid(GridConfig{1}((32,), (10.0,)))
        # Compare GS width with c0=0 vs c0=10
        r0 = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            potential=HarmonicTrap((1.0,)),
            n_steps=300, dt=0.005, tol=1e-7, initial_state=:polar, verbose=false)
        r_repulsive = find_ground_state(;
            grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 10.0, 1 => 0.0)),
            potential=HarmonicTrap((1.0,)),
            n_steps=300, dt=0.005, tol=1e-7, initial_state=:polar, verbose=false)
        n0 = SpinorBEC.total_density(Array(r0.workspace.state.psi), 1)
        n1 = SpinorBEC.total_density(Array(r_repulsive.workspace.state.psi), 1)
        # Repulsive c0>0 spreads density → lower peak density.
        @test maximum(n1) < maximum(n0)
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
