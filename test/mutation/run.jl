# test/mutation/run.jl — run the defect catalog against the suite.
#
#   julia --project=. test/mutation/run.jl [options]
#     --mutants a,b,…     subset of catalog ids            (default: all)
#     --shard k/n         every n-th class from k         (default: no sharding)
#     --probe NAME|list   grounded_cheap | oracles | fast  (default: grounded_cheap)
#                         or a comma-separated list of test files
#     --workers N         parallel test processes          (default: CPU threads − 2)
#     --out DIR           where the matrix + report go      (default: mutation_out/)
#     --allow-dirty       run with uncommitted src changes  (default: refuse)
#
# Cost: one package precompile per mutant. On-demand / nightly, not a PR gate.
#
# The harness edits files under `src/` and restores them. It refuses to start on
# a dirty `src/` so that "restored" is verifiable, restores in a `finally`, and
# re-checks `git diff` at the end.

using Dates

const _MUT_DIR = @__DIR__
const _TEST_DIR = dirname(_MUT_DIR)
const _ROOT = dirname(_TEST_DIR)

include(joinpath(_MUT_DIR, "catalog.jl"))
include(joinpath(_TEST_DIR, "_tiers.jl"))
include(joinpath(_TEST_DIR, "_inventory.jl"))

# ── options ────────────────────────────────────────────────────────
_arg(flag, default) = (i=findfirst(==(flag), ARGS);
    i === nothing ? default : ARGS[i + 1])

const OUT = abspath(_arg("--out", joinpath(_ROOT, "mutation_out")))
const NWORKERS = parse(Int, _arg("--workers", string(max(1, Sys.CPU_THREADS - 2))))
const ALLOW_DIRTY = "--allow-dirty" in ARGS

const MAX_COST = parse(Float64, _arg("--max-cost", "15"))

# Files `--max-cost` removed from the probe. Reported beside every escape claim:
# an escape is relative to the probe that ran, and this is the part of the suite
# that did not. Measured 2026-08-02 (#276): all SIX mutants that escaped the
# default `grounded_cheap` / 15 s probe were caught once the whole `full` tier
# ran with the cap lifted — four of them by a single file, one of which
# (workflow/test_lhy_block_wiring.jl, 256 s) this cap is what removes.
const EXCLUDED_BY_COST = String[]

function probe_files()
    spec = _arg("--probe", "grounded_cheap")
    # A comma-separated spec is a UNION of specs, resolved one at a time. The
    # first version treated the whole string as one token, so `dir:a,dir:b`
    # matched no branch — and the empty-selection guard below is what turned
    # that into an error instead of a report full of false gaps.
    if occursin(",", spec) && !occursin(".jl", spec)
        parts = string.(split(spec, ","))
        return unique(reduce(vcat, [_probe_spec(p) for p in parts]))
    end
    _probe_spec(spec)
end

