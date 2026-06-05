# Characterization tests for the sweep-view system (src/analysis/sweep/).
#
# to_viewspec -- a ~1500-line dispatcher -- had ZERO automated coverage prior to
# this file; only scripts/m1_sweep_golden_export.jl exercised the sweep
# emitters. These tests pin the externally-observable contract of the pure
# helpers (LUTs, per-cell hex resolution, dominant-m margin, VSUP alpha) and a
# structural characterization of EVERY execution path of the 2-axis heatmap
# emitter (the hypothesis-free panel grid + all five hypothesis relations +
# the spectrum observable + the 1-axis degenerate path), so a future
# decomposition of that god-function can be verified behaviour-preserving
# rather than refactored blind.
#
# Assertions are deliberately structural (shape + frozen endpoints + documented
# boundary cases), not pixel-exact, so they characterize behaviour without
# over-fitting to the current panel layout.

using Test
using SpinorBEC

# The five hypothesis-relation builders + the spectrum mark builder are ~700
# lines of deeply-nested closures (capturing ~20 heterogeneous locals). Their
# first-time JIT compilation is expensive enough (~5 min, capture-induced
# inference) to blow the fast tier's 15-min budget, so the testsets that force
# it are gated behind the heavy flag: they run in the nightly `full` tier
# (SPINORBEC_RUN_HEAVY_YAML=true, 90-min budget), not the per-push inner loop.
const _SKIP_HEAVY_VIEWSPEC = get(ENV, "SPINORBEC_RUN_HEAVY_YAML", "false") != "true"

# Minimal 2-axis sweep (B_nT log x omega linear). Mirrors the proven observable
# kinds from scripts/m1_sweep_golden_export.jl (signed / positive / wide-quality
# + optional spectrum). `hypothesis` (opt-in) selects the primary-mark relation;
# `b_vals` / `w_vals` control the swept-axis count (drop one to a singleton to
# exercise the 1-axis degenerate path).
function _sweep_result(; hypothesis=nothing, spectrum::Bool=false, F::Int=6,
    b_vals=[100.0, 200.0], w_vals=[0.3, 0.6])
    axes = SweepAxis[
        SweepAxis(:B_nT, "nT", :log, b_vals),
        SweepAxis(:omega, "rad", :linear, w_vals),
    ]
    observables = SweepObservable[
        SweepObservable(; key=:fz_total, kind=:signed, center=0.0),
        SweepObservable(; key=:E, kind=:positive, scale=:linear),
        SweepObservable(; key=:grad_norm, kind=:wide, scale=:log, role=:quality),
    ]
    if spectrum
        push!(observables, SweepObservable(; key=:m_dist, kind=:spectrum, index=:m))
    end
    data = Dict{Symbol, Any}[]
    for b in b_vals
        for w in w_vals
            row = Dict{Symbol, Any}(
                :B_nT => b,
                :omega => w,
                :fz_total => 0.1 * w,
                :E => 1.0 + 0.1 * b,
                :grad_norm => 1.0e-6,
                :conv => true,
            )
            if spectrum
                row[:m_dist] = fill(1.0 / (2F + 1), 2F + 1)
            end
            push!(data, row)
        end
    end
    meta = Dict{Symbol, Any}(:conv_column => :conv)
    if hypothesis !== nothing
        meta[:narrative] = Dict{Symbol, Any}(:hypothesis => hypothesis)
    end
    return SweepResult(axes, observables, data; meta=meta)
end

# One Hypothesis per relation, each wired with the minimum inputs its builder
# reads (mapped from src/analysis/sweep/viewspec.jl): a ModelSpec for the
# primary observable, plus relation-specific params (collapse needs
# collapse_var_fn; correlation needs obs_y; scaling/asymptote read axis).
function _hypotheses()
    base_model = ModelSpec(; fn=(ax) -> 0.05 * ax.omega, label="0.05 * omega")
    collapse_model = ModelSpec(;
        fn=(ax) -> 0.05 * ax.omega,
        label="0.05 * omega",
        collapse_var_fn=(ax) -> ax.omega / ax.B_nT,
        collapse_var_label="omega / B",
    )
    asymptote = Hypothesis(;
        relation=:asymptote,
        primary_obs=:fz_total,
        models=Dict(:fz_total => base_model),
        params=Dict{Symbol, Any}(:axis => :B_nT),
    )
    collapse = Hypothesis(;
        relation=:collapse,
        primary_obs=:fz_total,
        models=Dict(:fz_total => collapse_model),
    )
    residual = Hypothesis(;
        relation=:residual,
        primary_obs=:fz_total,
        models=Dict(:fz_total => base_model),
    )
    scaling = Hypothesis(;
        relation=:scaling,
        primary_obs=:fz_total,
        models=Dict(:fz_total => base_model),
        params=Dict{Symbol, Any}(:axis => :B_nT, :exponent => -1.0),
    )
    correlation = Hypothesis(;
        relation=:correlation,
        primary_obs=:fz_total,
        models=Dict(:fz_total => base_model),
        params=Dict{Symbol, Any}(:obs_y => :E),
    )
    return [
        ("asymptote", asymptote),
        ("collapse", collapse),
        ("residual", residual),
        ("scaling", scaling),
        ("correlation", correlation),
    ]
end

