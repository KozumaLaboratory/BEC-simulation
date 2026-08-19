# A declared mirror pair must flip EVERY axial quantity, not just the knob being
# scanned.
#
# WHY THIS EXISTS (#343, 2026-08-19)
#
# `docs/manuscript/klaus_protocol_sheet.md` records an acceptance gate:
#
#     | (init m x Omega sign) reversal symmetry | 3-digit match in both branches  PASS |
#
# Its two arms were `klaus_quench_omm0p5_keeprot` and
# `klaus_quench_omp0p5_keeprot_mFplus`. At the time they flipped all three axial
# quantities — m, Omega and B_z — so they were a genuine mirror pair and the
# 3-digit agreement meant something.
#
# `bce2068f` then flipped the field on the 211 configs pinning m=-F and left the
# m=+F ones alone, because for a lone m=+F config "flip the field" and "flip the
# seed" are both consistent and the intent is not recoverable from the file.
# Correct per file. But the two arms then both sat at B_z = +0.01 G: only two of
# the three axial quantities flipped, the pair stopped being a mirror, and
# re-running the gate would have compared an uphill Zeeman cascade against a
# downhill one. Nothing in the tree recorded that the two files were a pair, so
# nothing could warn.
#
# THE CLASS, not the instance: a repair applied file-by-file can be right on
# every file and still break a relationship spanning two of them. The fix is to
# make the relationship a declaration the machine can read:
#
#     # mirror-pair: <other-file>.yaml
#
# in the header of BOTH files. This test then checks the physics of the mirror.
#
# The mirror that reverses chirality (take y -> -y) acts on every axial vector:
#   L_z -> -L_z   =>  rotating_frame_omega flips
#   F   -> mirrored =>  the stretched seed flips m=-F <-> m=+F
#   B   -> axial too =>  B_z flips
# Flipping only Omega is not a mirror; flipping Omega and m is not a mirror
# either. #338 (Barnett) reached the same rule from the other side, where the
# missing partner was B_y because `SinusoidalWaveform` is odd.

using SpinorBEC
using Test
using YAML

const _RUNS = normpath(joinpath(@__DIR__, "..", "..", "runs"))
const _DECL = r"^#\s*mirror-pair:\s*(\S+\.yaml)\s*$"m

"""Every `(file, partner)` declared by a `# mirror-pair:` header line."""
function _declared_pairs(root)
    out = Tuple{String, String}[]
    for (dir, _, files) in walkdir(root), f in files
        endswith(f, ".yaml") || continue
        path = joinpath(dir, f)
        for m in eachmatch(_DECL, read(path, String))
            push!(out, (path, joinpath(dir, m.captures[1])))
        end
    end
    sort(out)
end

"""`(seed, omega, bz)` of the ground_state step and the LAST dynamics step."""
function _axial_signature(path)
    data = YAML.load_file(path)
    gs = nothing
    omega = nothing
    for step in data["pipeline"]
        step isa AbstractDict || continue
        if haskey(step, "ground_state")
            gs = step["ground_state"]
        elseif haskey(step, "dynamics")
            o = get(step["dynamics"], "rotating_frame_omega", nothing)
            o isa Number && (omega = Float64(o))
        end
    end
    gs === nothing && return nothing
    seed = get(gs, "initial_state", nothing)
    bzs = String(gs["B"]["Bz"])
    bz = parse(Float64, first(split(strip(bzs))))
    (; seed, omega, bz)
end

@testset "declared mirror pairs flip every axial quantity" begin
    pairs = _declared_pairs(_RUNS)

    # Not a silent cap: if the declaration syntax ever stops matching, this test
    # would pass over an empty set and report nothing. The count is pinned.
    @test length(pairs) >= 4

    seen = Set{Tuple{String, String}}()
    for (a, b) in pairs
        @test isfile(b)
        isfile(b) || continue
        push!(seen, (basename(a), basename(b)))

        # The declaration must be symmetric — a one-sided pointer is how the
        # relationship goes missing again the next time one file is edited.
        @test occursin(Regex("^#\\s*mirror-pair:\\s*" * basename(a) * "\\s*\$", "m"),
            read(b, String))

        sa, sb = _axial_signature(a), _axial_signature(b)
        @test sa !== nothing && sb !== nothing
        (sa === nothing || sb === nothing) && continue

        # 1. the stretched seed flips
        @test Set([sa.seed, sb.seed]) == Set(["m_minus_F", "m_plus_F"])
        # 2. Omega flips, same magnitude
        @test sa.omega !== nothing && sb.omega !== nothing
        @test sa.omega ≈ -sb.omega
        @test !(sa.omega ≈ 0.0)          # a zero-Omega "mirror" tests nothing
        # 3. B_z flips, same magnitude — the one bce2068f left behind
        @test sa.bz ≈ -sb.bz
        @test !(sa.bz ≈ 0.0)
    end

    # Canary: the checks above must be able to FAIL. Build the broken pair as it
    # stood between bce2068f and #343 — m and Omega flipped, B_z not — and
    # require the B_z clause to reject it. Without this, all-green is
    # indistinguishable from a predicate that matches everything.
    let good = (seed="m_minus_F", omega=-0.5, bz=0.01),
        broken = (seed="m_plus_F", omega=0.5, bz=0.01)      # <- B_z did not flip

        @test Set([good.seed, broken.seed]) == Set(["m_minus_F", "m_plus_F"])  # passes
        @test good.omega ≈ -broken.omega                                       # passes
        @test !(good.bz ≈ -broken.bz)      # …and THIS is what catches it
    end
end