function _probe_spec(spec::AbstractString)
    sel = if occursin(".jl", spec)
        string.(split(spec, ","))
    elseif spec == "oracles"
        copy(ORACLE_TESTS)
    elseif spec == "fast"
        select_tests("fast")
    elseif startswith(spec, "dir:")
        # Every tier-listed file under a subdirectory. The question "which of
        # test/workflow/ earns its runtime?" needs the whole directory in the
        # pool, not a grounding-filtered subset of it.
        pre = spec[5:end]
        filter(f -> startswith(f, pre), select_tests("full"))
    elseif spec == "grounded_cheap"
        # Files that can ground a claim (not pins, not API spellings). The pool
        # is deliberately wide: the question is WHICH file catches a defect, so
        # narrowing it up front would answer a different question.
        inv = inventory(_TEST_DIR)
        [
            f.path for f in inv
            if primary(f) in (:order, :differential, :metamorphic, :invariant, :exact) &&
                f.tier ∉ ("manual", "UNLISTED")
        ]
    else
        error("unknown --probe $spec")
    end
    # An unparseable or over-narrow probe must not silently measure nothing: with
    # zero files every mutant "escapes" and the report reads as a wall of gaps.
    # (Hit on 2026-07-31 with `--probe dir:a,dir:b`, which matches no branch and
    # returned an empty list — the exact silent-no-op class this catalog exists to
    # hunt, in the harness itself.)
    isempty(sel) && error("--probe $spec selected NO files. Check the spec; \
                           `dir:` takes one prefix, and a file list must name \
                           paths relative to test/.")
    # Every probe file is re-run once per mutant, so a single slow file costs
    # `--max-cost × n_mutants`. Dropped files are named, never silently cut.
    keep = filter(f -> _cost(f) <= MAX_COST, sel)
    isempty(keep) && error("--max-cost $MAX_COST removed every probe file; raise it.")
    dropped = setdiff(sel, keep)
    # UNION, not append: `probe_files` calls this once per comma-separated spec,
    # so a union like `dir:a,dir:b` would otherwise count a shared dropped file
    # twice — in the one section whose whole job is to state the probe's boundary
    # honestly.
    append!(EXCLUDED_BY_COST, setdiff(dropped, EXCLUDED_BY_COST))
    isempty(dropped) || println("  probe: dropped $(length(dropped)) file(s) over \
        --max-cost=$MAX_COST (", round(Int, sum(_cost, dropped)), "s): ",
        join(first(sort(dropped; by=_cost, rev=true), 5), ", "), " …")
    keep
end

function chosen_mutants()
    ids = _arg("--mutants", "")
    sel = if isempty(ids)
        MUTANTS
    else
        want = Set(Symbol.(split(ids, ",")))
        got = filter(m -> m.id in want, MUTANTS)
        length(got) == length(want) ||
            error("unknown mutant id(s): $(setdiff(want, Set(m.id for m in got)))")
        got
    end
    _shard(sel)
end

# `--shard k/n` takes every n-th class starting at k. A full pass costs
# n_mutants × n_probe_files package loads, which on one runner is hours: the
# nightly job asked for the whole catalog and was killed at its 180-minute
# timeout every night, doing nothing at all (2026-08-01). Sharding turns that
# into a sweep that completes over n nights and finishes every night.
#
# What is dropped is NAMED, not silently cut — a report that covers 1/7th of
# the catalog and does not say so reads as a clean bill of health.
function _shard(sel)
    spec = _arg("--shard", "")
    isempty(spec) && return sel
    parts = split(spec, "/")
    length(parts) == 2 || error("--shard takes k/n, got $spec")
    k, n = parse(Int, parts[1]), parse(Int, parts[2])
    (n >= 1 && 0 <= k < n) || error("--shard k/n needs 1 ≤ n and 0 ≤ k < n, got $spec")
    out = [m for (i, m) in enumerate(sel) if (i - 1) % n == k]
    isempty(out) && error("--shard $spec selected no classes out of $(length(sel))")
    println("  shard $k/$n: $(length(out)) of $(length(sel)) classes — NOT a full \
             catalog pass. Skipped: ", join(
            [String(m.id) for m in sel if !(m in out)], ", "))
    out
end

# ── running one probe pass ─────────────────────────────────────────
# Reuses test/run_chunk.jl's shared claim queue verbatim, so a probe pass
# executes each file exactly the way `Pkg.test()` does — a harness that ran
# tests its own way could report a catch the real suite would miss.

const _JL = Base.julia_cmd()

# file => every per-pass runtime this sweep observed, filled by `run_probe`.
# `cost_of` prefers the median of these over `_cost`'s estimate.
const MEASURED = Dict{String, Vector{Float64}}()