@testset "sweep-view system" begin
    @testset "dominant_m_with_margin -- margin gate" begin
        # 50-50 -> gap 0 < margin -> :mixed (the snap-and-flip failure that an
        # absolute purity threshold has; see docstring).
        @test dominant_m_with_margin([0.5, 0.5], [1, -1]) === :mixed
        @test dominant_m_with_margin([0.49, 0.51], [1, -1]; margin=0.1) === :mixed
        # Clear winner leads by > margin -> the dominant m value.
        @test dominant_m_with_margin([0.7, 0.15, 0.15], [1, 0, -1]; margin=0.1) == 1
        @test dominant_m_with_margin(Float64[], Int[]) === :mixed
    end

    @testset "reference colormap LUTs -- frozen endpoints" begin
        bal = sweep_balance_lut(8)
        vir = sweep_viridis_lut(8)
        @test length(bal) == 8 && eltype(bal) === NTuple{3, UInt8}
        @test length(vir) == 8 && eltype(vir) === NTuple{3, UInt8}
        # Endpoints are exact samples of the published stop list (t=0, t=1).
        @test bal[1] == (0x18, 0x1c, 0x43)
        @test bal[end] == (0x3c, 0x08, 0x14)
        @test vir[1] == (0x44, 0x01, 0x54)
        @test vir[end] == (0xfd, 0xe7, 0x24)
    end

    @testset "resolve_*_cell_hex -- NaN sentinel + shape" begin
        # NaN -> neutral grey sentinel (visibly distinct from any LUT colour).
        @test resolve_signed_cell_hex(NaN, -1.0, 1.0) == "#9aa0a6"
        @test resolve_positive_cell_hex(NaN, 0.0, 1.0) == "#9aa0a6"
        # In-range values resolve to a 7-char #rrggbb hex.
        @test length(resolve_signed_cell_hex(0.0, -1.0, 1.0)) == 7
        @test startswith(resolve_signed_cell_hex(0.5, -1.0, 1.0), "#")
        @test length(resolve_positive_cell_hex(0.5, 0.0, 1.0)) == 7
        @test length(resolve_positive_cell_hex(0.5, 1e-3, 1.0; scale=:log)) == 7
        # Out-of-clip saturates (no extrapolation) -- endpoints match clip ends.
        @test resolve_signed_cell_hex(5.0, -1.0, 1.0) == resolve_signed_cell_hex(1.0, -1.0, 1.0)
        @test resolve_signed_cell_hex(-5.0, -1.0, 1.0) == resolve_signed_cell_hex(-1.0, -1.0, 1.0)
    end

    @testset "compute_quality_alpha -- VSUP alpha fade" begin
        # q == threshold -> x = 0 -> alpha = 1 (fully trusted).
        @test compute_quality_alpha(1e-5; threshold=1e-5) ≈ 1.0
        # NaN quality -> alpha = 0 (missing-data sentinel is transparent).
        @test compute_quality_alpha(NaN; threshold=1e-5) == 0.0
        # good_low: q one full dynamic-range above threshold -> alpha = 0.
        @test compute_quality_alpha(1e-1; threshold=1e-5, dynamic_range_decades=4.0) ≈ 0.0
        # alpha is always within [0, 1].
        for q in (1e-9, 1e-6, 1e-3, 1.0, 1e3)
            @test 0.0 <= compute_quality_alpha(q; threshold=1e-5) <= 1.0
        end
    end

    @testset "to_viewspec -- 2-axis heatmap (hypothesis-free)" begin
        spec = to_viewspec(_sweep_result())
        @test spec isa AbstractDict
        @test occursin("vega", lowercase(String(spec["\$schema"])))
        @test spec["_view_shape"] == "heatmap"
        # 2-axis path emits a vconcat of hconcat panel rows; with three
        # observables it must be non-empty.
        @test haskey(spec, "vconcat") && !isempty(spec["vconcat"])
        @test haskey(spec, "_panels_count") && spec["_panels_count"] >= 1
    end

    # Heavy paths (gated to nightly/full -- see _SKIP_HEAVY_VIEWSPEC note above).
    # Each relation drives a distinct ~150-line primary-mark builder reachable
    # only with a hypothesis set; the spectrum path compiles the m_dist mark
    # builder. Correct, but compile-expensive, so kept out of the fast inner loop.
    if _SKIP_HEAVY_VIEWSPEC
        @testset "to_viewspec -- relation + spectrum paths (heavy, gated)" begin
            @test_skip false
        end
    else
        @testset "to_viewspec -- all hypothesis relation paths" begin
            for (name, hyp) in _hypotheses()
                spec = to_viewspec(_sweep_result(; hypothesis=hyp))
                @test spec isa AbstractDict
                @test spec["_view_shape"] == "heatmap"
                @test haskey(spec, "vconcat") && !isempty(spec["vconcat"])
            end
        end

        @testset "to_viewspec -- spectrum observable path" begin
            spec = to_viewspec(_sweep_result(; spectrum=true))
            @test spec["_view_shape"] == "heatmap"
            @test haskey(spec, "vconcat") && !isempty(spec["vconcat"])
        end
    end

    @testset "to_viewspec -- 1-axis degenerate path" begin
        # Single swept axis -> "line" view shape; 1D heatmap is not emitted yet
        # (empty vconcat for safety), so the path must not error.
        spec = to_viewspec(_sweep_result(; w_vals=[0.3]))
        @test spec["_view_shape"] == "line"
        @test haskey(spec, "vconcat") && isempty(spec["vconcat"])
    end

    @testset "write_viewspec / write_golden_per_cell_table -- JSON round-trip" begin
        result = _sweep_result()
        mktempdir() do dir
            vpath = joinpath(dir, "viewspec.json")
            gpath = joinpath(dir, "golden.json")
            @test write_viewspec(vpath, result) == vpath
            write_golden_per_cell_table(gpath, result)
            for p in (vpath, gpath)
                @test isfile(p) && filesize(p) > 0
                txt = strip(read(p, String))
                @test startswith(txt, "{") && endswith(txt, "}")
            end
        end
    end
end
