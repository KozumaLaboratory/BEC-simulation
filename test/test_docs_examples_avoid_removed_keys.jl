using Test
# Not used by the scan (this file reads markdown, not physics) but required by
# `test_tier_membership.jl`: every test file must be a standalone unit in
# parallel mode, and a file that relies on another having loaded the package is
# how `analysis/test_diagnostics.jl` passed by accident.
using SpinorBEC

# Does any LIVE document still TEACH a key the schema has removed?
#
# `docs/reference/yaml_schema_reference.md` carries a "Legacy aliases — removed"
# table: removed key | replacement | rejection site. On 2026-08-05 that table was
# CORRECT for all three keys below, and three LIVE guides were teaching the dead
# forms anyway:
#
#   docs/guides/pipeline_cookbook.md:20   backend: cuda        (enum is cpu|gpu)
#   docs/guides/lab_user_tutorial.md:49   backend: cuda
#   docs/guides/tsubame.md:181            backend: cuda
#   docs/guides/pipeline_cookbook.md:141  interactions.c_lhy   (moved to lhy:)
#   docs/reference/dynamics.md:100        loss.K3_per_m        (throws)
#
# Every one is an `inspect_config` ERROR, verified by running it — so a reader
# copying the cookbook's first example got a validation failure, not a wrong
# result. Loud, but it is exactly the shape the user named: a feature that was
# removed, left half-present in the prose, breaking when you put it in a config.
#
# The repo already knew every replacement. Nothing compared the examples against
# the table. This does.
#
# Scope, deliberately narrow so the gate stays TRUE:
#   - Only FENCED yaml/yml blocks. Prose that names a dead key in order to say it
#     is dead is the correct thing to write and must not be flagged.
#   - Only LIVE documents. FROZEN ones are dated and explicitly unmaintained
#     (`test_docs_live_set.jl` gates that split); repairing them was rejected as
#     policy on 2026-08-04.
#   - The reference file that DEFINES the table is skipped: its left column is
#     the authority, not a violation.
#   - Only rows whose left cell can be encoded UNAMBIGUOUSLY (below). A first
#     version took the leading identifier of every cell, read
#     "`loss: {K3_per_m: ...}`" as "`loss:` is retired", and flagged every
#     `loss:` block in the tree. Under-covering loudly beats over-flagging: the
#     skipped rows are printed, never silently dropped.

const DOCS = joinpath(@__DIR__, "..", "docs")
const SCHEMA_REF = joinpath(DOCS, "reference", "yaml_schema_reference.md")

# What a retired-key row can look like, and what it means inside a yaml block.
# `nested` needs the inline-mapping form because that is how the examples write
# it; a block-form `loss:\n  K3_per_m:` would be missed, which is why the
# fixture assertions below pin that real violations are still caught.
struct Rule
    label::String
    replacement::String
    pattern::Regex
end

"Encode one left-hand cell, or `nothing` if it cannot be pinned exactly."
function encode(cell::AbstractString, replacement::AbstractString)
    # More than one backticked alternative, or a parenthetical qualifier that
    # changes the meaning ("(flat B_hat)"), is not encodable as one regex.
    ticks = collect(eachmatch(r"`([^`]+)`", cell))
    length(ticks) == 1 || return nothing
    inner = strip(ticks[1].captures[1])

    # `key: {sub: ...}`  -> sub-key inside an inline mapping under key
    m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*\{\s*([A-Za-z_][A-Za-z0-9_]*)", inner)
    if m !== nothing
        k, sub = m.captures
        # `\s*:` after the sub-key so `K3_per_m` does not match `K3_per_m_cubic`
        return Rule("$k.$sub", replacement,
            Regex("^\\s*$k\\s*:\\s*\\{[^}]*\\b$sub\\s*:", "m"))
    end
    # `key: value`  -> a retired VALUE; the key itself is current
    m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*$", inner)
    if m !== nothing
        k, v = m.captures
        return Rule("$k: $v", replacement, Regex("^\\s*$k\\s*:\\s*$v\\b", "m"))
    end
    # `path.to.key`  -> leaf inside an inline mapping under the parent
    m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)$", inner)
    if m !== nothing
        parent, leaf = m.captures
        return Rule(inner, replacement,
            Regex("^\\s*$parent\\s*:\\s*\\{[^}]*\\b$leaf\\s*:", "m"))
    end
    # bare `key:`  -> a retired step-level key
    m = match(r"^([A-Za-z_][A-Za-z0-9_]*)\s*:$", inner)
    if m !== nothing
        k = m.captures[1]
        return Rule("$k:", replacement, Regex("^\\s*$k\\s*:", "m"))
    end
    nothing
end