"""
    cost_of(f) -> Float64

Seconds for one run of `f`: the median MEASURED on this machine when the sweep
has run it, else `_cost`'s hand-entered/`_DEFAULT_COST` estimate. Which one it
was is reported, because a set cover minimises whatever cost it is handed and a
tier recommendation is only as good as those seconds.
"""
function cost_of(f)
    v = get(MEASURED, f, Float64[])
    isempty(v) && return _cost(f)
    sort!(v)
    n = length(v)
    isodd(n) ? v[(n + 1) ÷ 2] : (v[n ÷ 2] + v[n ÷ 2 + 1]) / 2
end
is_measured(f) = !isempty(get(MEASURED, f, Float64[]))

# The harness spawns `run_chunk.jl` directly, so it does NOT inherit the
# deterministic FFT planning that `test/runtests.jl` sets. Without this a mutant
# would be compared against a baseline planned differently — round-off differences
# read as catches. See src/foundation/fft_planning.jl.
get!(ENV, "SPINORBEC_FFT_ESTIMATE", "1")

precompile_package() = run(
    pipeline(
        `$_JL --startup-file=no --project=$_ROOT -e "using Pkg; Pkg.precompile()"`;
        stdout=devnull, stderr=devnull),
)

"""
    run_probe(files, nworkers) -> Dict{String, Symbol}

`:green` passed, `:red` failed, `:unknown` never reported a verdict (its worker
died). `:unknown` is deliberately not merged into either — see the comment below.
"""
function run_probe(files::Vector{String}, nworkers::Int)
    qdir = mktempdir()
    write(joinpath(qdir, "queue.txt"), join(files, "\n"))
    runner = joinpath(_TEST_DIR, "run_chunk.jl")
    asyncmap(1:nworkers; ntasks=nworkers) do _
        run(
            pipeline(
                ignorestatus(
                    `$_JL --startup-file=no --project=$_ROOT --pkgimages=existing $runner --queue $qdir`
                );
                stdout=devnull, stderr=devnull),
        )
    end
    out = Dict{String, Symbol}()
    for (i, f) in enumerate(files)
        marker = joinpath(qdir, "done_$i")
        # THREE outcomes, not two. Folding a missing marker into FAIL is wrong in
        # a way that is invisible and that removes coverage rather than adding it:
        # a file whose worker died is then CREDITED with catching the mutant, so a
        # real gap is booked as covered and never re-probed. Which is the opposite
        # of the intent — the original comment reasoned only about the escape
        # direction ("an unrun file must never read as escaped") and that half is
        # still honoured below, because :unknown is not an escape either.
        #
        # Found 2026-08-01: the smoke run reported `oracles/test_continuity_equation.jl`
        # RED before any mutation, and it passes in isolation on the same commit and
        # the same node type through this very code path (`PASS 9.48`). It has no
        # randomness and one deterministic assertion, so it was never red — its
        # marker was missing. 12 workers, `maxrss` 51 GB in a 4-slot allocation.
        txt = isfile(marker) ? read(marker, String) : ""
        out[f] = if isempty(txt)
            :unknown
        elseif startswith(txt, "FAIL")
            :red
        else
            :green
        end
        # `run_chunk.jl` writes "<PASS|FAIL> <secs> <file>", so every pass has
        # already MEASURED this file on the machine that will schedule it. The
        # harness was discarding that and falling back to `_cost`, which is
        # `_DEFAULT_COST = 3.0` for everything outside its 88 hand-entered files
        # — measured on a 4-vCPU GitHub runner, and low by 3x for at least one
        # file (test_continuity_equation.jl: 3.0 declared, 9.48 s measured here).
        # Keep them: a report whose verdicts are measured and whose seconds are a
        # placeholder invites the placeholder to be quoted.
        parts = split(txt)
        if length(parts) >= 2
            s = tryparse(Float64, parts[2])
            s === nothing || push!(get!(MEASURED, f, Float64[]), s)
        end
    end
    rm(qdir; recursive=true, force=true)
    return out
end

# ── driver ─────────────────────────────────────────────────────────
function git_src_dirty()
    !success(`git -C $_ROOT diff --quiet -- src`) ||
        !success(`git -C $_ROOT diff --cached --quiet -- src`)
