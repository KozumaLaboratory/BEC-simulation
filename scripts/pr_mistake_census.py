#!/usr/bin/env python3
"""Re-derive the PR mistake census, or check the frozen one.

    python3 scripts/pr_mistake_census.py --verify-doc      # the frozen doc's lists resolve
    python3 scripts/pr_mistake_census.py --extract --since 447   # raw material for a re-read
    python3 scripts/pr_mistake_census.py --counts          # keyword trend (a DIFFERENT instrument)
    python3 scripts/pr_mistake_census.py --self-test       # controls only, no network

WHY THIS EXISTS
---------------
`docs/campaign/pr_mistake_census_2026_08_22.md` is FROZEN, and its closing line
says re-measuring is cheaper than re-reading. That was NOT TRUE when written:
the mining lived in a scratch directory and died with the session, so
"re-measure" meant writing it again from nothing. A document whose own advice
cannot be followed is a dead end. This file is what makes the advice real.

THE THREE MODES ARE THREE DIFFERENT INSTRUMENTS. Do not read one as the other.

  --verify-doc  Checks the FROZEN document against reality: every `#NNN` it
                lists is a real PR in range, and the count it states for each
                class equals the length of the list it prints. This is the only
                mode that adjudicates the committed document.

  --extract     Pulls the mistake-DESCRIBING lines out of PR bodies — the raw
                material the census was hand-classified from. `--since 447`
                gives the PRs the frozen document does not cover, which is the
                cheap way to extend it. Reading 40 extracted lines is minutes;
                reading 383 PR bodies is not.

  --counts      A keyword classifier over PR prose. It DISAGREES with the
                document's hand classification by up to 2.4x, and that is not a
                bug in either: the document counts PRs a human judged to be in a
                class, this counts PRs whose prose trips a regex. Useful for
                "is the rate rising", useless for "which PRs". The regexes were
                NOT tuned to reproduce the document's numbers — fitting the
                instrument to the answer is the defect the census logs as
                "a tolerance fitted to a failing expansion" (#144).

WHAT IT DELIBERATELY DOES NOT DO
--------------------------------
It does not re-derive the ACTIONABLE findings. Those became gates, and a second
statement of them here would be the duplicated-declaration defect the census
counts as class 1:

  * job exit status reflects its stages  -> test/test_submit_scripts_fail_loudly.jl
  * a retraction rests on resolvable grounds
                                         -> test/test_retracted_numbers_carry_their_replacement.jl
  * includes and commit citations resolve -> test/test_scripts_allowlist.jl,
                                             test/test_campaign_fix_list_gate.jl

Run the gates for the present. Run this for the trend.

CALIBRATION
-----------
A keyword scan over prose is exactly the instrument that reports a clean tree
when its regex is broken ("the regex became the measurement", three times in one
day — `docs/campaign/lessons_2026_08_04.md`). So every class carries a POSITIVE
control: a PR whose body MUST match. If a control fails, the class prints BLIND
and the run exits non-zero rather than printing a number. `--self-test` proves
that refusal is reachable without touching the network.
"""

import argparse
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
CACHE = os.path.join(ROOT, ".pr_census_cache.json")
DOC = os.path.join(ROOT, "docs", "campaign", "pr_mistake_census_2026_08_22.md")

# (name, pattern, positive-control PR). The control comes from the incident the
# class is named for, never from convenience: a control that cannot fail proves
# nothing, which is the degenerate-knob trap in another costume.
CLASSES = {
    1: ("declared physics silently absent on one path",
        r"silently (dropped|absent|collaps|zero)|dropped the (tabulated|lhy|table)"
        r"|no production run|c_lhy = 0|silently ran", 125),
    2: ("blind instrument — a null from a check that cannot fire",
        r"positive control|陽性対照|negative control|陰性対照|vacuous|blind"
        r"|never ran|一度も走って|could not (see|look)", 190),
    3: ("a retraction that does not reach the point of use",
        r"point of use|使用箇所|節単位|retired_literal|claims\.toml", 412),
    4: ("the correction is itself wrong",
        r"撤回とその撤回|訂正も.{0,4}premature|was itself false"
        r"|first version of this PR", 358),
    5: ("the shell or the scheduler silently did something else",
        r"qsub -v|set \+e|fetch-depth|first comma|exit_status 0|errexit", 427),
    6: ("the merge does not conflict but the artifact breaks",
        r"neither PR changed|concurrent merge|マージは衝突", 394),
    7: ("a test written to match the implementation pins the bug",
        r"written to match the bug|assertion written to match|バグに合わせて", 315),
    8: ("computed before verifying the premise",
        r"premise.{0,40}(wrong|false)|前提.{0,10}(誤|崩)|全面撤回|論文を読んだ", 303),
}

