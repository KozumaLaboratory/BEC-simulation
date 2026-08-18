using Test
using FFTW
using LinearAlgebra
using SpinorBEC
using SpinorBEC: _spin_chain_reason, _combined_step_unusable_full,
    _rtp_use_combined_step, COMBINED_SPIN_STEP_ENABLED, DEALIAS_2_3_ENABLED,
    _lhy_needs_spin

# Two guards, one property, and they had drifted apart.
#
# `_spin_chain_reason` (spin_chain.jl) decides whether the FUSED spin chain may
# replace the general chain. `_combined_step_unusable` (combined_spin_step.jl)
# decides the same thing for the COMBINED half-potential step. Both answer "does
# an operator sit inside the region I am about to collapse into one rotation?",
# both are hand-written lists, and neither derives from the other.
#
# MEASURED 2026-08-08, 8^3 Rb87 + DDI, one workspace per condition:
#
#   condition            spin_chain   combined    rtp selector
#   baseline             no           no          uses combined
#   c2 != 0              declines     declines    declines
#   tensor               declines     declines    declines
#   raman                declines     declines    declines
#   spatial LHY          declines     ->NOTHING<- ->USES COMBINED<-
#   spatial Zeeman       declines     declines    declines
#   transverse Zeeman    declines     no          declines   (selector catches it)
#   magnetic gradient    declines     no          uses combined
#   dealias on           declines     no          uses combined
#
# The `spatial LHY` row was the defect: `_half_potential_step_combined!` never
# calls `apply_spatial_lhy_spin_step!` — its only two call sites are in the
# general chain, split_step.jl:632 and :708 — so a `spinor_lhy=:spatial`
# workspace took the combined path with that substep silently absent. Reachable
# from YAML with `dynamics: {spin_step: combined, lhy: {kind: spatial}}`; no
# config under `runs/` sets either, so nothing in the tree was affected.
#
# The last three rows diverge LEGITIMATELY and that is why this file declares a
# table instead of asserting the two lists are equal:
#   * magnetic gradient — the combined path calls `_apply_mg_to_V!` /
#     `_remove_mg_from_V!` itself (combined_spin_step.jl:186,188,195,197).
#   * transverse Zeeman — the combined rotation MERGES it (docstring at
#     combined_spin_step.jl:323); `_rtp_use_combined_step` declines it anyway.
#   * dealias — the RTP loop applies the Orszag filter itself, around whichever
#     half-V it chose (run_loops.jl:163-166 and :174-177).
# Each of those was checked by reading the code, not assumed. A row whose
# `combined_carries_it` is `true` is a claim that the combined path handles the
# operator, and the citation is in the table.

@testset "the two spin-step guards agree, or say why not" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    inter = InteractionParams(Dict(0 => 20.0, 1 => -0.4))
    sp = SimParams(; dt=0.005, n_steps=1, imaginary_time=false)
    base = (; grid, atom=Rb87, interactions=inter, zeeman=ZeemanParams(0.3, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp,
        enable_ddi=true, c_dd=1.0, ddi_padding=false, fft_flags=FFTW.ESTIMATE)
    mk(; kw...) = make_workspace(; merge(base, NamedTuple(kw))...)

    "A polarisation ramp — SpatialLHY tabulates against |⟨F⟩|/F, so a uniform
    spinor makes the table degenerate and the arm would pass for a fixture
    reason rather than a physics one."
    ramp = let psi = zeros(ComplexF64, 8, 8, 8, 3)
        for I in CartesianIndices((8, 8, 8))
            x = grid.x[1][I[1]]
            f = clamp((x + 3.0) / 6.0, 0.0, 1.0)
            a = exp(-x^2 / 8)
            psi[I, 1] = a * sqrt(f)
            psi[I, 2] = a * sqrt(1 - f)
        end
        psi
    end

    # name => (build, combined_carries_it, why)
    CASES = [
        ("c2 != 0", () -> let ip = InteractionParams(Dict(0 => 20.0, 1 => -0.4, 2 => 0.2))
                (mk(; interactions=ip), ip)
            end, false, ""),
        ("tensor",
            () -> (
                mk(; atom=Cr52,
                    interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0, 4 => 0.05))),
                inter), false, ""),
        ("raman", () -> (mk(; raman=RamanCoupling{3}(0.5, 0.0, (0.0, 0.0, 0.0))),
                inter), false, ""),
        ("spatial LHY", () -> (mk(; spinor_lhy=:spatial, psi_init=ramp), inter),
            false, ""),
        ("spatial Zeeman",
            () -> (
                mk(; zeeman=ZeemanParams(),
                    spatial_zeeman=spatial_zeeman_field(grid; bz=(x, y, z) -> 0.3 + 0.01x)),
                inter), false, ""),
        ("transverse Zeeman",
            () -> (
                mk(;
                    zeeman=SpinorBEC.ZeemanField{Nothing}(
                        (0.1, 0.0, 0.3, 0.0), nothing,
                        (nothing, nothing, nothing, nothing)),
                ), inter),
            true, "the combined rotation merges it (combined_spin_step.jl:323)"),
        ("magnetic gradient",
            () -> (mk(; magnetic_gradient=MagneticGradient{3}(0.1, 1, 1.0)),
                inter), true,
            "the combined path applies and removes it itself (combined_spin_step.jl:186-197)"),
    ]

    # CALIBRATION. Every arm below is about a guard DECLINING. A baseline that
    # already declines would make all of them pass for the wrong reason, and a
    # `_spin_chain_reason` that declined everything would too.
    @testset "the baseline is accepted by both" begin
        w = mk()
        @test _spin_chain_reason(w, inter, copy(w.state.psi)) === nothing
        @test _combined_step_unusable_full(w) === nothing
        COMBINED_SPIN_STEP_ENABLED[] = true
        @test _rtp_use_combined_step(w)
        COMBINED_SPIN_STEP_ENABLED[] = false
    end

    @testset "$name" for (name, build, combined_carries, why) in CASES
        ws, ip = build()

        # both arms need the fusion guard to fire, or the row is not about what
        # it says it is about
        fusion = _spin_chain_reason(ws, ip, copy(ws.state.psi))
        @test fusion !== nothing

        combined = _combined_step_unusable_full(ws)
        if combined_carries
            # the divergence is DECLARED — and the reason must be recorded, so a
            # future `true` cannot be added without someone writing down why
            @test !isempty(why)
            @test combined === nothing
        else
            isnothing(combined) && println(
                "\n  `$name` declines the fusion but the combined step accepts it.\n",
                "  Either the combined path carries the operator — then set\n",
                "  combined_carries_it=true with a file:line — or it drops it\n",
                "  silently, which is the defect this file exists for.")
            @test combined !== nothing
        end
    end

    # And the production selector must refuse the one that was actually broken.
    @testset "the RTP selector refuses SpatialLHY" begin
        old = COMBINED_SPIN_STEP_ENABLED[]
        COMBINED_SPIN_STEP_ENABLED[] = true
        try
            w = mk(; spinor_lhy=:spatial, psi_init=ramp)
            @test _lhy_needs_spin(w.lhy)
            @test !_rtp_use_combined_step(w)
            # NEGATIVE CONTROL: the same selector, same flag, a workspace whose
            # only difference is the LHY kind, must still take the combined path
            w0 = mk(; psi_init=ramp)
            @test !_lhy_needs_spin(w0.lhy)
            @test _rtp_use_combined_step(w0)
        finally
            COMBINED_SPIN_STEP_ENABLED[] = old
        end
    end
end
