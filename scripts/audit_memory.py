#!/usr/bin/env python3
"""Audit the project's Claude memory tree for silent rot.

    python3 scripts/audit_memory.py [--memory-dir DIR] [--limit 17100]
    python3 scripts/audit_memory.py --fix-relocations   # repoint MOVED files

NOTE ON --limit. The load budget is asserted twice in this tree with values
differing by 46 %: 17100 B here (in use since 2026-07-27) and 24.4 KB / 24986 B
in CLAUDE.md, three memory files and docs/campaign/lessons_2026_08_04.md.
Neither cites the mechanism that truncates. The default stays at the smaller
one because the costs are asymmetric -- too small moves a few lines into a
sub-index one hop away, too large means the tail silently never loads and the
warning names the FILE, not the entries that fell off it. Do not raise it
without a citation to the actual behaviour.

Three failure modes, all of which were live on 2026-07-27 and none of which
announce themselves:

1. **Unreachable files.** `MEMORY.md` is the only thing loaded at session
   start. A memory that is neither indexed there nor linked from something
   that is will never be read again. 43 of 233 files (18%) were in this
   state, including the type-stability pitfalls and two Zeeman sign
   mistakes. Knowledge written down but never loaded is worse than absent:
   it creates the belief that a lesson was captured.

2. **Dangling `[[links]]`.** Renames drift and the pointer rots silently.
   13 were broken, two of them malformed enough to have swallowed a
   paragraph of prose into a link target.

3. **Index over budget.** `MEMORY.md` past the read limit gets truncated,
   which silently drops whatever is at the bottom.

Those three are gated (non-zero exit). A fourth is reported but NOT gated:

4. **Path references that do not resolve.** Memories cite `src/...jl`,
   `scripts/...`, `docs/...` constantly, and the citation is what a future
   session acts on. Measured 2026-08-05 over 595 such references:

       428  in HEAD
        80  removed from this tree's history
        52  retired `runs/_loop/` — archived outside the repo, correctly historical
        12  absent everywhere
        11  run output (pruned by design)
         7  placeholder (`scripts/foo.jl` in prose)
         5  ON ANOTHER REF ONLY

   A dead reference is not automatically a defect, and the buckets want four
   different responses:

   - **absent everywhere** — cited, never existed. The memory is wrong.
   - **ON ANOTHER REF ONLY** — the dangerous one. The memory is true in the
     worktree that has the file and false in the one that does not, while
     reading as universal. A memory written 2026-08-05 claimed
     `Fix: src/workflow/io/measurement_provenance.jl` in the present tense; it
     is real on `origin/feat/spgpe-full-reservoirs` and absent from `main`, so
     a reader concludes the bug class is closed when it is open. **Anchor a
     landed-fix claim to a ref, not just a date.**
   - **removed from this tree's history** — usually right and merely old: an
     incident report naming the file the incident happened in. Wants a date,
     not a deletion.
   - **untracked in the main checkout** — exists only as an uncommitted file in
     a single checkout, invisible to every other worktree and destroyed by a
     `git clean`, while the index treats it as a repo asset.

   Most apparent rot is neither: the tree MOVED under a stationary reference.
   9 of 45 unique dead paths (20 %) on 2026-08-05 were relocations, repaired by
   `--fix-relocations` under a rule needing no judgement — rewrite only when the
   basename resolves to exactly one file. State such a ratio per UNIQUE PATH,
   not per (memory, path) citation: the two differ by the citation multiplicity
   (5.7x here, because one moved file was cited by five memories) and the
   citation count flatters the repair.

   Not gated. Resolution depends on which worktree you run in, in-flight work
   is legitimately uncommitted, and whether to commit someone else's untracked
   work is a human decision. Report only.
"""
import argparse
import pathlib
import re
import subprocess
import sys
from collections import defaultdict

DEFAULT_DIR = pathlib.Path.home() / ".claude/projects/-home-suzume-workspace-BEC-simulation/memory"
# Index files are DISCOVERED in `index_stems`, not listed here -- the old
# hardcoded pair named 2 of the 8 that exist and manufactured 24 false orphans.