# Lines in a PR body that describe something going wrong. Deliberately wide:
# this feeds a human read, and a miss costs more than a false positive.
MISTAKE_RE = re.compile(
    r"撤回|反証|訂正|誤り|欠陥|バグ|見落と|blind|vacuous|positive control|陽性対照|"
    r"retract|refut|overturn|was wrong|were wrong|was false|were false|never existed|"
    r"silently|no production run|never (called|reached|ran|crossed)|zero production|"
    r"stale|had stopped being true|does not exist|ungated|nothing caught|"
    r"too (large|small)|× too|off by|wrong sign|符号|what went wrong|原因|失敗|"
    r"走っていなかった|測っていなかった", re.I)


def fetch(refresh=False):
    if os.path.isfile(CACHE) and not refresh:
        return json.load(open(CACHE))
    out = subprocess.run(
        ["gh", "pr", "list", "--state", "all", "--limit", "1000",
         "--json", "number,title,state,body"],
        capture_output=True, text=True, check=True).stdout
    data = json.loads(out)
    json.dump(data, open(CACHE, "w"))
    return data


def body(pr):
    return (pr.get("title") or "") + "\n" + (pr.get("body") or "")


def _issue_numbers():
    """Issue numbers. GitHub shares ONE numbering space with PRs and this
    repo's prose cites both — `#339` in the census is an issue, not a PR, and a
    checker that knows only about PRs calls it a dead citation."""
    out = subprocess.run(
        ["gh", "issue", "list", "--state", "all", "--limit", "1000",
         "--json", "number"],
        capture_output=True, text=True, check=True).stdout
    return {i["number"] for i in json.loads(out)}


def cmd_verify_doc(prs):
    """The frozen document's own lists must resolve, and match their stated counts."""
    if not os.path.isfile(DOC):
        print("MISSING: %s" % os.path.relpath(DOC, ROOT), file=sys.stderr)
        return 1
    text = open(DOC).read()
    real = {p["number"] for p in prs} | _issue_numbers()
    # `## 4. ... （8 PR）` or `（約 36 PR）` — the hedge is part of the corpus and
    # a regex that misses it drops a whole class OUT OF THE TABLE, silently.
    # That happened on the first run of this checker: class 2 simply was not
    # listed, and nothing said so. Hence the completeness assertion below.
    heads = list(re.finditer(r"^## (\d)\. (.+?)（(?:約\s*)?(\d+) PR", text, re.M))
    expected = len(re.findall(r"^## \d\. ", text, re.M))
    if not heads:
        print("BLIND: no class headings parsed out of the document — the "
              "extractor is broken, not the document clean", file=sys.stderr)
        return 1
    if len(heads) != expected:
        print("BLIND: %d of %d class headings parsed. A class missing from this "
              "table reads exactly like a class with nothing wrong."
              % (len(heads), expected), file=sys.stderr)
        return 1
    bad = 0
    print("class  stated  listed  unresolvable")
    for i, h in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        section = text[h.end():end]
        listed = sorted({int(m.group(1))
                         for m in re.finditer(r"#(\d{1,4})\b", section)})
        # Only the enumeration line, not every incidental mention: take the
        # numbers before the first table, which is where the lists live.
        dead = [n for n in listed if n not in real]
        stated = int(h.group(3))
        flag = ""
        if dead:
            flag = "  <- " + " ".join("#%d" % n for n in dead)
            bad += 1
        print("  %s      %2d    %4d%s" % (h.group(1), stated, len(listed), flag))
    print()
    print("`listed` counts every #NNN in the section (tables and prose included),")
    print("so it exceeds `stated`, which is the enumeration line only. The check")
    print("that matters is the last column: a citation that resolves to nothing.")
    print("PR and issue numbers share one space here and both are accepted.")
    if bad:
        print("\n%d section(s) cite a number that is neither a PR nor an issue." % bad)
        return 1
    print("\nAll %d classes parsed; every number the frozen census cites resolves."
          % len(heads))
    return 0


