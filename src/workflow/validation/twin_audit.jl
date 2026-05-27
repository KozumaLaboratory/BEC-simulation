# --- audit_twin_controls(runs_root) — Level-12 production audit ---
#
# Validation ladder Level 12 (memory `validation_ladder_2026_05_24.md`):
#   "Eu production: every K3-on / LHY-on run has a K3-off / LHY-off
#    twin for control."
#
# Without a paired control, K3 / LHY conclusions are confounded with
# whatever else changed. This function walks the `runs/` tree and
# reports any K3-on / LHY-on YAML that lacks a sibling control.
#
# Replaces `scripts/validation/production_audit.jl` (189 LOC ad-hoc
# script with bespoke CLI). The functional core is the same; the
# packaging is now a callable that returns a structured result.

export audit_twin_controls, TwinAuditResult, write_twin_off, write_missing_twins

using YAML

"""
    TwinAuditResult

Returned by `audit_twin_controls`. Fields:
* `n_scanned`     — total YAML files scanned
* `loss_on`       — Vector{String} paths with `loss:` block enabled
* `lhy_on`        — Vector{String} paths with `lhy.kind != "none"`
* `unparseable`   — Vector{String} YAMLs that didn't load
* `loss_orphans`  — `loss_on` entries lacking a sibling control twin
* `lhy_orphans`   — `lhy_on` entries lacking a sibling control twin
* `pass`          — `true` ⇔ both orphan lists empty
"""
struct TwinAuditResult
    n_scanned::Int
    loss_on::Vector{String}
    lhy_on::Vector{String}
    unparseable::Vector{String}
    loss_orphans::Vector{String}
    lhy_orphans::Vector{String}
    pass::Bool
end

function Base.show(io::IO, r::TwinAuditResult)
    print(
        io,
        "TwinAuditResult(pass=$(r.pass), $(r.n_scanned) YAMLs, " *
        "$(length(r.loss_orphans) + length(r.lhy_orphans)) orphans)",
    )
end

function Base.show(io::IO, ::MIME"text/plain", r::TwinAuditResult)
    println(io, r.pass ? "✓ " : "✗ ",
        "Twin-control audit ($(r.n_scanned) YAMLs scanned)")
    println(io, "  loss-on    : $(length(r.loss_on))")
    println(io, "  lhy-on     : $(length(r.lhy_on))")
    println(io, "  unparseable: $(length(r.unparseable))")
    if !isempty(r.loss_orphans)
        println(io, "  ORPHAN loss-on (no sibling control):")
        for y in r.loss_orphans
            println(io, "    $y")
        end
    end
    if !isempty(r.lhy_orphans)
        println(io, "  ORPHAN lhy-on (no sibling control):")
        for y in r.lhy_orphans
            println(io, "    $y")
        end
    end
end

"""
    audit_twin_controls(runs_root="runs"; verbose=false) -> TwinAuditResult

Walk `runs_root`, classify every YAML by whether it has `loss:` or
`lhy.kind != "none"` enabled, and check each "variable-on" YAML for a
sibling control twin (same directory, loss/lhy both off).
"""
function audit_twin_controls(runs_root::AbstractString="runs"; verbose::Bool=false)
    isdir(runs_root) || throw(
        ArgumentError("audit_twin_controls: $runs_root is not a directory")
    )
    yamls = _twin_find_yamls(runs_root)
    loss_on = String[]
    lhy_on = String[]
    unparseable = String[]
    for y in yamls
        c = _twin_classify(y)
        c.parseable || (push!(unparseable, y); continue)
        c.loss && push!(loss_on, y)
        c.lhy && push!(lhy_on, y)
    end

    loss_orphans = filter(y -> _twin_find_sibling(y, yamls) === nothing, loss_on)
    lhy_orphans = filter(
        y -> !(y in loss_on) && _twin_find_sibling(y, yamls) === nothing,
        lhy_on,
    )
    pass = isempty(loss_orphans) && isempty(lhy_orphans)

    verbose && println(
        TwinAuditResult(
            length(yamls), loss_on, lhy_on, unparseable,
            loss_orphans, lhy_orphans, pass),
    )

    TwinAuditResult(length(yamls), loss_on, lhy_on, unparseable,
        loss_orphans, lhy_orphans, pass)
end

function _twin_find_yamls(root::AbstractString)
    out = String[]
    for (dir, _, files) in walkdir(root)
        for f in files
            endswith(f, ".yaml") || continue
            f == "config.yaml" && continue        # skip run-output snapshots
            occursin("Zone.Identifier", f) && continue
            push!(out, joinpath(dir, f))
        end
    end
    out
end

# --- twin-control writer ---

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

_twin_off_path(orig::AbstractString) =
    let
        dir = dirname(orig)
        base, ext = splitext(basename(orig))
        joinpath(dir, base * "_TWIN_OFF" * ext)
    end

"""
    write_twin_off(orig_path) -> twin_path

Produce a LHY-off / loss-off sibling YAML next to `orig_path`. The
twin's filename is `<orig>_TWIN_OFF.yaml`. Every `lhy:` block is
replaced by `lhy: {kind: "none"}` and every `loss:` block is removed.

YAML.jl round-trips lose source comments; the new file embeds a header
pointing back to the original.
"""
function write_twin_off(orig::AbstractString)
    raw = YAML.load_file(orig)
    _strip_lhy_loss!(raw)
    twin = _twin_off_path(orig)
    open(twin, "w") do io
        println(io, "# TWIN CONTROL (auto-generated). Companion of:")
        println(io, "#   ", orig)
        println(io, "# Regenerate with: SpinorBEC.write_twin_off(\"$orig\")")
        println(io, "# LHY and loss blocks stripped; everything else preserved.")
        println(io, "# Comments from the original YAML are lost on the round-trip.")
        println(io)
        YAML.write(io, raw)
    end
    twin
end

"""
    write_missing_twins(runs_root="runs"; verbose=true) -> Vector{String}

Walk `runs_root`, find every K3-on / LHY-on YAML lacking a sibling
control, and emit a `_TWIN_OFF.yaml` twin for each. Returns the list of
twin paths written. Replaces the old `generate_twin_controls.jl` script.
"""
function write_missing_twins(runs_root::AbstractString="runs"; verbose::Bool=true)
    r = audit_twin_controls(runs_root; verbose=false)
    orphans = vcat(r.loss_orphans, r.lhy_orphans)
    isempty(orphans) && (verbose && println("No orphans — nothing to do."); return String[])
    verbose && println("Found $(length(orphans)) orphan YAML(s).")
    written = String[]
    for o in orphans
        twin = write_twin_off(o)
        verbose && println("  wrote $twin")
        push!(written, twin)
    end
    if verbose
        r2 = audit_twin_controls(runs_root; verbose=false)
        show(stdout, MIME("text/plain"), r2)
        println()
        r2.pass || println("\nWARNING: audit still reports orphans after twin generation.")
    end
    written
end

function _twin_classify(yaml_path::AbstractString)
    raw = try
        load_file(yaml_path)
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
            if haskey(body, "lhy") && body["lhy"] isa AbstractDict
                kind = get(body["lhy"], "kind", "none")
                kind != "none" && (has_lhy = true)
            end
        end
    end
    (loss=has_loss, lhy=has_lhy, parseable=true)
end

function _twin_find_sibling(yaml_path::AbstractString, all_yamls::Vector{String})
    dir = dirname(yaml_path)
    for other in all_yamls
        other == yaml_path && continue
        dirname(other) == dir || continue
        c = _twin_classify(other)
        c.parseable || continue
        (!c.loss && !c.lhy) && return other
    end
    return nothing
end
