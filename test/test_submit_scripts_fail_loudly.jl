# A job script may not exit 0 with a failed stage.
#
# WHY THIS EXISTS
#
# `scripts/tsubame_setup.sh` runs `set +e` — it has to, because `module load
# julia` always exits non-zero on TSUBAME 4, where no julia modulefile exists.
# From 2026-08-08 until 2026-08-20 it never turned errexit back on, so EVERY
# submit script that sourced it ran the rest of ITSELF unguarded. A job whose
# julia stage errored still reached its final `echo` and exited 0. Two failures
# came back as GREENs on 2026-08-08; job 8450018.13 reproduced it on 2026-08-20
# (PR #427), and the memory recording the first incident said it was FIXED —
# true on some ref, false on this tree, which is why a landed-fix claim has to
# be anchored to a ref rather than to a date.
#
# That is the whole class: the shell or the scheduler quietly did something
# other than what was written, and it was silent IN THE GREEN DIRECTION.
# #166 `qsub -v A=1,2,3` split on commas and the job ran the default geometry
# while its log said otherwise; #208 `git checkout` printed only `Aborting` and
# the job nearly ran a stale script; #263 `BR_TAG=` assigned instead of appended
# and four jobs raced on one ledger; #332 an over-quota volume broke `git` and
# `qsub` without presenting as a quota error; #445 `fetch-depth: 1` made an
# ancestor gate read 16 live entries as dead. None was caught by reading a log.
#
# WHAT THE PROPERTY ACTUALLY IS — AND WHAT IT IS NOT
#
# The first version of this gate asked "does the script contain `set -e`". That
# is a SPELLING, not the property, and measuring it got two answers wrong in
# opposite directions:
#
#   * `submit_test_tier.sh` and `klaus2022/submit_stripes.sh` were ACCUSED. Both
#     deliberately run without errexit and end `exit "$RC"` — which is STRONGER,
#     because the job exits with the suite's real code instead of `1`. Under
#     `-e` the run would abort before `RC=${PIPESTATUS[0]}` and the propagation
#     would be destroyed. The gate was asking them to become worse.
#   * `submit_load_check.sh`, `submit_gpu_smoke.sh`, `submit_mutation.sh` and
#     `submit_test_tier_ci.sh` were PARKED as "debt". All four captured each
#     stage's `$?`, printed it, and then ended on `echo` — exit 0 for a red
#     suite. That is not debt, it is the 2026-08-08 defect itself, live, in four
#     files. `submit_test_tier_ci.sh` said so IN ITS OWN HEADER and had said so
#     for weeks. All four are fixed in the commit that rewrote this file.
#
# So the property is: **the job's exit status reflects its stages.** Two ways to
# hold it, and both are first-class here —
#
#   (a) errexit, directly or through a `source`d sibling under `scripts/`; or
#   (b) an explicit status path — the script captures a status and `exit`s it.
#
# and one arrangement that is NEVER right, gated with no exception list at all:
# capturing `$?` and then exiting on something else. A script that knows the
# stage failed and reports success is strictly worse than one that never looked.
#
# WHAT IS NOT CHECKED, said plainly rather than implied. `set -e` does not fire
# inside a pipeline, a condition, or a `cmd || true`; `exit "$RC"` is only as
# good as where `RC` was captured. This gate holds "there is a status path",
# not "every stage is on it". `scripts/watch_until_done.sh` remains the
# instrument for "did the remote job actually succeed", and reading each stage's
# own artefact remains the discipline that made the 2026-08-08 results sound
# even while two stages had silently failed.

# Every test file is a standalone unit (test_tier_membership.jl), so the plain
# `using` form even though this gate reads the tree rather than the package.
using SpinorBEC
using Test

include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _REPO = normpath(joinpath(@__DIR__, ".."))
const _SCRIPTS = joinpath(_REPO, "scripts")

# `set -e`, `set -eu`, `set -euo pipefail` — anything switching errexit on.
const _ERREXIT_RE = r"^[ \t]*set[ \t]+-[a-zA-Z]*e"m
const _SET_PLUS_E_RE = r"^[ \t]*set[ \t]+\+[a-zA-Z]*e"m
# `source X` / `. X`
const _SOURCE_RE = r"^[ \t]*(?:source|\.)[ \t]+(\S+)"m
# `exit $rc` / `exit "$RC"` / `exit $?` — exiting WITH a status rather than with
# whatever the last `echo` returned.
const _EXIT_WITH_STATUS_RE = r"^[ \t]*exit[ \t]+\"?\$"m
# capturing a status at all
const _CAPTURES_STATUS_RE = r"\$\?|\$\{PIPESTATUS"