end

# A killed run (SIGTERM/SIGKILL, Ctrl-C, CI timeout) does not necessarily run
# `finally`, and a mutant left behind in src/ is a silently wrong repository —
# it happened on the first run of this harness. So the pre-mutation bytes go to
# a sidecar on disk BEFORE the file is touched, and the next run restores from
# it. Restoring from git instead would be simpler and wrong: with --allow-dirty
# it would throw away the working-tree changes the run was measuring.
const _INFLIGHT = joinpath(_MUT_DIR, ".inflight")
const _BACKUP = joinpath(_MUT_DIR, ".inflight_backup")

function recover_inflight()
    isfile(_INFLIGHT) && isfile(_BACKUP) || return rm(_INFLIGHT; force=true)
    f = strip(read(_INFLIGHT, String))
    @warn "recovering a mutation left behind by a killed run" file = f
    cp(_BACKUP, joinpath(_ROOT, f); force=true)
    rm(_INFLIGHT; force=true)
    rm(_BACKUP; force=true)
end

function apply!(m::Mutant)
    path = joinpath(_ROOT, m.file)
    src = read(path, String)
    count(m.pattern, src) == 1 || error("anchor for $(m.id) is STALE")
    write(_BACKUP, src)
    write(_INFLIGHT, m.file)
    write(path, replace(src, m.pattern => m.replacement))
    return nothing
end

function restore!(m::Mutant)
    cp(_BACKUP, joinpath(_ROOT, m.file); force=true)
    rm(_INFLIGHT; force=true)
    rm(_BACKUP; force=true)
end

function main()
    mkpath(OUT)
    recover_inflight()
    stale = check_anchors(_ROOT)
    if !isempty(stale)
        for (m, n) in stale
            println("STALE anchor: $(m.id) matched $n× in $(m.file)")
        end
        error("$(length(stale)) stale anchor(s) — a refactor moved the site; \
               fix the catalog before trusting any result.")
    end
    if git_src_dirty() && !ALLOW_DIRTY
        error("src/ has uncommitted changes; the harness edits src/ and must be \
               able to prove it restored it. Commit/stash, or pass --allow-dirty.")
    end

    files = probe_files()
    muts = chosen_mutants()
    println("mutation run: $(length(muts)) mutants × $(length(files)) probe files, \
             $NWORKERS workers → $OUT")

    println("\n[baseline] precompiling + running probe set unmutated…")
    precompile_package()
    baseline = run_probe(files, NWORKERS)
    already_red = sort([f for (f, s) in baseline if s === :red])
    base_unknown = sort([f for (f, s) in baseline if s === :unknown])
    if !isempty(already_red)
        println("  $(length(already_red)) file(s) already RED before any mutation \
                 — excluded from the catch matrix:")
        foreach(f -> println("    ", f), already_red)
    end
    if !isempty(base_unknown)
        println("  $(length(base_unknown)) file(s) never reported a verdict in the \
                 baseline (worker died — NOT a red test). Lower --workers; each one \
                 holds SpinorBEC + CUDA. Excluded:")
        foreach(f -> println("    ", f), base_unknown)
    end
    live = filter(f -> baseline[f] === :green, files)

    # catch[mutant id] = files that went red under it. `unknowns` is kept SEPARATE:
    # a file that never reported cannot be credited with a catch (that books a real
    # gap as covered), and cannot be called green either.
    catches = Dict{Symbol, Vector{String}}()
    unknowns = Dict{Symbol, Vector{String}}()
    for (k, m) in enumerate(muts)
        print("\n[$k/$(length(muts))] $(m.id) ($(m.class), $(m.severity)) … ")
        apply!(m)
        try
            precompile_package()
            res = run_probe(live, NWORKERS)
            catches[m.id] = sort([f for (f, s) in res if s === :red])
            unknowns[m.id] = sort([f for (f, s) in res if s === :unknown])
        finally
            restore!(m)
        end
        n = length(catches[m.id])
        u = length(unknowns[m.id])
        # An escape claim is only as good as the completeness of the probe that
        # produced it, so it is stated with the unknown count attached rather than
        # asserted flatly.
        println(
            if n == 0
                (
                    if u == 0
                        "ESCAPED THIS PROBE — no probe file caught it"
                    else
                        "UNRESOLVED — nothing caught it, but $u file(s) never reported"
                    end
                )
            else
                (u == 0 ? "caught by $n file(s)" : "caught by $n file(s) ($u unreported)")
            end,
        )
    end

    git_src_dirty() && @error "src/ is dirty after the run — inspect `git diff -- src`"

    write_matrix(muts, live, catches)
    report(muts, live, catches, already_red, unknowns, base_unknown)
