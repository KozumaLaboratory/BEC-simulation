#!/usr/bin/env julia

# Validation ladder for the Eu151 EdH/K3 program.
#
# Usage:
#   julia --project=. scripts/validation/edh_validation_ladder.jl plan
#   julia --project=. scripts/validation/edh_validation_ladder.jl dry-run --level 0
#   julia --project=. scripts/validation/edh_validation_ladder.jl audit-overrides
#   julia --project=. scripts/validation/edh_validation_ladder.jl run --level 1
#   julia --project=. scripts/validation/edh_validation_ladder.jl run --level 8 --include-heavy
#
# The script deliberately puts K3 branches late. Hamiltonian-only and DDI
# convention checks should pass before interpreting any loss-arrest result.

using Dates
using JSON
using Printf
using SpinorBEC

const OUT_DIR = "runs/validation_ladder"
const DRY_DIR = joinpath(OUT_DIR, "dry_run")
const REPORT_DIR = joinpath(OUT_DIR, "reports")

const RUNG_SPECS = [
    # Level 0: parser/unit sanity for production-like configs. Dry-run only.
    (level=0, id="dry_eu151_edh", path="runs/eu151_edh/config.yaml",
        group="parser/unit sanity", run=false, heavy=false),
    (level=0, id="dry_eu151_edh_c1phys", path="runs/eu151_edh_c1phys/config.yaml",
        group="parser/unit sanity", run=false, heavy=false),
    (level=0, id="dry_matsui_baseline",
        path="runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml",
        group="parser/unit sanity", run=false, heavy=false),
    (level=0, id="dry_k3_compare", path="runs/eu151_edh_k3_compare/config.yaml",
        group="parser/unit sanity", run=false, heavy=false),
    (level=0, id="dry_loss_factorial", path="runs/eu151_edh_loss_factorial/config.yaml",
        group="parser/unit sanity", run=false, heavy=false),
    (level=0, id="dry_k3_long", path="runs/eu151_edh_K3_long/config.yaml",
        group="parser/unit sanity", run=false, heavy=false),

    # Level 1: minimal Hamiltonian sanity.
    (level=1, id="00_scalar_free_uniform",
        path="runs/verification_suite/yamls/00_scalar_free_uniform_stationary.yaml",
        group="minimal physics", run=true, heavy=false),
    (level=1, id="01_scalar_harmonic_ground",
        path="runs/verification_suite/yamls/01_scalar_harmonic_oscillator_ground.yaml",
        group="minimal physics", run=true, heavy=false),
    (level=1, id="05_spin1_zeeman_phase_only",
        path="runs/verification_suite/yamls/05_spin1_zeeman_phase_only.yaml",
        group="minimal physics", run=true, heavy=false),
    (level=1, id="02_spin1_polar_contact",
        path="runs/verification_suite/yamls/02_spin1_polar_contact_ground.yaml",
        group="minimal physics", run=true, heavy=false),
    (level=1, id="03_spin1_ferromagnetic_contact",
        path="runs/verification_suite/yamls/03_spin1_ferromagnetic_contact_ground.yaml",
        group="minimal physics", run=true, heavy=false),
    (level=1, id="06_spin1_sma_spin_mixing",
        path="runs/verification_suite/yamls/06_spin1_sma_spin_mixing.yaml",
        group="minimal physics", run=true, heavy=false),

    # Level 2: DDI kernel/convention checks.
    (level=2, id="08_ddi_spherical_zero_kernel",
        path="runs/verification_suite/yamls/08_ddi_spherical_polarized_zero_kernel.yaml",
        group="DDI kernel", run=true, heavy=false),
    (level=2, id="L2_ddi_axis_flip_Bx",
        path="runs/verification_suite/yamls/L2_ddi_axis_flip_Bx.yaml",
        group="DDI kernel", run=true, heavy=false),
    (level=2, id="L2_ddi_prolate_trap",
        path="runs/verification_suite/yamls/L2_ddi_prolate_trap.yaml",
        group="DDI kernel", run=true, heavy=false),
    (level=2, id="L2_ddi_oblate_trap",
        path="runs/verification_suite/yamls/L2_ddi_oblate_trap.yaml",
        group="DDI kernel", run=true, heavy=false),

    # Level 3: Cr/F=3 EdH toy, no loss.
    (level=3, id="L3_cr_f3_edh_toy_ddi_on",
        path="runs/verification_suite/yamls/L3_cr_f3_edh_toy_ddi_on.yaml",
        group="canonical EdH toy", run=true, heavy=false),
    (level=3, id="L3_cr_f3_edh_toy_ddi_off",
        path="runs/verification_suite/yamls/L3_cr_f3_edh_toy_ddi_off.yaml",
        group="canonical EdH toy", run=true, heavy=false),

    # Level 4/6: Eu Hamiltonian-only and early convergence checks.
    (level=4, id="L4_eu_matsui_hamiltonian_only_32",
        path="runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_32.yaml",
        group="Eu Hamiltonian-only", run=true, heavy=false),
    (level=4, id="L4_eu_matsui_hamiltonian_only_ddi_off_32",
        path="runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_ddi_off_32.yaml",
        group="Eu Hamiltonian-only", run=true, heavy=false),

    # Level 5: operator-level RHS comparison against Kawaguchi-Ueda Phys
    # Reports 2012 textbook expressions (PDF in docs/refs/, notes in
    # docs/theory/). Script-bound (not YAML) — pure analytical sanity
    # check of the per-term Hamiltonian action on a known test ψ.
    (level=5, id="L5_operator_rhs_compare",
        script="scripts/validation/L5_operator_rhs_compare.jl",
        path="(script-bound; see `script` field)",
        group="operator-RHS compare vs Kawaguchi-Ueda 2012",
        run=true, heavy=false),
    (level=6, id="L4_eu_matsui_hamiltonian_only_48",
        path="runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_48.yaml",
        group="Eu grid convergence", run=true, heavy=false),
    (level=6, id="L4_eu_matsui_hamiltonian_only_64",
        path="runs/verification_suite/yamls/L4_eu_matsui_hamiltonian_only_64.yaml",
        group="Eu grid convergence", run=true, heavy=false),

    # Level 7: loss-only tests before K3 in EdH.
    (level=7, id="L7_loss_only_uniform_K3",
        path="runs/verification_suite/yamls/L7_loss_only_uniform_K3.yaml",
        group="loss-only", run=true, heavy=false),
    (level=7, id="L7clean_loss_only_uniform_K3",
        path="runs/verification_suite/yamls/L7clean_loss_only_uniform_K3.yaml",
        group="loss-only", run=true, heavy=false),

    # Levels 8-10: expensive K3 interpretation branches.
    (level=8, id="eu151_edh_k3_compare", path="runs/eu151_edh_k3_compare/config.yaml",
        group="K3 A/B", run=true, heavy=true),
    (level=9, id="eu151_edh_loss_factorial",
        path="runs/eu151_edh_loss_factorial/config.yaml",
        group="K3 x gamma_dr factorial", run=true, heavy=true),
    (level=10, id="eu151_edh_K3_long", path="runs/eu151_edh_K3_long/config.yaml",
        group="long production", run=true, heavy=true),
]