def load(memdir):
    """Live memories, plus `archive/` so links into it resolve.

    Globbing only the top level made every link into `archive/` read as a
    broken index entry -- 74 of them on 2026-08-05, not one of them real.
    Archived stems are returned separately because being out of the main index
    is what archiving *means*: they must resolve as link targets and must not
    count as orphans.
    """
    texts = {p.stem: p.read_text(encoding="utf-8") for p in sorted(memdir.glob("*.md"))}
    archived = set()
    for p in sorted(memdir.glob("archive/*.md")):
        if p.stem not in texts:
            texts[p.stem] = p.read_text(encoding="utf-8")
            archived.add(p.stem)
    return texts, archived


def index_stems(texts):
    """Every index file, discovered rather than listed.

    The hardcoded pair ("MEMORY", "memory_index_history") named 2 of the 8 that
    exist by 2026-08-05, so every memory filed into a newer sub-index read as an
    orphan. A constant that must be edited whenever the thing it describes grows
    is a staleness generator; derive it.
    """
    return tuple(sorted(s for s in texts
                        if s == "MEMORY" or s.startswith("memory_index_")))


_FENCE = re.compile(r"```.*?```", re.S)
_INLINE = re.compile(r"`[^`\n]*`")


def prose(text):
    """Text with code fences and inline spans removed.

    A memory that *documents* the `[[link]]` syntax must not be flagged for
    mentioning it — a linter you cannot write about is broken. Scanning
    stripped prose also keeps `Verify:` blocks (which contain real code, and
    sometimes brackets) out of the link graph.
    """
    return _INLINE.sub(" ", _FENCE.sub(" ", text))


# Every tracked top-level directory, and every extension a memory actually
# cites. Both lists were short: `figs/` (43 tracked files), `observability/`,
# `.github/` and `.claude/` were invisible, and so was every `.png` / `.csv`
# even under a covered directory. On 2026-08-05 that hid 25 citations, 10 of
# them dead -- and I asserted one figure's absence from a scan whose regex had
# never looked at its directory. **A scanner's coverage set is part of its
# result**: if you narrow the population, say so, or you are reporting
# "not found" as "not there".
_PATH = re.compile(
    r"\b((?:src|test|scripts|bench|docs|runs|ext|dashboard|figs|observability"
    r"|refs|\.github|\.githooks|\.claude|\.codex)"
    r"/[A-Za-z0-9_\-./]*\.(?:jl|md|py|yaml|yml|toml|sh|json|png|csv|tsv|svg))"
)
# Correctly-historical references, not rot:
#   runs/_loop/  — the first autonomous loop, retired 2026-06-08 and archived
#                  outside the repo (CLAUDE.md).
#   scripts/{loop,judge,scheduler,resource_probe,cleanup_branches}
#                — the same loop's machinery, moved to
#                  BEC-simulation-archive/loop_machinery_2026_06_08/.
_RETIRED_PREFIXES = ("runs/_loop/",)
_RETIRED_FILES = frozenset((
    "scripts/loop.sh", "scripts/judge.py", "scripts/scheduler.py",
    "scripts/resource_probe.py", "scripts/cleanup_branches.sh",
    "scripts/otel_query.py", "scripts/tests/test_judge_in_operator.py",
))

# `runs/` holds RUN OUTPUT, content-addressed and routinely pruned (the data
# lives on TSUBAME, the repo keeps figures and code). A memory naming a jld2 /
# summary.json / per-point file under runs/ is recording what a run produced,
# not asserting that the file is still there — so an absent one is expected,
# not drift. Only `runs/**/*.yaml` is a config, i.e. real input worth checking.
def _is_run_output(path):
    return path.startswith("runs/") and not path.endswith((".yaml", ".yml"))


def _placeholder(path):
    """Illustrative paths in prose, not claims about the repo."""
    return "..." in path or pathlib.Path(path).stem in {"foo", "bar", "x", "my_config"}


