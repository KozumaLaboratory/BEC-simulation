using Test
using SpinorBEC
using SpinorBEC: make_workspace, InteractionParams, SimParams, ZeemanParams,
    HarmonicTrap, parse_pipeline, _run_step

# A `dynamics:` step must build the DDI kernel its own `ddi:` block asks for.
#
# WHY THIS GATE EXISTS
#
# `secular`, `quasi_2d` and `l_z` are baked into the Q tensors, so — unlike
# `c_dd` — they cannot be inherited from `ws_prev`'s `DDIParams`; the dynamics
# handler has to re-resolve them from its own block. It re-resolved
# `trunc_radius` and `padded` and NOT these three, so `secular_ddi` took
# `make_workspace`'s `false` default no matter what the YAML said.
#
# The comment above that resolution had named `secular` as the exemplar of the
# class since 2026-07-29 — "Like `secular`, these are NOT carried on the
# inherited DDIParams" — while the code did not handle it. Prose naming the
# obligation is not the obligation being met, which is the whole shape of
# CLAUDE.md commitment 11.
#
# Live casualty: `runs/eu_ham_only_conservation/eu_ham_only_24_sec.yaml`, whose
# header states its purpose as "Compare against 24_nonsec to isolate the impact
# of off-diagonal DDI terms". Both arms ran the dynamics on the SAME
# (non-secular) kernel, so the comparison measured nothing in that phase. The
# ground-state phase differed, which is exactly why nothing looked wrong.
#
# THE GATE IS A DIFFERENTIAL, NOT A FIELD READ. `secular` leaves no flag on the
# built Workspace — it is visible only in the Q tensors — so "does
# ws.ddi.secular equal true" is not a question that can be asked, and a gate
# reading some adjacent config field could pass while the kernel stayed wrong.
#
# The main claims run the PIPELINE TWICE and compare the two results, rather
# than comparing against a hand-built workspace. A hand-built reference has to
# replicate every default the YAML path applies, which is a second copy of the
# resolution written in order to test the first — the defect this PR is about,
# reappearing in the test. The first draft did exactly that and failed by 0.027
# on a `trunc_radius` default it had not replicated.
#
# `_reference_ddi_ws` survives for the POSITIVE CONTROL only, where the question
# is "does this knob move the kernel at all" and no pipeline default is involved.

const _DDI_KNOB_GRID = make_grid(GridConfig((12, 12, 12), (8.0, 8.0, 8.0)))

"""Reference kernel at a given `secular`, built directly — the thing the
pipeline's workspace is compared against.

`ddi_padding` is passed EXPLICITLY, and the configs below set `padded` to the
same value, because the two entry points disagree about the default:
`make_workspace` defaults it `false` and the YAML path applies
`DDI_PADDED_DEFAULT = true`. Leaving it implicit made the `secular=false` arm
compare a padded kernel against an unpadded one and fail by 0.027 for a reason
having nothing to do with `secular`.

The `secular=true` arm passed anyway, which is the instructive part: the secular
kernel zeroes `Q_xz` identically, so a padding difference is invisible in the
quantity being compared. One arm of a two-arm test being blind to a confound
the other arm sees is exactly why both directions are here."""
function _reference_ddi_ws(secular::Bool; padded::Bool=false)
    make_workspace(;
        grid=_DDI_KNOB_GRID, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => -0.005)),
        zeeman=ZeemanParams(0.5, 0.0),
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=SimParams(; dt=0.001, n_steps=1),
        enable_ddi=true, c_dd=0.3, secular_ddi=secular, ddi_padding=padded,
    )
end

_q_gap(a, b) = maximum(abs, a.ddi.Q_xz .- b.ddi.Q_xz)

function _two_step_config(secular::Bool)
    inter = Dict("N_atoms" => 1000, "omega_ref" => 628.3, "c1_ratio" => -0.005)
    Dict{Any, Any}(
        "pipeline" => [
            Dict(
                "ground_state" => Dict{Any, Any}(
                    "atom" => "Eu151",
                    "grid" => Dict("n" => [12, 12, 12], "box" => [8.0, 8.0, 8.0]),
                    "potential" => Dict("type" => "harmonic", "omega" => [1.0, 1.0, 1.0]),
                    "interactions" => inter,
                    "ddi" => Dict("enabled" => true, "secular" => secular, "c_dd" => 0.3,
                        "padded" => false),
                    "lhy" => Dict("kind" => "none"),
                    "B" => Dict("Bz" => 0.01),
                    "n_steps" => 2, "dt" => 0.001,
                ),
            ),
            Dict(
                "dynamics" => Dict{Any, Any}(
                    "duration" => 0.002, "dt" => 0.001,
                    "B" => Dict("Bz" => 0.01),
                    "interactions" => inter,
                    "ddi" => Dict("secular" => secular, "c_dd" => 0.3, "padded" => false),
                ),
            ),
        ],
    )