function usage()
    println("""
    usage: julia --project=. scripts/validation/edh_validation_ladder.jl <command> [options]

    commands:
      plan              print ordered ladder
      dry-run           run run_yaml(...; dry_run=true) and save expanded YAML/logs
      audit-overrides   verify scan comparison override paths hit the intended branch fields
      run               execute selected YAMLs; heavy K3 runs require --include-heavy

    options:
      --level N         select one level; may be repeated
      --id ID           select one rung id; may be repeated
      --include-heavy   allow levels 8-10 to execute under `run`
    """)
end

function parse_cli(args)
    cmd = isempty(args) ? "plan" : args[1]
    levels = Set{Int}()
    ids = Set{String}()
    include_heavy = false
    i = 2
    while i <= length(args)
        a = args[i]
        if a == "--level"
            i == length(args) && error("--level requires an integer")
            push!(levels, parse(Int, args[i + 1]))
            i += 2
        elseif a == "--id"
            i == length(args) && error("--id requires a rung id")
            push!(ids, args[i + 1])
            i += 2
        elseif a == "--include-heavy"
            include_heavy = true
            i += 1
        elseif a in ("-h", "--help")
            usage()
            exit(0)
        else
            error("unknown option: $a")
        end
    end
    return (; cmd, levels, ids, include_heavy)
