# Gate for cutover step 4: a module-level `Ref` is ambient state, and ambient
# state that a kernel reads is a computation the artifact id cannot see.
#
# `docs/design/research_spec_and_provenance_architecture.md` §6, step 4. The
# failure this closes is not untidiness. `artifact_id` hashes the declaration
# (`Model` + `Stage`) and the code bytes (`code_tree_hash`); a value that is
# neither — assigned into a `Ref` after load — moves the numbers and moves no
# id. Two different computations then share one address, and step 3's admission
# serves whichever ran first.
#
# THREE WAYS THIS GATE COULD BE VACUOUS, AND WHAT IS DONE ABOUT EACH.
#
# 1. WRONG PATTERN. The gate the step's own design named was
#    `grep -rn "const .* = Ref(" src/hamiltonian/ src/foundation/spinor_utils/`.
#    Run verbatim on the tree it was written for it returns 8 lines and MISSES
#    `DEALIAS_K_CUTOFF`, whose binding is `Ref{Union{Nothing,Float64}}(nothing)`
#    — i.e. it would have gone green with the first `Ref` step 4 names still in
#    place. `_REF_BINDING` below matches `Ref(`, `Ref{`, and `Base.RefValue`.
#
# 2. WRONG SCOPE. That same grep excludes `ext/`, where `_SM_EULER_WARP` and
#    `_DDI_EULER_WARP` live, and they are read on a launch path. The scan
#    therefore covers `src/` AND `ext/` — every directory `code_tree_hash`
#    digests (`CODE_TREE_DIRS`), asserted equal below rather than restated.
#
# 3. NOTHING TO FIND. A scanner that silently matches nothing passes forever.
#    `_scan_refs` is run against a synthetic file with a known binding in it
#    (positive control), and the pinned set below is checked for equality in
#    BOTH directions, so a pin that no longer corresponds to a real binding is
#    red too.
#
# NOT CIRCULAR. `ALLOWED` is a literal in this file. It is not read from `src/`,
# not derived from the scan, and not filtered by anything the scan produces, so
# the gate cannot agree with a tree that drifted. Every entry carries the reason
# it is allowed to be ambient; deleting an entry is how a `Ref` gets retired,
# and adding one is a decision someone has to write down here.

using Test
using SpinorBEC
using SpinorBEC: CODE_TREE_DIRS

const _REPO = normpath(joinpath(@__DIR__, "..", ".."))

# `const`/`global` NAME `=` Ref... — `Ref(`, `Ref{`, or `Base.RefValue`. Leading
# whitespace is tolerated (a `const` inside a `module` block is indented) even
# though a `const` inside a function is a syntax error, so over-matching here
# cannot hide a binding.
const _REF_BINDING = r"^[ \t]*(?:const|global)[ \t]+([A-Za-z_][A-Za-z0-9_!]*)[ \t]*(?:::[^=]+)?=[ \t]*(?:Base\.)?Ref(?:Value)?[({]"

"Every `(relpath, name)` module-level Ref binding under `dirs` of `root`."
function _scan_refs(root::AbstractString, dirs)
    found = Tuple{String, String}[]
    for d in dirs
        dir = joinpath(root, d)
        isdir(dir) || continue
        for (dirpath, _, files) in walkdir(dir; follow_symlinks=false)
            for f in files
                endswith(f, ".jl") || continue
                path = joinpath(dirpath, f)
                rel = relpath(path, root)
                for line in eachline(path)
                    m = match(_REF_BINDING, line)
                    m === nothing || push!(found, (rel, String(m.captures[1])))
                end
            end
        end
    end
    sort!(found)
end