def _git(repo, *args):
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def path_report(texts, index_text, repo, main_checkout):
    """Classify every repo-path reference in the memories."""
    head = set(_git(repo, "ls-files").split())
    ever = set(_git(repo, "log", "--all", "--pretty=format:", "--name-only",
                    "--diff-filter=AM").split())
    # Split `ever` by whether the path is in THIS tree's ancestry. A file that
    # exists only on some other ref is not "removed" -- it is the ELSEWHERE
    # class, and it is the dangerous one, because the memory is true in one
    # worktree and false in another while reading as universal. Measured
    # 2026-08-05: a memory written that morning claimed
    # `Fix: src/workflow/io/measurement_provenance.jl` in the present tense;
    # the file is real on origin/feat/spgpe-full-reservoirs and absent from
    # main, so whether the bug class reads as closed depends on where you
    # happen to be standing.
    head_ever = set(_git(repo, "log", "HEAD", "--pretty=format:", "--name-only",
                         "--diff-filter=AM").split())
    untracked = set()
    if main_checkout and main_checkout.is_dir():
        untracked = {l[3:].strip() for l in
                     _git(main_checkout, "status", "--porcelain", "-uall").splitlines()
                     if l.startswith("??")}

    counts = defaultdict(int)
    untracked_only = defaultdict(list)
    absent = defaultdict(list)
    elsewhere = defaultdict(list)
    for stem, t in texts.items():
        indexed = f"({stem}.md)" in index_text
        # RAW text, not prose(): a path is nearly always written inside
        # backticks, and being in a code span makes it no less of a claim
        # about the repo. Scanning stripped prose here saw 48 of 517 refs.
        for p in sorted(set(_PATH.findall(t))):
            if _placeholder(p):
                counts["placeholder"] += 1
            elif any(p.startswith(r) for r in _RETIRED_PREFIXES) or p in _RETIRED_FILES:
                counts["retired (archived outside repo)"] += 1
            elif p in head:
                counts["in HEAD"] += 1
            elif _is_run_output(p):
                counts["run output (pruned by design)"] += 1
            elif p in untracked:
                counts["untracked in main checkout"] += 1
                indexed and untracked_only[stem].append(p)
            elif p in head_ever:
                counts["removed from this tree's history"] += 1
            elif p in ever:
                counts["ON ANOTHER REF ONLY"] += 1
                elsewhere[stem].append(p)
            else:
                counts["absent everywhere"] += 1
                indexed and absent[stem].append(p)
    return counts, untracked_only, absent, elsewhere


def unique_relocation(path, repo):
    """The one file in `repo` with this basename, or None if 0 or more than 1."""
    base = pathlib.Path(path).name
    hits = []
    for p in repo.rglob(base):
        if ".git" in p.parts or "node_modules" in p.parts or "worktrees" in p.parts:
            continue
        hits.append(str(p.relative_to(repo)))
        if len(hits) > 1:
            return None
    return hits[0] if len(hits) == 1 else None


def fix_relocations(memdir, repo):
    """Repoint dead paths that MOVED rather than died.

    Most apparent rot is the tree shifting under a stationary reference:
    `docs/research_notes/` -> `docs/archive/`, `docs/*_design.md` ->
    `docs/design/`, `src/three/` -> `dashboard/src/three/`. Measured 2026-08-05,
    9 of 45 unique dead paths (20 %) were of this kind.

    The rewrite rule needs no judgement, which is the whole point: substitute
    only when the basename resolves to EXACTLY ONE file in the tree. Two
    candidates or none, leave it for a human. That is why this is safe to run
    unattended and also why it will never finish the job.
    """
    head = set(_git(repo, "ls-files").split())
    edits = 0
    for p in sorted(memdir.glob("*.md")) + sorted(memdir.glob("archive/*.md")):
        text = p.read_text(encoding="utf-8")
        out = text
        for path in sorted(set(_PATH.findall(text))):
            if path in head or _placeholder(path) or (repo / path).exists():
                continue
            new = unique_relocation(path, repo)
            if new is None or new == path:
                continue
            out = out.replace(f"`{path}`", f"`{new}`")
            print(f"  {p.stem}\n      {path}\n   -> {new}")
            edits += 1
        if out != text:
            p.write_text(out, encoding="utf-8")
    print(f"\n{edits} path(s) rewritten")
    return edits


# Type prefixes every live memory carries. Links written before the convention
# landed name the bare stem, so `[[universal_theorem_status]]` misses
# `project_universal_theorem_status.md` sitting right there.
_PREFIXES = ("feedback_", "gotcha_", "mistake_", "project_", "reference_",
             "pitfall_", "memory_index_")


def resolve_stale_name(name, stems):
    """The one live stem an old-style link meant, or None if 0 or ambiguous."""
    n = name.replace("-", "_")
    if n in stems:
        return None                      # already resolves; nothing to repair
    hits = {s for s in stems if any(s == p + n for p in _PREFIXES)}
    return hits.pop() if len(hits) == 1 else None


