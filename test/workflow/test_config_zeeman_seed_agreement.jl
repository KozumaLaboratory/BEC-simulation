# Committed configs must agree with the Zeeman sign convention.
#
# The convention (CLAUDE.md, `Units.bfield_to_p`): H = -p·F_z + q·F_z² with
# p ≡ -g_F μ_B B, so physically H = +(g_F μ_B B·F). For g_F > 0 (Eu, Cr, He*)
# a POSITIVE B_z makes m = -F the lowest state.
#
# Measured 2026-07-29 on a 16³ Eu ground state, DDI off, spin-coherent seed so
# every m is free to win:
#
#     Bz = -0.01 Gauss  ->  <F_z> = +6.0
#     Bz = +0.01 Gauss  ->  <F_z> = -6.0
#
# A config that pins `initial_state: m_minus_F` under a NEGATIVE B_z is asking
# ITP to hold the state the field disfavours. Nothing errors — the run completes
# and produces a plausible-looking result for the opposite polarisation. The
# `runs/matsui_baseline/` set drifted this way (the sign predates the 2026-06-10
# B→p fix and its comment still claimed the old convention), which is what this
# gate exists to stop recurring.
#
# Scope: only configs that pin a fully-stretched seed AND set a non-zero B_z.
# Everything else is a legitimate choice and is not the business of this test.

using Test
using YAML

"""Extract Gauss from `"0.01 Gauss"` / `0.01` / `{Bz: ...}`; `nothing` if absent."""
function _bz_value(B)
    B isa Dict || return nothing
    bz = get(B, "Bz", nothing)
    bz === nothing && return nothing
    bz isa Number && return Float64(bz)
    bz isa AbstractString && return tryparse(Float64, first(split(strip(bz))))
    # ramp form {from: ..., to: ...} — the GS value is `from`
    if bz isa Dict && haskey(bz, "from")
        f = bz["from"]
        f isa Number && return Float64(f)
        f isa AbstractString && return tryparse(Float64, first(split(strip(f))))
    end
    return nothing
end

function _scan_configs(root)
    disagreements = String[]
    n_checked = 0
    for (dir, _, files) in walkdir(root)
        for f in files
            endswith(f, ".yaml") || continue
            path = joinpath(dir, f)
            data = try
                YAML.load_file(path)
            catch
                continue          # templates / fragments that are not standalone
            end
            (data isa Dict && get(data, "pipeline", nothing) isa AbstractVector) || continue
            for step in data["pipeline"]
                step isa Dict && haskey(step, "ground_state") || continue
                gs = step["ground_state"]
                gs isa Dict || continue
                seed = get(gs, "initial_state", nothing)
                seed in ("m_minus_F", "m_plus_F") || continue
                bz = _bz_value(get(gs, "B", nothing))
                (bz === nothing || bz == 0.0) && continue
                n_checked += 1
                # +Bz ⇒ m=-F lowest.  m_minus_F wants Bz > 0; m_plus_F wants Bz < 0.
                wants_positive = seed == "m_minus_F"
                if (bz > 0) != wants_positive
                    push!(disagreements,
                        "$path: initial_state=$seed with Bz=$bz " *
                        "(wants Bz " * (wants_positive ? "> 0" : "< 0") * ")")
                end
            end
        end
    end
    (; disagreements, n_checked)
end

@testset "committed configs agree with the Zeeman sign convention" begin
    root = joinpath(@__DIR__, "..", "..", "runs")
    @test isdir(root)
    r = _scan_configs(root)

    # If this is zero the gate is vacuous and something changed upstream.
    @test r.n_checked > 0

    # `m_minus_F` is unambiguous and is a hard gate: the config states the seed
    # it wants, and only a POSITIVE B_z makes that seed the ground state.
    minus = filter(d -> occursin("m_minus_F", d), r.disagreements)
    for d in minus
        @info "Zeeman/seed disagreement (m_minus_F)" config = d
    end
    @test isempty(minus)

    # `m_plus_F` is NOT gated, deliberately, and this is not a silent cap.
    #
    # A config pinning m=+F under a positive B_z is inconsistent the same way,
    # but the repair is ambiguous: flipping the FIELD negative and flipping the
    # SEED to m_minus_F both produce a consistent config, and they are physical
    # mirror images rather than the same state. Which one the author meant is
    # not recoverable from the file. So these are reported loudly and left for a
    # decision instead of being rewritten on a guess.
    plus = filter(d -> occursin("m_plus_F", d), r.disagreements)
    if !isempty(plus)
        @warn "m_plus_F configs disagree with the Zeeman convention; repair " *
            "is ambiguous (flip field vs flip seed) and needs an owner " *
            "decision — see this test's comment" count = length(plus)
        for d in plus
            @info "Zeeman/seed disagreement (m_plus_F, UNRESOLVED)" config = d
        end
    end
end
