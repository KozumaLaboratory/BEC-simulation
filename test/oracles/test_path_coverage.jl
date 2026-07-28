# Config-path coverage meta-test — coverage counted in (term × config),
# not per term.
#
# The set-equivalence meta-test in test_master_oracle.jl counts slots of
# H_TERMS_CANONICAL_ORDER = TERMS. But a term has internal PATH variants
# selected by config (DDI {secular, padded}, LHY kind, the real-time
# dissipative epilogue across drivers, …). Counting terms does not count
# paths — which is exactly how padded-DDI (App. A defect 9) and the
# absorbing-boundary omission each ran in production for ~1 month: each
# was a gate-less variant of an already-"covered" term.
#
# Two MECHANICAL invariants, each pinned to one of those real escapes:
#
#   A — RTP dissipative epilogue. Every src file with a real-time
#       step-advancing loop must route dissipation through the single
#       `apply_rt_dissipation!` helper, or be on an explicit excused
#       list (ITP / TDHFB / binary). A new driver that hand-writes a
#       step loop and silently omits loss+absorbing turns this RED.
#
#   B — enumerable config axes. Every value of each branching config
#       axis we can enumerate from the live source of truth (LHY kind
#       from the schema enum; DDI {secular, padded} Bools) must have a
#       coverage-manifest entry whose gate is a real, tier-registered
#       test. A new LHY kind / new DDI path with no gate turns this RED.
#
# Manifest hygiene: every :gated entry names a test file that exists,
# is registered in a tier (so the gate actually RUNS), and — for the
# LHY-kind axis — literally mentions the kind it claims to gate. Every
# :known_limit / :deferred carries a non-empty reason. No silent gaps.
#
# HONEST LIMITS. Invariant A is file-level, not per-function (a file
# with one correct RTP loop hides a second omitting one). The AXIS LIST
# in invariant B is manual — a brand-new config AXIS (not a new value of
# a listed axis) still needs a human to add it here. What is mechanical:
# new VALUES of listed axes, and new step-loop files.

using Test
using SpinorBEC

const _COV_TEST_ROOT = normpath(joinpath(@__DIR__, ".."))
const _COV_SRC_ROOT = normpath(joinpath(@__DIR__, "..", "..", "src"))

"""Relative-to-src paths of every `.jl` whose contents contain `needle`."""
function _src_files_with(needle::AbstractString)
    out = Set{String}()
    for (root, _, files) in walkdir(_COV_SRC_ROOT)
        for f in files
            endswith(f, ".jl") || continue
            p = joinpath(root, f)
            occursin(needle, read(p, String)) && push!(out, relpath(p, _COV_SRC_ROOT))
        end
    end
    out
end

"""Test files quoted in the tier lists (the set that actually runs). The tier
lists live in `_tiers.jl` (runtests.jl only orchestrates); reading runtests.jl
would instead pick up the scheduler's `_COST` keys and helper filenames."""
function _tier_registered_files()
    txt = read(joinpath(_COV_TEST_ROOT, "_tiers.jl"), String)
    Set(m.captures[1] for m in eachmatch(r"\"([\w/]+\.jl)\"", txt))
end

_test_file_mentions(rel, token) =
    occursin(token, read(joinpath(_COV_TEST_ROOT, rel), String))

# Step-advancing loops that legitimately apply NO real-time dissipation.
# Keyed by path relative to src/. Each must still BE a step loop (checked).
const _EXCUSED_STEP_LOOPS = Dict(
    "solvers/ground_state/itp_loop.jl" => "imaginary-time ITP: no physical loss/absorbing in ground-state relaxation",
    "hamiltonian/tdhfb/strang_step.jl" => "TDHFB engine, parallel-track to GP; no loss/absorbing pipeline (CLAUDE.md)",
    "hamiltonian/tdhfb/y4_midpoint_step.jl" => "TDHFB engine, parallel-track to GP; no loss/absorbing pipeline",
    "solvers/binary_simulation.jl" => "two-component GP: separate dissipation model, not the spinor RTP epilogue",
)

