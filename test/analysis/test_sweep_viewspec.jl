# Characterization tests for the sweep-view system (src/analysis/sweep/).
#
# `to_viewspec` is a ~1500-line dispatcher that, prior to this file, had ZERO
# automated coverage — only `scripts/m1_sweep_golden_export.jl` exercised the
# sweep emitters. These tests pin the externally-observable contract of the
# pure helpers (LUTs, per-cell hex resolution, dominant-m margin, VSUP alpha)
# and a smoke characterization of the 2-axis heatmap emitter + the golden /
# viewspec writers, so a future decomposition of the god-function can be
# verified behaviour-preserving rather than refactored blind.
#
# Assertions are deliberately structural (shape + endpoints + documented
# boundary cases), not pixel-exact, so they characterize behaviour without
# over-fitting to the current panel layout.

using Test
using SpinorBEC

@testset "sweep-view system" begin
    @testset "dominant_m_with_margin — margin gate" begin
        # 50-50 → gap 0 < margin → :mixed (the snap-and-flip failure an
        # absolute purity threshold has; see docstring).
        @test dominant_m_with_margin([0.5, 0.5], [1, -1]) === :mixed
        @test dominant_m_with_margin([0.49, 0.51], [1, -1]; margin=0.1) === :mixed
        # Clear winner leads by > margin → the dominant m value.
        @test dominant_m_with_margin([0.7, 0.15, 0.15], [1, 0, -1]; margin=0.1) == 1
        @test dominant_m_with_margin(Float64[], Int[]) === :mixed
    end

    @testset "reference colormap LUTs — frozen endpoints" begin
        bal = sweep_balance_lut(8)
        vir = sweep_viridis_lut(8)
        @test length(bal) == 8 && eltype(bal) === NTuple{3, UInt8}
        @test length(vir) == 8 && eltype(vir) === NTuple{3, UInt8}
        # Endpoints are exact samples of the published stop list (t=0, t=1).
        @test bal[1] == (0x18, 0x1c, 0x43)   # cmocean balance deep blue (24,28,67)
        @test bal[end] == (0x3c, 0x08, 0x14) # cmocean balance deep red  (60,8,20)
        @test vir[1] == (0x44, 0x01, 0x54)   # viridis deep purple (68,1,84)
        @test vir[end] == (0xfd, 0xe7, 0x24) # viridis bright yellow (253,231,36)
    end

    @testset "resolve_*_cell_hex — NaN sentinel + shape" begin
        # NaN → neutral grey sentinel (visibly distinct from any LUT colour).
        @test resolve_signed_cell_hex(NaN, -1.0, 1.0) == "#9aa0a6"
        @test resolve_positive_cell_hex(NaN, 0.0, 1.0) == "#9aa0a6"
        # In-range values resolve to a 7-char #rrggbb hex.
        for h in (resolve_signed_cell_hex(0.0, -1.0, 1.0),
            resolve_signed_cell_hex(0.5, -1.0, 1.0),
            resolve_positive_cell_hex(0.5, 0.0, 1.0),
            resolve_positive_cell_hex(0.5, 1e-3, 1.0; scale=:log))
            @test startswith(h, "#") && length(h) == 7
        end
        # Out-of-clip saturates (no extrapolation) — endpoints match clip ends.
        @test resolve_signed_cell_hex(5.0, -1.0, 1.0) == resolve_signed_cell_hex(1.0, -1.0, 1.0)
        @test resolve_signed_cell_hex(-5.0, -1.0, 1.0) == resolve_signed_cell_hex(-1.0, -1.0, 1.0)
    end

    @testset "compute_quality_alpha — VSUP alpha fade" begin
        # q == threshold → x = 0 → α = 1 (fully trusted).
        @test compute_quality_alpha(1e-5; threshold=1e-5) ≈ 1.0
        # NaN quality → α = 0 (missing-data sentinel is transparent).
        @test compute_quality_alpha(NaN; threshold=1e-5) == 0.0
        # good_low: q one full dynamic-range above threshold → α = 0.
        @test compute_quality_alpha(1e-1; threshold=1e-5,
            dynamic_range_decades=4.0) ≈ 0.0
        # α is always within [0, 1].
        for q in (1e-9, 1e-6, 1e-3, 1.0, 1e3)
            a = compute_quality_alpha(q; threshold=1e-5)
            @test 0.0 <= a <= 1.0
        end
    end

    # Minimal 2-axis sweep (B_nT log × omega linear), all converged. Mirrors
    # the proven observable kinds from scripts/m1_sweep_golden_export.jl
    # (signed / positive / wide-quality); the spectrum kind is exercised by
    # the script, not needed for the structural smoke here.
    function _minimal_sweep_result()
        axes = SweepAxis[
            SweepAxis(:B_nT, "nT", :log, [100.0, 200.0]),
            SweepAxis(:omega, "ω_⊥", :linear, [0.3, 0.6]),
        ]
        observables = [
            SweepObservable(; key=:fz_total, label="⟨F_z⟩", kind=:signed, center=0.0),
            SweepObservable(; key=:E, label="Energy", kind=:positive, scale=:linear),
            SweepObservable(; key=:grad_norm, label="‖∇E‖", kind=:wide,
                scale=:log, role=:quality),
        ]
        cells = [
            (100.0, 0.3, 0.12, 1.5, 1.0e-6),
            (100.0, 0.6, 0.24, 1.6, 2.0e-6),
            (200.0, 0.3, 0.06, 1.4, 1.0e-6),
            (200.0, 0.6, 0.12, 1.5, 3.0e-6),
        ]
        data = Vector{Dict{Symbol, Any}}()
        for (b, w, fz, e, g) in cells
            push!(data, Dict{Symbol, Any}(
                :B_nT => b, :omega => w,
                :fz_total => fz, :E => e, :grad_norm => g,
                :conv => true))
        end
        meta = Dict{Symbol, Any}(:conv_column => :conv)
        return SweepResult(axes, observables, data; meta=meta)
    end

    @testset "to_viewspec — 2-axis heatmap smoke" begin
        result = _minimal_sweep_result()
        spec = to_viewspec(result)
        @test spec isa AbstractDict
        @test occursin("vega", lowercase(String(spec["\$schema"])))
        @test spec["_view_shape"] == "heatmap"
        # 2-axis path emits a vconcat of hconcat panel rows; with three
        # observables it must be non-empty.
        @test haskey(spec, "vconcat") && !isempty(spec["vconcat"])
        @test haskey(spec, "_panels_count") && spec["_panels_count"] >= 1
    end

    @testset "write_viewspec / write_golden_per_cell_table — JSON round-trip" begin
        result = _minimal_sweep_result()
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
