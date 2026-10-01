using Test
# parallel-runner contract: every test file loads the package (plain form)
using SpinorBEC

# The gate for "work that already exists must be dispositioned, not merely
# available".
#
# On 2026-08-20 an SPGPE campaign re-derived a cache-key bug that PR #351 had
# already found, fixed and gated two days earlier, and — worse — shipped a
# documented limit that the same PR had already RETRACTED. An entire ensemble was
# designed on a limit that did not exist. `gh pr list` had been run at the start of
# that session and #351 was IN THE OUTPUT with `feat(spgpe):` in its title, on a
# task that was entirely SPGPE.
#
# Two memory notes covered it exactly and neither fired, which is the argument
# against writing a third: salience loses to task momentum. So the remedy is an
# artifact that must exist and a state it may not be left in —
# `docs/campaign/prior_art/<topic>.md`, one row per matching open PR / issue /
# branch, and `unread` is a failure.
#
# WHAT THIS GATE DOES NOT DO, stated because a gate that implies more than it
# checks is worse than none. It cannot tell whether the enumeration is CURRENT —
# the runner has no network — and it cannot tell whether a `read` row was really
# read. It checks the two things that are decidable from the file: every row has a
# known disposition, and none is still `unread`. The generator
# (`scripts/prior_art.py`) is what makes enumerating cheap; this is what makes
# leaving a row unread impossible to do quietly.
@testset "prior-art records carry a disposition for every entry" begin
    python = Sys.iswindows() ? "python" : "python3"
    root = normpath(joinpath(@__DIR__, ".."))
    dir = joinpath(root, "docs", "campaign", "prior_art")
    tool = joinpath(root, "scripts", "prior_art.py")
    @test isfile(tool)

    # `--check` is the same predicate the tool exposes to a human, so the gate and
    # the command someone runs by hand cannot drift apart.
    ok = success(pipeline(`$python $tool --check`; stdout=devnull, stderr=devnull))
    if !ok
        @info "prior-art check failed; run `python3 scripts/prior_art.py --check`" *
            " to see which entries are unread" dir
    end
    @test ok

    # CANARY. A checker that cannot fail is the failure mode this whole family of
    # gates exists to remove, so plant the exact defect and require a refusal.
    mktempdir() do d
        rec = joinpath(d, "prior_art")
        mkpath(rec)
        write(
            joinpath(rec, "canary.md"),
            """
# Prior art — canary

| ref | disposition | what | note |
|---|---|---|---|
| #1 | read | pr: fine | |
| #2 | unread | pr: the one that would have stopped it | |
""",
        )
        # Point the tool at the temporary tree by running it from there: RECORD_DIR
        # is derived from the script's own location, so a copy of the script beside
        # a `docs/campaign/prior_art` is what makes this reachable.
        fake_root = joinpath(d, "fake")
        mkpath(joinpath(fake_root, "scripts"))
        mkpath(joinpath(fake_root, "docs", "campaign"))
        cp(tool, joinpath(fake_root, "scripts", "prior_art.py"))
        cp(rec, joinpath(fake_root, "docs", "campaign", "prior_art"))
        refused =
            !success(
                pipeline(
                    `$python $(joinpath(fake_root, "scripts", "prior_art.py")) --check`;
                    stdout=devnull, stderr=devnull),
            )
        @test refused          # an `unread` row MUST fail

        # …and the negative half: the same tree with that row dispositioned passes,
        # so the canary is testing the row and not the tree's existence.
        p = joinpath(fake_root, "docs", "campaign", "prior_art", "canary.md")
        write(p, replace(read(p, String), "| unread |" => "| unrelated |"))
        @test success(
            pipeline(
                `$python $(joinpath(fake_root, "scripts", "prior_art.py")) --check`;
                stdout=devnull, stderr=devnull),
        )
    end
end