"Rules from the 'Legacy aliases — removed' table, plus the cells it could not encode."
function retired_rules(path=SCHEMA_REF)
    lines = readlines(path)
    i = findfirst(l -> occursin("Legacy aliases", l), lines)
    i === nothing && return (Rule[], String[])
    rules, skipped = Rule[], String[]
    for l in lines[i:end]
        startswith(l, "|") || continue
        cells = strip.(split(l, "|"; keepempty=false))
        length(cells) >= 2 || continue
        (startswith(cells[1], "removed key") || all(c -> all(∈("-: "), c), cells)) && continue
        r = encode(cells[1], cells[2])
        r === nothing ? push!(skipped, cells[1]) : push!(rules, r)
    end
    (rules, skipped)
end

"Fenced yaml/yml blocks as (start_line, text)."
function yaml_blocks(path)
    blocks, open_at, buf = Tuple{Int, String}[], 0, String[]
    for (n, l) in enumerate(readlines(path))
        s = strip(l)
        if open_at == 0 && (s == "```yaml" || s == "```yml")
            open_at, buf = n, String[]
        elseif open_at != 0 && startswith(s, "```")
            push!(blocks, (open_at, join(buf, "\n")))
            open_at = 0
        elseif open_at != 0
            push!(buf, l)
        end
    end
    blocks
end

is_frozen(p) = any(l -> occursin("FROZEN", l), Iterators.take(eachline(p), 6))

function live_markdown()
    out = String[]
    for (root, _, files) in walkdir(DOCS)
        occursin(joinpath("docs", "audit"), root) && continue   # machine output; quotes old text
        for f in files
            endswith(f, ".md") || continue
            p = joinpath(root, f)
            (abspath(p) == abspath(SCHEMA_REF) || is_frozen(p)) && continue
            push!(out, p)
        end
    end
    out
end

scan(rules, docs) = [
    "$(relpath(p, dirname(DOCS))) (yaml at line $line): `$(r.label)` was removed — use $(r.replacement)"
    for p in docs for (line, body) in yaml_blocks(p) for r in rules if occursin(r.pattern, body)
]

@testset "LIVE docs do not teach a removed schema key" begin
    rules, skipped = retired_rules()
    docs = live_markdown()

    # CALIBRATION. An empty rule set passes every input; an extractor that finds
    # no yaml blocks reports every document clean. Both print what success
    # prints, so assert the population before judging it.
    @testset "the instrument sees its inputs" begin
        @test length(rules) >= 6
        @test any(r -> r.label == "backend: cuda", rules)
        @test any(r -> r.label == "interactions.c_lhy", rules)
        @test any(r -> r.label == "loss.K3_per_m", rules)
        # Measured 2026-08-05: 19 LIVE markdown files carrying 15 fenced yaml
        # blocks. Set just below, so a collapse of the population reddens here
        # rather than passing as "no violations". First written as >= 20 from a
        # guess, which failed on the true value.
        @test length(docs) >= 18
        @test sum(length(yaml_blocks(p)) for p in docs) >= 14
    end

    # A rule set this broad has one dangerous failure mode: flagging the CORRECT
    # form. Pin both directions on synthetic blocks so over-breadth reddens here
    # rather than in someone's unrelated PR.
    @testset "catches the dead form, spares the live one" begin
        dead = """
            pipeline:
              - ground_state:
                  interactions: {N_atoms: 5, c_lhy: 1135.0}
                  loss: {K3_per_m: [0.1]}
                  backend: cuda
            """
        live = """
            pipeline:
              - ground_state:
                  interactions: {N_atoms: 5, c1_ratio: 0.0}
                  lhy: {kind: scalar, c_lhy: 1135.0}
                  loss: {K3_per_m_cubic: [0.1], K3_per_m_si: ["1e-30 m^6/s"]}
                  backend: gpu
            """
        hits(body) = [r.label for r in rules if occursin(r.pattern, body)]
        @test "backend: cuda" in hits(dead)
        @test "interactions.c_lhy" in hits(dead)
        @test "loss.K3_per_m" in hits(dead)
        # and the corrected forms trip nothing — `lhy.c_lhy`, `K3_per_m_cubic`,
        # `K3_per_m_si` and `backend: gpu` are all current.
        @test isempty(hits(live))
    end

    violations = scan(rules, docs)
    if !isempty(violations) || !isempty(skipped)
        !isempty(violations) && println("\nLIVE documents teaching a removed schema key:")
        foreach(v -> println("  ", v), violations)
        # No silent caps: say which table rows this gate does NOT cover.
        !isempty(skipped) &&
            println("\nnot encodable as one pattern, NOT checked (", length(skipped), "):")
        foreach(s -> println("  - ", s), skipped)
    end
    @test isempty(violations)
end
