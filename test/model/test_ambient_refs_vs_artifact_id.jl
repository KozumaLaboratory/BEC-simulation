# Cutover step 4: for every ambient `Ref` still on a kernel path, does flipping
# it move `artifact_id`?
#
# `test/model/test_no_ambient_module_refs.jl` enumerates the Refs. This file
# MEASURES each one against the id, which is the property that actually matters:
# a Ref that changes a number and not the id means two different computations
# share one address, and step 3's admission serves whichever ran first.
#
# The expectation is PINNED per Ref, with `:moves` and `:blind` both real
# answers:
#
#   :moves  the value reaches the declaration (for the dealias pair, via
#           `GridSpec`), so two runs differing in it get two ids. Pinning this
#           is what stops someone unhooking it again.
#   :blind  the value does NOT reach the declaration. That is the open hole, and
#           it is pinned so that closing it is a VISIBLE diff here rather than a
#           silent improvement nobody notices. Each `:blind` entry carries the
#           reason it is still open.
#
# TWO WAYS THIS COULD MEASURE NOTHING, AND WHAT IS DONE ABOUT EACH.
#
#   * A flip that does not flip. `:blind` is trivially satisfied by a poke that
#     changed nothing, so every entry asserts the Ref's value actually differs
#     after `flip!` and is back afterwards.
#   * A harness that returns a constant id. At least one entry must be `:moves`
#     (asserted), the base id must be a deterministic 16-hex string, and
#     restoring must give the base id back after every flip.
#
# The `:blind` entries are NOT a claim that those Refs are harmless. Measured
# effect on ψ, one flip at a time, Eu F=6 16³ with DDI:
#   MEANFIELD_MIDPOINT_ENABLED   2.2e-6 over 4 RT steps, 2.4e-4 over 200; 0 in ITP
#   COMBINED_SPIN_STEP_ENABLED   1.7e-9 over 8 RTP steps (unpadded DDI); 0 padded
#   SPIN_CHAIN_FUSION_ENABLED    exactly 0 (CPU has no fused kernel; GPU is
#                                bit-identical, which is what its parity gate demands)
#   SPIN_TAYLOR_ENABLED          6.2e-14 over 4 RT steps, 3.6e-13 over 20 ITP steps

using Test
using SpinorBEC
using SpinorBEC: resolve_gs, _gs_artifact_id,
    DEALIAS_2_3_ENABLED, DEALIAS_K_CUTOFF,
    MEANFIELD_MIDPOINT_ENABLED, COMBINED_SPIN_STEP_ENABLED,
    SPIN_CHAIN_FUSION_ENABLED, SPIN_TAYLOR_ENABLED,
    SPIN_TAYLOR_DEGREE_CAP, SPIN_TAYLOR_RK_MAX

# A ground-state step that resolves on its own. Eu F=6 with DDI, because that is
# the configuration every one of these Refs is actually read in.
_base_step() = Dict{String, Any}(
    "atom" => "Eu151",
    "grid" => Dict{String, Any}("n" => [8, 8, 8], "box" => [6.0, 6.0, 6.0]),
    "interactions" => Dict{String, Any}(
        "N_atoms" => 1000, "omega_ref" => 691.15, "c1_ratio" => -0.01),
    "potential" => Dict{String, Any}("type" => "harmonic", "omega" => [1.0, 1.0, 2.0]),
    "B" => Dict{String, Any}("Bz" => 0.01),
    "ddi" => Dict{String, Any}("secular" => true),
    "method" => "itp",
    "n_steps" => 20,
    "dt" => 0.002,
    "tol" => 1.0e-8,
    "backend" => "cpu",
)

# `resolve_gs` mutates its dict (it writes back derived `ddi.c_dd`, `lhy_kind`,
# `lhy_opts`), so each call gets its own copy or entry N inherits entry N-1's
# derived slots.
function _id()
    q = deepcopy(_base_step())
    _gs_artifact_id(resolve_gs(q, nothing, nothing, nothing; verbose=false), q)
end

