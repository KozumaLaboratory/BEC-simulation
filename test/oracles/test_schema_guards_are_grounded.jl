# Three schema guards, grounded in the physics they protect.
#
# The 2026-08-19 mutation sweep (60 classes x 376 files, TSUBAME) found that each
# of these three defect classes had EXACTLY ONE catcher in the whole per-PR
# surface, and that in each case the sole catcher was a `:pin` or `:api` test —
# it asserts that the parser throws, which is a spelling, not a claim. A guard
# whose only evidence is "the current code throws here" cannot say whether HERE
# is the right place, so a boundary that drifts one term takes the test with it.
#
# What each testset below adds is the missing half: an independent statement of
# WHY the boundary is where it is, taken from the machinery the guard protects
# rather than restated from the guard. Written so the assertion fails if the
# guard moves OR if the physics moves and the guard does not follow.
#
# Sole-catcher status per class, from that sweep:
#   schema_c1_ratio_singularity_guard  <- workflow/test_schema_validation_edge_cases.jl (:pin)
#   b_block_cartesian_direction_guard  <- workflow/test_b_block_normalize.jl            (:api)
#   gs_interactions_inherit_over_explicit <- workflow/test_pipeline_name_and_precedence.jl (:pin)

using Test
using SpinorBEC
using SpinorBEC: interaction_params_from_constraint, apply_B_block_normalize!,
    _validate_ground_state_physics!, resolve_atom,
    _resolve_gs_interactions, _parse_gs_interactions, InteractionParams

