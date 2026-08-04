using Test
using SpinorBEC
using SpinorBEC: TOP_LEVEL_KEYS, GS_SCHEMA, LHY_SCHEMA, SAVE_SCHEMA, B_SCHEMA, LOSS_SCHEMA

# A key a document teaches must be a key the schema accepts.
#
# The 2026-08-04 duplicate-fact sweep found 105 facts stated in 593 places, 84
# of the sets already disagreeing. The worst were YAML spellings: a reader copies
# a block out of a guide and gets an exception before any physics starts. Five
# were live in executed guides — `save_every:` (folded into `save:`),
# `theta_deg:`/`phi_deg:` (the accepted keys are `theta`/`phi`, and in RADIANS
# rather than degrees, so a bare rename would have changed the physics).
#
# This gate compares docs against the SCHEMA ITSELF rather than a list someone
# maintains, so retiring a key makes the docs that still teach it red.
#
# Scope is deliberately narrow: a token is only a finding when it appears as a
# YAML KEY inside a ```yaml fence. The first version of this scan reported 388
# harmful `save_every` and 322 `spinor_lhy` — both are alive as Julia
# identifiers (`SimParams.save_every`, the `spinor_lhy` kwarg of
# `make_workspace`) and only the YAML usage is dead. That count was measuring
# the regex.

const _REPO = normpath(joinpath(@__DIR__, "..", ".."))

# spelling => what to use instead. Each is verified below to be absent from the
# schema, so this table cannot rot into asserting something that came back.
const RETIRED_YAML_KEYS = Dict(
    "save_every" => "save: {every: N}",
    "save_psi_snapshots" => "save: {psi: true}",
    "save_snapshot_precision" => "save: {precision: f32}",
    "save_snapshot_compression" => "save: {compression: true}",
    "spinor_lhy" => "lhy: {kind: ...}",
    "theta_deg" => "theta (RADIANS)",
    "phi_deg" => "phi (RADIANS)",
    "K3_per_m" => "K3_per_m_cubic / K3_per_m_si",
    "gamma_sc" => "Gamma_sc",
)

"Line numbers inside a ```yaml fence."
function _yaml_lines(text)
    ok = Set{Int}()
    inblock = false
    for (i, l) in enumerate(split(text, '\n'))
        st = strip(l)
        if startswith(st, "```")
            inblock = startswith(st, "```yaml")
            continue
        end
        inblock && push!(ok, i)
    end
    ok
end

_dated(text) = occursin(r"^> \*\*FROZEN \d{4}-\d{2}"m, first(text, 600))

@testset "docs teach only keys the schema accepts" begin
    @testset "the retired spellings really are retired" begin
        # Or this file asserts a fiction. Each must be absent from every schema
        # table that could plausibly own it.
        all_keys = union(Set(keys(GS_SCHEMA)), Set(keys(SAVE_SCHEMA)),
            Set(keys(B_SCHEMA)), Set(keys(LOSS_SCHEMA)), Set(keys(LHY_SCHEMA)),
            Set(String.(TOP_LEVEL_KEYS)))
        for k in keys(RETIRED_YAML_KEYS)
            @test !(k in all_keys)
        end
        # POSITIVE CONTROL: the replacements ARE accepted, so the table is not
        # simply naming strings that were never keys at all.
        @test "every" in keys(SAVE_SCHEMA)
        @test "psi" in keys(SAVE_SCHEMA)
        @test "theta" in keys(B_SCHEMA)
        @test "phi" in keys(B_SCHEMA)
        @test "lhy" in keys(GS_SCHEMA)
    end

    @testset "no maintained doc teaches a retired key" begin
        offenders = String[]
        for (root, _, files) in walkdir(joinpath(_REPO, "docs")), f in files
            endswith(f, ".md") || continue
            rel = relpath(joinpath(root, f), _REPO)
            # The two harvest archives quote configs verbatim on purpose.
            startswith(rel, "docs/validation/config_") && continue
            startswith(rel, "docs/audit/") && continue
            text = read(joinpath(root, f), String)
            # A dated document is a record, not instruction — it may quote what
            # was true then. That is the whole point of dating it.
            _dated(text) && continue
            yl = _yaml_lines(text)
            isempty(yl) && continue
            for (k, replacement) in RETIRED_YAML_KEYS
                rx = Regex("^\\s*" * k * "\\s*:", "m")
                for m in eachmatch(rx, text)
                    ln = count(==('\n'), text[1:(m.offset)]) + 1
                    ln in yl || continue
                    push!(offenders, "$rel:$ln  `$k:` -> $replacement")
                end
            end
        end
        isempty(offenders) ||
            println("  retired YAML keys taught by maintained docs:\n    ",
                join(offenders, "\n    "))
        @test offenders == String[]
    end

    @testset "the reference's top-level table IS the schema's key set" begin
        # yaml_schema_reference.md's "Top-level keys" table is a TRANSCRIPTION
        # of TOP_LEVEL_KEYS, so it drifts by construction. It listed `metadata`,
        # `name`, `notes` and `version` as accepted ("free-form, ignored at
        # runtime") after they were deleted on 2026-08-04 — the exact keys whose
        # deletion this repository had just committed.
        ref = joinpath(_REPO, "docs", "reference", "yaml_schema_reference.md")
        if !isfile(ref)
            @test_skip "reference not present"
        else
            txt = read(ref, String)
            i = findfirst("## Top-level keys", txt)
            j = findnext("Any other top-level", txt, last(i))
            @test i !== nothing && j !== nothing
            section = txt[last(i):first(j)]
            documented = Set(
                String(m.captures[1])
                for m in eachmatch(r"\|\s*`([a-z_]+)`\s*\|", section)
            )
            schema = Set(String.(collect(TOP_LEVEL_KEYS)))
            extra = sort(collect(setdiff(documented, schema)))
            missing_keys = sort(collect(setdiff(schema, documented)))
            isempty(extra) ||
                println("  reference documents keys the schema rejects: ", join(extra, " "))
            isempty(missing_keys) ||
                println("  schema keys the reference omits: ", join(missing_keys, " "))
            @test extra == String[]
            @test missing_keys == String[]
            # The extraction must actually find rows, or both sets are empty and
            # the comparison is vacuous — which is exactly what my first regex
            # did (it anchored to line start and matched nothing).
            @test length(documented) >= 8
        end
    end

    # POSITIVE CONTROL on the scanner: it must SEE a planted occurrence, or
    # "no offenders" means "the scanner is blind".
    @testset "positive control: the scanner reads yaml fences" begin
        probe = """
        # T

        ```yaml
        pipeline:
          - dynamics:
              save_every: 100
        ```
        """
        yl = _yaml_lines(probe)
        found = false
        for m in eachmatch(r"^\s*save_every\s*:"m, probe)
            ln = count(==('\n'), probe[1:(m.offset)]) + 1
            ln in yl && (found = true)
        end
        @test found
        # …and must NOT fire outside a fence
        prose = "the `save_every` field of SimParams\nsave_every: 5\n"
        @test isempty(_yaml_lines(prose))
    end
end
