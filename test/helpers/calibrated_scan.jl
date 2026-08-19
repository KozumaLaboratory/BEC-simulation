# A scan that CANNOT return a number it has not proved it could get wrong.
#
# WHY THIS EXISTS
#
# On 2026-08-05/06 nine measurements in this session were silently blind, and
# every one of them printed a clean, plausible result:
#
#   an external `diff` tool with no +/- prefixes    -> "zero non-comment changes"
#   `--no-ext-diff` passed before `diff`             -> "0 lines seen"
#   zsh not word-splitting `$VAR` in a for-loop      -> "main touched no cited file"
#   `occursin(f)` fixing the SECOND argument          -> "citation is unanchored"
#   counting LINES where the defect fits on one       -> canary walked through
#   a regex over source instead of evaluating         -> CI_EXTRA 90 for a list of 113
#   reading `r.warnings` for an `@info`               -> "the advisory never fires"
#   `grep -c` on a missing file returning 0           -> "failures: 0"
#   a path regex omitting `figs/` and `.png`          -> "the figure does not exist"
#
# Each was fixed where it happened. NONE fixed the class, and the class is not
# carelessness: it is that a bespoke scan written inline has no way to say "I
# looked and found nothing" differently from "I could not look". Both print the
# same number.
#
# Calibrating by hand works — it caught five of the nine — but it is a habit, and
# a habit is forgotten about half the time. So the calibration is moved into the
# TYPE: `calibrated_scan` will not give you a result unless a known-present
# probe was found AND a known-absent probe was rejected. There is no argument
# order to get wrong and nothing to remember.
#
# USE
#
#     hits = calibrated_scan(
#         corpus;                       # the things to look at
#         match   = x -> …,             # the predicate under test
#         present = a_thing_that_must_match,
#         absent  = a_thing_that_must_not_match,
#     )
#
# It throws `BlindScan` if either probe disagrees, naming which one. A scan that
# cannot see its own positive control is not evidence, so it is not returned.

export BlindScan, calibrated_scan, count_matches, tree_files

"""
    BlindScan

Thrown when a scan's probes show it cannot distinguish presence from absence.

The message names WHICH probe failed, because "the positive control was not
found" and "the negative control matched" are different bugs: the first means
the extractor is broken, the second means the predicate is too wide.
"""
struct BlindScan <: Exception
    which::Symbol      # :present | :absent
    probe::Any
    detail::String
end

function Base.showerror(io::IO, e::BlindScan)
    if e.which === :present
        print(io, "BlindScan: the positive control ", repr(e.probe),
            " did NOT match. The scan cannot see a thing that is there, so a ",
            "result of zero would be indistinguishable from a clean tree. ",
            e.detail)
    else
        print(io, "BlindScan: the negative control ", repr(e.probe),
            " DID match. The predicate is wider than the thing being looked ",
            "for, so a non-zero result is not evidence. ", e.detail)
    end
end

"""
    calibrated_scan(corpus; match, present, absent, describe=string)

Apply `match` to every element of `corpus` and return those that match — but
only after proving `match(present)` and `!match(absent)`.

`present` must be an element (or element-shaped value) the predicate is REQUIRED
to match; `absent` one it is required to reject. Choose them from the real
failure you are guarding against, not from convenience: a positive control that
cannot fail proves nothing.

Throws `BlindScan` rather than returning a suspect answer, because a scan that
has not shown it can distinguish the two cases is not a measurement.
"""
function calibrated_scan(corpus; match, present, absent, describe=string)
    match(present) || throw(
        BlindScan(:present, describe(present),
            "Check the extractor before the population: an empty result here is " *
            "the same string as a clean corpus."),
    )
    match(absent) && throw(
        BlindScan(:absent, describe(absent),
            "Narrow the predicate. Widening an exclusion list instead is fixing " *
            "the threshold, not the fixture."),
    )
    filter(match, collect(corpus))
end

"""
    count_matches(pattern, text) -> Int

Number of MATCHES, not of lines containing one.

The distinction is not pedantic: a gate that counted matching lines passed its
own canary on 2026-08-06 because the planted defect —
`Dict("Na23" => 1, "Rb87" => 1, "Eu151" => 6)` — was three pairs on one line.
Anything that can appear more than once per line must be counted this way.
"""
count_matches(pattern::Regex, text::AbstractString) =
    length(collect(eachmatch(pattern, text)))

count_matches(pattern::Regex, lines::AbstractVector) =
    sum(l -> count_matches(pattern, l), lines; init=0)

"""
    tree_files(root; ext=".jl", skip=…) -> Vector{String}

Every file under `root` with the given extension, as paths relative to `root`'s
parent, with the directories that are never source (`.git`, `node_modules`,
nested worktrees) removed.

Exists so that "which files are in scope" is written ONCE. Two scans in this
session disagreed about the corpus — one omitted `figs/`, another `bench/` —
and each reported an absence that was really a gap in its own reach.
"""
function tree_files(root; ext=".jl", skip=(".git", "node_modules", "worktrees"))
    out = String[]
    parent = dirname(rstrip(root, '/'))
    for (dir, dirs, files) in walkdir(root)
        filter!(d -> !(d in skip), dirs)
        for f in files
            endswith(f, ext) || continue
            push!(out, relpath(joinpath(dir, f), parent))
        end
    end
    sort(out)
end
