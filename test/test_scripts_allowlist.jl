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
# `Meta.lower` expands macros in THIS module, so a macro the corpus uses has to be
# resolvable here or every file "lowers" by failing to see the macro at all — which
# silently disarms the gate below. `calibrated_scan` caught exactly that: its
# positive control stopped matching when Printf was absent from Main.
using Printf
# `git_corpus` — the corpus this gate judges must be the one CI judges. Included
# at top level, not inside the testset that needs it, because two later testsets
# in this file include the same helper and the first use must not depend on
# which of them ran.
include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _SCRIPTS_ALLOWLIST = Set([
    # ── entry points / hard test gates ──
    "cli.jl",                      # shim → SpinorBEC.cli_main
    "generate_state.jl",           # docs/STATE.md generator (test-gated)
    "prior_art.py",                # prior-art dispositions (test-gated)
    # The PR mistake census, re-derivable. The FROZEN document says re-measuring
    # is cheaper than re-reading; that was false while the mining lived in a
    # scratch directory, and this is what makes it true. `--verify-doc` checks
    # the committed document's own citations resolve.
    "pr_mistake_census.py",
    "reduce_result_backlog.jl",     # result.jld2 backlog sweep (calls the gated reducer)
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
    # The static-trap omega_eff array for the EdH quench. One arm per task on
    # purpose: a shard reaped at h_rt must not take completed neighbours with it.
    "submit_klaus_weff_scan.sh",
    "submit_lt64_endpoint_ensemble.sh",
    # #423 — eu151_klaus_phi_phys at production scale with the anti-aligned
    # preparation. One job, not an array: `run_yaml` has no point selection, so
    # the 8-point scan is indivisible from outside; it IS resumable, so a
    # walltime kill costs only the point it was inside.
    "submit_edh_phi_phys_anti_aligned.sh",
    # #376 — one runs/saito_li_torus/cells/*.yaml resolution cell. On TSUBAME
    # rather than the local card: 128³ x D=13 keeps 8.12 GiB of L-BFGS history
    # at the default m, and dropping m for one point of a four-point convergence
    # line would make that point answer a different question.
    "submit_saito_torus_cell.sh",
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
    "eu334/submit_ed_probe.sh",
    "eu334/window.jl",
    "eu334/nucleation_bifurcation.jl",
    "eu334/nucleate.jl",
    "eu334/classify.jl",
    "eu334/ed_growth_probe.jl",
    "eu334/viz_eu334.py",
    # ── active campaign: branch spectrum / spinodal (docs/guides/eu_spinodal_spectrum.md, #339) ──
    # Reads #335's cells and shares its _preamble.sh — the two campaigns measure
    # the SAME states, one by continuation and one by the second variation.
    "eu_spectrum/_cells.jl",
    "eu_spectrum/branch_spectrum.jl",
    "eu_spectrum/submit_spectrum.sh",
    # #397 (which consumer owns the preconditioner default) + #399 (does λ_min
    # converge on the polarised branch) — same knob, same cells, one job.
    "eu_spectrum/precond_ab.jl",
    "eu_spectrum/submit_precond_ab.sh",
    # ── active campaign: Eu isotope q prediction (docs/guides/eu_isotope_q_prediction.md, #341) ──
    "eu_isotope_q/q_boundary.jl",
    "eu_isotope_q/magnon_gap.jl",
    # ── active campaign: field-noise shielding spec (docs/guides/eu_shielding_spec.md, #362) ──
    "eu_noise/noise_hold.jl",
    "eu_noise/shielding_spec.jl",
    "eu_noise/submit_noise.sh",
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
    # The number-constraint arc (2026-08-19). Each of these is a measurement whose
    # result is quoted in a commit message or in docs/guides/spgpe.md, kept so the
    # number can be re-measured rather than trusted:
    #   handoff_window          where the c-field can take over from the 0-D model
    #   eu_number_conserving    the closed-loop evaporation driver
    #   eu_equilibrium_N0       N_0 the constraint predicts along the ramp
    #   n0_estimator_check      the N_0 estimator against a known TF state, per component
    #   mu_constraint_continuity  the non-monotonicity that killed the level-sum form
    #   mu_lda_allocation       where 36 GB came from (answer: not here)
    #   energy_damping_dt_convergence / _clean_conservation  one-time vs per-step loss
    "kz/energy_damping_clean_conservation.jl",
    "kz/energy_damping_dt_convergence.jl",
    # Removes the ramp: fixed (mu, T, eps_cut) at the ramp's end values, to separate
    # "the field cannot condense here" from "the ramp does not leave time for it".
    # The DESIGN question the c-field slowdown cannot answer: a real slower ramp pays
    # more three-body loss, so it scans the 0-D model over a stretched time axis and
    # reads the peak equilibrium N_0 off the same LDA constraint.
    "kz/ramp_slowdown_design.jl",
    # Whether the 0-D model is still quasi-static at the ramps that scan recommends.
    "kz/ramp_quasistatic_validity.jl",
    "kz/fixed_point_condensation.jl",
    "kz/eu_cost.jl",
    "kz/eu_equilibrium_N0.jl",
    "kz/eu_number_conserving.jl",
    "kz/eu_prof.jl",
    "kz/handoff_window.jl",
    "kz/mu_constraint_continuity.jl",
    "kz/mu_lda_allocation.jl",
    "kz/n0_estimator_check.jl",
    "kz/submit_eu_nc.sh",
    "kz/submit_kz_mode.sh",
    "kz/submit_kz_torus.sh",
    "kz/submit_kz_torus_sharded.sh",
    "kz/sync_tsubame.sh",
    # ── active campaign: Eu shape / evaporation (TSUBAME) ──
    "eu_shape/deploy_tsubame.sh",
    "eu_shape/submit_finite_t.sh",
    "eu_shape/submit_spgpe_evap.sh",
    # ── Klaus 2022 type-C reproduction (#345), cited by its gate ──
    # The run driver carries the pre-registered ACCEPT thresholds and applies
    # them, so it is the criterion rather than a description of one; the
    # re-analyser re-derives the verdicts from the saved frames without a run
    # (which is how the θ→0 control's window was corrected without paying
    # another hour); the figure script emits what
    # `docs/validation/figures/klaus2022_*.png` are built from.
    "klaus2022_reproduce.jl",
    "klaus2022_reanalyse.jl",
    "klaus2022_figures.py",
    # The ensemble re-measurement at the paper's own analysis window
    # (700 ms - 1.1 s, Fig. 4c), one seed per job. A cluster submit wrapper —
    # category 3, same as the other `submit_*.sh` above.
    "klaus2022/submit_stripes.sh",
    # #407: the FFTW thread × grid RSS pathology (36.9 GB at 48³ against 1.15 GB
    # at 128³, same thread count). The workaround shipped with #405; this is the
    # mechanism, and it is a repo script rather than a one-off because the same
    # trap is waiting for every other campaign that sets a thread count.
    "klaus2022/fftw_thread_probe.jl",
    "klaus2022/submit_fftw_probe.sh",
    # #406: the magnetostricted-AR sensitivity table (1.16 against a published
    # 1.03). A table before a scan, per CLAUDE.md gate 2 — most cells are ~zero
    # and knowing WHICH is the result.
    "klaus2022/ar_sensitivity.jl",
    "klaus2022/submit_ar_sensitivity.sh",
    # ── validation probes still cited as live instruments ──
    # Generates the omega_eff scan configs. Exists because PR #403 landed two
    # documents and no configs, so its evidence read `absent` in the claim ledger
    # -- re-deriving it was a re-derivation, not a re-run.
    "validation/klaus_weff_scan_gen.jl",
    # Classification, deliberately separate from the trajectory jobs: a shard
    # reaped at h_rt never reads its own completed work.
    "validation/klaus_weff_extract.jl",
    "validation/matsui_dataset_to_csv.jl",
    "validation/rk4ip_gpu_cost_probe.jl",
    # #444 — radial cloud size across an omega_eff scan. The observable that
    # settled 10.4 nT: population readings disagreed with each other, the cloud
    # explained it, and the data was already in the cache.
    "validation/klaus_weff_cloud_size.jl",
    # #424 — applies the endpoint criterion that was fixed before the 20 arms
    # launched. The threshold is a constant in the file so it cannot be
    # re-fitted to whatever landed.
    "validation/lt64_endpoint_verdict.jl",
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
    # Ignore local-only clutter that git is told to ignore (e.g. mcp/.venv) —
    # and NOTHING else. This was `git ls-files scripts`, the index alone, which
    # also dropped every file the author had not `git add`-ed yet: the gate went
    # green on the very PRs it exists to judge, then CI went red (#422/#425).
    # `git_corpus` is the index PLUS unignored working-tree files; see its
    # docstring for why the failure lands on the green side.
    known = git_corpus(root, "scripts")
    on_disk = Set(f for f in on_disk if ("scripts/" * f) in known)

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
# two literals is an ordinary expression — and dies at MACRO EXPANSION with
# "First argument to `@printf` after `io` must be a format string". Hit twice on
# 2026-08-19, once in a driver and once in a test written to close a different
# hole, each time discovered by a scheduler after minutes of queue and JIT.
#
# The obvious gate — `Meta.lower` the whole file, which expands macros without
# executing anything — DOES NOT WORK, and the way that was found is the point.
# `Meta.parseall` returns a `:toplevel` block, and lowering a `:toplevel` does not
# recurse into its forms: each is lowered when it is evaluated. So the check
# returned "ok" for every file including the planted defect. `calibrated_scan`
# refused to report, naming the positive control, instead of printing a clean zero.
#
# So the gate reads the AST for the defect directly. That is narrower — it knows
# about `@printf`/`@sprintf` and nothing else — and the narrowness is stated rather
# than papered over: this catches the format-string class, not "macros expand".
@testset "@printf format strings are literals, not concatenations" begin
    root = normpath(joinpath(@__DIR__, ".."))
    include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

    _concat(x) = x isa Expr && x.head === :call && !isempty(x.args) && x.args[1] === :*

    """Every `@printf`/`@sprintf` in `ex` whose FORMAT SLOT is a concatenation.

    Only the format slot. Checking the first two argument positions blindly was the
    first version and it flagged `@printf("… %4.0f%% …\n", 100thr, …)` in
    `kz_toroidal_winding.jl` — `100thr` is juxtaposition multiplication, an
    ordinary VALUE argument, and perfectly fine. A gate that cries wolf on correct
    code gets switched off.

    So: args[3] is the format unless it is an IO, in which case args[4] is. A
    String literal in args[3] settles it without needing to know what an IO looks
    like."""
    function bad_formats(ex, out=String[])
        if ex isa Expr
            if ex.head === :macrocall && length(ex.args) >= 3 &&
                ex.args[1] in (Symbol("@printf"), Symbol("@sprintf"))
                # args[3] is the format UNLESS it is a bare symbol, which is the
                # `@printf(io, fmt, …)` form. A String literal there is the format;
                # so is a concatenation, which is exactly the defect — an earlier
                # rule that fell through to args[4] whenever args[3] was not a
                # String therefore skipped past the bad format and inspected a
                # value, and the positive control caught it.
                fmt = (ex.args[3] isa Symbol && length(ex.args) >= 4) ?
                      ex.args[4] : ex.args[3]
                _concat(fmt) && push!(out, string(ex.args[1], " at ", ex.args[2]))
            end
            for a in ex.args
                bad_formats(a, out)
            end
        end
        out
    end

    function offenders(path)
        src = read(path, String)
        ex = try
            Meta.parseall(src)
        catch e
            return ["parse: " * sprint(showerror, e)]
        end
        bad_formats(ex)
    end

    files = String[]
    for d in ("test", "scripts", joinpath("docs", "guides", "figures"))
        isdir(joinpath(root, d)) || continue
        for (dir, _, fs) in walkdir(joinpath(root, d)), f in fs
            endswith(f, ".jl") && push!(files, joinpath(dir, f))
        end
    end

    # The probes carry the ACTUAL defect and its innocent twin, in the two argument
    # shapes the extractor has to tell apart.
    probe = mktempdir()
    bad = joinpath(probe, "bad.jl")
    good = joinpath(probe, "good.jl")
    write(bad, "using Printf\n@printf(\"a\" * \"%d\\n\", 1)\n")
    # The negative control carries the three innocent shapes, including the one the
    # first version got wrong: a juxtaposition-multiplied VALUE argument.
    write(
        good,
        "using Printf\n@printf(\"a%d\\n\", 1)\n@printf(stderr, \"b%d\\n\", 2)\n" *
        "x = 3\n@printf(\"c%.0f%%\\n\", 100x)\n",
    )

    broken = calibrated_scan(files;
        match=p -> !isempty(offenders(p)),
        present=bad, absent=good,
        describe=p -> relpath(p, root))

    @test isempty(broken)
    for p in broken
        @info "concatenated @printf format" file = relpath(p, root) what = offenders(p)
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