end

function selected_specs(levels::Set{Int}, ids::Set{String})
    specs = collect(RUNG_SPECS)
    isempty(levels) || (specs = filter(s -> s.level in levels, specs))
    isempty(ids) || (specs = filter(s -> s.id in ids, specs))
    specs
end

# Rung tuples that carry `blocked=true` are external-dependency-blocked.
# Tuples that carry `script=<path>` invoke that Julia script instead of
# `run_yaml(s.path)`; used for analytical/operator-level checks like L5.
# `hasproperty` keeps the older entries — which omit these fields entirely —
# usable without retrofitting them.
_is_blocked(s) = hasproperty(s, :blocked) && s.blocked === true
_blocked_reason(s) = hasproperty(s, :blocked_reason) ? s.blocked_reason : "(no reason recorded)"
_rung_script(s) = hasproperty(s, :script) ? s.script : nothing

function status_dict(status; kwargs...)
    d = Dict{String, Any}("status" => status)
    for (k, v) in kwargs
        d[string(k)] = v
    end
    d
end

function print_plan(specs)
    println("EdH validation ladder")
    println("K3 is intentionally late; do not interpret levels 8-10 before 1-7 pass.")
    last_level = nothing
    for s in specs
        if s.level != last_level
            println()
            println("Level $(s.level): $(s.group)")
            last_level = s.level
        end
        flag = s.run ? "" : " [dry-run only]"
        heavy = s.heavy ? " [heavy]" : ""
        blocked = _is_blocked(s) ? " [BLOCKED: $(_blocked_reason(s))]" : ""
        script = _rung_script(s)
        if script !== nothing
            tag = isfile(script) ? "" : " [missing script]"
            println("  $(s.id): script=$script$flag$heavy$blocked$tag")
        else
            exists = isfile(s.path) ? "" : " [missing]"
            println("  $(s.id): $(s.path)$flag$heavy$blocked$exists")
        end
    end
end

function run_dry_runs(specs)
    mkpath(DRY_DIR)
    results = Dict{String, Any}()
    for s in specs
        out_path = joinpath(DRY_DIR, s.id * ".yaml")
        print("[dry-run] $(s.id) ... ")
        if _is_blocked(s)
            println("BLOCKED: $(_blocked_reason(s))")
            results[s.id] = status_dict("BLOCKED"; reason=_blocked_reason(s), path=s.path)
            continue
        end
        if _rung_script(s) !== nothing
            println("SKIP script-bound rung (dry-run is YAML-only)")
            results[s.id] = status_dict("SKIP"; reason="script-bound", path=s.path)
            continue
        end
        if !isfile(s.path)
            println("missing")
            results[s.id] = status_dict("MISSING"; path=s.path)
            continue
        end
        t0 = time()
        try
            open(out_path, "w") do io
                redirect_stdout(io) do
                    run_yaml(s.path; dry_run=true)
                end
            end
            dt = round(time() - t0; digits=2)
            println("OK -> $out_path ($(dt)s)")
            results[s.id] = status_dict("OK"; path=s.path, output=out_path, elapsed_sec=dt)
        catch err
            dt = round(time() - t0; digits=2)
            msg = sprint(showerror, err)
            println("FAIL ($(dt)s): $msg")
            results[s.id] = status_dict("FAIL"; path=s.path, error=msg, elapsed_sec=dt)
        end
    end
    write_report("dry_run_report.json", results)
    return any(v -> v isa Dict && v["status"] == "FAIL", values(results)) ? 1 : 0
