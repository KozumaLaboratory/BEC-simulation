using Test
using SpinorBEC
using SpinorBEC: GroundStateStep, parse_pipeline, _prepare_config_file, _run_step,
    resolve_gs, GSResolved, restore_dealias_refs!, DEALIAS_2_3_ENABLED,
    DEALIAS_K_CUTOFF, linear_p, transverse_b

# A ground-state step that declares physics this path does not read must REFUSE,
# not run.
#
# WHY
#
# `GSResolved.dropped_physics` has existed since cutover step 1b and only
# `gs_model` consulted it. So a config in that state got no Model — loudly — and
# ran anyway, silently. The run is the half that produces numbers.
#
# THE LIVE CASE, measured 2026-08-19 over all 455 resolving ground-state steps:
# exactly two configs, both `B_direction`, both already wrong.
#
#   runs/klaus_hybrid/klaus_hybrid_nostir_control.experiment.jl
#   runs/klaus_hybrid/klaus_hybrid_magnetostir_omega_m0p74.experiment.jl
#
# Both declare `B: {B_mag: "0.01 Gauss", theta: 3.14159}` — the field along −z —
# together with `initial_state: m_minus_F`. That pairing is the ANTI-ALIGNED
# stretched state, which is what an EdH experiment is about. What runs is
# `p = -147.955`: the same number `theta: 0` gives, i.e. the field along +z and
# the state ALIGNED. Per
# `gotcha_edh_needs_the_anti_aligned_stretched_state_2026_08_19` the rotation
# enhancement is +16.5 % anti-aligned against −0.45 % aligned, so the effect
# those configs exist to measure is absent from the arm that actually ran.
#
# WHAT THIS FILE PINS, AND WHAT IT DOES NOT
#
# It pins the REFUSAL. It does not repair the two configs: which spelling the
# author wants (`Bz` with a sign, or no tilt) is a physics choice. It also pins
# the underlying fact — that the GS path ignores `theta` entirely — because a
# future change making `theta` live would make the refusal wrong, and this is
# where that should surface.

const _RDP_DIR = mktempdir()

const _RDP_BASE = """
Dict{String, Any}(
    "pipeline" => [Dict{String, Any}(
        "ground_state" => Dict{String, Any}(
            "B" => Dict{String, Any}(
                "__BBLOCK__" => nothing,
            ),
            "atom" => "Eu151",
            "backend" => "cpu",
            "ddi" => Dict{String, Any}(
                "enabled" => false,
            ),
            "dt" => 0.002,
            "grid" => Dict{String, Any}(
                "box" => [6.0, 6.0, 6.0],
                "n" => [8, 8, 8],
            ),
            "interactions" => Dict{String, Any}(
                "N_atoms" => 1000,
                "c1_ratio" => -0.01,
                "omega_ref" => 691.15,
            ),
            "lhy" => Dict{String, Any}(
                "kind" => "none",
            ),
            "method" => "itp",
            "n_steps" => 2,
            "potential" => Dict{String, Any}(
                "omega" => [1.0, 1.0, 1.0],
                "type" => "harmonic",
            ),
            "tol" => 1.0e-6,
        ),
    )],
)
"""

function _rdp_write(name, bblock)
    p = joinpath(_RDP_DIR, name)
    data = SpinorBEC._julia_config_string(_RDP_BASE)
    data["pipeline"][1]["ground_state"]["B"] = bblock
    write(p, repr(data))
    p
end

"Run `f` with the dealias globals restored — `_prepare_config_file` leaves them set."
function _rdp_guarded(f)
    was_en, was_kc = DEALIAS_2_3_ENABLED[], DEALIAS_K_CUTOFF[]
    try
        f()
    finally
        restore_dealias_refs!(was_en, was_kc)
    end
end

function _rdp_gs_step(path)
    cfg = parse_pipeline(Dict{Any, Any}(_prepare_config_file(path, false, false)))
    first(s for s in cfg.steps if s isa GroundStateStep)
end

"`:ran`, or the exception message."
function _rdp_run(path)
    _rdp_guarded() do
        try
            _run_step(_rdp_gs_step(path), nothing, nothing, nothing, nothing; verbose=false)
            :ran
        catch e
            e isa ArgumentError ? e.msg : sprint(showerror, e)
        end
    end
end

@testset "a ground_state step refuses physics it would drop" begin
    @testset "the GS path really does ignore the field direction" begin
        # The premise. If this ever stops being true — if `theta` becomes live on
        # this path — the refusal below is wrong and should be deleted, and this
        # is the assertion that says so rather than leaving a stale guard.
        ps = Float64[]
        for θ in ("0.0", "1.0", "1.5707963", "3.14159")
            p = _rdp_write("theta_$(replace(θ, "." => "p")).experiment.jl",
                Dict("B_mag" => 0.01, "theta" => parse(Float64, θ), "phi" => 0.0))
            r = _rdp_guarded() do
                resolve_gs(_rdp_gs_step(p).params, nothing, nothing, nothing;
                    verbose=false)::GSResolved
            end
            push!(ps, linear_p(r.zeeman))
            @test transverse_b(r.zeeman, 0.0) == (0.0, 0.0)
        end
        # Every θ gives the SAME p — including θ = π, which physically is the
        # opposite field. That is the drop.
        @test all(≈(ps[1]), ps)
    end

    @testset "a declared-but-dropped direction is refused" begin
        p = _rdp_write(
            "tilted.experiment.jl", Dict("B_mag" => 0.01, "theta" => 3.14159, "phi" => 0.0)
        )
        msg = _rdp_run(p)
        @test msg !== :ran
        @test occursin("does not read", msg)
        @test occursin("B_direction", msg)
    end

    @testset "an axial field still runs" begin
        # The negative control. A refusal that fired on everything would pass the
        # arm above while breaking the corpus, and 453 of the 455 resolving
        # ground-state steps are this shape.
        @test _rdp_run(_rdp_write("axial.experiment.jl", Dict("Bz" => 0.01))) === :ran
        # …including the trivial `theta: 0` direction block, which
        # `apply_B_block_normalize!` leaves behind for a purely axial field and
        # which names nothing dropped.
        @test _rdp_run(
            _rdp_write("theta0.experiment.jl", Dict("B_mag" => 0.01, "theta" => 0.0, "phi" => 0.0))
        ) === :ran
    end

    @testset "the override runs, and says so" begin
        # An override that passed quietly would be a default. `@warn` is the
        # difference, and the same shape `SPINORBEC_ALLOW_STALE_POINTS` uses.
        p = _rdp_write(
            "tilted_override.experiment.jl", Dict("B_mag" => 0.01, "theta" => 3.14159, "phi" => 0.0)
        )
        withenv("SPINORBEC_ALLOW_DROPPED_GS_PHYSICS" => "1") do
            @test_logs (:warn,) match_mode = :any begin
                @test _rdp_run(p) === :ran
            end
        end
        # …and it is off by default, so the refusal above was not an artefact of
        # the environment this suite happens to run in.
        @test !haskey(ENV, "SPINORBEC_ALLOW_DROPPED_GS_PHYSICS")
    end
end