end

@testset "a dynamics step honours its own kernel-shaping DDI knobs" begin
    ref_sec = _reference_ddi_ws(true)
    ref_non = _reference_ddi_ws(false)

    @testset "positive control: `secular` is a live knob" begin
        # Without this the whole file is the degenerate-knob trap: if the two
        # kernels were identical, "the dynamics workspace matches the secular
        # one" would be true however the resolution behaved.
        @test _q_gap(ref_sec, ref_non) > 0.1
        # …and the knob does the PHYSICALLY expected thing rather than merely
        # something: the secular limit Larmor-averages the off-diagonal
        # components to zero and leaves the axial one alone.
        @test maximum(abs, ref_sec.ddi.Q_zz .- ref_non.ddi.Q_zz) == 0.0
        @test maximum(abs, ref_sec.ddi.Q_xy) == 0.0
        @test maximum(abs, ref_non.ddi.Q_xy) > 0.1
    end

    # Both claims below are DIFFERENTIAL between two runs of the pipeline, not
    # comparisons against a hand-built workspace.
    #
    # The first draft did compare against `_reference_ddi_ws`, and the
    # `secular=false` arm failed by 0.027 with GS and DYN reporting the SAME
    # number — i.e. the two pipeline steps already agreed and the hand-built
    # reference was the odd one out, because replicating the reference means
    # replicating every default the YAML path applies (`trunc_radius` here) and
    # one of them was missed. Writing a second copy of the resolution in order
    # to test the first is the defect this PR is about, in the test.
    #
    # Running the pipeline twice and comparing needs no such copy, and states
    # the broken property directly: before the fix `dyn(true)` and `dyn(false)`
    # were the SAME kernel.
    function _pipeline_kernels(secular::Bool)
        cfg = parse_pipeline(_two_step_config(secular))
        psi, g, a, ws_gs, _ = _run_step(cfg.steps[1], nothing, nothing, nothing, nothing;
            verbose=false)
        _, _, _, ws_dyn, _ = _run_step(cfg.steps[2], psi, g, a, ws_gs; verbose=false)
        (ws_gs, ws_dyn)
    end

    gs_t, dyn_t = _pipeline_kernels(true)
    gs_f, dyn_f = _pipeline_kernels(false)

    @testset "the dynamics kernel MOVES with the declared secular" begin
        # THE regression. Pre-fix this was 0.0: `secular_ddi` never reached
        # `make_workspace`, so both configs built the non-secular kernel.
        @test _q_gap(dyn_t, dyn_f) > 0.1
        # The ground-state arm was already correct, and pinning it makes a
        # future failure legible: if BOTH go to zero the resolution died, if
        # only the dynamics one does it has regressed to this bug.
        @test _q_gap(gs_t, gs_f) > 0.1
    end

    @testset "the two steps of one config build the SAME kernel" begin
        # What "honours it" means, without naming a number: a config declaring
        # the same knob in both steps must not silently run two different
        # Hamiltonians. This is the arm that fails if only one handler is fixed.
        @test _q_gap(gs_t, dyn_t) == 0.0
        @test _q_gap(gs_f, dyn_f) == 0.0
    end

    @testset "the pipeline's secular kernel is the secular one" begin
        # One absolute anchor, on the quantity the secular limit defines exactly
        # and which therefore carries no default-sensitivity: the off-diagonal
        # components are identically zero, and only there.
        @test maximum(abs, dyn_t.ddi.Q_xy) == 0.0
        @test maximum(abs, dyn_t.ddi.Q_xz) == 0.0
        @test maximum(abs, dyn_f.ddi.Q_xy) > 0.1
        @test maximum(abs, dyn_f.ddi.Q_xz) > 0.1
    end

    @testset "every kernel-shaping knob is passed, not just the tested one" begin
        # `quasi_2d` and `l_z` were dropped by the same omission and select an
        # entirely different kernel. A behavioural test for them needs a Q2D
        # fixture; this is the cheap structural half — the handler must at least
        # forward them — and it is what fails if a future edit removes one again.
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "experiments",
                "pipeline", "run_step_dynamics.jl"), String)
        code = join([split(l, "#")[1] for l in split(src, "\n")], "\n")
        for kw in ("secular_ddi=", "quasi_2d_ddi=", "l_z_ddi=")
            @test occursin(kw, code)
        end
        # Calibrated: a kwarg that is NOT forwarded must read as absent, or the
        # three above prove nothing about this predicate.
        @test !occursin("definitely_not_a_kwarg=", code)
    end
end
