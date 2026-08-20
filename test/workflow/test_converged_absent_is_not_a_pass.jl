# "Nobody checked" must not be written as "converged".
#
# `run_registry.jl` read the convergence flag as
#
#     converged = get(result, :ground_state_converged, true)
#
# and wrote the result unconditionally. That default collapsed three distinct
# states into one:
#
#   converged            the solver ran and reached its tolerance
#   did not converge     the solver ran and did not
#   NOBODY CHECKED       there is no convergence information at all
#
# The third is not hypothetical. `:ground_state_converged` is already the
# discriminator for "did a ground state run at all" (`model/complete.jl:222`), so
# a dynamics-only pipeline has none — and the rotating-basis ground state
# (`run_step_rotating/ground_state.jl`) returns `mu` and no convergence flag
# either. Every rotating-basis run therefore wrote `converged = true` having
# never been asked, and satisfied CAMPAIGN.md guard 7 ("conv == false =>
# disqualified") by construction.
#
# Found 2026-08-20 by smoking `runs/eu151_klaus_phi_phys/` before spending GPU
# hours on it: the run came back `E=NaN conv=true`, and the energy was NaN for
# the same reason — an absent key read through a default.
#
# The fix is to write nothing when there is nothing to report. Every consumer
# already handles absence (`haskey` in html_report.jl and run_summary.jl,
# `_gslib_get(..., -1)` in gs_library.jl, the optional-key list in
# open_result.jl), and absence cannot be mistaken for a pass.

using SpinorBEC
using Test

const _REPO = normpath(joinpath(@__DIR__, "..", ".."))
const _REG = joinpath(_REPO, "src", "workflow", "experiments",
    "pipeline", "run_registry.jl")

@testset "an absent convergence flag is never written as a pass" begin
    src = read(_REG, String)

    # 1. The defaulting-to-true read is gone, at every site.
    @test !occursin(":ground_state_converged, true)", src)

    # 2. …and the replacement reads absence AS absence.
    @test occursin(":ground_state_converged, nothing)", src)
    @test count(", nothing)", src) >= 1

    # 3. Every write of the key is guarded, so `nothing` never reaches the file.
    #    Count writes and guarded writes and require them equal — a new
    #    unguarded write anywhere in this file fails here.
    writes = length(collect(eachmatch(r"f\[\"converged\"\]\s*=", src)))
    guarded = length(
        collect(eachmatch(
            r"converged\s*===\s*nothing\s*\|\|\s*\(f\[\"converged\"\]\s*=", src)),
    )
    @test writes >= 2                 # the scan-point path and the single-run path
    @test guarded == writes

    # POSITIVE CONTROL. Arms 1-3 are all satisfied by a file that never mentions
    # `converged`, so pin that the thing being guarded is actually present.
    @test occursin("ground_state_converged", src)
    @test occursin("f[\"converged\"]", src)
end