def fix_links(memdir):
    """Repoint [[links]] and index entries at renamed files.

    Same judgement-free rule as `fix_relocations`: rewrite only when the old
    name resolves to EXACTLY ONE live stem under a known type prefix. Ambiguous
    or absent, leave it — a dangling link to a memory that was never written is
    legitimate (it marks something worth writing), so silence is the correct
    output for those.
    """
    files = sorted(memdir.glob("*.md")) + sorted(memdir.glob("archive/*.md"))
    stems = {p.stem for p in files}
    edits = 0
    for p in files:
        text = p.read_text(encoding="utf-8")
        out = text
        for raw in set(re.findall(r"\[\[([^\]]+)\]\]", prose(text))) | \
                   set(re.findall(r"\]\(([A-Za-z0-9_\-]+)\.md\)", prose(text))):
            new = resolve_stale_name(raw, stems)
            if new is None:
                continue
            out = out.replace(f"[[{raw}]]", f"[[{new}]]").replace(f"]({raw}.md)", f"]({new}.md)")
            print(f"  {p.stem}: {raw} -> {new}")
            edits += 1
        if out != text:
            p.write_text(out, encoding="utf-8")
    print(f"\n{edits} link(s) repointed")
    return edits


def resolvable_names(texts):
    names = set(texts)
    for stem, t in texts.items():
        m = re.search(r"^name:\s*(.+)$", t, re.M)
        if m:
            names.add(m.group(1).strip().strip("\"'"))
        names.add(stem.replace("_", "-"))
    return names


_LINK = re.compile(r"\[\[([^\]]+)\]\]|\]\(([A-Za-z0-9_\-]+)\.md\)")


def link_targets(text):
    """Every stem this text points at, in EITHER link form."""
    for wiki, md in _LINK.findall(prose(text)):
        raw = wiki or md
        key = raw[:-3] if raw.endswith(".md") else raw
        yield key.replace("-", "_")


