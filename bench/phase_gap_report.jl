# The JUDGEMENT half of `phase_gap_error_budget.jl`, separated from the
# measurement half so that changing how a result is READ costs a second instead
# of 40 minutes of H100.
#
# That separation is not tidiness. Of the first four runs of that bench, two
# changed no physics at all — one added a recorded column, one fixed a line of
# this logic — and each still paid the full grid. Reading is cheap; measuring is
# not; they should not share a cost.
#
# ONE DECLARATION. The bench `include`s this file and calls `report`, so there is
# no second copy of the verdict to drift. Running this file directly replays the
# same judgement over a JSONL written by an earlier run:
#
#     julia bench/phase_gap_report.jl .gap_cache/rows.jsonl
#
# It deliberately does NOT depend on SpinorBEC — it reads numbers a run already
# produced, so it starts instantly and can be run anywhere.

using Printf

const REF_ARM = "reference (Euler, full_bdg)"

"""
    report(rows; io = stdout)

`rows` is any iterable of NamedTuples carrying `arm, B, dE, conv, dEf, distinct,
sep0, sep1, sep, growth`. Prints the three judgements in the order they have to be
read: whether the scaffolding produced the answer, whether the accuracy setting
changes the answer, and only then the boundary verdict.
"""
function report(rows; io::IO=stdout)
    rows = collect(rows)
    isempty(rows) && (println(io, "[report] no rows"); return nothing)
    arms = unique(r.arm for r in rows)
    BS = sort(unique(r.B for r in rows))
    at(arm, B) = rows[findfirst(r -> r.arm == arm && r.B == B, rows)]

    # The scaffolding check comes FIRST: if the common stage 1 already merged the
    # seeds, nothing below is about the physics, and saying so has to precede
    # saying anything else.
    println(io, "\n[scaffolding] which leg of sep@0 → sep@1 → sep did the collapsing?")
    let n_total = length(rows),
        # Stage 1 owns the merge when it closed more of the gap than the arm did.
        # Only meaningful where a collapse happened at all, so points that never
        # merged are counted separately rather than folded into either verdict.
        # An earlier version compared sep@1 to the FINAL sep and called them close
        # "merged" — which fires when stage 2 did nothing, not when stage 1 did
        # everything. The smoke refuted it on all 16 points.
        collapsed = [r for r in rows if r.sep < 0.1 * r.sep0]

        merged = [r for r in collapsed if (r.sep0 - r.sep1) > (r.sep1 - r.sep)]
        late = [r for r in collapsed if (r.sep0 - r.sep1) <= (r.sep1 - r.sep)]
        never = n_total - length(collapsed)
        @printf(io,
            "  stage 1 did most of it: %d   the arm did most of it: %d   no collapse: %d   (of %d)\n",
            length(merged), length(late), never, n_total)
        if !isempty(merged)
            println(io, "  The first group's `dist` verdict is about the two-stage scaffolding,")
            println(io, "  NOT about whether two minima exist. Fix the design before reading")
            println(io, "  any classification from those points.")
        elseif never == n_total
            println(io, "  Nothing collapsed anywhere — the seeds stayed apart, so `dist` is")
            println(io, "  the arm's own answer (and a too-short run looks like this too:")
            println(io, "  check `conv` before believing it).")
        else
            println(io, "  The collapse is the arm's own doing, so `dist` is about the physics.")
        end
    end

    # The classification, not ΔE, is what the claims rest on — so the next thing
    # to report is whether the ARMS AGREE about it. If two accuracy settings put
    # the same (B, seeds) in different winding classes, that disagreement IS the
    # accuracy requirement, stated in the units the claim is made in, and it needs
    # neither a converged ΔE nor a slope to mean something.
    println(io, "\n[classification] does the accuracy setting change the ANSWER?")
    @printf(io, "  %-36s %s\n", "arm", join((@sprintf("%9.2e", B) for B in BS), " "))
    for arm in arms
        @printf(io, "  %-36s %s\n", arm,
            join((at(arm, B).distinct ? "  distinct" : "      same" for B in BS), " "))
    end
    let base = Dict(B => at(arms[1], B).distinct for B in BS)
        dis = [(arm, B) for arm in arms[2:end], B in BS if at(arm, B).distinct != base[B]]
        if isempty(dis)
            println(io, "  All arms agree on every point — so no setting tested here changes")
            println(io, "  the classification, and the requirement is looser than the coarsest.")
        else
            println(io, "  DISAGREEMENT at $(length(dis)) point(s): " *
                        join(("$(a) @ B=$(b)" for (a, b) in dis), "; "))
            println(io, "  Each is a setting that changes the answer, i.e. an accuracy floor —")
            println(io, "  but read it against `sep` in the table: a pair already 4 orders")
            println(io, "  closer at that B is a near-degenerate crossover, where any setting")
            println(io, "  can flip the label and none of them is wrong.")
        end
    end

    println(io)
    ref = [at(REF_ARM, B) for B in BS]
    usable = [i for i in eachindex(BS)
              if ref[i].conv && ref[i].distinct && (ref[i].growth == 0)]
    if length(usable) < 2
        println(io, """[verdict] The reference arm has $(length(usable)) usable B point(s) — a point is
usable only if BOTH seeds converged, ended in DIFFERENT winding classes, AND the
mean field the LHY table came from is dynamically stable. Of $(length(BS)) points:
$(count(r -> r.conv, ref)) converged, $(count(r -> r.distinct, ref)) distinct, $(count(r -> r.growth == 0, ref)) stable. Fewer than two usable means
the boundary cannot be located here and no δB can be quoted — and the breakdown
says WHICH of the three is missing, so the next run changes that one rather than
the tolerances.""")
        return nothing
    end

    dEs = [ref[i].dE for i in usable]
    Bs = [BS[i] for i in usable]
    signs = sign.(dEs)
    bracketed = any(signs[1:(end - 1)] .!= signs[2:end])
    slope = (dEs[end] - dEs[1]) / (Bs[end] - Bs[1])
    @printf(io, "[verdict] usable B points: %d   ∂(ΔE)/∂B = %.4e   boundary %s\n",
        length(usable), slope, bracketed ? "BRACKETED" : "NOT bracketed")
    if !bracketed
        println(io, """  Not bracketed ⇒ this is a local rate on one side, and any δB from it is an
  extrapolation. Widen the scan before quoting a boundary shift.""")
    end
    slope == 0 && return nothing

    println(io, "  δB = δ(ΔE)/|∂(ΔE)/∂B|, each arm against the reference at the same B:")
    B0 = BS[usable[1]]
    for arm in arms
        arm == REF_ARM && continue
        g = at(arm, B0)
        d = abs(g.dE - at(REF_ARM, B0).dE)
        @printf(io, "    %-36s δ(ΔE) %10.3e → δB %10.3e  (conv %s)\n",
            arm, d, d / abs(slope), g.conv ? "yes" : "NO")
    end
    println(io, """
  The dt/2 row is the BASELINE: the boundary shift already accepted by choosing
  dt. An approximation whose δB sits well under it is not what limits the
  boundary. And note the direction that helps — a SMALL |∂(ΔE)/∂B| is the bad
  case: it means the phases stay near-degenerate over a wide range of B, so any
  energy error moves the apparent boundary a long way, and far enough that way
  there is a crossover there and not a boundary at all.""")
    nothing
