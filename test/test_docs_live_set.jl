using Test
using SpinorBEC

# What must be TRUE, and what merely must be DATED.
#
# 183 documents cannot be kept true against a codebase taking several merges a
# day. Measured 2026-08-04: 98 of 184 rows carried claims about the code that
# were no longer true, and 7 of the 10 anchors CLAUDE.md sends readers to were
# stale (`docs/audit/docs_inventory_2026-08-04.md`).
#
# So the tree is split. Everything not in LIVE below carries a dated FROZEN
# header saying it describes the tree as of that date and is not maintained — a
# frozen document does NOT need to be true, which is what makes this affordable.
# The cost of consistency then scales with |LIVE|, not with the file count.
#
# This gate holds the split itself. It is deliberately cheap: it does not check
# whether a LIVE document is CORRECT — no test can — it checks that the
# partition is honest, so a file cannot quietly be both.

const LIVE_DOCS = [
    # GENERATED, and gated against the code by
    # `test_state_doc_is_current.jl` — the only LIVE doc whose
    # correctness is machine-checked rather than merely asserted.
    "docs/STATE.md",
    # The SPGPE Kibble-Zurek record: what reproduces, at what sigma, and under
    # which invariance checks. LIVE rather than dated because the ladder continues —
    # step 1 (c1 on) results land here — and freezing a document one is about to
    # update would be a false label.
    "docs/validation/spgpe_kz_reproduction.md",
    "docs/architecture/rotating_basis.md",
    "docs/archive/README.md",
    "docs/campaign/CAMPAIGN.md",
    "docs/campaign/fix_list.toml",
    # Which of the three things "Klaus" named is meant where (#344). LIVE
    # because it is a naming rule people are told to follow, and it has its
    # own gate: test/validation/test_klaus_name_disambiguation.jl.
    "docs/conventions/klaus_name_disambiguation.md",
    "docs/conventions/testing_strategy.md",
    "docs/design/hamiltonian_layered_architecture.md",
    "docs/design/research_spec_and_provenance_architecture.md",
    "docs/design/unified_spec_architecture.md",
    "docs/guides/fast_larmor_regime.md",
    "docs/guides/lab_user_tutorial.md",
    "docs/guides/pipeline_cookbook.md",
    "docs/guides/spgpe.md",
    "docs/guides/tsubame.md",
    "docs/index.md",
    "docs/manuscript/latex_templates/pandoc_workflow.sh",
    "docs/manuscript/papers/paper3_universal_theorem/sign_pattern_lemma1_general_S.md",
    "docs/reference/dynamics.md",
    "docs/reference/yaml_schema_reference.md",
    "docs/validation/config_metadata_blocks.toml",
    "docs/validation/config_prose_harvest.toml",
    "docs/validation/full_bdg_scheme_dependence_eu_f6.md",
    # Arrived with main 2026-08-04. It calls itself the "single entry point for
    # what this campaign established, excluded, and could not close", and
    # matsui_reproduction_status.md now points readers at it — so it is what a
    # reader is sent to, which is the LIVE test.
    # The Klaus 2022 type-C claim's evidence: published parameters per figure,
    # the systematics, the model-selection numbers, and the pre-registered
    # thresholds. LIVE rather than dated because the gate reads its thresholds
    # and one row of it is an OPEN disagreement — a reader has to know it is
    # maintained.
    "docs/validation/klaus2022_primary_source.md",
    "docs/validation/matsui_campaign_report.md",
    "docs/validation/parameter_contract_with_Ueda.md",
    "docs/validation/step6_ueda_reference_state/reference_state.yaml",
    "docs/validation/ueda_status.md"]

const _REPO = normpath(joinpath(@__DIR__, ".."))
# Match the HEADER, not the word. A live document may legitimately discuss
# something being frozen — `hamiltonian_layered_architecture.md` says "FROZEN
# 2026-06-06" about a DESIGN, not about itself — and the first version of this
# predicate flagged it, which is the instrument reading prose as metadata.
const _FROZEN_MARK = r"^> \*\*FROZEN \d{4}-\d{2}(-\d{2})?\.\*\*"m
_frozen(path) = occursin(_FROZEN_MARK, first(read(joinpath(_REPO, path), String), 600))

@testset "docs: the live/frozen split is honest" begin
    @testset "every LIVE file exists and is NOT frozen" begin
        for f in LIVE_DOCS
            p = joinpath(_REPO, f)
            @test isfile(p)
            isfile(p) && @test !_frozen(f)
        end
    end

    @testset "every other doc is dated" begin
        # A document that is neither LIVE nor dated is the failure mode this
        # whole exercise exists to remove: a reader cannot tell whether to
        # trust it. New files land here, which is the point — writing one is a
        # decision to maintain it or to date it.
        live = Set(LIVE_DOCS)
        undated = String[]
        for (root, _, files) in walkdir(joinpath(_REPO, "docs")), f in files
            endswith(f, ".md") || continue
            rel = relpath(joinpath(root, f), _REPO)
            rel in live && continue
            _frozen(rel) || push!(undated, rel)
        end
        isempty(undated) || println("  neither LIVE nor dated:\n    ", join(undated, "\n    "))
        @test undated == String[]
    end

    @testset "the budget holds" begin
        # If LIVE grows without anyone noticing, the gate silently becomes the
        # thing it replaced. 30 is not sacred; exceeding it deliberately means
        # editing this number and saying why in the commit.
        @test length(LIVE_DOCS) <= 30
        @test length(LIVE_DOCS) == length(unique(LIVE_DOCS))
    end

    # POSITIVE CONTROL. The two arms above are satisfied by a `_frozen` that
    # always returns the convenient answer, so pin that it discriminates.
    @testset "positive control: the detector reads the header" begin
        mktempdir() do d
            yes = joinpath(d, "y.md");
            no = joinpath(d, "n.md")
            write(yes, "# T\n\n> **FROZEN 2026-01-01.** …\n")
            write(no, "# T\n\njust a document\n")
            @test occursin("FROZEN", first(read(yes, String), 600))
            @test !occursin("FROZEN", first(read(no, String), 600))
        end
    end
end