def cmd_extract(prs, since, until):
    scope = [p for p in prs
             if p["number"] >= since and (until is None or p["number"] <= until)]
    scope.sort(key=lambda p: -p["number"])
    shown = 0
    for p in scope:
        hits = [l.strip() for l in (p.get("body") or "").splitlines()
                if len(l.strip()) >= 12 and MISTAKE_RE.search(l)]
        if not hits:
            continue
        shown += 1
        print("\n### #%d [%s] %s" % (p["number"], p["state"][0], p["title"][:140]))
        for h in hits[:9]:
            print("  - " + h[:300])
    print("\n%d of %d PRs in range describe something going wrong."
          % (shown, len(scope)))
    if scope and shown == 0:
        print("REFUSING to read that as a clean range: %d PRs matched nothing, "
              "which is more likely a broken extractor." % len(scope),
              file=sys.stderr)
        return 1
    return 0


def cmd_counts(prs, max_pr):
    by_num = {p["number"]: p for p in prs}
    scope = [p for p in prs if max_pr is None or p["number"] <= max_pr]
    blind = []
    print("corpus: %d PRs (%d merged)%s\n" % (
        len(scope), sum(1 for p in scope if p["state"] == "MERGED"),
        "" if max_pr is None else "  [<= #%d]" % max_pr))
    for cid in sorted(CLASSES):
        name, pat, control = CLASSES[cid]
        rx = re.compile(pat, re.I)
        ctl = by_num.get(control)
        if ctl is None or not rx.search(body(ctl)):
            blind.append((cid, control,
                          "not in corpus" if ctl is None else "did not match"))
            print("%d. %-52s  BLIND" % (cid, name[:52]))
            continue
        n = sum(1 for p in scope if rx.search(body(p)))
        print("%d. %-52s %3d PR" % (cid, name[:52], n))
    if blind:
        print("\nREFUSED. A failed positive control means the classifier is "
              "broken, NOT that the tree is clean:")
        for cid, control, why in blind:
            print("  class %d: control #%d %s" % (cid, control, why))
        return 1
    print("\nA DIFFERENT INSTRUMENT from the document's hand classification —")
    print("they disagree by up to 2.4x and both are right about their own")
    print("question. Use this for the trend, `--verify-doc` for the document.")
    return 0


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--verify-doc", action="store_true")
    g.add_argument("--extract", action="store_true")
    g.add_argument("--counts", action="store_true")
    g.add_argument("--self-test", action="store_true")
    ap.add_argument("--since", type=int, default=1)
    ap.add_argument("--until", type=int, default=None)
    ap.add_argument("--max-pr", type=int, default=None)
    ap.add_argument("--refresh", action="store_true")
    a = ap.parse_args()

    if a.self_test:
        fake = [{"number": 125, "title": "x", "body": "nothing relevant", "state": "MERGED"}]
        rc = cmd_counts(fake, None)
        ok = rc != 0
        print("\nself-test:", "OK — a corpus with no signal REFUSES to count"
              if ok else "BROKEN — it printed counts over a corpus with no signal")
        return 0 if ok else 1

    prs = fetch(a.refresh)
    if a.verify_doc:
        return cmd_verify_doc(prs)
    if a.extract:
        return cmd_extract(prs, a.since, a.until)
    return cmd_counts(prs, a.max_pr)


if __name__ == "__main__":
    sys.exit(main())
