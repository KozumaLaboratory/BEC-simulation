#!/usr/bin/env julia
#
# generate_twin_controls.jl — produce LHY-off / loss-off twin controls
# for the orphan YAMLs flagged by `audit_twin_controls(runs)`.
#
# For every orphan, writes a sibling YAML in the same directory with:
#   - every `lhy:` block replaced by `lhy: {kind: "none"}`
#   - every `loss:` block removed
# and emits a top-of-file marker:
#   # TWIN CONTROL (auto-generated). Companion of:
#   #   <original path>
#   # Regenerate with: julia --project=. scripts/validation/generate_twin_controls.jl
#
# Round-trips via YAML.jl (comments lost; intentional — twins are
# derivatives, not source). The TwinAuditResult after running this
# should report 0 orphans.
#
# Usage:
#   julia --project=. scripts/validation/generate_twin_controls.jl
#   julia --project=. scripts/validation/generate_twin_controls.jl --dry-run
#
# Replaces the manual "write 23 sibling YAMLs by hand" cleanup pass
# in the 2026-05-26 self-contained-validation pivot. See
# `docs/validation/self_contained_validation_report.md` → Layer-F /
# audit section.

using YAML
using SpinorBEC

const DRY_RUN = "--dry-run" in ARGS

function _strip_lhy_loss!(node)
    if node isa AbstractDict
        for k in collect(keys(node))
            v = node[k]
            if string(k) == "lhy" && v isa AbstractDict
                node[k] = Dict("kind" => "none")
            elseif string(k) == "loss"
                delete!(node, k)
            else
                _strip_lhy_loss!(v)
            end
        end
    elseif node isa AbstractVector
        for x in node
            _strip_lhy_loss!(x)
        end
    end
    node
end

function _twin_path(orig::AbstractString)
    dir = dirname(orig)
    base, ext = splitext(basename(orig))
    joinpath(dir, base * "_TWIN_OFF" * ext)
end

function generate_one(orig::AbstractString)
    raw = YAML.load_file(orig)
    _strip_lhy_loss!(raw)
    twin = _twin_path(orig)
    if DRY_RUN
        println("  [dry-run] $orig -> $twin")
        return twin
    end
    open(twin, "w") do io
        println(io, "# TWIN CONTROL (auto-generated). Companion of:")
        println(io, "#   ", orig)
        println(io, "# Regenerate with:")
        println(io, "#   julia --project=. scripts/validation/generate_twin_controls.jl")
        println(io, "# LHY and loss blocks stripped; everything else preserved.")
        println(io, "# Comments from the original YAML are lost on the round-trip.")
        println(io)
        YAML.write(io, raw)
    end
    println("  wrote $twin")
    twin
end

function main()
    r = audit_twin_controls("runs"; verbose=false)
    orphans = vcat(r.loss_orphans, r.lhy_orphans)
    isempty(orphans) && (println("No orphans — nothing to do."); return)

    println("Found $(length(orphans)) orphan YAML(s).")
    for o in orphans
        generate_one(o)
    end

    if !DRY_RUN
        println("\nRe-running audit:")
        r2 = audit_twin_controls("runs"; verbose=false)
        show(stdout, MIME("text/plain"), r2)
        println()
        if !r2.pass
            println("\nWARNING: audit still reports orphans after twin generation.")
            exit(1)
        else
            println("\n✓ All orphans now have a sibling control twin.")
        end
    end
end

main()
