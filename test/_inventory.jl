# test/_inventory.jl — what does each test file actually ground?
#
# A simulator with no experiment to check it against can only be grounded four
# ways (Roache's verification hierarchy, plus differential testing):
#
#   :exact         compared against a closed form computed IN the test
#   :order         error scaling under refinement matches the theoretical rate
#   :invariant     a conserved / algebraic property holds (norm, hermiticity, …)
#   :metamorphic   an observable transforms correctly under a symmetry
#   :differential  two independent statements of the same physics agree
#
# Everything else is NOT validation:
#
#   :pin           a number a past run happened to produce
#   :api           a spelling — key names, types, throws
#
# Pins and API tests are useful (they detect change, and change is often a bug)
# but they cannot carry a physics claim, and they are the tests that go red on
# every legitimate refactor. This script measures the split so the suite can be
# pruned on evidence rather than on taste.
#
# Run: julia test/_inventory.jl [--csv out.csv] [--files]
# No SpinorBEC load — pure source scan, ~1 s.

const _INV_DIR = @__DIR__
# `_tiers.jl` may already be loaded (the mutation harness loads both); its
# consts cannot be redefined.
isdefined(@__MODULE__, :FAST_TESTS) || include(joinpath(_INV_DIR, "_tiers.jl"))

# ── Grounding markers ──────────────────────────────────────────────
# Ordered strongest-first only for the "primary" label; a file keeps every
# label it matches. Patterns are deliberately generous: this is an inventory,
# not a gate. Over-crediting a file is the safe direction — it lands in the
# "grounded" bucket and gets read by a human, rather than being silently
# proposed for deletion.

const _MARKERS = [
    :order => [
        r"convergence"i, r"\border\b.{0,40}(≈|==|isapprox|@test)"i,
        r"refine"i, r"\bslope\b"i, r"log\(.{0,30}err"i,
        r"for\s+dt\s+in", r"for\s+n(_steps|steps|_pts)\s+in", r"halv(e|ing)"i,
        r"richardson"i, r"\bp_obs\b", r"observed_order"i,
    ],
    :differential => [
        r"reference_\w+", r"dumb_\w+", r"\blegacy\b"i, r"parity"i,
        # "bit-identity" is not "bit-identical", and the file whose whole title
        # is "HamTerm ↔ independent statement bit-identity" was landing in :pin.
        r"bit[-_ ]?identit"i, r"↔",
        r"registry.{0,40}(≈|isapprox)"i, r"cpu.{0,30}gpu"i, r"gpu.{0,30}cpu"i,
        r"bit[-_ ]?identical"i, r"cross[-_ ]?check"i, r"\btwin\b"i,
        r"independent(ly)?\s+(computed|stated|implement)"i,
    ],
    :metamorphic => [
        # A round-trip is f⁻¹(f(x)) == x — the canonical metamorphic relation.
        # It was ONLY in _API_MARKERS, so the two SI round-trips (physical
        # quantities through unit conversion and back) read as spelling tests.
        r"round[-_ ]?trip"i,
        r"covarian"i, r"invarian"i, r"symmetr"i, r"\bparity\b"i,
        r"translat"i, r"rotat\w*.{0,40}(≈|isapprox)"i, r"mirror"i,
        r"global[_ ]phase"i, r"time[-_ ]revers"i, r"gauge"i, r"chiral"i,
    ],
    :invariant => [
        # Algebraic contracts stated as maths rather than as the word
        # "conservation": Σ parts == total, and the accumulate contract.
        r"total.{0,30}(≈|==).{0,10}(Σ|sum|parts)"i, r"Σ\s*parts"i,
        r"accumulat"i,
        r"conserv"i, r"\bdrift\b"i, r"hermitic"i, r"unitar"i,
        r"norm\w*\s*.{0,20}(≈|isapprox)\s*1", r"sum[_ ]rule"i,
        r"positive[-_ ]?(semi)?definite"i, r"virial"i, r"trace"i,
        r"continuity"i, r"completeness"i, r"orthonormal"i,
    ],
    :exact => [
        # The claim written as the identity itself. These files state
        # `E = Re⟨ψ|Hψ⟩·dV`, `E = −Ω·⟨L_z⟩`, `= ψ†·F_α·ψ`, `v = k` — none of
        # which contains the word "analytic", so all of them were :pin.
        r"⟨ψ\s*\|", r"ψ†", r"Re⟨", r"⟨L_z⟩", r"⟨F", r"·dV\b",
        r"analytic"i, r"\bexact\b"i, r"closed[-_ ]form"i, r"theoretical"i,
        r"gauss[-_ ]hermite"i, r"manufactured"i, r"\bclosed form\b"i,
        r"known\s+(solution|answer|value)"i, r"first[-_ ]principles"i,
    ],
]

