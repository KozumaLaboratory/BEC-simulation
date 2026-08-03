# The cutover step-6 harvest — every item routed, nothing able to vanish.
#
# `docs/design/unified_spec_architecture.md` cutover step 6. Gates
# `docs/validation/config_prose_harvest.toml` (the judgement: 300 items, each
# with a bucket, a disposition and a written destination) and
# `docs/validation/config_metadata_blocks.toml` (the mechanical record: the 302
# `metadata:` blocks the step deletes, verbatim).
#
# THE PROPERTY THIS FILE GATES. Not "the harvest is good" — nothing can test
# that. It gates that the harvest cannot silently SHRINK. The failure this step
# is exposed to is the one the whole campaign is about: knowledge that is only
# in prose disappears when the prose is edited, and nobody notices because
# nothing was reading it. So the gate is a SET EQUALITY over item ids plus
# pinned counts, and the counts are LITERALS HERE, read from nothing:
#
#   1. Every id in the file is in the pinned set and vice versa. Deleting a row,
#      renaming one, or adding one unannounced turns this red.
#   2. Every item has a non-empty bucket from the closed vocabulary, a
#      disposition from the closed vocabulary, and a non-empty `destination` —
#      which is the "a discard needs a stated reason, silence is not a bucket"
#      rule made mechanical.
#   3. Counts per bucket and per disposition, pinned. Arm 1 alone would stay
#      green if someone reclassified 60 caveats as discards; a gate that reads
#      the file and checks the file proves nothing.
#   4. The metadata dump covers exactly the configs that still carry a block, so
#      the safety net cannot be narrower than the thing being cut.
#
# WHY THE COUNTS ARE SPELLED OUT AND NOT SUMMED FROM THE FILE. The same reason
# `test_matsui2025_ref.jl` pins its four dip numbers: a self-consistent file is
# the thing that goes wrong, and a check derived from the artifact it checks is
# an identity. These numbers were measured on the tree at the commit that landed
# the harvest, and if a later pass legitimately changes one, changing it here is
# the declaration that it was deliberate.

using Test
using TOML

const _REPO = normpath(joinpath(@__DIR__, "..", ".."))
const _HARVEST = joinpath(_REPO, "docs", "validation", "config_prose_harvest.toml")
const _MDUMP = joinpath(_REPO, "docs", "validation", "config_metadata_blocks.toml")

# --- the pins. Literals, in this file, read from nothing. --------------------

const PIN_ITEMS = 300
const PIN_SUITES = 6
const PIN_CONFIGS_READ = 391
const PIN_PROSE_LINES = 5347

# What the knowledge IS.
const PIN_BUCKETS = Dict(
    "DERIVATION" => 87,
    "CAVEAT" => 74,
    "RETRACTION" => 67,
    "TARGET" => 54,
    "DISCARD" => 18,
)

# Where it went TODAY. The five `open_*` rows are the debt: 252 of 300 items
# have a named destination that does not exist yet. That is the honest number
# and it is pinned so it cannot drift downward without someone saying so.
const PIN_DISPOSITIONS = Dict(
    "landed" => 27,
    "refs_extended" => 3,
    "open_needs_code" => 75,
    "open_needs_measurement" => 37,
    "open_no_pinnable_source" => 9,
    "open_ledger_caveat" => 67,
    "open_ledger_retracted" => 64,
    "discard" => 18,
)

const PIN_SUITE_ITEMS = Dict(
    "matsui_ueda" => 100,
    "eu151_edh" => 70,
    "residual" => 34,
    "eu_gs_phase" => 32,
    "eu_k3_lhy" => 32,
    "klaus_barnett" => 32,
)

# The `metadata:` block being deleted, measured on the tree.
# 321, not 302. Nineteen more arrived WITH origin/main while this cutover was
# deleting the key from the schema — `runs/matsui_fig4b/*` (14) and
# `runs/lhy_mode_ablation_reconstructed/*` (5). Arm 4 caught them: it asserts
# that whatever still carries a block on disk is in the dump, "the net may be
# wider than the cut, never narrower", and the merge made the cut narrower.
# Left alone they would have been configs whose `metadata:` the schema no longer
# accepts.
const PIN_MD_BLOCKS = 321
const PIN_MD_LINES = 2225
# 60: the new blocks contributed `reconstructs`. The others (`suite`,
# `claim_type`, `grid_n`, `ladder_level`, `reference`, `target`, `LHY_kind`)
# were already in the 59.
const PIN_MD_KEYS = 60

