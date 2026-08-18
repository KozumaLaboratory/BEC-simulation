using Test
using SpinorBEC
using SpinorBEC: ATOM_REGISTRY, _atom_F, recommend_uge_profile

# The VRAM estimate must take F from `ATOM_REGISTRY` — the one declaration of F
# per species — for EVERY registered atom, not from a second hand-written table.
#
# One lived in `profile_recommend.jl` until 2026-08-06 and held 7 of the
# registry's 23 atoms, with `Cs133` wrong in-table (F=1 against the registry's
# 3). Since the estimate scales as `spinor_mult = 2F + 1`, a missing atom was
# under-sized by exactly (2F_true+1)/3:
#
#     Dy162  5.67x     Eu153  4.33x     Er166  4.33x
#     Cs133  2.33x     Rb85   1.67x
#
# `Eu153` at 128^3 was recommended `gpu_1` at 0.94 GB while the identical-F
# `Eu151` got `default` at 4.06 GB. That is not a cosmetic drift: the under-sized
# job OOMs on TSUBAME, `failure_analysis` classifies it `:killed_bug`, and
# `retry.jl` escalates the resource class — the queue is paid for twice, in real
# money.
#
# The comment above the old table called F=1 "the safe lower bound for scalar
# VRAM estimation". For a RESOURCE estimate low is the UNSAFE side, and that
# inversion is why the table survived: it read as a conservative default.

"A minimal spec whose largest grid carries `atom`."
function spec_for(atom; n=(64, 64, 64))
    Dict(
        "pipeline" => [
            Dict(
                "ground_state" => Dict(
                    "atom" => atom,
                    "grid" => Dict("n" => collect(n), "box" => [10.0, 10.0, 10.0]),
                ),
            ),
        ],
    )
end

@testset "VRAM sizing reads F from ATOM_REGISTRY" begin
    # CALIBRATION. A lookup that returns 1 for everything satisfies "no atom is
    # under-sized" against a registry read the same broken way. Assert the
    # registry itself carries a spread of F before comparing anything to it.
    @testset "the registry has a spread of F to be wrong about" begin
        Fs = [a.F for a in values(ATOM_REGISTRY)]
        @test length(ATOM_REGISTRY) >= 20
        @test maximum(Fs) >= 6
        @test length(unique(Fs)) >= 4
    end

    @testset "every registered atom resolves to its registry F" begin
        wrong = String[]
        for (sym, atom) in ATOM_REGISTRY
            got = _atom_F(String(sym))
            got == atom.F || push!(wrong, "$sym: got $got, registry says $(atom.F)")
        end
        isempty(wrong) || println("\n  atoms whose sizing F is not the registry's:\n    ",
            join(wrong, "\n    "))
        @test isempty(wrong)
    end

    # The direction matters more than the value. A resource estimate that is too
    # LOW picks a smaller GPU class and the job dies; too high only wastes queue.
    @testset "an unknown atom falls back low, and that is documented as unsafe" begin
        @test _atom_F("zzz_not_an_atom") == 1
        @test _atom_F("") == 1
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "autopilot",
                "profile_recommend.jl"), String)
        # The direction must be stated at the fallback. Note the shape of this
        # assertion: a first version forbade the phrase "safe lower bound"
        # outright and tripped on the dated note EXPLAINING why that phrase was
        # wrong — a ban on a string cannot tell a claim from a retraction of it.
        # So assert the correct direction is present, at the fallback, instead.
        i = findfirst("_atom_F(atom::AbstractString)", src)
        @test i !== nothing
        near = src[max(1, first(i) - 400):min(lastindex(src), last(i) + 400)]
        @test occursin("UNDER-estimate", near) || occursin("unsafe", near) ||
            occursin("1 if unparseable", near)
    end

    # The two isotopes that made the defect visible: same F, and before the fix
    # they landed in different profiles.
    @testset "same-F isotopes get the same recommendation" begin
        @test ATOM_REGISTRY[:Eu151].F == ATOM_REGISTRY[:Eu153].F
        r151 = recommend_uge_profile(spec_for("Eu151"; n=(128, 128, 128)))
        r153 = recommend_uge_profile(spec_for("Eu153"; n=(128, 128, 128)))
        @test r151.profile == r153.profile
        @test isapprox(r151.est_vram_gb, r153.est_vram_gb; rtol=1e-9)
    end

    # And the estimate must actually move with F, or the arms above are vacuous.
    @testset "the estimate scales with the multiplicity" begin
        low = recommend_uge_profile(spec_for("Na23"))       # F = 1
        high = recommend_uge_profile(spec_for("Dy162"))     # F = 8
        @test high.est_vram_gb > low.est_vram_gb
        # 2F+1: 17/3 for Dy162 against Na23
        @test isapprox(high.est_vram_gb / low.est_vram_gb, 17 / 3; rtol=0.15)
    end

    # No second F table may reappear.
    @testset "there is no second F-by-atom table" begin
        src = read(
            joinpath(@__DIR__, "..", "..", "src", "workflow", "autopilot",
                "profile_recommend.jl"), String)
        @test !occursin("_F_BY_ATOM", src)
        @test occursin("ATOM_REGISTRY", src)
    end
end
