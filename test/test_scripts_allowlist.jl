# scripts/ allowlist gate — the CONTRIBUTING.md `scripts/` charter, as a test.
#
# The charter ("scripts/ holds operational artifacts; compute lives in src/")
# existed as prose since the 117→2 campaign, and with no gate the directory
# regrew to 306 files. This asserts SET EQUALITY in both directions:
#   - a file on disk but not in the allowlist  → the charter is being bypassed;
#     absorb the logic into src/ (+ a cli.jl subcommand if it needs an entry
#     point), or — for a genuinely new operational artifact / active campaign
#     dir — add it HERE in the same PR, where the reviewer sees it.
#   - an allowlist entry with no file on disk   → stale list; prune it.
#
# 2026-08-18 cleanup: 306 → 76. One-off drivers were archived verbatim to
# /home/suzume/workspace/BEC-simulation-archive/scripts_2026_08_18/ (and
# remain in git history); reusable logic went to src/ (gs_library, spinor
# phase classifier, phase-scan tables, validation matrix, Matsui Fig-4B
# report, docs figure builders, cli_main).

using Test
# parallel-runner contract: every test file loads the package (plain form)
using SpinorBEC

const _SCRIPTS_ALLOWLIST = Set([
    # ── entry points / hard test gates ──
    "cli.jl",                      # shim → SpinorBEC.cli_main
    "generate_state.jl",           # docs/STATE.md generator (test-gated)
    "audit_memory.py",             # memory-store auditor (CLAUDE.md-gated)
    "preflight_invariants.jl",     # physics-invariant preflight battery
    "watch_until_done.sh",         # job watcher with a reachable RED
    # ── build tooling (category 2) ──
    "build_sysimage.jl",
    "build_sysimage_full.jl",
    "build_sysimage_matsui.jl",
    "_sysimage_precompile_full.jl",
    "_sysimage_precompile_matsui.jl",
    "build_paper_latex.sh",
    "filter_bib.sh",
    # ── declarative ops specs (category 3) ──
    "spinor-autopilot.service",
    "spinor-autopilot.timer",
    "spinor-dashboard.service",
    "spinorbec.env",
    "spinorbec.def",
    "tsubame_setup.sh",
    "deploy_dashboard_auth.sh",
    # ── cluster submit wrappers (UGE; declarative + qsub) ──
    "submit_test_tier.sh",
    "submit_mutation_sweep.sh",
    "submit_kz_exponent.sh",
    "submit_eu_bscan.sh",
    "tsubame/_preamble.sh",
    "tsubame/preflight.sh",
    "tsubame/submit_gpu_smoke.sh",
    "tsubame/submit_load_check.sh",
    "tsubame/submit_mutation.sh",
    "tsubame/submit_test_tier.sh",
    "tsubame/submit_test_tier_ci.sh",
    "tsubame/ums_probe.sh",
    # ── loop-engineering integrity floor (Stop-hook executes by path) ──
    "loop/loop_gate.sh",
    "loop/verify.jl",
    # ── MCP gateway (Claude Desktop → TSUBAME) ──
    "mcp/tsubame_server.py",
    "mcp/README.md",
    # ── active campaign: Eu weak-field ramp protocols (docs/guides/eu_adiabatic_protocol.md) ──
    "eu_adiabatic_ramp_protocol.jl",
    "eu_adiabatic_window.jl",
    "eu_bscan_pinned_continuation.jl",
    "eu_kappa_ramp_protocol.jl",
    "eu_kappa_edh_winding.jl",
    "eu_torque_protocol.jl",
    "eu_campaign_resume.sh",
    "run_eu_adiabatic_ramp.sh",
    "run_eu_kappa_ramp.sh",
    "viz_style.py",
    "viz_eu_adiabatic_ramp.py",
    "viz_eu_bscan_animation.py",
    "viz_eu_edh_quantisation.py",
    "viz_eu_kappa_ramp.py",
    "viz_eu_torque.py",
    # ── active campaign: Eu κ-hysteresis loop (docs/guides/eu_kappa_hysteresis_loop.md, #352) ──
    "eu_hysteresis/_preamble.sh",
    "eu_hysteresis/branch_continuation.jl",
    "eu_hysteresis/branch_stability.jl",
    "eu_hysteresis/launch.sh",
    "eu_hysteresis/loop_width.jl",
    "eu_hysteresis/sg_signature.jl",
    "eu_hysteresis/submit_branch.sh",
    "eu_hysteresis/submit_ramp.sh",
    "eu_hysteresis/submit_smoke.sh",
    "eu_hysteresis/submit_stability.sh",
    # ── active campaign: Eu in-place nucleation (docs/guides/eu_in_place_nucleation.md, #334) ──
    "eu334/_preamble.sh",
    "eu334/launch.sh",
    "eu334/submit_bifurcation.sh",
    "eu334/submit_nucleate.sh",
    "eu334/submit_smoke.sh",
    "eu334/submit_classify.sh",
    "eu334/window.jl",
    "eu334/nucleation_bifurcation.jl",
    "eu334/nucleate.jl",
    "eu334/classify.jl",
    "eu334/viz_eu334.py",
    # ── active campaign: KZ / SPGPE (scripts/kz/README.md) ──
    "kz/README.md",
    "kz/classical_field_tc.jl",
    "kz/mdamp_dt.jl",
    "kz/mdamp_eq.jl",
    "kz/mdamp_fdr.jl",
    "kz/mdamp_long.jl",
    "kz/mdamp_proj.jl",
    "kz/ramp_design.jl",
    "kz/run_mdamp.sh",
    "kz/run_mdampdt.sh",
    "kz/run_mdampfdr.sh",
    "kz/run_mdamplong.sh",
    "kz/run_mdampproj.sh",
    "kz/submit_kz_spin1.sh",
    "kz/submit_kz_torus.sh",
    "kz/submit_kz_torus_sharded.sh",
    "kz/sync_tsubame.sh",
    # ── active campaign: Eu shape / evaporation (TSUBAME) ──
    "eu_shape/deploy_tsubame.sh",
    "eu_shape/submit_finite_t.sh",
    "eu_shape/submit_spgpe_evap.sh",
    # ── validation probes still cited as live instruments ──
    "validation/matsui_dataset_to_csv.jl",
    "validation/rk4ip_gpu_cost_probe.jl",
    "validation/rk4ip_step_size_probe.jl",
    "validation/rk4ip_time_to_solution_gpu.jl",
    "validation/scan_job_cost_breakdown.jl",
    "validation/step_cost_ablation_gpu.jl",
])

