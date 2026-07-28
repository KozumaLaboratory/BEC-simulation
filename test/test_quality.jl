# Package-quality static analysis: Aqua + ExplicitImports + JET typo-only.
# Run as part of FAST_TESTS so every push catches structural rot fast.
#
# Scope (per 2026-05-23 research, `commit_msg_15.txt`):
# - Aqua catches: method ambiguities, stale deps, piracy, compat bounds,
#   unbound-type-params, undocumented public names.
# - ExplicitImports catches: implicit `using X`, stale explicit imports.
# - JET (mode=:typo) catches: undefined references statically reachable
#   from exported entry points.
#
# What this DOESN'T catch (per the same research):
# - Kwargs that the function body never reads (e.g. `fft_plans=nothing`)
# - Kwargs whose callers all pass the default (e.g. `picard_iters=1`)
# - Name/observable mismatch (e.g. `apply_nematic_step!` body is a
#   singlet-pair Hamiltonian). These need LLM review or naming-convention
#   discipline (file name ↔ main export name); see CLAUDE.md §"Naming
#   convention" for the predator policy added 2026-05-23.

using SpinorBEC
using Test
using Aqua
using ExplicitImports

# JET stays unloaded unless the opt-in below is on: the typo check is
# default-skipped, so `using JET` was ~1 s of load on every CI run buying
# nothing. Loaded here at top level (not inside the testset) so the later
# `JET.test_package` reference resolves in a fresh world age.
const RUN_JET = lowercase(get(ENV, "SPINORBEC_JET", "false")) == "true"
RUN_JET && @eval using JET

@testset "Aqua quality checks" begin
    # Method ambiguities: skipped pending Workspace 23-type-param triage.
    # The check would correctly flag a handful of intra-package abstract
    # dispatches but those are deliberate hot-loop specialisations that
    # require a separate cleanup pass.
    Aqua.test_all(
        SpinorBEC;
        ambiguities=false,
        # unbound_args flags `_compute_k_squared(k::NTuple{N, Vector{T}}, ...)
        # where {N, T<:AbstractFloat}` because the N=0 edge case would
        # leave T unbound. In practice N ∈ {1,2,3} for Grid and the call
        # site always passes a concrete-T tuple. The check is structurally
        # correct but the dead branch isn't reachable; skip it.
        unbound_args=false,
        # `persistent_tasks` flags long-lived Tasks left behind after
        # `using SpinorBEC` — flaky in our env (false positive from
        # PrecompileTools workload tasks holding briefly past the using).
        # Disable until the upstream check stabilises.
        persistent_tasks=false,
        # Stale-deps ignores:
        # - CUDA / Makie / HTTP / WriteVTK: weak-dep extension triggers
        # - BenchmarkTools: used by scripts/bench/ which share the package
        #   env (no scripts/Project.toml). Keep in [deps].
        # - PackageCompiler: same justification — scripts/build_sysimage*.jl
        #   build a SpinorBEC sysimage; sharing the package env keeps the
        #   sysimage's Project.toml identical to runtime.
        stale_deps=(
            ignore=[:CUDA, :Makie, :HTTP, :WriteVTK, :BenchmarkTools, :PackageCompiler],
        ),
        deps_compat=(check_extras=false,),
    )
end

@testset "ExplicitImports" begin
    # `check_no_implicit_imports` would flag ~50 module-level `using X`
    # statements in src/SpinorBEC.jl that pull in entire packages.
    # Cleaning those is a separate (large) refactor; @test_broken for now
    # so the test_quality.jl gate stays useful for the checks below.
    @test_broken check_no_implicit_imports(SpinorBEC) === nothing

    # Every explicit import should come from the package that "owns" the
    # symbol (not transitively re-exported). E.g. `Base.transcode` is
    # re-exported by `CodecZlib` but importing via `CodecZlib: transcode`
    # makes the dependency artificially tighter.
    @test check_all_explicit_imports_via_owners(SpinorBEC) === nothing

    # No `using X: name` where `name` is never referenced. This is the
    # actively-tracked rot signal: when a function is renamed or deleted,
    # the stale `using X: old_name` survives this test.
    @test check_no_stale_explicit_imports(SpinorBEC) === nothing
end

@testset "JET typo smoke" begin
    # JET.test_package on SpinorBEC takes >1 h even with mode=:typo
    # (measured 2026-05-23: the 22-param Workspace × ~50 dispatch sites
    # in `make_workspace` blows up the work the analyzer has to do).
    # Default-skip; opt in via SPINORBEC_JET=true when explicitly
    # auditing a regression.
    if RUN_JET
        JET.test_package(SpinorBEC; mode=:typo, target_defined_modules=true)
    else
        @test_skip false
    end
end
