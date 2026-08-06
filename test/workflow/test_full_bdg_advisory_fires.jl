using Test
using SpinorBEC
using SpinorBEC: GS_SCHEMA, inspect_config
using Logging

# The `full_bdg` cost advisory must fire for every ansatz that HAS a closed form.
#
# `schema.jl` advised the ~100x cheaper closed form when
# `init in ("polar", "ferromagnetic")`. `ferromagnetic` was retired from the
# `initial_state` enum in favour of `m_plus_F` / `m_minus_F` and the condition
# was never updated — so from that day the advisory was a FALSE NEGATIVE on
# exactly the configs it exists for. `runs/eu_lhy_longtime/LHY_full_bdg_*.yaml`
# and friends paid the full BdG cost with no hint that `fm_contact` /
# `fm_dipolar` agree to ~1e-4 (gated by
# `test/oracles/test_lhy_full_bdg_closed_form_parity.jl`).
#
# This is the shape that hides best: a condition testing a vocabulary that moved
# under it. Nothing fails, nothing warns, and the only symptom is a bill.
#
# The gate is a PROPERTY, not a list of names: every value the enum offers that
# names a closed-form ansatz must reach the advisory.

const _FM = ("m_plus_F", "m_minus_F")

function spec_with(init; kind="full_bdg")
    Dict(
        "pipeline" => [
            Dict(
                "ground_state" => Dict(
                    "atom" => "Na23",
                    "grid" => Dict("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
                    "interactions" =>
                        Dict("N_atoms" => 1000, "omega_ref" => 100.0, "c1_ratio" => 0.0),
                    "lhy" => Dict("kind" => kind),
                    "initial_state" => init,
                    "dt" => 0.005, "n_steps" => 1,
                ),
            ),
        ],
    )
end

"""
Does the schema emit the closed-form advisory for this spec?

The advisory is an `@info`, so it goes through the LOGGER — not into
`inspect_config`'s findings list. A first version of this helper read
`r.warnings` and reported "does not fire" for every ansatz including `polar`,
where it demonstrably does. The instrument was looking in the wrong place, which
is indistinguishable from the feature being broken.
"""
function advises(spec)
    mktempdir() do d
        p = joinpath(d, "probe.yaml")
        open(io -> print(io, _to_yaml(spec)), p, "w")
        buf = IOBuffer()
        with_logger(SimpleLogger(buf, Logging.Info)) do
            try
                inspect_config(p)
            catch
                # a spec this test builds should parse; if it does not, the arms
                # below fail on an empty log rather than on a swallowed error
            end
        end
        occursin("closed form", String(take!(buf)))
    end
end

# Minimal YAML emitter — the spec here is flat enough that a dependency on the
# writer would be a bigger surface than the test.
function _to_yaml(x, indent=0)
    pad = " "^indent
    if x isa AbstractDict
        join([string(pad, k, ":\n", _to_yaml(v, indent + 2)) for (k, v) in x])
    elseif x isa AbstractVector && !isempty(x) && first(x) isa AbstractDict
        join([string(pad, "-\n", _to_yaml(e, indent + 2)) for e in x])
    elseif x isa AbstractVector
        string(pad, "[", join(x, ", "), "]\n")
    elseif x isa AbstractString
        string(pad, x, "\n")
    else
        string(pad, x, "\n")
    end
end

@testset "the full_bdg closed-form advisory fires" begin
    # CALIBRATION. `advises` returning false for everything makes the negative
    # arms pass and the positive ones fail loudly — but `advises` returning TRUE
    # for everything would make the positive arms pass silently. Pin both
    # directions on a case where the answer is known.
    @testset "the enum still offers the names being tested" begin
        e = GS_SCHEMA["initial_state"].enum
        @test "polar" in e
        for fm in _FM
            @test fm in e
        end
        # the name the condition used to test, which the enum dropped
        @test !("ferromagnetic" in e)
    end

    @testset "it fires for polar and for both FM ansätze" begin
        @test advises(spec_with("polar"))
        for fm in _FM
            @test advises(spec_with(fm))
        end
    end

    # The negative control. Without it, an advisory that fired on EVERY config
    # would satisfy every arm above.
    @testset "it does not fire where no closed form applies" begin
        @test !advises(spec_with("skyrmion"))
        @test !advises(spec_with("polar"; kind="polar_contact"))
    end
end