@testset "prior-art UTF-8 rows preserve notes and invalid dispositions" begin
    python = Sys.iswindows() ? "python" : "python3"
    tool = joinpath(@__DIR__, "..", "scripts", "prior_art.py")
    program = raw"""
import importlib.util
import pathlib
import sys
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("prior_art", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as d:
    mod.RECORD_DIR = pathlib.Path(d)
    p = mod.RECORD_DIR / "topic.md"
    p.write_text("| ref | disposition | what | note |\n"
                 "|---|---|---|---|\n"
                 "| #7 | read | pr: 日本語 | 調査理由 | 続き |\n"
                 "| #8 | invalid | issue: 未処理 | 保持する |\n",
                 encoding="utf-8")
    assert list(mod.record_rows(p)) == [
        ("#7", "read", "pr: 日本語", "調査理由 | 続き"),
        ("#8", "invalid", "issue: 未処理", "保持する")]
    assert mod.check() == 1
    mod.write_record("topic", ["日本語"],
                     [{"kind": "pr", "ref": "#7", "title": "日本語"}])
    rows = list(mod.record_rows(p))
    assert rows[0][3] == "調査理由 | 続き"
    assert rows[1][1:] == ("invalid", "(no longer open)", "保持する")
    assert mod.check() == 1
    p.write_text(p.read_text(encoding="utf-8").replace("| invalid |", "| read |"),
                 encoding="utf-8")
    assert mod.check() == 0
    p.write_text("| #9 | unread |\n", encoding="utf-8")
    try:
        mod.check()
    except ValueError:
        pass
    else:
        raise AssertionError("truncated unread row silently disappeared")
    for broken in ("| | read | pr: missing reference | |\n",
                   "| #7 | read | pr: one | first note |\n"
                   "| #7 | read | pr: two | second note |\n"):
        p.write_text(broken, encoding="utf-8")
        before = p.read_bytes()
        try:
            mod.write_record("topic", [], [])
        except ValueError:
            pass
        else:
            raise AssertionError("ambiguous record was overwritten")
        assert p.read_bytes() == before
    p.unlink()
    mod.write_record("topic", ["title"],
                     [{"kind": "pr", "ref": "#7", "title": "left | right"}])
    assert list(mod.record_rows(p)) == [
        ("#7", "unread", "pr: left &#124; right", "")]
    # Failure on a first enumeration must not manufacture an apparently complete
    # empty record. Existing records must also survive partial results unchanged.
    for topic in ("new_topic", "topic"):
        target = mod.RECORD_DIR / (topic + ".md")
        before = target.read_bytes() if target.exists() else None
        with patch.object(sys, "argv", ["prior_art", "--topic", topic,
                                        "--keywords", "title"]), \
             patch.object(mod, "enumerate_topic", return_value=([], False)):
            assert mod.main() == 2
        assert (target.read_bytes() if target.exists() else None) == before
"""
    @test success(`$python -c $program $tool`)
end

# Provider failures and successful enumeration must have different outcomes.
# Mock the subprocess boundary rather than installing a /bin/sh gh fixture:
# the same cases must exercise the real enumeration and CLI on every OS.
@testset "regenerating a prior-art record cannot destroy it" begin
    python = Sys.iswindows() ? "python" : "python3"
    tool = joinpath(@__DIR__, "..", "scripts", "prior_art.py")
    program = raw"""
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("prior_art", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
with tempfile.TemporaryDirectory() as d:
    mod.ROOT = pathlib.Path(d)
    mod.RECORD_DIR = pathlib.Path(d)
    rec = mod.RECORD_DIR / "t.md"
    rec.write_text("| ref | disposition | what | note |\n"
                   "|---|---|---|---|\n"
                   "| #7 | read | pr: a thing | THE REASON |\n", encoding="utf-8")
    before = rec.read_bytes()
    argv = ["prior_art", "--topic", "t", "--keywords", "spgpe"]
    with patch.object(sys, "argv", argv), \
         patch.object(mod.subprocess, "run", side_effect=FileNotFoundError("missing provider")):
        assert mod.main() == 2
    assert rec.read_bytes() == before

    calls = []
    def provider(args, **kwargs):
        calls.append(args)
        assert kwargs["encoding"] == "utf-8"
        if args[:3] == ["gh", "pr", "list"]:
            out = json.dumps([{"number": 7, "title": "a thing 日本語",
                               "headRefName": "f/spgpe"}], ensure_ascii=False)
        elif args[:3] == ["gh", "issue", "list"]:
            out = "[]"
        elif args[0] == "git":
            out = "origin/unrelated\n"
        else:
            raise AssertionError(args)
        return subprocess.CompletedProcess(args, 0, stdout=out, stderr="")
    with patch.object(sys, "argv", argv), \
         patch.object(mod.subprocess, "run", side_effect=provider):
        assert mod.main() == 0
    assert len(calls) == 3
    assert list(mod.record_rows(rec)) == [
        ("#7", "read", "pr: a thing 日本語", "THE REASON")]
"""
    @test success(`$python -c $program $tool`)
end