# axis, value, status, ref.
#   :gated       → ref = test file (relpath under test/). Checked: file
#                  exists, is tier-registered, and (LHY axis) mentions the value.
#   :known_limit → ref = non-empty reason (path intentionally a no-op).
#   :deferred    → ref = non-empty reason (gate owed; tracked, not silent).
const PATH_COVERAGE = [
    # --- LHY kind (SSoT: SpinorBEC.LHY_SCHEMA["kind"].enum) ---
    (axis=:lhy_kind, value="none", status=:known_limit,
        ref="no-op: LHYTerm short-circuits when lhy=nothing ∧ c_lhy=0 (lhy_term.jl)"),
    (axis=:lhy_kind, value="scalar", status=:gated, ref="hamiltonian/test_lhy.jl"),
    # quasi_2d LHY kind has NO distinct term-face code path — it
    # auto-derives c_lhy into the SAME scalar LHYTerm (CLAUDE.md: "Auto-
    # derive c_lhy for scalar / quasi_2d"; the quasi_2d *DDI* kernel is a
    # separate axis). So the term physics rides the scalar gate; the
    # kind-handling itself is gated at the config-compile layer.
    (axis=:lhy_kind, value="quasi_2d", status=:gated,
        ref="workflow/test_dynamics_lhy_plumbing.jl"),
    (axis=:lhy_kind, value="polar_two_channel", status=:gated,
        ref="hamiltonian/test_spinor_lhy_validation.jl"),
    (axis=:lhy_kind, value="full_bdg", status=:gated,
        ref="hamiltonian/test_spinor_lhy.jl"),
    (axis=:lhy_kind, value="polar_contact", status=:gated,
        ref="hamiltonian/test_lhy_polar.jl"),
    (axis=:lhy_kind, value="polar_dipolar", status=:gated,
        ref="hamiltonian/test_lhy_polar.jl"),
    (axis=:lhy_kind, value="fm_contact", status=:gated,
        ref="hamiltonian/test_lhy_polar.jl"),
    (axis=:lhy_kind, value="fm_dipolar", status=:gated,
        ref="hamiltonian/test_lhy_polar.jl"),
    (axis=:lhy_kind, value="icosahedral", status=:gated,
        ref="hamiltonian/test_icosahedral_lhy.jl"),
    # The only kind not built from ONE spinor: `e₁(p)` tabulated from the
    # cloud's own local spinors. The wiring gate covers the builder, the
    # uniform-cloud fallback to `:full_bdg`, and the resolver's knobs; the
    # table itself is `hamiltonian/test_spatial_lhy.jl` and its gradient
    # (whose polarisation term the propagator also carries since #131) is
    # `hamiltonian/test_lhy_gradient_all_modes.jl`.
    (axis=:lhy_kind, value="spatial", status=:gated,
        ref="workflow/test_lhy_block_wiring.jl"),

    # --- DDI secular kernel (master oracle fixtures A secular / A′ full) ---
    (axis=:ddi_secular, value=true, status=:gated, ref="oracles/test_master_oracle.jl"),
    (axis=:ddi_secular, value=false, status=:gated, ref="oracles/test_master_oracle.jl"),

    # --- DDI zero-padded convolution ---
    # unpadded = the registry path the master oracle compares per term;
    # padded = propagator-only face, gated by the dumb_rhs_ddi_padded
    # dt-valley (energy/gradient faces are unpadded by design — App. A
    # defect-9 KNOWN-LIMIT).
    (axis=:ddi_padded, value=false, status=:gated, ref="oracles/test_master_oracle.jl"),
    (axis=:ddi_padded, value=true, status=:gated, ref="hamiltonian/test_ddi_padded.jl"),
]

@testset "config-path coverage meta-test (term × config)" begin
    @testset "A: every RTP step-loop routes dissipation through one helper" begin
        step_files = _src_files_with(".step += 1")
        driver_files = _src_files_with("apply_rt_dissipation!")

        @test !isempty(step_files)
        for f in step_files
            @testset "$f" begin
                @test (f in driver_files) || haskey(_EXCUSED_STEP_LOOPS, f)
            end
        end
        # excuses must be live (still a step loop) and not secretly drivers
        for (f, reason) in _EXCUSED_STEP_LOOPS
            @testset "excused: $f" begin
                @test f in step_files
                @test !(f in driver_files)
                @test !isempty(reason)
            end
        end
    end

    @testset "B: every enumerable config-axis value is in the manifest" begin
        lhy_kinds = SpinorBEC.LHY_SCHEMA["kind"].enum
        manifest_lhy = Set(e.value for e in PATH_COVERAGE if e.axis === :lhy_kind)
        for k in lhy_kinds
            @testset "lhy_kind=$k present" begin
                @test k in manifest_lhy
            end
        end
        # no stale manifest LHY entry (every manifest kind is a live schema value)
        for k in manifest_lhy
            @test k in lhy_kinds
        end
        for ax in (:ddi_secular, :ddi_padded)
            vals = Set(e.value for e in PATH_COVERAGE if e.axis === ax)
            @testset "$ax both Bools present" begin
                @test true in vals
                @test false in vals
            end
        end
    end

    @testset "manifest hygiene: gated refs real + tier-registered; excuses non-empty" begin
        tier = _tier_registered_files()
        @test "oracles/test_path_coverage.jl" in tier   # self-registered (this file runs)
        for e in PATH_COVERAGE
            @testset "$(e.axis)=$(e.value)" begin
                if e.status === :gated
                    @test isfile(joinpath(_COV_TEST_ROOT, e.ref))
                    @test e.ref in tier
                    if e.axis === :lhy_kind && e.value isa AbstractString
                        @test _test_file_mentions(e.ref, e.value)
                    end
                else
                    @test e.status in (:known_limit, :deferred)
                    @test !isempty(e.ref)
                end
            end
        end
    end
end