# A UGE directive. Matched on the RAW text on purpose: `#$ -l h_rt=...` is a
# comment to bash and a directive to the scheduler, so it is the single
# strongest signal that a file is a job script — and it is invisible to any
# corpus built by stripping comments. Getting this backwards silently removed
# `submit_gpu_smoke.sh` and `submit_load_check.sh` from the corpus while I was
# measuring, which is the same shape as #322's "the regex became the
# measurement".
const _UGE_DIRECTIVE_RE = r"^#\$[ \t]+-"m
# A runner invocation. Matched on CODE ONLY, because "julia" and "qsub" appear
# in the usage comment of nearly every script in the tree.
const _RUNS_SOMETHING_RE = r"(\bqsub\b)|(\bjulia\b)|(\$\{?JULIA)"m

_strip_comments(text) = join(
    (l for l in split(text, '\n') if !startswith(lstrip(l), "#")), '\n')

"""
Files a script `source`s that resolve inside `scripts/`.

Resolution is by the `scripts/`-relative SUFFIX, because every real call site
roots the path on an env var with a cluster default
(`"\${EU335_ROOT:-/gs/fs/...}/scripts/eu_hysteresis/_preamble.sh"`) which cannot
be resolved from here. Anything that does not resolve is dropped, and an arm
below asserts the extractor found some — otherwise "no unresolved sources" and
"the regex matched nothing" print the same zero.
"""
function _sourced_siblings(text::AbstractString)
    out = String[]
    for m in eachmatch(_SOURCE_RE, text)
        arg = strip(m.captures[1], ['"', '\''])
        i = findlast("scripts/", arg)
        i === nothing && continue
        p = joinpath(_SCRIPTS, arg[(last(i) + 1):end])
        isfile(p) && push!(out, p)
    end
    out
end

function _has_errexit(path::AbstractString, seen=Set{String}())
    path in seen && return false      # a source cycle is not a proof
    push!(seen, path)
    text = read(path, String)
    occursin(_ERREXIT_RE, text) && return true
    any(q -> _has_errexit(q, seen), _sourced_siblings(text))
end

_shell_scripts() = sort([
    joinpath(_REPO, p) for p in git_corpus(_REPO, "scripts")
    if endswith(p, ".sh") && isfile(joinpath(_REPO, p))
])

_is_job_shaped(path) =
    let raw = read(path, String)
        occursin(_UGE_DIRECTIVE_RE, raw) ||
            occursin(_RUNS_SOMETHING_RE, _strip_comments(raw))
    end

# (a) or (b): the job's status can reflect a failed stage.
_has_status_path(path) =
    _has_errexit(path) ||
    occursin(_EXIT_WITH_STATUS_RE, _strip_comments(read(path, String)))

# The arrangement that is never right: it LOOKED at the status and then exited
# on something else.
_records_and_discards(path) =
    let code = _strip_comments(read(path, String))
        occursin(_CAPTURES_STATUS_RE, code) &&
            !occursin(_EXIT_WITH_STATUS_RE, code) && !_has_errexit(path)
    end

# ── Job-shaped scripts with no status path, by design ────────────────────────
#
# Named with the reason, because a rule wide enough to excuse these would excuse
# a real submit script too. Unknown scripts fall on the GUILTY side: the failure
# being guarded against is silence, and a new job script is exactly where it
# lands. There is no "debt" bucket — the four entries that were parked in one on
# 2026-08-22 turned out to be the defect, and a bucket that can hold the defect
# is a place for it to live rather than a place for it to be seen.
const _NO_STATUS_PATH_BY_DESIGN = Dict(
    # Verdict reporters. Their job is to OBSERVE non-zero exits and classify
    # them; aborting on the first would delete the verdict — the failure #384
    # recorded, where a timeout deleted evidence instead of failing.
    "scripts/loop/loop_gate.sh" => "gate runner: reports rather than aborts",
    # Status reporter over a ledger. Verified 2026-08-22 that errexit would
    # BREAK it: the per-index loop uses bare `[ "\$c" -lt "\$n" ] && missing=...`,
    # whose false branch is a complete command returning 1.
    "scripts/eu_campaign_resume.sh" => "reads remote state; `[ ] && x` breaks under -e",
    # An advisory. It prints warnings and is meant to be read, not obeyed; a
    # preflight that aborts is a preflight nobody runs.
    "scripts/tsubame/preflight.sh" => "advisory: warns, does not adjudicate",
    # A measurement harness with a `trap` that qdels its own jobs. Aborting
    # mid-probe would leak cluster jobs, which is worse than a wrong number.
    "scripts/tsubame/ums_probe.sh" => "probe with a qdel trap; abort would leak jobs",
    # Sourced preamble, not a job. It self-guards where it matters, with
    # explicit `|| exit 1` on the `cd` and an explicit refusal on a dirty src/ —
    # and `exit` from a sourced file exits the CALLER, which is the intent.
    "scripts/tsubame/_preamble.sh" => "sourced preamble; guards with explicit `exit 1`",
)