@testset "scripts/ allowlist (CONTRIBUTING.md charter, gated)" begin
    root = normpath(joinpath(@__DIR__, ".."))
    sdir = joinpath(root, "scripts")
    on_disk = Set{String}()
    for (dir, _, files) in walkdir(sdir)
        rel = relpath(dir, sdir)
        for f in files
            # editor droppings / venvs are not repo content; git status catches those
            push!(on_disk, rel == "." ? f : joinpath(rel, f))
        end
    end
    # ignore local-only clutter that is not tracked by git (e.g. mcp/.venv)
    tracked = Set(split(read(`git -C $root ls-files scripts`, String), '\n';
        keepempty=false))
    on_disk = Set(f for f in on_disk if ("scripts/" * f) in tracked)

    extra = sort(collect(setdiff(on_disk, _SCRIPTS_ALLOWLIST)))
    stale = sort(collect(setdiff(_SCRIPTS_ALLOWLIST, on_disk)))

    @testset "no unlisted files (absorb into src/ or allowlist in the same PR)" begin
        @test isempty(extra)
        isempty(extra) || @info "unlisted scripts/ files" extra
    end
    @testset "no stale allowlist entries" begin
        @test isempty(stale)
        isempty(stale) || @info "allowlist entries with no file" stale
    end
end

# The allowlist asserts a file EXISTS. It says nothing about whether that file
# still runs, and on 2026-08-18 the 306→76 absorption deleted
# `scripts/eu_ramp_common.jl` while two #335 instruments
# (`eu_hysteresis/branch_{continuation,stability}.jl`) kept including it. Both
# died on their first line for a month with nothing red: the allowlist was
# happy, the tier suite does not execute scripts, and the campaign that needed
# them was already finished. The class is "a tracked artifact points at a path
# that a later commit removed", and it is checkable in milliseconds.
@testset "include targets in scripts/ and docs figures resolve" begin
    root = normpath(joinpath(@__DIR__, ".."))
    include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

    # `include(joinpath(@__DIR__, "a", "b.jl"))` and `include("a/b.jl")`.
    # Anything with an interpolation or a non-literal argument is skipped rather
    # than guessed at — and the count of skips is reported, so an extractor that
    # understands nothing cannot pass as a tree with nothing to find.
    re_dir = r"include\(\s*joinpath\(\s*@__DIR__\s*,\s*((?:\"[^\"]*\"\s*,\s*)*\"[^\"]*\")\s*\)\s*\)"
    re_lit = r"include\(\s*\"([^\"$]*)\"\s*\)"
    lit_parts(s) = String[strip(x, ['"', ' ']) for x in split(s, ",")]

    # (file, printable target, [candidate absolute paths]). A `.jl` include is
    # relative to its own file; the `julia -e '… include("x") …'` lines inside
    # submit wrappers and usage comments run from the repo root. Both bases are
    # offered and either one resolving is enough — the gate is looking for a
    # target that exists NOWHERE, which is what a deletion leaves behind.
    # `out`, not `refs`: a nested function assigning to a name that is already a
    # local of the enclosing scope writes to THAT variable, and the first version
    # of this gate silently replaced the corpus with the two-entry calibration
    # probe — then reported the probe as the tree's only broken includes.
    include_refs = function (path)
        src = read(path, String)
        out = Tuple{String, String, Vector{String}}[]
        for m in eachmatch(re_dir, src)
            t = joinpath(lit_parts(m[1])...)
            push!(out, (path, t, [normpath(joinpath(dirname(path), t))]))
        end
        for m in eachmatch(re_lit, src)
            t = String(m[1])
            push!(
                out,
                (path, t, [normpath(joinpath(dirname(path), t)),
                    normpath(joinpath(root, t))]),
            )
        end
        out
    end

    files = String[]
    for d in ("scripts", joinpath("docs", "guides", "figures"))
        isdir(joinpath(root, d)) || continue
        for (dir, _, fs) in walkdir(joinpath(root, d)), f in fs
            (endswith(f, ".jl") || endswith(f, ".sh")) && push!(files, joinpath(dir, f))
        end
    end
    refs = Tuple{String, String, Vector{String}}[]
    for f in files
        append!(refs, include_refs(f))
    end

    # The extractor is the part that can go blind: a regex that matches nothing
    # reports a clean tree. Prove it recovers both forms from source it will
    # actually meet, before any count taken with it is used.
    probe = mktempdir()
    write(joinpath(probe, "p.jl"),
        "include(joinpath(@__DIR__, \"sub\", \"there.jl\"))\ninclude(\"flat.jl\")\n")
    got = Set(r[2] for r in include_refs(joinpath(probe, "p.jl")))
    @test joinpath("sub", "there.jl") in got
    @test "flat.jl" in got

    broken = calibrated_scan(refs;
        match=r -> !any(isfile, r[3]),
        present=("synthetic", "gone.jl", [joinpath(root, "deleted_by_a_later_commit.jl")]),
        absent=("synthetic", "Project.toml", [joinpath(root, "Project.toml")]),
        describe=r -> string(r[1], " → ", r[2]))

    @test isempty(broken)
    isempty(broken) || @info "include targets that exist under no base" broken
    @test !isempty(refs)      # nothing to check ⇒ the extractor, not the tree