end

"""
    read_rows(path) -> Vector{NamedTuple}

The JSONL the bench streams, one row per cell. Hand-parsed rather than via a JSON
package so this file has no dependencies at all and starts instantly — the rows
are flat and numeric, so there is nothing to get wrong.
"""
function read_rows(path::AbstractString)
    rows = NamedTuple[]
    for line in eachline(path)
        isempty(strip(line)) && continue
        d = Dict{String, Any}()
        for m in eachmatch(r"\"(\w+)\":(\"[^\"]*\"|[^,}]+)", line)
            k, v = m.captures[1], m.captures[2]
            d[k] = startswith(v, '"') ? String(v[2:(end - 1)]) :
                   v == "true" ? true : v == "false" ? false : parse(Float64, v)
        end
        push!(rows, (arm=d["arm"], B=d["B"], dE=d["dE"], conv=d["conv"],
            dEf=d["dEf"], distinct=d["distinct"], sep0=d["sep0"],
            sep1=d["sep1"], sep=d["sep"], growth=d["growth"]))
    end
    rows
end

if abspath(PROGRAM_FILE) == @__FILE__
    path = length(ARGS) >= 1 ? ARGS[1] :
           joinpath(@__DIR__, "..", ".gap_cache", "rows.jsonl")
    rows = read_rows(path)
    println("[report] $(length(rows)) row(s) from $(path)")
    report(rows)
end
