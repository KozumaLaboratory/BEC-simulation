# test/mutation/run.jl — run the defect catalog against the suite.
#
#   julia --project=. test/mutation/run.jl [options]
#     --mutants a,b,…     subset of catalog ids            (default: all)
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

function probe_files()
    spec = _arg("--probe", "grounded_cheap")
    sel = if occursin(".jl", spec)
        string.(split(spec, ","))
    elseif spec == "oracles"
        copy(ORACLE_TESTS)
    elseif spec == "fast"
        select_tests("fast")
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
    # Every probe file is re-run once per mutant, so a single slow file costs
    # `--max-cost × n_mutants`. Dropped files are named, never silently cut.
    keep = filter(f -> _cost(f) <= MAX_COST, sel)
    dropped = setdiff(sel, keep)
    isempty(dropped) || println("  probe: dropped $(length(dropped)) file(s) over \
        --max-cost=$MAX_COST (", round(Int, sum(_cost, dropped)), "s): ",
        join(first(sort(dropped; by=_cost, rev=true), 5), ", "), " …")
    keep
end

function chosen_mutants()
    ids = _arg("--mutants", "")
    isempty(ids) && return MUTANTS
    want = Set(Symbol.(split(ids, ",")))
    sel = filter(m -> m.id in want, MUTANTS)
    length(sel) == length(want) ||
        error("unknown mutant id(s): $(setdiff(want, Set(m.id for m in sel)))")
    sel
end

# ── running one probe pass ─────────────────────────────────────────
# Reuses test/run_chunk.jl's shared claim queue verbatim, so a probe pass
# executes each file exactly the way `Pkg.test()` does — a harness that ran
# tests its own way could report a catch the real suite would miss.

const _JL = Base.julia_cmd()

precompile_package() = run(
    pipeline(
        `$_JL --startup-file=no --project=$_ROOT -e "using Pkg; Pkg.precompile()"`;
        stdout=devnull, stderr=devnull),
)

"""
    run_probe(files, nworkers) -> Dict{String, Bool}   (true = file went RED)
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
    out = Dict{String, Bool}()
    for (i, f) in enumerate(files)
        marker = joinpath(qdir, "done_$i")
        # No marker = the file never completed (worker died). Treat as red: an
        # unrun file must never read as "this mutant escaped".
        out[f] = !isfile(marker) || startswith(read(marker, String), "FAIL")
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
    already_red = sort([f for (f, red) in baseline if red])
    if !isempty(already_red)
        println("  $(length(already_red)) file(s) already RED before any mutation \
                 — excluded from the catch matrix:")
        foreach(f -> println("    ", f), already_red)
    end
    live = filter(f -> !baseline[f], files)

    # catch[mutant id] = set of files that went red under it
    catches = Dict{Symbol, Vector{String}}()
    for (k, m) in enumerate(muts)
        print("\n[$k/$(length(muts))] $(m.id) ($(m.class), $(m.severity)) … ")
        apply!(m)
        try
            precompile_package()
            res = run_probe(live, NWORKERS)
            catches[m.id] = sort([f for (f, red) in res if red])
        finally
            restore!(m)
        end
        n = length(catches[m.id])
        println(n == 0 ? "ESCAPED — no test caught it" : "caught by $n file(s)")
    end

    git_src_dirty() && @error "src/ is dirty after the run — inspect `git diff -- src`"

    write_matrix(muts, live, catches)
    report(muts, live, catches, already_red)
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
    cost = Dict(f => _cost(f) for f in files)
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

function report(muts, files, catches, already_red)
    io = IOBuffer()
    println(io, "# Mutation report — ", Dates.format(now(), "yyyy-mm-dd HH:MM"))
    println(io, "\n$(length(muts)) cataloged defect classes × $(length(files)) probe files.\n")

    escaped = [m for m in muts if isempty(get(catches, m.id, String[]))]
    println(io, "## Escaped — a real gap ($(length(escaped)))\n")
    isempty(escaped) && println(io, "(none)\n")
    for m in sort(escaped; by=m -> (m.severity != :fatal, m.severity != :gross))
        println(io, "- **$(m.id)** [$(m.severity)/$(m.class)] `$(m.file)`  \n",
            "  $(strip(m.note))  \n  incident: $(m.incident)")
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
    dead = sort([f for f in files if caught_by[f] == 0]; by=_cost, rev=true)
    println(io, "\n## Caught nothing in this catalog ($(length(dead)) files, ",
        round(Int, sum(_cost, dead; init=0.0)), "s)\n")
    println(io, "Evidence, not proof: these defend claims the catalog does not ",
        "exercise. Read them\nagainst the claim they name — a file that names ",
        "no claim and catches no cataloged\ndefect is the deletion candidate.\n")
    foreach(f -> println(io, "- `$f` ($(round(Int, _cost(f)))s)"), dead)

    cover = min_cover(muts, files, catches)
    println(io, "\n## Minimum-cost cover ($(length(cover)) files, ",
        round(Int, sum(_cost, cover; init=0.0)), "s)\n")
    println(io, "Catches every class any file catches. This is the evidence-based ",
        "`fast` tier.\n")
    foreach(f -> println(io, "- `$f` ($(round(Int, _cost(f)))s)"), cover)

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
