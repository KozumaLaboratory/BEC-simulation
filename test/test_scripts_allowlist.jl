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
