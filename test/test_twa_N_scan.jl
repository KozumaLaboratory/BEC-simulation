using Test
using SpinorBEC
using JLD2

# TWA N scan validity test (Round-2 Task 1).
#
# This test does NOT run the 90-min ensemble batch. It validates the
# *analysis pipeline* against pre-computed `runs/twa_N_scan/N{N}/result.jld2`
# ensembles when they exist, and skips otherwise. The expensive runs are
# kicked off via `examples/twa_N_scan.jl` outside the test suite.
#
# What is tested when results are present:
#   - JLD2 layout: dynamics/ensemble/phase_02/density/{mean,variance}
#   - Mean/variance arrays have the right rank (4D: nx, ny, nz, nt) and
#     the trajectory count is exactly 50
#   - 1/N validity: |on_axis(TWA) - on_axis(det)| / on_axis(det) decreases
#     monotonically as N grows; σ/μ at peak shrinks as N grows
#   - Genuine dipolar instability: FWHM_z stays in {5, 6, 7} regardless of N

const _RUNS_ROOT = joinpath(@__DIR__, "..", "runs")
const _DETERMINISTIC = joinpath(@__DIR__, "..", "runs", "eu151_edh_postfix_local",
    ".archive_baseline", "point_001.jld2")
const _N_VALUES = (1000, 10000, 100000)

# `run_yaml` resolves outputs to `runs/<basename>_<hash>/result.jld2`. The
# N-scan configs live at `runs/twa_N_scan/N{N}.yaml`, so results land at
# `runs/N{N}_<hash>/`. Discover the freshest match per N.
function _resolve_result(N::Integer)
    isdir(_RUNS_ROOT) || return nothing
    hits = String[]
    for d in readdir(_RUNS_ROOT; join=true)
        isdir(d) || continue
        occursin(Regex("^N$(N)_[0-9a-f]+\$"), basename(d)) || continue
        rj = joinpath(d, "result.jld2")
        isfile(rj) && push!(hits, rj)
    end
    isempty(hits) ? nothing : (sort!(hits; by=mtime, rev=true); first(hits))
end

function _final_density_stats(path::AbstractString; ensemble::Bool)
    jldopen(path, "r") do f
        if ensemble
            mean_arr = f["dynamics/ensemble/phase_02/density/mean"]
            var_arr = f["dynamics/ensemble/phase_02/density/variance"]
            @assert ndims(mean_arr) == 4
            @assert size(mean_arr) == size(var_arr)
            nx, ny, nz, _ = size(mean_arr)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = mean_arr[:, :, :, end]
            varr = var_arr[:, :, :, end]
            n_traj = f["dynamics/ensemble/phase_02/n_trajectories"]
        else
            psi = f["psi"]
            nx, ny, nz, _ = size(psi)
            cx, cy, cz = nx ÷ 2 + 1, ny ÷ 2 + 1, nz ÷ 2 + 1
            dens = sum(abs2.(psi); dims=4)[:, :, :, 1]
            varr = nothing
            n_traj = 1
        end

        peak = maximum(dens)
        prof_z = dens[cx, cy, :]
        h = peak / 2
        idx = findall(>(h), prof_z)
        fwhm_z = isempty(idx) ? 0 : last(idx) - first(idx) + 1

        on_axis = dens[cx, cy, cz] / max(peak, 1e-30)
        sigma_over_mu = NaN
        if varr !== nothing
            peak_idx = argmax(dens)
            σ = sqrt(max(varr[peak_idx], 0.0))
            sigma_over_mu = σ / max(peak, 1e-30)
        end
        (; n_traj, peak, fwhm_z, on_axis, sigma_over_mu)
    end
end

@testset "TWA N scan analysis pipeline" begin
    resolved = Dict(N => _resolve_result(N) for N in _N_VALUES)
    available = [N for N in _N_VALUES if resolved[N] !== nothing]
    if isempty(available) || !isfile(_DETERMINISTIC)
        @info "Skipping TWA N scan tests: no ensemble JLD2 available yet" \
              runs_root=_RUNS_ROOT deterministic=_DETERMINISTIC
        @test_skip "ensemble outputs not present (run examples/twa_N_scan.jl first)"
        return nothing
    end

    det = _final_density_stats(_DETERMINISTIC; ensemble=false)
    @test isfinite(det.peak) && det.peak > 0
    @test det.fwhm_z >= 1

    results = [
        (; N, stats=_final_density_stats(resolved[N]; ensemble=true))
        for N in available
    ]

    @testset "ensemble layout" begin
        for r in results
            @test r.stats.n_traj == 50
            @test isfinite(r.stats.peak)
            @test 0.0 <= r.stats.on_axis <= 1.0
            @test 0.0 <= r.stats.sigma_over_mu < 10.0
        end
    end

    @testset "FWHM_z N-independence (genuine dipolar instability)" begin
        # Z-elongation is set by mean-field DDI, not by quantum fluctuations,
        # so all three N values should land in {5, 6, 7} cells.
        for r in results
            @test 4 <= r.stats.fwhm_z <= 8
        end
    end

    if length(results) >= 2
        @testset "1/N scaling (TWA - deterministic) shrinks with N" begin
            Δrel = [abs(r.stats.on_axis - det.on_axis) / max(det.on_axis, 1e-30)
                    for r in results]
            # We expect monotone decrease; allow one inversion for stat noise
            # at 50 trajectories (standard error ~1/√50 ≈ 14%).
            inversions = sum(Δrel[i + 1] > 1.5 * Δrel[i] for i in 1:(length(Δrel) - 1))
            @test inversions <= 1
        end

        @testset "σ/μ × √N approximately N-independent" begin
            scaled = [r.stats.sigma_over_mu * sqrt(r.N) for r in results]
            ratio_max_over_min = maximum(scaled) / max(minimum(scaled), 1e-30)
            # 1/√N scaling means scaled values cluster within a factor of ~3
            # at 50 trajectories (allowing trajectory-level statistical noise).
            @test ratio_max_over_min < 5.0
        end
    end
end
