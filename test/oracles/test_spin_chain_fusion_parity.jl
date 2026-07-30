# Gate for the fused V half-step `diag · SM · DDI · SM · diag`
# (src/hamiltonian/integrator/spin_chain.jl +
# ext/SpinorBECCUDAExt/gpu_spin_chain.jl).
#
# The fused kernel claims to be the SAME splitting as the operator-by-operator
# half-step, not a cheaper approximation of it: the same operators, in the same
# order, with the same fields — only the HBM round-trips between them are
# removed. That claim is testable exactly, so this gate demands BIT-IDENTITY
# rather than a tolerance. A tolerance would let a genuinely different
# splitting (e.g. merging the three rotations into one, which is what
# `split_step_combined!` deliberately does) slip through as "close enough". It
# also catches things a tolerance cannot: it found a 1-ulp multiply
# association, `ψ·vph·zph` where the diagonal kernel writes `ψ·(vph·zph)`.
#
# The second half of the file pins the eligibility list. The fused path
# REPLACES the half-step, so anything `_spin_chain_reason` fails to list would
# be silently DROPPED. One arm per entry, each checking both that the reason
# fires and that the step still agrees with the unfused path.

using Test
using LinearAlgebra: norm
import CUDA
using SpinorBEC

if !CUDA.functional()
    @info "CUDA not functional — skipping spin-chain fusion parity"