# Gates whose subject is the SUITE, not the physics: coverage meta-tests, static
# source scans, doc-citation ratchets. They ground nothing about the simulator
# and are not meant to — but they are not pins or spellings either, and calling
# them :pin marks them for pruning. Checked BEFORE :pin/:api, after the five
# grounding labels.
const _META_MARKERS = [
    r"meta[-_ ]?test"i, r"\bcoverage\b"i, r"every\s+\w+\s+is\s+(gated|in|listed)"i,
    r"no\s+bare\s+`?\w+`?\s+broadcast"i, r"source[-_ ]scan"i,
    r"cite\s+runs/"i, r"do\s+not\s+shadow"i, r"orphan"i, r"allowlist"i,
]

const _API_MARKERS = [
    r"@test_throws", r"haskey\(", r"\bisa\s+[A-Z]", r"hasfield\(",
    r"\bkeys\(", r"schema"i, r"round[-_ ]?trip"i, r"@test_nowarn",
]

# A numeric literal on the right of a comparison with no refinement anywhere:
# `@test x ≈ 0.4271`, `@test err < 1e-3`. The tolerance is a fitted constant,
# not one derived from a discretisation.
const _PIN_MARKERS = [
    r"(≈|isapprox\()\s*-?\d+\.\d+", r"[<>]\s*\d+\.?\d*e-\d+", r"atol\s*=\s*\d"
]

# ── Layer ──────────────────────────────────────────────────────────
# The code is a stack: primitives → operators → stepping → solvers → workflow.
# A test's layer is the HIGHEST machinery it drives, because that is what sets
# both its cost and how far a failure is from its cause. A physics defect caught
# at L4 costs ~1000× more to run and arrives with no localisation; the same
# defect caught at L1 names the function.
#
# The rule this measures against: a layer's tests verify THAT LAYER'S contract.
# Higher layers test composition and wiring, never the physics again.
const _LAYERS = [
    :L4_workflow => [
        r"\brun_config\b", r"\brun_yaml\b", r"\brun_pipeline\b", r"\bExperiment\(",
        r"load_config", r"autopilot"i, r"\bsweep\(", r"\brun!\(",
    ],
    :L3_solver => [
        r"find_ground_state", r"run_simulation!", r"\bsimulate\b",
        r"bayesian_optimize", r"trace_phase_boundary", r"\bscan_1d\b", r"\bscan_2d\b",
        r"\bTWA\b", r"\bsgpe\b"i, r"continuation"i,
    ],
    :L2_stepping => [
        r"split_step", r"apply_\w*step!", r"yoshida"i, r"_aba_step!",
        r"strang"i, r"composer"i, r"dealias"i, r"spin_chain"i, r"propagat"i,
    ],
    # `make_workspace` is the L0/L1 boundary: a Workspace is 23+ type
    # parameters and the JIT cascade this codebase pays for. A test that builds
    # one is not a primitive test however pure its assertion looks.
    :L1_operator => [
        r"make_workspace", r"energy_contribution", r"apply_operator!",
        r"energy_decomposition", r"energy_gradient!", r"\bHamTerm\b",
        r"build_h_terms_registry", r"reference_\w+_(apply!|energy)",
        r"\bsign_oracle\b", r"total_energy", r"\bWorkspace\b",
    ],
]

struct FileInfo
    path::String
    tier::String
    loc::Int
    ntest::Int
    cost::Float64
    labels::Vector{Symbol}
    npin::Int
    napi::Int
    nmeta::Int
    layer::Symbol
end

_tier_of(f) =
    if f in FAST_TESTS
        "fast"
    elseif f in CI_EXTRA
        "ci"
    elseif f in FULL_EXTRA
        "full"
    elseif f in PHYSICS_TESTS
        "physics"
    elseif f in MANUAL_TESTS_ALLOWLIST
        "manual"
    else
        "UNLISTED"
    end

function _layer_of(src::String)
    for (name, pats) in _LAYERS
        any(p -> occursin(p, src), pats) && return name
    end
    return :L0_primitive
end

function _scan(root::String, rel::String)
    src = read(joinpath(root, rel), String)
    labels = Symbol[]
    for (name, pats) in _MARKERS
        any(p -> occursin(p, src), pats) && push!(labels, name)
    end
    FileInfo(
        rel, _tier_of(rel),
        count(==('\n'), src),
        count(r"@test[\s_]", src),
        _cost(rel),
        labels,
        sum(p -> count(p, src), _PIN_MARKERS; init=0),
        sum(p -> count(p, src), _API_MARKERS; init=0),
        sum(p -> count(p, src), _META_MARKERS; init=0),
        _layer_of(src),
    )
end

