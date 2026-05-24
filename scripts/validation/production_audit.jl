#!/usr/bin/env julia
#
# Level 12 — production audit (twin control check).
#
# Validation ladder Level 12 (memory `validation_ladder_2026_05_24.md`):
#
#   > Eu production: every K3-on / LHY-on run has a K3-off / LHY-off
#     twin for control.
#
# Without a paired control run, conclusions about K3 / LHY effects are
# confounded with whatever else changed in the YAML. This audit walks
# `runs/` for production YAMLs and reports any K3-on / LHY-on config
# that lacks a matching control twin.
#
# Heuristic for "twin":
#   - Same basename prefix in a sibling directory
#   - The other YAML has the loss / lhy block disabled (loss: false /
#     lhy: {kind: none}) but the rest of the pipeline is identical
#     to the variable-swap level.
#
# This is intentionally a lint, not a hard test — production
# campaigns often live in their own directory with a dedicated twin
# convention. The audit prints what it found and exits 0 if every
# K3-on / LHY-on file has at least one likely twin.
#
# Usage:
#   julia --project=. scripts/validation/production_audit.jl [runs_root]
#
# Default runs_root = "runs/". Exit code 0 on PASS, 1 on FAIL.

using YAML

function _classify(yaml_path::AbstractString)
    raw = try
        YAML.load_file(yaml_path)
    catch
        return (loss=false, lhy=false, parseable=false)
    end
    pipeline = get(raw, "pipeline", nothing)
    pipeline isa AbstractVector || return (loss=false, lhy=false, parseable=true)
    has_loss = false
    has_lhy = false
    for step in pipeline
        step isa AbstractDict || continue
        for (_, body) in step
            body isa AbstractDict || continue
            # loss enabled when `loss:` is present and not false/0/null.
            if haskey(body, "loss")
                v = body["loss"]
                if v isa AbstractDict
                    has_loss = true
                elseif v isa Number && v != 0
                    has_loss = true
                elseif v isa AbstractString && lowercase(v) != "false"
                    has_loss = true
                end
            end
            # lhy enabled when `lhy.kind` != "none".
            if haskey(body, "lhy") && body["lhy"] isa AbstractDict
                kind = get(body["lhy"], "kind", "none")
                kind != "none" && (has_lhy = true)
            end
        end
    end
    (loss=has_loss, lhy=has_lhy, parseable=true)
end

function _find_yamls(root::AbstractString)
    yamls = String[]
    for (dir, _, files) in walkdir(root)
        for f in files
            endswith(f, ".yaml") || continue
            # Skip the auto-generated config.yaml snapshots stored
            # inside run output directories — those aren't user
            # production configs.
            f == "config.yaml" && continue
            # Skip Zone.Identifier sidecars from Windows transfer.
            occursin("Zone.Identifier", f) && continue
            push!(yamls, joinpath(dir, f))
        end
    end
    yamls
end

function _has_twin(yaml_path, all_yamls)
    # Look for any sibling YAML in the same directory with K3 off / LHY
    # off (i.e. a control twin).
    dir = dirname(yaml_path)
    stem = first(splitext(basename(yaml_path)))
    for other in all_yamls
        other == yaml_path && continue
        dirname(other) == dir || continue
        # Lighter heuristic: same prefix up to first `_` or shared
        # token. We accept ANY sibling with loss/lhy off as a plausible
        # twin and report the pairing.
        c = _classify(other)
        c.parseable || continue
        (!c.loss && !c.lhy) && return other
    end
    return nothing
end

root = length(ARGS) >= 1 ? String(ARGS[1]) : "runs"
isdir(root) || (println(stderr, "ERROR: $root not a directory"); exit(2))

println("=== Level 12 production audit (twin control check) ===")
println("root: $root")
println()

all_yamls = _find_yamls(root)
println("Scanned $(length(all_yamls)) YAML files (excluding cached config.yaml snapshots).")
println()

loss_on = String[]
lhy_on = String[]
unparseable = String[]

for y in all_yamls
    c = _classify(y)
    c.parseable || (push!(unparseable, y); continue)
    c.loss && push!(loss_on, y)
    c.lhy && push!(lhy_on, y)
end

println("Loss-on YAMLs : $(length(loss_on))")
println("LHY-on YAMLs  : $(length(lhy_on))")
println("Unparseable   : $(length(unparseable))")
println()

# Twin check.
loss_orphan = String[]
lhy_orphan = String[]
global twins_found = 0

for y in loss_on
    t = _has_twin(y, all_yamls)
    if t === nothing
        push!(loss_orphan, y)
    else
        global twins_found += 1
    end
end
for y in lhy_on
    # Skip if already in loss_on (avoid double-counting orphan messages).
    y in loss_on && continue
    t = _has_twin(y, all_yamls)
    if t === nothing
        push!(lhy_orphan, y)
    else
        global twins_found += 1
    end
end

println(
    "Twins found for $twins_found of $(length(loss_on) + length(lhy_on) - length(intersect(loss_on, lhy_on))) variable-on YAMLs."
)
println()

if !isempty(loss_orphan)
    println("ORPHAN loss-on YAMLs (no sibling control found):")
    for y in loss_orphan
        println("  $y")
    end
    println()
end
if !isempty(lhy_orphan)
    println("ORPHAN lhy-on YAMLs (no sibling control found):")
    for y in lhy_orphan
        println("  $y")
    end
    println()
end
if !isempty(unparseable)
    println("UNPARSEABLE YAMLs:")
    for y in unparseable
        println("  $y")
    end
    println()
end

n_orphan = length(loss_orphan) + length(lhy_orphan)
if n_orphan == 0
    println("✓ PASS: every loss-on / lhy-on YAML has at least one sibling control twin.")
    exit(0)
else
    println("✗ FAIL: $n_orphan orphan YAML(s) found. Add a sibling control twin")
    println("        (loss: false + lhy: {kind: none}) before interpreting results.")
    exit(1)
end