# The pinned set. `(relpath, name) => reason`.
#
# `[STEP-4]` marks a binding cutover step 4 is retiring: it is read on a path
# that produces numbers, and it is ambient, so today it can change an answer
# without changing an id. Those lines are deleted one at a time as each Ref
# lands — in the id first, then the global — and this gate is what makes the
# deletion visible.
#
# Everything else is SESSION state: a cache, a registry, a callback slot or a
# restore snapshot. None of it is read by a kernel, and a run's numbers do not
# depend on its value.
const ALLOWED = Dict{Tuple{String, String}, String}(
    # --- [STEP-4] numerics, still ambient ---------------------------------
    ("src/hamiltonian/integrator/dealias.jl", "DEALIAS_2_3_ENABLED") => "[STEP-4] the Orszag projector; already IN the id via GridSpec.dealias_two_thirds \
                                                                (resolve_gs.jl:311), so what remains is deleting the global",
    ("src/hamiltonian/integrator/dealias.jl", "DEALIAS_K_CUTOFF") => "[STEP-4] physical-k form of the same projector; already IN the id via \
                                                             GridSpec.dealias_k_cut (resolve_gs.jl:337)",
    ("src/hamiltonian/integrator/split_step.jl", "MEANFIELD_MIDPOINT_ENABLED") => "[STEP-4] real-time only (measured exactly 0.0 under ITP: `!imaginary_time` \
                                                                          guards both half-potential sites). Belongs in the params of an `:evolve` Stage, and \
                                                                          no `:evolve` Stage exists yet — `run_step_dynamics.jl` declares none",
    ("src/hamiltonian/integrator/combined_spin_step.jl", "COMBINED_SPIN_STEP_ENABLED") => "[STEP-4] a different splitting of the same H, agreeing at O(dt^3). Same \
                                                                                  destination and same blocker as MEANFIELD_MIDPOINT_ENABLED; combined_spin_step.jl:42-46 \
                                                                                  already says so",
    ("src/hamiltonian/integrator/spin_chain.jl", "SPIN_CHAIN_FUSION_ENABLED") => "[STEP-4] measured bit-identical on both devices; it exists so \
                                                                         test/oracles/test_spin_chain_fusion_parity.jl can run BOTH statements on one input. \
                                                                         Freezing it would delete the gate — but the parity gate is CUDA-only, so on a \
                                                                         CPU-only CI nothing exercises it",
    ("src/foundation/spinor_utils/spin_rotation_taylor.jl", "SPIN_TAYLOR_ENABLED") => "[STEP-4] routes every spin rotation between Taylor-Horner and the exact Euler \
                                                                              5-stage, on BOTH devices and on the ITP path (measured 3.6e-13 over 20 ITP steps). Wants \
                                                                              a declared per-run field; the parity gates on both devices flip it, so it needs an \
                                                                              argument path first",
    ("src/foundation/spinor_utils/spin_rotation_taylor.jl", "SPIN_TAYLOR_TOL") => "[STEP-4, UNFROZEN BY #307] this branch froze it to a const on the stated grounds \
                                                                          that production R ~ 1e-5 floors the degree at 2 so the tolerance cannot be felt. \
                                                                          Measured on main: R_max = 1.3e-3…5.4e-2 for Eu F=6, degrees 5 through 9, and the \
                                                                          degree returns 2 only below R ~ 3e-8 — four orders under the weakest production \
                                                                          cell. The premise was three orders wrong, so it stays a Ref and stays a \
                                                                          registered accuracy knob. Gated by test_taylor_tolerance_binds.jl",
    ("src/foundation/spinor_utils/spin_rotation_taylor.jl", "SPIN_TAYLOR_RSAFE") => "[STEP-4, UNFROZEN BY #307] frozen here alongside SPIN_TAYLOR_TOL and restored \
                                                                            with it — the two are read by the same schedule and splitting them would leave \
                                                                            half the schedule declared and half ambient. The halving threshold is asserted \
                                                                            where it is DECIDED (the schedule) in \
                                                                            test_cpu_spin_rotation_taylor_parity.jl, because the amp sweep that claims to \
                                                                            cross it does not actually depend on it",
    ("src/foundation/spinor_utils/spin_rotation_taylor.jl", "SPIN_TAYLOR_DEGREE_CAP") => "[STEP-4] NOT a numerics choice: the positive control for \
                                                                                 test_taylor_tolerance_criterion.jl, whose NegligibleErrorSpec returns :indeterminate \
                                                                                 when the control cannot breach. Freezing it deletes the only control that works. Keep \
                                                                                 ambient, rename to say so, and guard at the pipeline boundary so a clamped cap cannot \
                                                                                 file an artifact under a production id",

    # --- session state: caches, registries, callback slots, snapshots -----
    ("src/workflow/experiments/inspect.jl", "CHECK_REGISTRY") => "the pre-flight check registry; populated at load, read by the inspector, never \
                                                         by a kernel",
    ("src/workflow/experiments/pipeline/run_registry.jl", "_cuda_reclaim_callback") => "weak-extension callback slot: the CUDA ext installs it at load",
    ("src/workflow/experiments/pipeline/run_registry.jl", "_cuda_functional_callback") => "weak-extension callback slot: answers whether CUDA is usable, for logging",
    ("src/workflow/experiments/pipeline/run_registry.jl", "_cuda_state_lines_callback") => "weak-extension callback slot: device state lines for the run banner",
    ("src/workflow/experiments/runtime/dealias_block.jl", "_DEALIAS_PENDING_SNAPSHOT") => "restore snapshot for the two dealias globals; goes away with them",
    ("src/workflow/autopilot/queue.jl", "_DEFAULT_QUEUE_ROOT") => "process-wide default queue location; scheduler state, no physics",
    ("src/workflow/autopilot/breakers.jl", "_DEFAULT_BREAKER_THRESHOLDS") => "circuit-breaker thresholds; scheduler policy, no physics",
    ("src/workflow/autopilot/monitor.jl", "_DIVERGENCE_THRESHOLDS") => "divergence-reap thresholds; decides whether a run is KILLED, not what it computes",
    ("src/workflow/monitoring/notifications.jl", "_SLACK_HTTP_HINT_SHOWN") => "print-once latch for a Slack hint",
    ("src/workflow/io/measurement_provenance.jl", "_SRC_FINGERPRINT") => "SHA-1 of src/ captured in __init__ so a measurement file records what the PROCESS is \
                                                                 running, not what is on disk when it writes. It cannot be a const: precompile time is \
                                                                 not load time, and the failure this closes is a sync landing mid-run — 16 shards once \
                                                                 stamped the post-sync commit while executing pre-sync code. Read only by \
                                                                 provenance_header, never by a kernel",
    ("src/workflow/io/measurement_provenance.jl", "_LOAD_ENV") => "julia version, thread count, hostname and whether the module came off a precompiled \
                                                         cache, captured alongside the fingerprint and for the same reason. cached= is the \
                                                         one field that makes a stale-cache run distinguishable, since a matching source \
                                                         fingerprint does not prove the executed code came from those sources",
)

