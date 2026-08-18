using Test
using SpinorBEC

# Which published numbers does this repository actually check itself against?
#
# CLAUDE.md defines the verification-type split and requires a report to say
# which type a claim falls under: "A: code correctness … B: physics agreement …
# **C: model fidelity** — comparison to published experimental data (Klaus et al. 2022,
# Matsui Eu Bogoliubov cascade, Prasad 2019 vortex, Yan-Li-Saito Barnett)."
#
# Nothing enumerated the type-C claims, so the question could only be answered
# by reading 348 test files — and the answer, when read, is that **none of the
# four targets CLAUDE.md names is gated by any test**. `test_klaus_validation.jl`
# is in `MANUAL_TESTS_ALLOWLIST` and has not been touched since 2026-05-25;
# `test_matsui_fig4_dip.jl` pins the numbers read off THEIR published dataset
# and never computes ours; the other two have no test at all.
#
# What this file is: the registry, plus the assertions that keep it true.
#
#   * every GATED entry names a test file that exists and is in a tier, so a
#     claim cannot be listed as checked while its check is orphaned or deleted;
#   * the UNGATED set is a ratchet — it must match exactly, so a new type-C
#     target cannot be added to the docs without appearing here, and a gap
#     cannot be closed without deleting its entry;
#   * every target CLAUDE.md names must appear in the registry.
#
# What this file is NOT: a substitute for the runs. Closing an ungated entry
# means computing our number and comparing it, which for the Eu targets is a
# 3D dynamics run and belongs in a nightly/TSUBAME job, not here.

"""One published comparison. `gate` is the test file that performs it
(relative to `test/`), or `nothing` when nothing does."""
struct TypeCClaim
    source::String
    quantity::String
    published::String
    gate::Union{String, Nothing}
    note::String
end

const TYPE_C_CLAIMS = TypeCClaim[
    # ── Gated: a test computes our number and compares it ────────────────
    TypeCClaim(
        "Roccuzzo & Ancilotto 2019", "a_dd(Er166)", "65.5 a₀",
        "validation/test_dipolar_supersolid_tube.jl", "atomic constant"),
    TypeCClaim(
        "Roccuzzo & Ancilotto 2019", "a_dd(Dy164)", "130.8 a₀",
        "validation/test_dipolar_supersolid_tube.jl", "atomic constant"),
    TypeCClaim(
        "Roccuzzo & Ancilotto 2019",
        "supersolid is the ground state at ε_dd = 1.45 and not at 1.30",
        "their Fig. 1 tube cell (L = 15.873 µm, 11 droplets)",
        "validation/test_dipolar_supersolid_tube.jl",
        "the only entry where OUR eGPE result is compared to a published PHYSICAL conclusion"),
    TypeCClaim(
        "Rooney et al., PRA 86 053634, Fig. 2", "reservoir coefficients (γ̄, ℳ̄)",
        "γ̄ = 1.5e-4, ℳ̄ = 2.7e-4", "dynamics/test_spgpe.jl",
        "their own published coefficients, recomputed from (μ, T, ε_cut)"),
    TypeCClaim(
        "Miyazawa 2021 (¹⁵¹Eu evaporation)", "trap depth, peak density, PSD",
        "U/k_B = 350 µK, n₀ = 3.3e13 cm⁻³, PSD = 2.7e-4",
        "solvers/test_evaporation.jl", "0-D kinetic model, not the GPE"),
    TypeCClaim(
        "Miyazawa 2021 (¹⁵¹Eu evaporation)", "condensation temperature",
        "T_c ≈ 410 nK (uncorrected)", "solvers/test_condensate.jl",
        "0-D, finite-size corrected"),
    TypeCClaim(
        "Knoop et al., PRA 2011", "Na23 singlet/quintet scattering lengths",
        "a₀ = 47.36 a₀, a₂ = 52.98 a₀", "foundation/test_atoms.jl",
        "input constants, not model output"),

    # ── Ungated: named as a target, nothing computes our side ────────────
    TypeCClaim(
        "Matsui et al. 2025, Fig. 4B", "EdH dip centre and width",
        "their sim −2.5495 / 13.07 nT; their exp −2.5 / 12.84 nT", nothing,
        "test_matsui_fig4_dip.jl pins THEIR curve only. Ours is −2.5099 / 12.740 " *
        "at N = 3.5e4 (per-field rms 1.1 %, width 0.10 % — #299/#323, recorded in " *
        "docs/validation/matsui_residual_root_cause.md and matsui_campaign_report.md), " *
        "and lives in those documents, not in a gate. The 2026-08-19 reading of " *
        "this row was −2.138 / 14.62, superseded when the atom number was " *
        "corrected. The exp abscissa carries a ±10 nT offset, so only the WIDTH " *
        "arbitrates."),
    TypeCClaim(
        # THE PAPER (arXiv:2206.12265), not the fast-Larmor regime and not this
        # project's own rotation-assisted EdH quench — see
        # docs/conventions/klaus_name_disambiguation.md for why that mattered.
        "Klaus et al. 2022", "magnetostirring vortex nucleation", "—", nothing,
        "workflow/test_klaus_validation.jl now RUNS (2026-08-01 — it was not a " *
        "schema problem, its `initial_state` was inverted against the field sign) " *
        "and is in CI_EXTRA. It stays ungated here because its own header says " *
        "what it is: a plumbing smoke for the magnetostir path, NOT a physics " *
        "validation of the published vortex-stripe count, which needs the full " *
        "64x64x32 + 1 s stir"),
    TypeCClaim(
        "Matsui et al. (Eu Bogoliubov cascade)", "spin-excitation cascade", "—", nothing,
        "no test"),
    TypeCClaim(
        "Prasad et al. 2019", "vortex dynamics", "—", nothing, "no test"),
    TypeCClaim(
        "Yan, Li & Saito (Barnett)", "Barnett rotation / EdH conversion", "—", nothing,
        "the Barnett arc has run and been retracted twice; no gate"),
]