"""
errexit state of a shell AFTER sourcing `path`, started with or without `-e`.

Returns `:on` or `:off`. `TMPDIR` is redirected so a setup file that creates
scratch directories does so inside the test's own temporary tree.
"""
function _errexit_after_sourcing(path::AbstractString; caller_errexit::Bool)
    mktempdir() do tmp
        pre = caller_errexit ? "set -e; " : ""
        script = string(pre, "source '", path, "' >/dev/null 2>&1; ",
            "case \"\$-\" in *e*) echo on;; *) echo off;; esac")
        out = withenv("TMPDIR" => tmp, "SPINORBEC_SCRATCH_DIR" => nothing) do
            read(`bash -c $script`, String)
        end
        Symbol(strip(out))
    end
end

@testset "sourcing a scripts/ preamble leaves the caller's errexit as it found it" begin
    setup = joinpath(_SCRIPTS, "tsubame_setup.sh")
    @test isfile(setup)

    # THE PROPERTY, EXECUTED. Not "the file contains `set -e`" — it contains
    # `set +e` too, and which one wins is a question about execution order that
    # only execution answers. Grepping is exactly what the two `_preamble.sh`
    # files did, and their reading was right when written and false when read.
    @test _errexit_after_sourcing(setup; caller_errexit=true) === :on

    # NEGATIVE CONTROL. Sourcing must not IMPOSE errexit either, or a verdict
    # reporter that sources it would start aborting on the exits it exists to
    # classify.
    @test _errexit_after_sourcing(setup; caller_errexit=false) === :off

    # CANARY. Red has to be reachable or the two arms above are decoration.
    # Delete the restore block — the exact 2026-08-08 state — and the first arm
    # must flip. The mutation is ANCHORED on the guard variable rather than on a
    # bare `set -e`, so a reformat cannot make it silently match a different
    # line, and its landing is asserted: a `replace` that quietly matched
    # nothing is how a canary passes against the defect it was written for
    # (#125).
    mktempdir() do d
        orig = read(setup, String)
        @test occursin("_SBEC_ERREXIT_WAS_SET", orig)   # the anchor still exists
        mutated = replace(orig,
            r"if \[ \"\$\{_SBEC_ERREXIT_WAS_SET:-0\}\" = \"1\" \]; then\n[ \t]*set -e\nfi" => "# restore deleted by the canary",
        )
        @test mutated != orig                            # ...and the mutation landed
        @test !occursin(r"^[ \t]*set -e$"m, mutated)     # ...on the restore, not elsewhere
        broken = joinpath(d, "tsubame_setup_broken.sh")
        write(broken, mutated)
        @test _errexit_after_sourcing(broken; caller_errexit=true) === :off
    end
end

@testset "any sourced file that disables errexit is executed by the arm above" begin
    # FORCING FUNCTION. The arm above probes one file by name. That is only
    # honest if no OTHER sourced preamble turns errexit off — otherwise the
    # named probe is a spot check being read as coverage. Derived, so a future
    # preamble that needs `set +e` reddens this until it is probed too.
    const_probed = Set([joinpath(_SCRIPTS, "tsubame_setup.sh")])

    sourced = Set{String}()
    for s in _shell_scripts(), q in _sourced_siblings(read(s, String))
        push!(sourced, q)
    end
    # Positive control on the extractor: 13 job scripts get errexit ONLY through
    # a sourced sibling, so an empty set here means the resolver broke, not that
    # nothing is sourced.
    @test !isempty(sourced)

    disables = sort([p for p in sourced if occursin(_SET_PLUS_E_RE, read(p, String))])
    unprobed = setdiff(Set(disables), const_probed)
    isempty(unprobed) || println(
        "  sourced preambles that run `set +e` but are not execution-probed:\n    ",
        join(sort(collect(unprobed)), "\n    "),
        "\n  → add an `_errexit_after_sourcing` arm, or stop disabling errexit there.")
    @test isempty(unprobed)
    # And the one we do probe must still be in the set, or the arm above is
    # probing a file that no longer matters while this one reports clean.
    @test !isempty(intersect(Set(disables), const_probed))
end