@testset "no unpinned module-level Ref under src/ and ext/" begin
    @testset "the scanner finds a known binding (positive control)" begin
        mktempdir() do tmp
            mkpath(joinpath(tmp, "src", "deep"))
            write(
                joinpath(tmp, "src", "deep", "probe.jl"),
                """
# a comment mentioning Ref( that must not match
const PLAIN = Ref(true)
const PARAMETRIC = Ref{Union{Nothing, Float64}}(nothing)
const REFVALUE = Base.RefValue{Int}(3)
const NOT_A_REF = Dict{Int, Int}()
f() = Ref(0)
""",
            )
            got = _scan_refs(tmp, ("src",))
            @test got == [("src/deep/probe.jl", "PARAMETRIC"),
                ("src/deep/probe.jl", "PLAIN"),
                ("src/deep/probe.jl", "REFVALUE")]
        end
    end

    # The scan covers exactly what the id's code digest covers. Restated as an
    # assertion instead of a second literal, so the two cannot drift.
    @test Set(CODE_TREE_DIRS) == Set(("src", "ext"))

    found = _scan_refs(_REPO, CODE_TREE_DIRS)

    @testset "the scan is not empty" begin
        @test !isempty(found)
    end

    @testset "no binding outside the pinned set" begin
        unpinned = [x for x in found if !haskey(ALLOWED, x)]
        if !isempty(unpinned)
            for (rel, name) in unpinned
                @info "unpinned module-level Ref" file = rel name = name
            end
        end
        @test unpinned == Tuple{String, String}[]
    end

    @testset "no pin without a binding" begin
        # A stale pin is the other half of the gate: it would let a Ref be
        # deleted and re-added elsewhere without anyone writing down why.
        stale = sort!([k for k in keys(ALLOWED) if !(k in found)])
        @test stale == Tuple{String, String}[]
    end

    @testset "every pin says why" begin
        for (k, reason) in ALLOWED
            @test length(reason) > 30
        end
    end
end