"""Primary label: strongest grounding present, else :pin if it asserts
numbers, else :api if it only asserts spellings, else :unclassified."""
function primary(fi::FileInfo)
    for (name, _) in _MARKERS
        name in fi.labels && return name
    end
    # :meta is checked AFTER the five grounding labels, not before. Meta-first
    # was tried and measured: it moves 18 files, and among them
    # `test_master_oracle.jl` (:differential — the dumb-vs-production gate),
    # `test_propagator_references.jl` (:order) and `test_term_fd_registry_
    # coverage.jl` (:order). Those ground physics AND carry a coverage clause;
    # calling them :meta understates them, which is the direction that turns a
    # file into a pruning candidate. Two coverage gates therefore keep an
    # over-credited grounding label, which is the safe direction this file
    # declares in its header.
    fi.nmeta > 0 && return :meta
    fi.npin > 0 && return :pin
    fi.napi > 0 && return :api
    return :unclassified
end

function inventory(root::String=_INV_DIR)
    files = String[]
    for (dir, _, fs) in walkdir(root), f in fs
        startswith(f, "test_") && endswith(f, ".jl") || continue
        push!(files, relpath(joinpath(dir, f), root))
    end
    sort!(files)
    [_scan(root, f) for f in files]
end

const _ORDER = [:order, :differential, :metamorphic, :invariant, :exact,
    :meta, :pin, :api, :unclassified]

_row(k, n, tot, cost) = println("  ", rpad(string(k), 16),
    lpad(string(n), 4), " files ", lpad("$(round(Int, 100n / tot))%", 5),
    lpad("$(round(Int, cost))s", 8))

function report(inv::Vector{FileInfo}; show_files::Bool=false)
    println("── SpinorBEC test inventory ", "─"^44)
    println("$(length(inv)) files, $(sum(f -> f.loc, inv)) lines, ",
        "$(sum(f -> f.ntest, inv)) assertions, ",
        "$(round(sum(f -> f.cost, inv); digits=0)) s modelled serial cost\n")

    println("Grounding (primary label — what the file can actually prove):")
    tot = length(inv)
    for k in _ORDER
        sel = filter(f -> primary(f) == k, inv)
        isempty(sel) && continue
        _row(k, length(sel), tot, sum(f -> f.cost, sel))
        show_files && for f in sel
            println("        ", rpad(f.path, 62), f.tier)
        end
    end

    grounded = count(f -> primary(f) in (:order, :differential, :metamorphic,
            :invariant, :exact), inv)
    println("\n  grounded: $grounded/$tot ($(round(100grounded/tot))%)   ",
        "ungrounded (pin/api/none): $(tot - grounded)")

    println("\nBy LAYER — the highest machinery each file drives:")
    println("  layer          files      cost   assertions   cost/assertion")
    for k in (:L0_primitive, :L1_operator, :L2_stepping, :L3_solver, :L4_workflow)
        sel = filter(f -> f.layer == k, inv)
        isempty(sel) && continue
        c = sum(f -> f.cost, sel)
        a = sum(f -> f.ntest, sel)
        println("  ", rpad(string(k), 15), lpad(length(sel), 4),
            lpad("$(round(Int, c))s", 9), lpad(a, 12),
            lpad(string(round(1000c / max(a, 1); digits=1), " ms"), 16))
    end

    println("\nBy directory (grounded / total):")
    dirs = unique(map(f -> (d=dirname(f.path); isempty(d) ? "." : d), inv))
    for d in sort(dirs)
        sel = filter(f -> (dd=dirname(f.path); (isempty(dd) ? "." : dd) == d), inv)
        g = count(f -> primary(f) in (:order, :differential, :metamorphic,
                :invariant, :exact), sel)
        println("  ", rpad(d, 22), lpad("$g/$(length(sel))", 8),
            lpad("$(round(Int, 100g/length(sel)))%", 6),
            lpad("$(round(Int, sum(f -> f.cost, sel)))s", 8))
    end

    unlisted = filter(f -> f.tier == "UNLISTED", inv)
    if !isempty(unlisted)
        println("\n✗ $(length(unlisted)) file(s) in NO tier:")
        foreach(f -> println("    ", f.path), unlisted)
    end
    return nothing
end

function write_csv(inv::Vector{FileInfo}, path::String)
    open(path, "w") do io
        println(io, "path,tier,loc,assertions,cost_s,primary,labels,pins,api,meta,layer")
        for f in inv
            println(
                io,
                join(
                    (f.path, f.tier, f.loc, f.ntest, f.cost,
                        primary(f), join(f.labels, ";"), f.npin, f.napi, f.nmeta, f.layer), ","),
            )
        end
    end
    println("\nwrote $path")
end

if abspath(PROGRAM_FILE) == @__FILE__
    inv = inventory()
    report(inv; show_files=("--files" in ARGS))
    i = findfirst(==("--csv"), ARGS)
    i !== nothing && write_csv(inv, ARGS[i + 1])
end