end

# Same class, other language. A submit wrapper is only ever executed by the
# scheduler, so a quoting slip in one is discovered by a job that dies in its
# first second after queueing — `${2:?… stage A's …}` is parsed, and the
# apostrophe inside it took a launcher down. `bash -n` parses without running,
# which is exactly the distinction that makes this safe to gate.
# Parsing is not enough for Julia either. `@printf("a" * "b", x)` PARSES — `*` of
# two literals is an ordinary expression — and dies at macro-expansion with
# "First argument to `@printf` after `io` must be a format string". Hit twice on
# 2026-08-19, once in a driver and once in a test, each time discovered by a
# scheduler after minutes of queue and JIT.
#
# `Meta.lower` expands macros WITHOUT executing anything, which is the distinction
# that makes this affordable: the file's body never runs, so a test file costs
# milliseconds instead of its own runtime.
@testset "test and script .jl files expand their macros" begin
    root = normpath(joinpath(@__DIR__, ".."))
    include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

    """`nothing` if the file lowers, else the error message.

    A parse failure is reported too — it is the same defect one stage earlier —
    but named separately so the two are not confused."""
    function lower_error(path)
        src = read(path, String)
        ex = try
            Meta.parseall(src)
        catch e
            return "parse: " * sprint(showerror, e)
        end
        r = Meta.lower(Main, ex)
        (r isa Expr && r.head === :error) ? "lower: " * string(r.args[1]) : nothing
    end

    files = String[]
    for d in ("test", "scripts", joinpath("docs", "guides", "figures"))
        isdir(joinpath(root, d)) || continue
        for (dir, _, fs) in walkdir(joinpath(root, d)), f in fs
            endswith(f, ".jl") && push!(files, joinpath(dir, f))
        end
    end

    # The probes carry the ACTUAL defect, not a stand-in: a concatenated `@printf`
    # format, against a literal one. A checker that only caught syntax errors would
    # pass the positive control and miss every instance of this.
    probe = mktempdir()
    bad = joinpath(probe, "bad.jl")
    good = joinpath(probe, "good.jl")
    write(bad, "using Printf\n@printf(\"a\" * \"%d\\n\", 1)\n")
    write(good, "using Printf\n@printf(\"a%d\\n\", 1)\n")

    broken = calibrated_scan(files;
        match=p -> lower_error(p) !== nothing,
        present=bad, absent=good,
        describe=p -> relpath(p, root))

    @test isempty(broken)
    for p in broken
        @info "does not expand" file = relpath(p, root) err = lower_error(p)
    end
    @test !isempty(files)
end

@testset "shell scripts under scripts/ parse" begin
    root = normpath(joinpath(@__DIR__, ".."))
    include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))
    shs = String[]
    for (dir, _, fs) in walkdir(joinpath(root, "scripts")), f in fs
        endswith(f, ".sh") && push!(shs, joinpath(dir, f))
    end
    parses(p) = success(pipeline(`bash -n $p`; stdout=devnull, stderr=devnull))

    probe = mktempdir()
    good = joinpath(probe, "good.sh")
    bad = joinpath(probe, "bad.sh")
    write(good, "echo ok\n")
    write(bad, "x=\${1:?it's broken}\n")

    bad_scripts = calibrated_scan(shs; match=p -> !parses(p), present=bad, absent=good,
        describe=p -> relpath(p, root))
    @test isempty(bad_scripts)
    isempty(bad_scripts) || @info "shell scripts that do not parse" bad_scripts
    @test !isempty(shs)
end