end

function _load_prepared_yaml(path::String)
    redirect_stdout(devnull) do
        Base.invokelatest(SpinorBEC._run_yaml_prepare, path, false, false)
    end
end

function _step_kind(data::Dict, idx0::Int)
    pipe = get(data, "pipeline", Any[])
    pipe isa AbstractVector || return nothing
    idx = idx0 + 1
    1 <= idx <= length(pipe) || return nothing
    step = pipe[idx]
    step isa AbstractDict && length(step) == 1 || return nothing
    string(first(keys(step)))
end

function _path_contains_step_kind(data::Dict, path::String)
    parts = split(path, '.')
    length(parts) >= 4 || return false
    parts[1] == "pipeline" || return false
    idx0 = tryparse(Int, parts[2])
    idx0 === nothing && return false
    kind = _step_kind(data, idx0)
    kind !== nothing && parts[3] == kind
end

function _nested_step_kind_problems(patched::Dict)
    problems = String[]
    pipe = get(patched, "pipeline", Any[])
    pipe isa AbstractVector || return problems
    for (i, step) in enumerate(pipe)
        step isa AbstractDict && length(step) == 1 || continue
        kind = string(first(keys(step)))
        params = first(values(step))
        if params isa AbstractDict && haskey(params, kind)
            push!(problems, "nested key pipeline.$(i - 1).$kind.$kind")
        end
    end
    problems
end

function audit_overrides(specs)
    mkpath(REPORT_DIR)
    results = Dict{String, Any}()
    had_failure = false

    for s in specs
        if _is_blocked(s)
            results[s.id] = status_dict("BLOCKED"; reason=_blocked_reason(s), path=s.path)
            continue
        end
        isfile(s.path) || begin
            results[s.id] = status_dict("MISSING"; path=s.path)
            had_failure = true
            continue
        end
        data = _load_prepared_yaml(s.path)
        scan = get(data, "scan", nothing)
        runs = scan isa AbstractDict ? get(scan, "comparison_runs", nothing) : nothing
        if !(runs isa AbstractVector) || isempty(runs)
            results[s.id] = status_dict("NO_SCAN"; path=s.path)
            continue
        end

        entries = Any[]
        for r in runs
            name = string(get(r, "name", "<unnamed>"))
            override = SpinorBEC.parse_override_map(get(r, "override", Dict()))
            patched = SpinorBEC.apply_overrides(data, override)
            warnings = String[]
            for path in keys(override)
                if _path_contains_step_kind(data, path)
                    push!(warnings,
                        "override path '$path' includes the step kind after pipeline index; use auto-unwrapped path",
                    )
                end
            end
            append!(warnings, _nested_step_kind_problems(patched))
            isempty(warnings) || (had_failure = true)
            loss = SpinorBEC._get_unwrapped_path(patched, "pipeline.2.loss")
            push!(
                entries,
                Dict(
                    "name" => name,
                    "override_keys" => sort(collect(keys(override))),
                    "warnings" => warnings,
                    "effective_pipeline_2_loss" => loss === nothing ? nothing : sprint(show, loss),
                ),
            )
        end
        status = any(e -> !isempty(e["warnings"]), entries) ? "WARN" : "OK"
        results[s.id] = status_dict(status; path=s.path, comparison_runs=entries)
    end

    report_path = write_report("override_audit.json", results)
    println("Wrote $report_path")
    return had_failure ? 1 : 0
end