def reachable(texts, roots):
    """Files reachable from `roots` by markdown links OR [[links]], to fixpoint.

    Following only `[[...]]` was the defect. Sub-indexes list their entries as
    `](name.md)` markdown links, so every sub-index contributed zero children
    and everything filed into one read as unreachable -- 24 false orphans on
    2026-08-05. The `hops=4` bound is gone too: a fixpoint cannot silently
    under-report because a chain was one hop longer than someone guessed.
    """
    seen = set(roots)
    frontier = set(roots)
    while frontier:
        nxt = set()
        for stem in frontier:
            for key in link_targets(texts.get(stem, "")):
                if key in texts and key not in seen:
                    seen.add(key)
                    nxt.add(key)
        frontier = nxt
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--memory-dir", type=pathlib.Path, default=DEFAULT_DIR)
    ap.add_argument("--limit", type=int, default=17100, help="MEMORY.md byte budget")
    ap.add_argument("--repo", type=pathlib.Path, default=pathlib.Path.cwd(),
        help="repo whose paths the memories cite")
    ap.add_argument("--fix-links", action="store_true",
        help="repoint [[links]] and index entries at renamed files, then exit")
    ap.add_argument("--fix-relocations", action="store_true",
        help="repoint dead paths whose basename resolves uniquely, then exit")
    ap.add_argument("--main-checkout", type=pathlib.Path,
        default=pathlib.Path("/home/suzume/workspace/BEC-simulation"),
        help="checkout to look in for untracked files (worktrees cannot see each other's)")
    args = ap.parse_args()

    memdir = args.memory_dir
    if args.fix_links:
        return 0 if fix_links(memdir) >= 0 else 1
    if args.fix_relocations:
        return 0 if fix_relocations(memdir, args.repo.resolve()) >= 0 else 1
    if not memdir.is_dir():
        print(f"no memory dir at {memdir}", file=sys.stderr)
        return 2
    texts, archived = load(memdir)
    if "MEMORY" not in texts:
        print("no MEMORY.md", file=sys.stderr)
        return 2
    indexes = index_stems(texts)

    # Calibrate before reporting. A scan whose extraction is broken reports a
    # clean tree in exactly the same words as a clean tree does -- an earlier
    # hand-rolled pass over this store reported 52 unreachable memories when
    # the true count was 0, because it recognised one link spelling.
    probe_reach = reachable(texts, {"MEMORY"})
    if "MEMORY" not in texts or len(probe_reach) < 2:
        print("CALIBRATION FAILED: MEMORY.md reaches nothing; the link graph is "
              "not being parsed and every count below would be fiction.",
              file=sys.stderr)
        return 2

    index_text = "".join(prose(texts.get(i, "")) for i in indexes)
    linked = set(re.findall(r"\]\(([A-Za-z0-9_\-]+)\.md\)", index_text))
    reach = reachable(texts, set(indexes))
    orphans = sorted(set(texts) - reach - set(indexes) - archived)
    broken_index = sorted(linked - set(texts))

    names = resolvable_names(texts)
    dangling = defaultdict(list)
    for stem, t in texts.items():
        for lk in re.findall(r"\[\[([^\]]+)\]\]", prose(t)):
            key = lk[:-3] if lk.endswith(".md") else lk
            if key not in names and key.replace("-", "_") not in texts:
                dangling[key].append(stem)

    size = len(texts["MEMORY"].encode("utf-8"))
    fails = []

    print(f"memories            : {len(texts) - len(indexes) - len(archived)}"
          f"   (+{len(archived)} archived)")
    print(f"MEMORY.md size      : {size} / {args.limit} bytes")
    if size > args.limit:
        fails.append(f"MEMORY.md is {size - args.limit} bytes over budget — it will be truncated")

    print(f"unreachable files   : {len(orphans)}")
    for o in orphans[:20]:
        print(f"    {o}")
    if orphans:
        fails.append(f"{len(orphans)} memories are reachable from nothing and will never load")

    # A [[link]] to a memory that does not exist YET is legal by the memory
    # format's own rule -- it marks something worth writing. Gating on those
    # trains people to ignore the gate. Only DRIFT is a failure: a link whose
    # target exists under a renamed stem, which `--fix-links` can repair.
    stems = set(texts)
    drift = {k: v for k, v in dangling.items() if resolve_stale_name(k, stems)}
    forward = {k: v for k, v in dangling.items() if k not in drift}
    print(f"dangling [[links]]  : {len(drift)} drift / {len(forward)} forward-ref")
    for k, v in sorted(drift.items())[:20]:
        print(f"    DRIFT   [[{k}]] -> {resolve_stale_name(k, stems)}  <- {', '.join(v[:3])}")
    for k, v in sorted(forward.items())[:20]:
        print(f"    forward [[{k}]]  <- {', '.join(v[:3])}   (not written yet — legal)")
    if drift:
        fails.append(f"{len(drift)} [[links]] point at a RENAMED file "
                     f"(run --fix-links)")

    print(f"index -> missing    : {broken_index}")
    if broken_index:
        fails.append(f"index links to {len(broken_index)} missing files")

    counts, untracked_only, absent, elsewhere = path_report(texts, index_text,
        args.repo, args.main_checkout)
    print("\npath references cited by memories:")
    for k in sorted(counts, key=lambda k: -counts[k]):
        print(f"    {counts[k]:4d}  {k}")
    if untracked_only:
        n = sum(len(v) for v in untracked_only.values())
        print(f"\n  WARN  {n} artifacts cited by {len(untracked_only)} INDEXED memories exist")
        print("        only as untracked files in one checkout — invisible to other")
        print("        worktrees, and gone after a `git clean` or worktree removal:")
        for stem, ps in sorted(untracked_only.items(), key=lambda kv: -len(kv[1])):
            print(f"          {len(ps):2d}  {stem}")
    if elsewhere:
        n = sum(len(v) for v in elsewhere.values())
        print(f"\n  WARN  {n} paths cited by {len(elsewhere)} memories exist ONLY ON ANOTHER REF.")
        print("        A present-tense claim about one of these reads as landed in the")
        print("        worktree that has it and as junk in the one that does not. Anchor")
        print("        the claim to a ref, not just a date:")
        for stem, ps in sorted(elsewhere.items(), key=lambda kv: -len(kv[1]))[:10]:
            print(f"          {stem}: {', '.join(ps[:2])}")

    if absent:
        n = sum(len(v) for v in absent.values())
        print(f"\n  WARN  {n} paths cited by {len(absent)} INDEXED memories resolve nowhere")
        print("        (never committed, not untracked either — in-flight or a typo):")
        for stem, ps in sorted(absent.items(), key=lambda kv: -len(kv[1])):
            print(f"          {stem}: {', '.join(ps[:3])}")

    if fails:
        print("\nFAIL")
        for f in fails:
            print(f"  - {f}")
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