# `(name, expectation, read, flip!, restore!)`. `read` is used only to prove the
# flip flipped.
const AMBIENT_REFS = [
    (:dealias_2_3, :moves,
        "the Orszag projector, read into GridSpec.dealias_two_thirds at \
resolve_gs.jl:311",
        () -> DEALIAS_2_3_ENABLED[],
        v -> (DEALIAS_2_3_ENABLED[] = !v)),
    (:dealias_k_cut, :moves,
        "the physical-k form of the same projector, read into GridSpec.dealias_k_cut \
via _dealias_k_cut_value(). The `2_3` axis existing does NOT cover this one: they are \
separate GridSpec fields and 71 committed configs set k_cut explicitly",
        () -> DEALIAS_K_CUTOFF[],
        v -> (DEALIAS_K_CUTOFF[] = v === nothing ? 7.5 : nothing)),
    (:meanfield_midpoint, :blind,
        "BLIND. Real-time only (`!imaginary_time` guards both `_half_potential` \
sites), so it belongs in the params of an `:evolve` Stage — and no `:evolve` Stage \
exists: run_step_dynamics.jl declares none",
        () -> MEANFIELD_MIDPOINT_ENABLED[],
        v -> (MEANFIELD_MIDPOINT_ENABLED[] = !v)),
    (:combined_spin_step, :blind,
        "BLIND. Same destination and same blocker. combined_spin_step.jl:42-46 \
already says it is a physics choice the run must make",
        () -> COMBINED_SPIN_STEP_ENABLED[],
        v -> (COMBINED_SPIN_STEP_ENABLED[] = !v)),
    (:spin_chain_fusion, :blind,
        "BLIND, and staying that way: it exists so the fusion parity gate can run \
BOTH statements on one input, and it is measured bit-identical",
        () -> SPIN_CHAIN_FUSION_ENABLED[],
        v -> (SPIN_CHAIN_FUSION_ENABLED[] = !v)),
    (:spin_taylor, :blind,
        "BLIND, and read on the ITP path too (3.6e-13 over 20 steps) — so unlike \
the two above, this one is blind in a stage that DOES have an id. Wants a declared \
per-run field; the parity gates on both devices flip it, so it needs an argument \
path first",
        () -> SPIN_TAYLOR_ENABLED[],
        v -> (SPIN_TAYLOR_ENABLED[] = !v)),
    (:spin_taylor_degree_cap, :blind,
        "BLIND BY DESIGN and guarded instead: it is the positive control for \
test_taylor_tolerance_criterion.jl, no run sets it, and `run_pipeline` throws while \
it is clamped (test_taylor_degree_cap_guard.jl)",
        () -> SPIN_TAYLOR_DEGREE_CAP[],
        v -> (SPIN_TAYLOR_DEGREE_CAP[] = v == 2 ? SPIN_TAYLOR_RK_MAX : 2)),
]

@testset "every ambient Ref, measured against artifact_id" begin
    base = _id()

    @testset "the harness measures something" begin
        @test base !== nothing
        @test base isa AbstractString
        @test length(base) == 16
        @test all(c -> c in "0123456789abcdef", base)
        # Deterministic, or every inequality below could be satisfied by noise.
        @test _id() == base
        # At least one `:moves`, or the harness cannot detect movement at all.
        @test any(e -> e[2] === :moves, AMBIENT_REFS)
        # The enumeration is the point; pin the count so an entry cannot be lost.
        @test length(AMBIENT_REFS) == 7
        @test length(unique(first.(AMBIENT_REFS))) == 7
    end

    for (name, expect, why, read, flip!) in AMBIENT_REFS
        @testset "$name — $expect" begin
            before = read()
            moved_id = nothing
            after = nothing
            try
                flip!(before)
                after = read()
                moved_id = _id()
            finally
                flip!(after === nothing ? read() : after)
            end
            # The flip flipped. Without this, `:blind` is satisfied by a no-op.
            @test after != before
            @test read() == before
            # ... and restoring gives the base id back, so the measurement is
            # about the flip and not about drift in the resolver.
            @test _id() == base

            if expect === :moves
                @test moved_id !== nothing
                @test moved_id != base
            else
                @test moved_id == base
            end
        end
    end
end