@testset "schema guards are grounded in the physics they protect" begin

    # ── 1. the c1_ratio singularity ─────────────────────────────────────
    #
    # `interaction_params_from_constraint` computes c0 = c_total / (1 + F²·c1_ratio)
    # (coefficients.jl:261). The schema refuses at c1_ratio <= -1/F², and -1/F² is
    # written out a second time in schema.jl:629. Two independent spellings of one
    # root is exactly the drift shape this repo keeps paying for, so the bound is
    # DERIVED from the constructor here and the schema is checked against it.
    @testset "the refusal boundary is the root of the c0 denominator" begin
        for F in (1, 2, 6)
            bound = -1.0 / F^2

            # POSITIVE CONTROL on the physics: just inside, c0 is finite and
            # positive, i.e. there is something real for the schema to admit.
            # Without this the "just outside" assertion below could pass on a
            # constructor that is broken everywhere.
            ip_ok = interaction_params_from_constraint(;
                c_total=1.0, c1_ratio=bound + 1e-3, F=F)
            @test isfinite(ip_ok.c[0])
            @test ip_ok.c[0] > 0

            # Just outside: c0 is non-finite or has flipped sign. THIS is the
            # non-physical coupling the guard exists to keep out — asserted on
            # the constructor, not on the parser.
            ip_bad = interaction_params_from_constraint(;
                c_total=1.0, c1_ratio=bound - 1e-3, F=F)
            @test !(isfinite(ip_bad.c[0]) && ip_bad.c[0] > 0)

            # AT the root the denominator is exactly zero, so c0 is Inf.
            ip_at = interaction_params_from_constraint(; c_total=1.0, c1_ratio=bound, F=F)
            @test !isfinite(ip_at.c[0])
        end
    end

    @testset "the schema refuses exactly where the constructor diverges" begin
        # Eu151 is F=6, so the boundary under test is -1/36 and NOT the -1 that
        # the schema's own generous (-1, 1) range would allow. A guard keyed to
        # the wrong F passes a range check and still hands the solver an infinity.
        eu = resolve_atom(:Eu151)
        @test eu !== nothing
        F = eu.F
        @test F == 6                       # the boundary below is -1/36, not -1
        bound = -1.0 / F^2

        mkstep(cr) = Dict{String, Any}(
            "atom" => "Eu151",
            "interactions" => Dict{String, Any}("c1_ratio" => cr),
        )

        # Admitted side: strict mode must NOT throw where c0 is physical.
        # This is the control that keeps the next assertion from passing on a
        # validator that refuses everything.
        ok = interaction_params_from_constraint(; c_total=1.0, c1_ratio=bound + 1e-3, F=F)
        @test ok.c[0] > 0
        @test _validate_ground_state_physics!(
            mkstep(bound + 1e-3), "pipeline.0", Dict{String, Any}(); strict=true) isa Any

        # Refused side: at and below the root.
        for cr in (bound, bound - 1e-3, -0.5)
            bad = interaction_params_from_constraint(; c_total=1.0, c1_ratio=cr, F=F)
            @test !(isfinite(bad.c[0]) && bad.c[0] > 0)   # the physics is bad here
            @test_throws ArgumentError _validate_ground_state_physics!(
                mkstep(cr), "pipeline.0", Dict{String, Any}(); strict=true)
        end
    end

    # ── 2. Cartesian vs spherical B ─────────────────────────────────────
    #
    # The existing guard asserts `@test_throws ArgumentError`. That says the
    # parser refuses; it does not say the two forms actually disagree, which is
    # the entire reason refusing is right. If they agreed, accepting both would
    # be harmless and the guard would be gratuitous.
    @testset "the two B forms are refused because they disagree" begin
        Bz, theta = 1.0, 0.5

        # Reading A — Cartesian wins: the field is along +z, so theta_eff = 0.
        vec_cartesian = (0.0, 0.0, Bz)
        # Reading B — the spherical direction wins: same magnitude, tilted.
        vec_spherical = (sin(theta) * Bz, 0.0, cos(theta) * Bz)

        # The ambiguity is REAL and not a rounding difference: the two readings
        # differ by an amount comparable to |B| itself. `theta` is not small.
        gap = sqrt(sum((a - b)^2 for (a, b) in zip(vec_cartesian, vec_spherical)))
        @test gap > 0.1 * Bz
        # And the transverse component — the thing that decides whether spin
        # mixing is driven at all — is zero in one reading and not the other.
        @test vec_cartesian[1] == 0.0
        @test abs(vec_spherical[1]) > 0.1 * Bz

        # Only now is the refusal meaningful: it keeps a config whose field is
        # genuinely ambiguous from reaching a solver that would silently pick one.
        wrap(step) = Dict{String, Any}(
            "pipeline" => Any[Dict{String, Any}("ground_state" => step)])
        @test_throws ArgumentError apply_B_block_normalize!(
            wrap(Dict{String, Any}(
                "B" => Dict{String, Any}("Bz" => Bz, "theta" => theta))))

        # NEGATIVE CONTROL: theta = 0 IS accepted, because there the two readings
        # coincide — the guard is about disagreement, not about key co-presence.
        # Without this a guard that refused every B block would pass above.
        vec_theta0 = (sin(0.0) * Bz, 0.0, cos(0.0) * Bz)
        @test all(a ≈ b for (a, b) in zip(vec_cartesian, vec_theta0))
        cfg0 = wrap(Dict{String, Any}("B" => Dict{String, Any}("Bz" => Bz, "theta" => 0)))
        @test apply_B_block_normalize!(cfg0) isa Any
    end

    # ── 3. a step's own `interactions:` beats the inherited workspace ────
    #
    # This is the defect that voided a published comparison arm: a `c1_ratio` set
    # on a ground_state step never reached `c0`, every scan point still differed
    # from its neighbours, and the axis was simply not the one the config asked
    # for (project_matsui_fig4b_reproduction_2026_07_30). Its sole catcher was a
    # `:pin`. Grounded here as a differential on the resolved coupling: the value
    # the resolver returns must be the value the step ASKED for.
    @testset "explicit interactions beat the inherited workspace" begin
        atom = resolve_atom(:Eu151)
        @test atom !== nothing

        asked, inherited = -0.02, -0.005
        mkinter(cr) = Dict{String, Any}(
            "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => cr)

        # POSITIVE CONTROL. The two candidate answers must be distinguishable in
        # the resolved coupling, or "the right one won" is unfalsifiable — a
        # degenerate knob, which is how a null result gets read as a pass.
        ip_asked = _parse_gs_interactions(mkinter(asked), atom)
        ip_inherited = _parse_gs_interactions(mkinter(inherited), atom)
        @test !isapprox(ip_asked.c[1], ip_inherited.c[1]; rtol=1e-6)
        @test !isapprox(ip_asked.c[0], ip_inherited.c[0]; rtol=1e-6)

        # `_resolve_gs_interactions` reads exactly one field off ws_prev, so a
        # NamedTuple stands in for the Workspace — building a real one would drag
        # a grid and FFT plans in for a precedence question that has neither.
        ws_prev = (; interactions=ip_inherited)
        step = Dict{String, Any}("interactions" => mkinter(asked))

        got = _resolve_gs_interactions(step, ws_prev, atom)
        @test got.c[1] ≈ ip_asked.c[1]
        @test got.c[0] ≈ ip_asked.c[0]
        # Stated as the failure, not only as the pass: inverting the precedence
        # returns the inherited value, and that is the shape of the incident.
        @test !isapprox(got.c[1], ip_inherited.c[1]; rtol=1e-6)

        # The inheritance path itself still works — a guard that made explicit
        # ALWAYS win by breaking inheritance would pass the assertions above.
        inherited_only = _resolve_gs_interactions(Dict{String, Any}(), ws_prev, atom)
        @test inherited_only.c[1] ≈ ip_inherited.c[1]
    end
end