function run_selected(specs; include_heavy::Bool=false)
    mkpath(REPORT_DIR)
    results = Dict{String, Any}()
    for s in specs
        print("[run] $(s.id) ... ")
        if _is_blocked(s)
            println("BLOCKED: $(_blocked_reason(s))")
            results[s.id] = status_dict("BLOCKED"; reason=_blocked_reason(s), path=s.path)
            continue
        end
        if !s.run
            println("SKIP dry-run-only rung")
            results[s.id] = status_dict("SKIP"; reason="dry-run-only", path=s.path)
            continue
        end
        if s.heavy && !include_heavy
            println("SKIP heavy; pass --include-heavy")
            results[s.id] = status_dict(
                "SKIP"; reason="heavy requires --include-heavy", path=s.path
            )
            continue
        end
        script = _rung_script(s)
        if script !== nothing
            results[s.id] = _run_script_rung(s, script)
            continue
        end
        if !isfile(s.path)
            println("MISSING")
            results[s.id] = status_dict("MISSING"; path=s.path)
            continue
        end
        t0 = time()
        try
            run_dir = run_yaml(s.path)
            dt = round(time() - t0; digits=2)
            println("OK -> $run_dir ($(dt)s)")
            results[s.id] = status_dict("OK"; path=s.path, run_dir=run_dir, elapsed_sec=dt)
        catch err
            dt = round(time() - t0; digits=2)
            msg = sprint(showerror, err)
            println("FAIL ($(dt)s): $msg")
            results[s.id] = status_dict("FAIL"; path=s.path, error=msg, elapsed_sec=dt)
        end
    end
    write_report("run_report.json", results)
    return any(v -> v isa Dict && v["status"] == "FAIL", values(results)) ? 1 : 0
end

# Script-bound rung dispatcher: runs `julia --project=. <script>` in a
# subprocess, captures stdout/stderr, judges PASS/FAIL by exit code.
# The subprocess gets its own JIT warmup but that is unavoidable for an
# analytical / operator-level check that does NOT match the run_yaml shape.
function _run_script_rung(s, script::String)
    if !isfile(script)
        println("MISSING SCRIPT: $script")
        return status_dict("MISSING"; path=script)
    end
    t0 = time()
    log_path = joinpath(REPORT_DIR, "$(s.id).log")
    mkpath(REPORT_DIR)
    cmd = `julia --project=. $script`
    ok = open(log_path, "w") do io
        success(pipeline(cmd; stdout=io, stderr=io))
    end
    dt = round(time() - t0; digits=2)
    if ok
        println("OK -> $log_path ($(dt)s)")
        return status_dict("OK"; script=script, log=log_path, elapsed_sec=dt)
    else
        println("FAIL ($(dt)s); see $log_path")
        return status_dict("FAIL"; script=script, log=log_path, elapsed_sec=dt)
    end
end

function write_report(name::String, results)
    mkpath(REPORT_DIR)
    path = joinpath(REPORT_DIR, name)
    payload = Dict{String, Any}(
        "created_at" => string(now()),
        "results" => results,
    )
    open(path, "w") do io
        JSON.print(io, payload, 2)
        println(io)
    end
    path
end

function main(args)
    opts = parse_cli(args)
    specs = selected_specs(opts.levels, opts.ids)
    if isempty(specs)
        available_levels = sort(unique(s.level for s in RUNG_SPECS))
        msg =
            "no ladder rungs selected. Filters: levels=$(sort(collect(opts.levels))), " *
            "ids=$(sort(collect(opts.ids))). Available levels in RUNG_SPECS: " *
            "$available_levels."
        if !isempty(opts.levels)
            missing_lvls = sort(collect(setdiff(opts.levels, Set(available_levels))))
            isempty(missing_lvls) || (msg *= " Requested level(s) $missing_lvls are not defined.")
        end
        error(msg)
    end

    if opts.cmd == "plan"
        print_plan(specs)
        return 0
    elseif opts.cmd == "dry-run"
        return run_dry_runs(specs)
    elseif opts.cmd == "audit-overrides"
        return audit_overrides(specs)
    elseif opts.cmd == "run"
        return run_selected(specs; include_heavy=opts.include_heavy)
    else
        usage()
        error("unknown command: $(opts.cmd)")
    end
end

exit(main(ARGS))
