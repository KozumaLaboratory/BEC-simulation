# Validation tests for `split_step_combined!` (interpretation A: nested
# Strang with single combined linear-F rotation per V(dt/2)).
#
# Three checks:
# 1. Convergence: combined vs sequential agree to O(dt²) — quadratic in dt.
# 2. Norm + magnetization conservation across many steps.
# 3. ITP convergence: same ground state energy as sequential, within
#    the order-2 splitting tolerance.

using SpinorBEC
using Test, SpinorBEC, LinearAlgebra

const _N = 16
const _GRID = make_grid(GridConfig((_N, _N, _N), (8.0, 8.0, 8.0)))

# Transverse-arm fixture constants. Named because the closed forms the two
# transverse testsets check are written in terms of them.
const _TRANSVERSE_DT = 0.002
const _TRANSVERSE_BX = 0.4
const _TRANSVERSE_BZ = 0.5

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
    @testset "Convergence vs split_step! (shared midpoint ⇒ O(dt³) agreement)" begin
        # Both `split_step!` and `split_step_combined!` now freeze the DDI/c₁
        # mean field at the implicit-midpoint (Picard predictor-corrector) when
        # DDI is active, so their leading O(dt²) Strang error terms MATCH and
        # the two splittings (sequential SM-DDI-SM vs fused Combined) differ
        # only at O(dt³): halving dt drops the per-step diff by ~8×. (Before
        # the combined path was midpoint-symmetrised it leaked Mz and the two
        # differed at O(dt²) → ~4×.)
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
        # diff now scales as dt³ → ratio ~8× per halving (shared midpoint MF).
        ratio_1 = diffs[1] / diffs[2]
        ratio_2 = diffs[2] / diffs[3]
        @test 5.5 < ratio_1 < 11.0
        @test 5.5 < ratio_2 < 11.0
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

    # Shared fixture for the two transverse arms below. `q` is a parameter
    # because the two paths are the same operator only at q = 0 — see the
    # second arm.
    function _mk_transverse_ws(; bx, q)
        sp = SimParams(; dt=_TRANSVERSE_DT, n_steps=1, imaginary_time=false)
        zeeman = TimeDependentZeeman(
            ConstantWaveform(_TRANSVERSE_BZ), ConstantWaveform(q),
            ConstantWaveform(bx), ConstantWaveform(0.0),
        )
        ws = make_workspace(;
            grid=_GRID, atom=Eu151,
            interactions=InteractionParams(Dict(0 => 50.0, 1 => 1.0)),
            zeeman, potential=HarmonicTrap(1.0, 1.0, 1.0),
            sim_params=sp,
            enable_ddi=true, c_dd=100.0,
        )
        copyto!(ws.state.psi, init_psi(_GRID, SpinSystem(6); state=:m_plus_F))
        SpinorBEC._normalize_psi!(ws.state.psi, ws.grid, 13, 3)
        ws
    end

    function _fy_total(ws)
        _, fy, _ = SpinorBEC.spin_density_vector(
            Array(ws.state.psi), ws.spin_matrices, 3
        )
        sum(fy) * SpinorBEC.cell_volume(ws.grid)
    end

    @testset "Transverse Zeeman alive in combined path (App. A defect-8 regression)" begin
        # `zeeman_at` collapses TimeDependentZeeman to a diagonal-only
        # value, so the old `transverse_b(zee, t)` inside
        # `_apply_combined_spin_step!` returned (0, 0) — the combined
        # path's transverse branch was structurally dead. Directional
        # gate: H ⊃ −bx·Fx gives d⟨Fy⟩/dt = bx·⟨Fz⟩ > 0 from m=+F;
        # pre-fix the combined step left ⟨Fy⟩ at exactly 0 while the
        # sequential path rotated.
        #
        # q = 0 here, and that is load-bearing. This arm ran at q = 0.1 until
        # 2026-07-31 and had been red since b3881a23 unified the quadratic
        # Zeeman to the FIELD AXIS, `q(b̂·F)²`. With b tilted, that term
        # contributes at first order — the closed form from m = +F is
        #
        #   d⟨F_y⟩/dt = bx⟨F_z⟩ − 2q sinθcosθ ⟨F_z² − F_x²⟩
        #             = 0.4·6 − 2(0.1)(0.4879)(33) = −0.820,
        #
        # i.e. −1.64e-3 after one dt — which is exactly what the sequential
        # path measured. The physics was right and the assertion was stale.
        # The second arm below pins the divergence itself.
        ws_seq = _mk_transverse_ws(; bx=_TRANSVERSE_BX, q=0.0)
        SpinorBEC.split_step!(ws_seq)
        ws_comb = _mk_transverse_ws(; bx=_TRANSVERSE_BX, q=0.0)
        SpinorBEC.split_step_combined!(ws_comb)
        fy_seq = _fy_total(ws_seq)
        fy_comb = _fy_total(ws_comb)
        # At q = 0 the drive is the whole first-order story, so compare against
        # the closed form rather than a bare sign — a threshold of 1e-4 against
        # a 4.8e-3 signal would also pass on a step 48x too small.
        predicted = _TRANSVERSE_BX * 6 * _TRANSVERSE_DT
        @test isapprox(fy_seq, predicted; rtol=0.05)   # sequential sees the drive
        @test isapprox(fy_comb, predicted; rtol=0.05)  # combined does too (defect 8)
        @test isapprox(fy_comb, fy_seq; rtol=0.05)     # same operator, O(dt²) apart
    end

    @testset "Tilted field with q ≠ 0: the paths differ, and RTP declines" begin
        # `_apply_combined_spin_step!` folds only the LINEAR transverse
        # −(bx F_x + by F_y) into its rotation and leaves a lab-z `q F_z²` in
        # the diagonal step, while the sequential path applies the whole tilted
        # `−(b·F) + q(b̂·F)²` as one eigen-exact matrix. Those are the same
        # operator only along ẑ or at q = 0, which `_rtp_use_combined_step`
        # documents and guards.
        #
        # The guard is what production depends on, so gate the guard — and gate
        # that the divergence it exists for is real, otherwise a future change
        # could make the two paths agree and leave a guard nobody notices is
        # now pointless.
        q = 0.1
        ws_seq = _mk_transverse_ws(; bx=_TRANSVERSE_BX, q)
        SpinorBEC.split_step!(ws_seq)
        ws_comb = _mk_transverse_ws(; bx=_TRANSVERSE_BX, q)
        SpinorBEC.split_step_combined!(ws_comb)
        fy_seq = _fy_total(ws_seq)
        fy_comb = _fy_total(ws_comb)

        # Sequential = the field-axis closed form, sign included.
        θ = atan(_TRANSVERSE_BX, _TRANSVERSE_BZ)
        predicted_seq = (_TRANSVERSE_BX * 6 - 2q * sin(θ) * cos(θ) * (36 - 3)) *
                        _TRANSVERSE_DT
        @test isapprox(fy_seq, predicted_seq; rtol=0.05)
        @test fy_seq < 0                       # the q term dominates and flips it

        # Combined = the lab-z form, which from a pure m state contributes
        # nothing at first order, so it lands on the q = 0 answer.
        @test isapprox(fy_comb, _TRANSVERSE_BX * 6 * _TRANSVERSE_DT; rtol=0.05)

        # Hence: production must not take this path here. Both arms run with
        # COMBINED_SPIN_STEP_ENABLED forced on — it is `false` by default and
        # is the FIRST thing the guard checks, so a `== false` measured at the
        # default would pass even with the tilt check deleted. The axial arm is
        # the positive control: it must come back `true`, or the tilted `false`
        # is not evidence about the tilt.
        axial = _mk_transverse_ws(; bx=0.0, q)
        old = SpinorBEC.COMBINED_SPIN_STEP_ENABLED[]
        SpinorBEC.COMBINED_SPIN_STEP_ENABLED[] = true
        try
            @test SpinorBEC._rtp_use_combined_step(ws_comb) == false
            @test SpinorBEC._rtp_use_combined_step(axial) == true
        finally
            SpinorBEC.COMBINED_SPIN_STEP_ENABLED[] = old
        end
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
