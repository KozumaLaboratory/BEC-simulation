using Test
using SpinorBEC
using SpinorBEC: _outer_potential_fwd!, _outer_potential_bwd!, _ddi_step!,
    _half_potential_step!

# These tests pin the ITP and RTP non-DDI operator chains to the same code
# path. Pre-2026-06-02 they had diverged silently: the transverse Zeeman
# step (bx/by) was added to RTP's `_half_potential_step!` but never to
# ITP's `_outer_potential_{fwd,bwd}!`. In-plane B had no effect on the
# ITP ground state, and the M1-ITP Gate-1 sweep produced a B-flat map. The
# refactor merges both call sites onto `_outer_operators_{fwd,bwd}!`.
#
# These tests guard against future drift: if anyone touches one chain
# without the other, V(dt/2) via ITP vs RTP no longer agrees and the
# test fails. (Single source of truth + arithmetic equivalence check.)
@testset "ITP/RTP outer-operator equivalence" begin
    grid = make_grid(GridConfig((16, 16), (10.0, 10.0)))
    interactions = InteractionParams(Dict(0 => 1.0, 1 => 0.05))
    sp = SimParams(; dt=0.01, n_steps=10, imaginary_time=true)

    @testset "Diagonal Zeeman only" begin
        ws_itp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.3, 0.05), sim_params=sp)
        ws_rtp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.3, 0.05), sim_params=sp)
        # Seed both with the same wavefunction.
        copyto!(ws_itp.state.psi, ws_rtp.state.psi)

        # RTP path: V(dt/2) = _half_potential_step!
        _half_potential_step!(ws_rtp, sp.dt / 2, 3, 2, true)
        # ITP path: outer_fwd(dt/4) + DDI(dt/2) + outer_bwd(dt/4)
        _outer_potential_fwd!(ws_itp, sp.dt / 4, 3, 2, true)
        _ddi_step!(ws_itp, sp.dt / 2, 2, true)
        _outer_potential_bwd!(ws_itp, sp.dt / 4, 3, 2, true)

        @test ws_itp.state.psi ≈ ws_rtp.state.psi atol=1e-12
    end

    @testset "Transverse Zeeman bx/by (smoking-gun bug regression)" begin
        # The pre-2026-06-02 bug: ITP silently dropped transverse Zeeman.
        # With bx ≠ 0, the two paths gave different ψ. With the shared
        # operator-chain helper they must now agree exactly.
        td_zee = TimeDependentZeeman(
            ConstantWaveform(0.0),   # p_wf
            ConstantWaveform(0.0),   # q_wf
            ConstantWaveform(0.4),   # bx_wf — the killer of the M1 sweep
            ConstantWaveform(0.0),   # by_wf
        )
        ws_itp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=td_zee, sim_params=sp)
        ws_rtp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=td_zee, sim_params=sp)
        copyto!(ws_itp.state.psi, ws_rtp.state.psi)

        _half_potential_step!(ws_rtp, sp.dt / 2, 3, 2, true)
        _outer_potential_fwd!(ws_itp, sp.dt / 4, 3, 2, true)
        _ddi_step!(ws_itp, sp.dt / 2, 2, true)
        _outer_potential_bwd!(ws_itp, sp.dt / 4, 3, 2, true)

        @test ws_itp.state.psi ≈ ws_rtp.state.psi atol=1e-12
        # And — important sanity — bx ≠ 0 must MOVE ψ. If both paths agreed
        # but neither did anything, the test above would silently pass. We
        # repeat the V(dt/2) on a fresh bx=0 workspace and require the bx≠0
        # result to differ from it; the difference is the in-plane Zeeman
        # effect we lost pre-fix.
        ws_noB = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=ZeemanParams(0.0, 0.0), sim_params=sp)
        _half_potential_step!(ws_noB, sp.dt / 2, 3, 2, true)
        @test !isapprox(ws_itp.state.psi, ws_noB.state.psi; atol=1e-6)
    end

    @testset "Combined: bx + diag Zeeman + spin mixing" begin
        td_zee = TimeDependentZeeman(
            ConstantWaveform(0.2),
            ConstantWaveform(0.03),
            ConstantWaveform(0.4),
            ConstantWaveform(0.1),
        )
        ws_itp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=td_zee, sim_params=sp)
        ws_rtp = make_workspace(; grid, atom=Rb87, interactions,
            zeeman=td_zee, sim_params=sp)
        copyto!(ws_itp.state.psi, ws_rtp.state.psi)

        _half_potential_step!(ws_rtp, sp.dt / 2, 3, 2, true)
        _outer_potential_fwd!(ws_itp, sp.dt / 4, 3, 2, true)
        _ddi_step!(ws_itp, sp.dt / 2, 2, true)
        _outer_potential_bwd!(ws_itp, sp.dt / 4, 3, 2, true)

        @test ws_itp.state.psi ≈ ws_rtp.state.psi atol=1e-12
    end
end