end

function write_matrix(muts, files, catches)
    open(joinpath(OUT, "catch_matrix.csv"), "w") do io
        println(io, "file,", join((string(m.id) for m in muts), ","))
        for f in files
            println(io, f, ",",
                join((m.id in keys(catches) && f in catches[m.id] ? 1 : 0
                      for m in muts), ","))
        end
    end
end

"""Greedy set cover: the cheapest file subset that still catches every mutant
any file catches. This is what a `fast` tier should be — not the files that
happen to run quickly."""
function min_cover(muts, files, catches)
    remaining = Set(m.id for m in muts if !isempty(get(catches, m.id, String[])))
    cost = Dict(f => cost_of(f) for f in files)
    picked = String[]
    while !isempty(remaining)
        best, best_score = "", -Inf
        for f in files
            f in picked && continue
            gain = count(id -> f in catches[id], remaining)
            gain == 0 && continue
            score = gain / max(cost[f], 0.1)
            score > best_score && ((best, best_score) = (f, score))
        end
        isempty(best) && break
        push!(picked, best)
        setdiff!(remaining, [id for id in remaining if best in catches[id]])
    end
    picked
end

function report(muts, files, catches, already_red, unknowns=Dict{Symbol, Vector{String}}(),
    base_unknown=String[])
    io = IOBuffer()
    println(io, "# Mutation report — ", Dates.format(now(), "yyyy-mm-dd HH:MM"))
    println(io, "\n$(length(muts)) cataloged defect classes × $(length(files)) probe files.\n")

    _unk(m) = get(unknowns, m.id, String[])
    nothing_caught = [m for m in muts if isempty(get(catches, m.id, String[]))]
    # An escape is a claim about the WHOLE probe set having run. Where files went
    # unreported, the honest verdict is unresolved — reported separately so it can
    # be re-probed, not averaged into either bucket.
    escaped = [m for m in nothing_caught if isempty(_unk(m))]
    unresolved = [m for m in nothing_caught if !isempty(_unk(m))]

    println(io, "## Caught by nothing in the probe ($(length(escaped)))\n")
    # NOT "a real gap", which is what this said until 2026-08-02 and which the
    # numbers do not support: escaping a 264-file grounded/<=15 s probe is not
    # escaping the suite. All six escapes from that probe were caught by the full
    # tier. State the probe's boundary next to the claim so the claim cannot be
    # quoted without it.
    if !isempty(EXCLUDED_BY_COST)
        println(io, "Relative to THIS probe. `--max-cost=$MAX_COST` held back ",
            "$(length(EXCLUDED_BY_COST)) file(s) totalling ",
            round(Int, sum(_cost, EXCLUDED_BY_COST)), "s, and `grounded_cheap` ",
            "excludes pins and API-spelling tests entirely. Re-probe an escape ",
            "with `--probe dir: --max-cost 400` before calling it a gap.\n")
    end
    isempty(escaped) && println(io, "(none)\n")
    for m in sort(escaped; by=m -> (m.severity != :fatal, m.severity != :gross))
        println(io, "- **$(m.id)** [$(m.severity)/$(m.class)] `$(m.file)`  \n",
            "  $(strip(m.note))  \n  incident: $(m.incident)")
    end

    if !isempty(unresolved)
        println(io, "\n## UNRESOLVED — nothing caught it, but the probe was incomplete ",
            "($(length(unresolved)))\n")
        println(io, "Not an escape and not a catch. Re-probe these with fewer ",
            "workers.\n")
        for m in sort(unresolved; by=m -> (m.severity != :fatal, m.severity != :gross))
            println(io, "- **$(m.id)** [$(m.severity)/$(m.class)] — ",
                "$(length(_unk(m))) file(s) never reported: ",
                join(first(_unk(m), 4), ", "))
        end
    end

    # A file credited with a catch it did not report would book a real gap as
    # covered, so say where verdicts went missing at all, not only where it
    # changed the verdict.
    noisy = [m for m in muts if !isempty(_unk(m)) && !isempty(get(catches, m.id, String[]))]
    if !isempty(noisy) || !isempty(base_unknown)
        println(io, "\n## Probe completeness\n")
        isempty(base_unknown) ||
            println(io, "- baseline: $(length(base_unknown)) file(s) never reported ",
                "(worker died, NOT red): ", join(first(base_unknown, 5), ", "))
        for m in noisy
            println(io, "- `$(m.id)`: caught, but $(length(_unk(m))) file(s) never ",
                "reported — the catch stands, the coverage count is a lower bound")
        end
    end

    println(io, "\n## Catches per mutant\n")
    for m in muts
        c = get(catches, m.id, String[])
        uniq = length(c) == 1 ? "  ← ONLY test for this class" : ""
        println(io, "- `$(m.id)`: $(length(c)) file(s)$uniq")
        length(c) <= 4 && foreach(f -> println(io, "    - $f"), c)
    end

    caught_by = Dict(f => count(m -> f in get(catches, m.id, String[]), muts)
                     for f in files)
    dead = sort([f for f in files if caught_by[f] == 0]; by=cost_of, rev=true)
    println(io, "\n## Caught nothing in this catalog ($(length(dead)) files, ",
        round(Int, sum(cost_of, dead; init=0.0)), "s)\n")
    println(io, "Evidence, not proof: these defend claims the catalog does not ",
        "exercise. Read them\nagainst the claim they name — a file that names ",
        "no claim and catches no cataloged\ndefect is the deletion candidate.\n")
    foreach(f -> println(io, "- `$f` ($(round(Int, cost_of(f)))s)"), dead)

    cover = min_cover(muts, files, catches)
    println(io, "\n## Minimum-cost cover ($(length(cover)) files, ",
        round(Int, sum(cost_of, cover; init=0.0)), "s)\n")
    println(io, "Catches every class any file catches. This is the evidence-based ",
        "`fast` tier.\n")
    # A set cover minimises the cost it is handed, so say where those seconds came
    # from. `_cost` is `_DEFAULT_COST = 3.0` for every file outside its 88
    # hand-entered ones, measured on a 4-vCPU GitHub runner — quoting a total built
    # from placeholders as "the evidence-based fast tier" would be the instrument
    # overstating itself.
    nest = count(f -> !is_measured(f), cover)
    nest == 0 || println(io, "**$(nest) of $(length(cover)) seconds above are ",
        "`_cost` ESTIMATES, not measurements** (this sweep did not record a time ",
        "for them).\n")
    foreach(
        f -> println(io, "- `$f` ($(round(Int, cost_of(f)))s",
            is_measured(f) ? " measured" : " est.", ")"), cover)

    if !isempty(already_red)
        println(io, "\n## Excluded: red before any mutation\n")
        foreach(f -> println(io, "- `$f`"), already_red)
    end

    txt = String(take!(io))
    write(joinpath(OUT, "report.md"), txt)
    println("\n", txt)
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