@testset "a script that records a stage's status may not exit on something else" begin
    # NO EXCEPTION LIST. Capturing `$?` and then ending on `echo` is never the
    # right arrangement: the script has already established that the stage
    # failed. Four files were in exactly this state on 2026-08-22 —
    # submit_load_check, submit_gpu_smoke, submit_mutation, submit_test_tier_ci —
    # and one of them had the defect written in its own header.
    scripts = _shell_scripts()
    jobish = filter(_is_job_shaped, scripts)
    @test !isempty(jobish)

    mktempdir() do d
        # Controls from the REAL shapes. `present` is submit_test_tier_ci.sh as
        # it stood before the fix; `absent` is the same file after it.
        bad = joinpath(d, "records_and_discards.sh")
        write(
            bad,
            "#!/bin/bash\n#\$ -cwd\n\$JULIA -e 'exit(1)'\n" *
            "echo \"TEST_RC=\$?\"\necho \"ALL DONE\"\n",
        )
        good = joinpath(d, "records_and_exits.sh")
        write(
            good,
            "#!/bin/bash\n#\$ -cwd\n\$JULIA -e 'exit(1)'\nRC=\$?\n" *
            "echo \"TEST_RC=\$RC\"\necho \"ALL DONE\"\nexit \"\$RC\"\n",
        )

        offenders = calibrated_scan(
            jobish; match=_records_and_discards, present=bad, absent=good,
            describe=s -> relpath(s, _REPO))
        rel = sort([relpath(s, _REPO) for s in offenders])
        isempty(rel) || println(
            "  these look at a stage's status and then exit on an `echo`:\n    ",
            join(rel, "\n    "),
            "\n  → capture it (`RC=\$?`) and end with `exit \"\$RC\"`.")
        @test rel == String[]
    end
end

@testset "every job-shaped script has a status path, or is named" begin
    scripts = _shell_scripts()
    jobish = filter(_is_job_shaped, scripts)
    @test !isempty(jobish)

    mktempdir() do d
        # The negative control gets its status path only THROUGH a sourced
        # sibling — the arrangement 13 scripts in the tree actually use, so the
        # transitive resolver is proved live on every run rather than assumed.
        bad = joinpath(d, "no_status_path.sh")
        write(bad, "#!/bin/bash\n#\$ -cwd\njulia --project=. -e 'exit(1)'\necho done\n")
        good = joinpath(d, "guarded_via_source.sh")
        write(
            good,
            "#!/bin/bash\nsource \"$(joinpath(_SCRIPTS, "tsubame_setup.sh"))\"\n" *
            "qsub -g x foo\n",
        )

        offenders = calibrated_scan(
            jobish; match=s -> !_has_status_path(s), present=bad, absent=good,
            describe=s -> relpath(s, _REPO))
        rel = sort([relpath(s, _REPO) for s in offenders])

        # BOTH DIRECTIONS. A new script cannot join the excused set silently,
        # and a script that gains a status path must be struck from it — an
        # allowlist nobody prunes becomes a permanent excuse, which is the shape
        # `KNOWN-LIMIT` takes when left alone (#372).
        added = setdiff(rel, keys(_NO_STATUS_PATH_BY_DESIGN))
        stale = setdiff(keys(_NO_STATUS_PATH_BY_DESIGN), rel)
        isempty(added) || println(
            "  job scripts whose exit status cannot reflect a failed stage:\n    ",
            join(added, "\n    "),
            "\n  → `set -euo pipefail`, or capture and `exit \"\$RC\"`, or add a",
            " row to `_NO_STATUS_PATH_BY_DESIGN` saying why neither is right.")
        isempty(stale) || println(
            "  these now have a status path — delete them from the excuse list:\n    ",
            join(sort(collect(stale)), "\n    "))
        @test added == String[]
        @test isempty(stale)
    end
end

@testset "the corpus is built the way the two signals actually live" begin
    # The distinction is load-bearing and easy to get backwards — I got it
    # backwards once while measuring this. A UGE directive IS a bash comment, so
    # a corpus built from stripped code loses precisely the strongest evidence
    # that a file is a job script; `qsub` and `julia`, conversely, appear in the
    # usage header of nearly every script, so matching them on raw text pulls in
    # files that run nothing.
    uge = [s for s in _shell_scripts() if occursin(_UGE_DIRECTIVE_RE, read(s, String))]
    @test !isempty(uge)
    for s in uge
        # every one of them would VANISH from a stripped-code corpus...
        stripped = _strip_comments(read(s, String))
        @test !occursin(_UGE_DIRECTIVE_RE, stripped)
        # ...and must still be judged job-shaped
        @test _is_job_shaped(s)
    end

    # And the other way: a file whose only mention of julia is in prose is not a
    # job script.
    mktempdir() do d
        prose = joinpath(d, "prose_only.sh")
        write(prose, "#!/bin/bash\n# usage: qsub ... julia --project=.\necho hi\n")
        @test !_is_job_shaped(prose)
    end

    # The excuse list stays readable, and every entry resolves.
    for p in keys(_NO_STATUS_PATH_BY_DESIGN)
        @test isfile(joinpath(_REPO, p))
    end
    @test length(_NO_STATUS_PATH_BY_DESIGN) <= 8
end