@testset "type-C claim registry" begin
    gated = [c for c in TYPE_C_CLAIMS if c.gate !== nothing]
    ungated = [c for c in TYPE_C_CLAIMS if c.gate === nothing]

    @testset "every gated claim's test exists and is in a tier" begin
        # `_tiers.jl` is include()d by the runner; pull it in when running this
        # file on its own.
        isdefined(Main, :FAST_TESTS) || include(joinpath(@__DIR__, "..", "_tiers.jl"))
        tiered = union(
            Set(FAST_TESTS), Set(CI_EXTRA), Set(FULL_EXTRA),
            Set(PHYSICS_TESTS), Set(MANUAL_TESTS_ALLOWLIST),
        )
        for c in gated
            @testset "$(c.source): $(c.quantity)" begin
                @test isfile(joinpath(@__DIR__, "..", c.gate))
                # In a tier, and NOT the manual allowlist — a claim gated only
                # by a file nothing runs is an ungated claim.
                @test c.gate in tiered
                @test !(c.gate in Set(MANUAL_TESTS_ALLOWLIST))
            end
        end
    end

    @testset "the ungated set is exactly what we admit to" begin
        # Ratchet, both directions. Adding a type-C target without a gate must
        # land here; closing a gap must delete its entry.
        @test Set(c.source for c in ungated) == Set([
            "Matsui et al. 2025, Fig. 4B",
            "Klaus et al. 2022",
            "Matsui et al. (Eu Bogoliubov cascade)",
            "Prasad et al. 2019",
            "Yan, Li & Saito (Barnett)",
        ])
    end

    @testset "every target CLAUDE.md names appears in the registry" begin
        # The doc sentence is the claim; this keeps the registry from silently
        # falling behind it.
        claude = read(joinpath(@__DIR__, "..", "..", "CLAUDE.md"), String)
        line = only(filter(l -> occursin("C: model fidelity", l), split(claude, '\n')))
        # (what CLAUDE.md writes, what the registry calls it)
        for (doc_name, registry_key) in (
            # "Klaus et al. 2022", not "Klaus 2022" and never bare "Klaus":
            # the word alone also named the fast-Larmor regime and this
            # project's own protocol. docs/conventions/klaus_name_disambiguation.md.
            ("Klaus et al. 2022", "Klaus"),
            ("Matsui", "Matsui"),
            ("Prasad 2019", "Prasad"),
            ("Yan-Li-Saito", "Saito"),
        )
            @test occursin(doc_name, line)
            @test any(c -> occursin(registry_key, c.source), TYPE_C_CLAIMS)
        end
    end

    @testset "the registry is not silently empty" begin
        # Positive control: a table nobody maintains degrades to zero rows, and
        # every assertion above would still pass.
        @test length(gated) >= 7
        @test length(ungated) >= 5
        @test all(!isempty(c.quantity) for c in TYPE_C_CLAIMS)
    end
end