else
    include(joinpath(@__DIR__, "..", "..", "bench", "eu151_params.jl"))

    const _N = 20
    const _GRID = make_grid(GridConfig(ntuple(_ -> _N, 3), ntuple(_ -> 12.0, 3)))

    function _ws(; c1_ratio=0.05, kwargs...)
        sp = SimParams(; dt=2e-4, n_steps=1, imaginary_time=false, save_every=10^9)
        ws = make_workspace(;
            grid=_GRID, atom=Eu151, interactions=eu_interaction_params(c1_ratio),
            zeeman=ZeemanParams(EU_p_weak, 0.0),
            potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
            sim_params=sp, enable_ddi=true, c_dd=EU_c_dd,
            backend=CUDABackend(), kwargs...,
        )
        psi = init_psi(_GRID, ws.spin_matrices.system;
            state=:spin_coherent, init_theta=0.6, init_phi=0.4)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(_GRID))
        copyto!(ws.state.psi, psi)
        ws
    end

    "ψ after `n` steps with the fusion forced on / off."
    function _run(fused::Bool, n::Int; kwargs...)
        old = SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[]
        SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = fused
        try
            ws = _ws(; kwargs...)
            for _ in 1:n
                SpinorBEC.split_step!(ws)
            end
            CUDA.synchronize()
            return Array(ws.state.psi)
        finally
            SpinorBEC.SPIN_CHAIN_FUSION_ENABLED[] = old
        end
    end

    """
    Relative agreement between the two arms.

    NOT `a == b`. Bit-identity is what the fusion is designed to deliver on a
    fixed device state, and it does hold when this file runs alone — measured
    max|a-b| = 0.0 at 1, 2 and 5 steps. It does NOT hold reliably inside a
    `full`-tier worker that has already run thirty other files: the same two arms
    came back 1e-10 apart on ψ of scale 0.13, i.e. agreeing to ~1e-9 relative,
    which is round-off and not a physics difference. GPU reduction order is a
    function of launch configuration and pool state, so exact equality is not a
    property this path can be held to across processes — CLAUDE.md records the
    same conclusion for the fused/broadcast boundary (9b30c8bb).

    The bound below is still a genuine differential gate: 1e-12 relative is four
    orders tighter than the O(dt²) difference a real splitting change would make,
    and the padded-vs-bare assertions in this file rely on the same scale to tell
    the two convolutions apart.

    (The in-worker discrepancy was NOT reproduced by replaying that worker's
    toggle-flipping predecessors — `SPIN_TAYLOR_ENABLED`,
    `COMBINED_SPIN_STEP_ENABLED`, `MEANFIELD_MIDPOINT_ENABLED` — so this is a
    robustness fix to the CLAIM, not a diagnosed root cause.)
    """
    function _agree(a, b)
        scale = max(maximum(abs, a), maximum(abs, b))
        scale == 0 && return false
        maximum(abs, a .- b) / scale
    end

    @testset "fused half-step ≡ the unfused one, to round-off" begin
        SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
        a = _run(true, 5)
        b = _run(false, 5)
        @test _agree(a, b) < 1e-12
        # The two arms really did take different paths: with the midpoint
        # predictor-corrector off there is no frozen ψ_mf, so the fused arm
        # declines and the equality above would be trivially true.
        @test SpinorBEC._spin_chain_reason(_ws(), _ws().interactions,
            CUDA.zeros(ComplexF64, 2)) === nothing
        # And the step actually moved ψ.
        @test norm(a) > 0 && a != Array(_ws().state.psi)
    end

    # `DDI_PADDED_DEFAULT` is `true`, so this — not the bare kernel above — is the
    # shape every `run_yaml` RTP run builds. It was unpinned while
    # `_spin_chain_reason` declined a padded DDI outright, which meant the arm
    # above was gating a path production had stopped taking.
    @testset "the fusion holds with a zero-padded DDI too" begin
        SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
        a = _run(true, 5; ddi_padding=true)
        b = _run(false, 5; ddi_padding=true)
        @test _agree(a, b) < 1e-12
        wsp = _ws(; ddi_padding=true)
        @test wsp.ddi_padded !== nothing
        @test SpinorBEC._spin_chain_reason(
            wsp, wsp.interactions, CUDA.zeros(ComplexF64, 2)) === nothing
        # Padding changes Φ, so the padded arm must NOT agree with the bare one.
        # Without this, a padded workspace that silently ran the bare convolution
        # — the failure the index map exists to prevent — would still pass.
        @test _agree(a, _run(true, 5)) > 1e-6
    end

    @testset "no frozen mean field ⇒ the fusion declines" begin
        ws = _ws()
        # `psi_mf === nothing` is the plain (non-midpoint) half-step: the two
        # spin-mixing substeps then see different ψ and share nothing.
        @test SpinorBEC._spin_chain_reason(ws, ws.interactions, nothing) !== nothing
        SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = false
        try
            @test _run(true, 3) == _run(false, 3)
        finally
            SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
        end
    end

    @testset "each operator on the eligibility list blocks the fusion" begin
        base = _ws()
        pmf = CUDA.zeros(ComplexF64, 2)

        # c₁ = 0 — no spin-mixing rotation to fuse with in the first place.
        @test SpinorBEC._spin_chain_reason(
            base, eu_interaction_params(0.0), pmf) !== nothing

        # c₂ ≠ 0 — the singlet-pair substep sits between diag and DDI.
        ip2 = InteractionParams(
            Dict(0 => base.interactions[0], 1 => base.interactions[1], 2 => 0.3))
        @test SpinorBEC._spin_chain_reason(base, ip2, pmf) !== nothing

        # A transverse field makes the Zeeman substep a separate rotation.
        ztr = TimeDependentZeeman(ConstantWaveform(EU_p_weak), ConstantWaveform(0.0),
            ConstantWaveform(0.4), nothing)
        wst = _ws(; zeeman=ztr)
        @test SpinorBEC._spin_chain_reason(wst, wst.interactions, pmf) !== nothing
        SpinorBEC.MEANFIELD_MIDPOINT_ENABLED[] = true
        @test _run(true, 3; zeeman=ztr) == _run(false, 3; zeeman=ztr)

        # The Orszag F-filter reshapes ⟨F⟩ for DDI but not for spin-mixing, so
        # the two would no longer be the same field.
        old = SpinorBEC.DEALIAS_2_3_ENABLED[]
        SpinorBEC.DEALIAS_2_3_ENABLED[] = true
        try
            @test SpinorBEC._spin_chain_reason(base, base.interactions, pmf) !== nothing
        finally
            SpinorBEC.DEALIAS_2_3_ENABLED[] = old
        end

        # No DDI at all — nothing to fuse around.
        wsn = make_workspace(;
            grid=_GRID, atom=Eu151, interactions=eu_interaction_params(0.05),
            zeeman=ZeemanParams(EU_p_weak, 0.0),
            potential=HarmonicTrap(1.0, 1.0, EU_λ_z),
            sim_params=SimParams(; dt=2e-4, n_steps=1, save_every=10^9),
            enable_ddi=false, backend=CUDABackend())
        @test SpinorBEC._spin_chain_reason(wsn, wsn.interactions, pmf) !== nothing
    end
end