# Every id, spelled out. This is the set-equality arm and it is deliberately
# long: an inventory whose membership is summarised rather than listed is an
# inventory an item can fall out of.
const PIN_IDS = Set{String}(
    vcat(
        ["matsui_ueda-$(lpad(i, 3, '0'))" for i in 1:100],
        ["eu_gs_phase-$(lpad(i, 3, '0'))" for i in 1:32],
        ["eu151_edh-$(lpad(i, 3, '0'))" for i in 1:70],
        ["eu_k3_lhy-$(lpad(i, 3, '0'))" for i in 1:32],
        ["klaus_barnett-$(lpad(i, 3, '0'))" for i in 1:32],
        ["residual-$(lpad(i, 3, '0'))" for i in 1:34],
    ),
)

@testset "config prose harvest" begin
    @test isfile(_HARVEST)
    @test isfile(_MDUMP)
    doc = TOML.parsefile(_HARVEST)
    items = doc["item"]

    @testset "arm 1 — set equality over item ids" begin
        ids = Set(String(i["id"]) for i in items)
        @test length(ids) == length(items)          # no duplicate ids
        @test length(PIN_IDS) == PIN_ITEMS          # the pin is the size it claims
        @test setdiff(PIN_IDS, ids) == Set{String}()   # nothing lost
        @test setdiff(ids, PIN_IDS) == Set{String}()   # nothing smuggled in
    end

    @testset "arm 2 — every item is routed, and a discard states its reason" begin
        buckets = Set(String.(doc["harvest"]["buckets"]))
        disps = Set(String.(doc["harvest"]["dispositions"]))
        @test buckets == Set(keys(PIN_BUCKETS))
        @test disps == Set(keys(PIN_DISPOSITIONS))
        for it in items
            @test String(it["bucket"]) in buckets
            @test String(it["disposition"]) in disps
            # A destination or a stated reason — the same field, because "this
            # stays in prose because X" is a routing decision, not an absence.
            @test !isempty(strip(String(it["destination"])))
            @test !isempty(strip(String(it["locus"])))
            @test !isempty(strip(String(it["verbatim"])))
            @test !isempty(strip(String(it["why"])))
            # An open item must say what blocks it; a closed one must not pretend to.
            if startswith(String(it["disposition"]), "open_")
                @test !isempty(strip(String(get(it, "blocked_on", ""))))
            end
        end
    end

    @testset "arm 3 — pinned counts, per bucket and per disposition" begin
        @test length(items) == PIN_ITEMS
        @test doc["harvest"]["items"] == PIN_ITEMS
        @test doc["harvest"]["suites"] == PIN_SUITES
        @test doc["harvest"]["configs_read"] == PIN_CONFIGS_READ
        @test doc["harvest"]["prose_lines_attributed"] == PIN_PROSE_LINES
        count_by(f) = begin
            c = Dict{String, Int}()
            for it in items
                k = String(it[f])
                c[k] = get(c, k, 0) + 1
            end
            c
        end
        @test count_by("bucket") == PIN_BUCKETS
        @test count_by("disposition") == PIN_DISPOSITIONS
        @test count_by("suite") == PIN_SUITE_ITEMS
        @test Set(keys(doc["suite"])) == Set(keys(PIN_SUITE_ITEMS))
        for (s, n) in PIN_SUITE_ITEMS
            @test doc["suite"][s]["items"] == n
        end
        # The debt, stated as one number rather than left to be added up.
        open_n = count(it -> startswith(String(it["disposition"]), "open_"), items)
        @test open_n == 252
    end

    @testset "arm 4 — the safety net covers the thing being cut" begin
        md = TOML.parsefile(_MDUMP)
        blocks = md["block"]
        @test length(blocks) == PIN_MD_BLOCKS
        @test md["dump"]["configs_with_metadata"] == PIN_MD_BLOCKS
        @test md["dump"]["physical_lines"] == PIN_MD_LINES
        @test md["dump"]["distinct_keys"] == PIN_MD_KEYS
        @test length(md["dump"]["key_counts"]) == PIN_MD_KEYS
        # Not 45. The cutover plan's estimate was low and the file says so.
        @test PIN_MD_KEYS != 45   # the cutover plan estimated 45; it was low then and lower now
        dumped = Set(String(b["path"]) for b in blocks)
        @test length(dumped) == PIN_MD_BLOCKS       # one row per config, no dupes
        for b in blocks
            @test startswith(String(b["path"]), "runs/")
            @test occursin("metadata:", String(b["raw"]))
            @test !isempty(b["keys"])
        end
        # Whatever still carries a block on disk must be in the dump. Once the
        # deletion lands this set is empty and the arm is vacuously true, which
        # is the point: the net may be wider than the cut, never narrower.
        still = String[]
        for (root, _, files) in walkdir(joinpath(_REPO, "runs"))
            for f in files
                endswith(f, ".yaml") || endswith(f, ".yml") || continue
                p = joinpath(root, f)
                any(startswith(l, "metadata:") for l in eachline(p)) || continue
                push!(still, relpath(p, _REPO))
            end
        end
        @test isempty(setdiff(Set(still), dumped))
    end
end
