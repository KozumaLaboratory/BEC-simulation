#!/usr/bin/env python3
"""Audit the project's Claude memory tree for silent rot.

    python3 scripts/audit_memory.py [--memory-dir DIR] [--limit 17100]

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
   session acts on. Measured 2026-07-27 over 517 such references:

       271  in HEAD
       154  removed from the repo (mostly in settled historical memories)
        44  retired `runs/_loop/` — archived outside the repo, correctly historical
        26  absent everywhere
        18  untracked in the main checkout
         4  placeholder (`scripts/foo.jl` in prose)

   The 18 are the ones that matter: 4 INDEXED memories cite artifacts that
   exist only as untracked files in a single checkout (which held 603 of
   them). Invisible to every other worktree, and destroyed by a `git clean`
   or a worktree removal, while the memory index treats them as repo assets.

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
INDEXES = ("MEMORY", "memory_index_history")


def load(memdir):
    return {p.stem: p.read_text(encoding="utf-8") for p in sorted(memdir.glob("*.md"))}


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


_PATH = re.compile(
    r"\b((?:src|test|scripts|bench|docs|runs|ext|dashboard)"
    r"/[A-Za-z0-9_\-./]*\.(?:jl|md|py|yaml|yml|toml|sh|json))"
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
    untracked = set()
    if main_checkout and main_checkout.is_dir():
        untracked = {l[3:].strip() for l in
                     _git(main_checkout, "status", "--porcelain", "-uall").splitlines()
                     if l.startswith("??")}

    counts = defaultdict(int)
    untracked_only = defaultdict(list)
    absent = defaultdict(list)
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
            elif p in ever:
                counts["removed from the repo"] += 1
            else:
                counts["absent everywhere"] += 1
                indexed and absent[stem].append(p)
    return counts, untracked_only, absent


def resolvable_names(texts):
    names = set(texts)
    for stem, t in texts.items():
        m = re.search(r"^name:\s*(.+)$", t, re.M)
        if m:
            names.add(m.group(1).strip().strip("\"'"))
        names.add(stem.replace("_", "-"))
    return names


def reachable(texts, roots, hops=4):
    """Files reachable from the indexes via markdown links, then [[links]]."""
    seen = set(roots)
    for _ in range(hops):
        for stem in list(seen):
            for lk in re.findall(r"\[\[([^\]]+)\]\]", prose(texts.get(stem, ""))):
                key = (lk[:-3] if lk.endswith(".md") else lk).replace("-", "_")
                if key in texts:
                    seen.add(key)
    return seen


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--memory-dir", type=pathlib.Path, default=DEFAULT_DIR)
    ap.add_argument("--limit", type=int, default=17100, help="MEMORY.md byte budget")
    ap.add_argument("--repo", type=pathlib.Path, default=pathlib.Path.cwd(),
        help="repo whose paths the memories cite")
    ap.add_argument("--main-checkout", type=pathlib.Path,
        default=pathlib.Path("/home/suzume/workspace/BEC-simulation"),
        help="checkout to look in for untracked files (worktrees cannot see each other's)")
    args = ap.parse_args()

    memdir = args.memory_dir
    if not memdir.is_dir():
        print(f"no memory dir at {memdir}", file=sys.stderr)
        return 2
    texts = load(memdir)
    if "MEMORY" not in texts:
        print("no MEMORY.md", file=sys.stderr)
        return 2

    index_text = "".join(prose(texts.get(i, "")) for i in INDEXES)
    linked = set(re.findall(r"\]\(([A-Za-z0-9_\-]+)\.md\)", index_text))
    reach = reachable(texts, linked)
    orphans = sorted(set(texts) - reach - set(INDEXES))
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

    print(f"memories            : {len(texts) - len(INDEXES)}")
    print(f"MEMORY.md size      : {size} / {args.limit} bytes")
    if size > args.limit:
        fails.append(f"MEMORY.md is {size - args.limit} bytes over budget — it will be truncated")

    print(f"unreachable files   : {len(orphans)}")
    for o in orphans[:20]:
        print(f"    {o}")
    if orphans:
        fails.append(f"{len(orphans)} memories are reachable from nothing and will never load")

    print(f"dangling [[links]]  : {len(dangling)}")
    for k, v in sorted(dangling.items())[:20]:
        print(f"    [[{k}]]  <- {', '.join(v[:3])}")
    if dangling:
        fails.append(f"{len(dangling)} [[links]] point at nothing")

    print(f"index -> missing    : {broken_index}")
    if broken_index:
        fails.append(f"index links to {len(broken_index)} missing files")

    counts, untracked_only, absent = path_report(texts, index_text, args.repo,
        args.main_checkout)
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
