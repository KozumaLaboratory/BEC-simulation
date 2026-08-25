# The three stored-run drivers that were NOT migrated when `reanalyze` landed
# (#483), now routed through it — gated here on synthetic fixtures.
#
# WHY A TEST AND NOT A RUN. None of the three can be executed in CI: their arms
# are 94 GiB of stored ψ on a cluster and the numbers they print were taken off
# runs nobody is going to repeat. So the migration's safety cannot come from
# "the output looks the same"; it has to come from each driver keeping the
# reduction it used to perform, inline, and DIFFERENCING it against `reanalyze`
# on every arm. This file gates that the differential exists, that it is exact,
# and — the part that is easy to skip — that the fixtures could tell the two
# apart if they disagreed.
#
# The positive control in each case is the same shape: the window must MATTER on
# the fixture. A differential over data where the whole trajectory and the hold
# give the same number is satisfied by a window that does nothing, which is the
# defect 97ec124e fixed and the degenerate-knob trap in another costume.

using Test
using JLD2
using JSON
using Printf
using Statistics
using SpinorBEC

const _RDM_REPO = normpath(joinpath(@__DIR__, "..", ".."))

module _LT64
include(
    joinpath(normpath(joinpath(@__DIR__, "..", "..")),
        "scripts", "validation", "lt64_endpoint_verdict.jl"),
)
end

module _Cloud
include(
    joinpath(normpath(joinpath(@__DIR__, "..", "..")),
        "scripts", "validation", "klaus_weff_cloud_size.jl"),
)
end

module _K2022
include(joinpath(normpath(joinpath(@__DIR__, "..", "..")),
    "scripts", "klaus2022_reanalyse.jl"))
end

# --- fixtures ----------------------------------------------------------------

"Run `f` with stdout captured, and return what it printed."
function _capture(f)
    mktemp() do path, io
        redirect_stdout(f, io)
        close(io)
        read(path, String)
    end
end

"""
30 frames. The maximum of the whole trajectory sits at frame 5 — before the hold
— and the hold (the last `nhold`) rises to a lower, interior second maximum.
That is the shape §12.1 corrected, and without it the window under test could be
replaced by `:all` and every assertion here would still pass.
"""
function _padj30(; scale=1.0)
    s = zeros(Float64, 30)
    for i in 1:10
        s[i] = scale * 0.30 * exp(-((i - 5)^2) / 8)
    end
    for i in 11:30
        s[i] = scale * (0.10 + 0.05 * exp(-((i - 20)^2) / 6))
    end
    s
end

function _write_padj_point(dir, adj; git_hash="15a9f1ee", D=13)
    mkpath(dir)
    P = zeros(Float64, length(adj), D)
    P[:, 2] .= 0.6 .* adj
    P[:, 3] .= 0.4 .* adj
    P[:, 1] .= 1.0 .- adj
    path = joinpath(dir, "point_001.jld2")
    JLD2.jldopen(path, "w") do f
        f["dynamics/component_populations"] = P
        f["env/git_hash"] = git_hash
        f["env/git_dirty"] = true
    end
    path
end

# --- lt64_endpoint_verdict ----------------------------------------------------

@testset "lt64_endpoint_verdict goes through reanalyze (#483)" begin
    # The suite's own constants, derived once. 100.0 / (0.005 * 1000) = 20.
    @test _LT64.HOLD_FRAMES == 20

    mktempdir() do root
        for g in ("baseline", "static", "rotating"), i in 1:7
            _write_padj_point(joinpath(root, "lt64_ens_$(g)_$i"),
                _padj30(; scale=1.0 + 0.01 * i + (g == "static" ? 0.2 : 0.0)))
        end
        # An arm that died before it had a full hold: named, not dropped, and not
        # clamped into a whole-trajectory answer.
        _write_padj_point(joinpath(root, "lt64_ens_baseline_short"), _padj30()[1:8])

        dirs = sort(
            filter(d -> isdir(d) && occursin("lt64_ens", basename(d)),
                readdir(root; join=true)),
        )
        m = SpinorBEC.reanalyze(_LT64.padj_series, dirs;
            observables=[_LT64.OBS_PEAK, _LT64.OBS_ENDPOINT],
            declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
        peak_ra = m[_LT64.OBS_PEAK.name]

        # THE FIXTURE'S OWN CONTROL: the hold peak is not the trajectory's peak.
        good = "lt64_ens_baseline_1"
        ref = _LT64.arm_values(joinpath(root, good))
        @test ref.hold_from == 11
        @test maximum(_padj30(; scale=1.01)) > ref.peak
        # ...and the two statements of the observable agree, exactly.
        @test peak_ra.values[good] == ref.peak
        @test Int(peak_ra.readings[good].argmax) == ref.peak_frame
        @test m[_LT64.OBS_ENDPOINT.name].values[good] == ref.endpoint

        # The short arm is refused rather than answered.
        @test peak_ra.values["lt64_ens_baseline_short"] === nothing
        @test occursin("does not fit", peak_ra.failures["lt64_ens_baseline_short"])

        txt = _capture(() -> _LT64.main([root]))
        @test !occursin("REFERENCE DISAGREES", txt)
        @test occursin("ARMS THAT DID NOT LAND", txt)
        @test occursin("lt64_ens_baseline_short", txt)
        # THE PRE-REGISTERED CRITERION, RE-DERIVED HERE AND COMPARED. #495 asks
        # the migration to show the verdict did not move; the 20 real arms are on
        # the cluster, so what is executable is this: the criterion is restated
        # from the README's formula — pooled sd across the two compared groups,
        # SE_diff = sd·√(1/nb + 1/ns), threshold 2σ — and the number the driver
        # prints must match it. Reading the diff and seeing the block unchanged
        # is not the same as running it.
        @test occursin("VERDICT", txt)
        @test occursin("ADMISSIBLE false", txt)
        ends(pref, sc) = [_padj30(; scale=1.0 + 0.01 * i + sc)[end] for i in 1:7]
        b, s = ends("baseline", 0.0), ends("static", 0.2)
        nb = ns = 7
        sd_pool = sqrt(((nb - 1) * var(b) + (ns - 1) * var(s)) / (nb + ns - 2))
        se_diff = sd_pool * sqrt(1 / nb + 1 / ns)
        nsig = abs(sum(s) / ns - sum(b) / nb) / se_diff
        @test occursin(@sprintf("|diff| / SE    = %.2f sigma", nsig), txt)
        @test occursin(nsig >= 2.0 ? "  ESTABLISHED:" : "  NOT ESTABLISHED", txt)
        @test occursin(@sprintf("SE_diff        = %.5f", se_diff), txt)

        rec = JSON.parsefile(joinpath(root, "lt64_endpoint_verdict_reanalysis.json"))
        @test rec["admissible"] === false
        @test any(r -> occursin("not_ancestor_gated", r), rec["inadmissible_because"])
        @test rec["n_dirty"] == rec["n_points"]
        @test Set(keys(rec["observables"])) ==
            Set([_LT64.OBS_PEAK.name, _LT64.OBS_ENDPOINT.name])
        @test rec["observables"][_LT64.OBS_PEAK.name]["window"] == "last 20"
    end
end

# --- klaus_weff_cloud_size ----------------------------------------------------

"A (4,4,2,2) spinor whose width in x/y grows with `w`, so `radial_rms` moves."
function _psi_frame(w::Float64)
    psi = zeros(ComplexF64, 4, 4, 2, 2)
    for c in 1:2, k in 1:2, j in 1:4, i in 1:4
        x = i - 2.5
        y = j - 2.5
        psi[i, j, k, c] = complex(exp(-(x^2 + y^2) / (2 * w^2)))
    end
    psi
end

"""
30 frames with THREE maxima: the global one at frame 5 (pre-hold), a second at
frame 12 — inside the doubled hold (9:30) but outside the base hold (20:30) — and
a third at 25, inside both.

The middle one is the fixture's whole point: without it the two hold scales
return the same number and the correction this driver's migration carries (one
window per arm's own hold, instead of the base window for both) would be
untestable.
"""
function _padj30_two_scales()
    s = zeros(Float64, 30)
    for i in 1:10
        s[i] = 0.30 * exp(-((i - 5)^2) / 8)
    end
    for i in 11:19
        s[i] = 0.20 + 0.05 * exp(-((i - 12)^2) / 4)
    end
    for i in 20:30
        s[i] = 0.10 + 0.05 * exp(-((i - 25)^2) / 6)
    end
    s
end

function _write_cloud_arm(dir, adj, widths)
    mkpath(dir)
    D = 13
    P = zeros(Float64, length(adj), D)
    P[:, 2] .= 0.6 .* adj
    P[:, 3] .= 0.4 .* adj
    path = joinpath(dir, "point_001.jld2")
    JLD2.jldopen(path, "w") do f
        f["dynamics/component_populations"] = P
        for (i, w) in enumerate(widths)
            f["dynamics/psi_snapshots_streamed/frame_$i"] = _psi_frame(w)
        end
        f["grid_box_size"] = [8.0, 8.0, 4.0]
        f["env/git_hash"] = "306ef71a"
        f["env/git_dirty"] = true
    end
    path
end

@testset "klaus_weff_cloud_size goes through reanalyze (#483)" begin
    @test _Cloud.hold_frames(_Cloud.HOLD_BASE) == 11
    @test _Cloud.hold_frames(2 * _Cloud.HOLD_BASE) == 22

    mktempdir() do root
        adj = _padj30_two_scales()
        widths = [1.0 + 0.02 * i for i in 1:30]
        for w in ("0p714", "1p000", "1p400")
            _write_cloud_arm(joinpath(root, "klaus_weff$(w)_B5p2nT_n32"), adj, widths)
        end
        # A doubled-hold arm: the one whose window this file got wrong for both.
        _write_cloud_arm(joinpath(root, "klaus_weff1p000_B5p2nT_hold2p0x_n32"),
            adj, widths)
        # ...and a doubled-hold arm that died at 15 frames, i.e. shorter than its
        # own 22-frame window. It must be NAMED, and the scan must survive it.
        _write_cloud_arm(joinpath(root, "klaus_weff1p400_B5p2nT_hold2p0x_n32"),
            adj[1:15], widths[1:15])

        path = joinpath(root, "klaus_weff1p000_B5p2nT_n32", "point_001.jld2")
        pay = _Cloud.arm_series(path)
        @test pay isa Dict && length(pay["r"]) == 30 && length(pay["P_adj"]) == 30
        # The cloud size actually varies, or `r at hold start` vs `r at end`
        # would be the same number and the reduction would be untested.
        @test pay["r"][end] > pay["r"][1]

        # THE TWO HOLD SCALES ARE TWO WINDOWS, and on this fixture they differ —
        # which is why the doubled arm now reports both and why one heading over
        # the two was worth correcting.
        r11 = _Cloud.reference_reduction(pay["r"], pay["P_adj"]; nhold=11)
        r22 = _Cloud.reference_reduction(pay["r"], pay["P_adj"]; nhold=22)
        @test r11.hold_from == 20 && r22.hold_from == 9
        @test r11.padj_peak != r22.padj_peak

        csv = joinpath(root, "cloud.csv")
        txt = _capture(() -> _Cloud.main([root, "--field", "B5p2nT", "--csv", csv]))
        @test !occursin("REFERENCE DISAGREES", txt)
        # The short arm is named and the other four still report.
        @test occursin("COULD NOT BE READ", txt)
        @test occursin("does not fit", txt)
        @test occursin("w=1.400 hold=2p0", txt)
        @test occursin("HOLD DOUBLING", txt)
        @test occursin("pre-2026-08-26", txt) ||
            occursin("until 2026-08-26", txt)

        lines = readlines(csv)
        # STAMPED. This wrote a bare CSV until 2026-08-26.
        @test startswith(first(lines), "# provenance:")
        @test occursin("padj_peak_fixed_base_window", lines[2])
        @test length(lines) == 2 + 4

        rec = JSON.parsefile(joinpath(root, "cloud_reanalysis.json"))
        @test Set(keys(rec)) == Set(["hold_1.0x", "hold_2.0x"])
        @test rec["hold_1.0x"]["admissible"] === false
        @test rec["hold_2.0x"]["observables"]["peak P_adj in hold"]["window"] ==
            "last 22"
        # The legacy window is DECLARED on the doubled arms and absent on the
        # base ones, where it would be the same observable twice.
        @test haskey(rec["hold_2.0x"]["observables"],
            "peak P_adj in last 11 frames (pre-2026-08-26 window)")
        @test !haskey(rec["hold_1.0x"]["observables"],
            "peak P_adj in last 11 frames (pre-2026-08-26 window)")
    end
end

# --- klaus2022_reanalyse ------------------------------------------------------

"""
Frames whose θ reaches 0 only at frame 27, and whose stripe order drops when it
does — the situation §6 is about. The pre-registered "last 20 %" window (24:30)
therefore still contains three frames AT THE FULL TILT, while the declared window
(27:30) does not.

That overlap is the fixture's control. If θ reached 0 before the last 20 % began,
the two windows would coincide and the differential would pass for a driver that
ignored the θ condition entirely.
"""
function _k2022_frames(; n=30, tilt_until=26)
    [
        (t=Float64(i), theta=(i <= tilt_until ? deg2rad(35) : 0.0),
            axis_order=(i <= tilt_until ? 3.0 : 1.0) + 0.01 * i,
            null=1.0, prom=(i <= tilt_until ? 2.0 : 0.5), k_mode=0.5 + 0.001 * i,
            misalign=deg2rad(i <= tilt_until ? 4.0 : 20.0)) for i in 1:n
    ]
end

"A saved frames file: striped column densities on a 32² grid, one per time."
function _write_k2022_frames(dir, arm; times)
    nx = ny = 32
    cols = [
        [
            1.0 + 0.2 * sin(2π * 3 * i / nx) *
                  exp(-((i - nx / 2)^2 + (j - ny / 2)^2) / 200)
            for i in 1:nx, j in 1:ny
        ] for _ in times
    ]
    p = joinpath(dir, "$(arm)_frames.jld2")
    JLD2.jldopen(p, "w") do f
        f["times"] = collect(float.(times))
        f["column_density"] = cols
        f["dx"] = 0.25
        f["dy"] = 0.25
    end
    p
end

@testset "klaus2022_reanalyse goes through reanalyze (#483)" begin
    fr = _k2022_frames()
    payload, aux = _K2022.frames_payload(fr)
    @test Set(keys(payload)) ==
        Set(["axis_order", "null", "prom", "k_mode", "misalign_sq", "t"])
    # `misalign` is carried SQUARED so an rms composes out of `:mean`.
    @test payload["misalign_sq"][1] ≈ deg2rad(4.0)^2

    D = 12.0
    mktempdir() do root
        p = joinpath(root, "control_frames.jld2")
        JLD2.jldopen(p, "w") do f
            f["placeholder"] = 1                # no `env/` — an unstamped artifact
        end
        obs = vcat(
            _K2022.window_observables("pre-registered", _K2022.last_20pct),
            _K2022.window_observables("declared", _K2022.theta_reached_zero),
            [_K2022.OBS_BASELINE])
        m = SpinorBEC.reanalyze(_ -> (payload, aux), [p]; observables=obs,
            declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
        label = "control_frames.jld2"
        baseline = m[_K2022.OBS_BASELINE.name].values[label]
        @test baseline == fr[1].axis_order

        pre = _K2022.summarise_from(m, label, "pre-registered", baseline, D)
        fix = _K2022.summarise_from(m, label, "declared", baseline, D)

        # THE REFERENCE, differenced exactly as the driver does it.
        ref_pre = _K2022.summarise(
            [f for (i, f) in enumerate(fr) if _K2022.last_20pct(i, aux)], baseline, D)
        ref_fix = _K2022.summarise(
            [f for (i, f) in enumerate(fr) if _K2022.theta_reached_zero(i, aux)],
            baseline, D)
        @test _K2022.reference_disagreement(ref_pre, pre) === nothing
        @test _K2022.reference_disagreement(ref_fix, fix) === nothing

        # THE FIXTURE'S CONTROL: the two windows must disagree, or this gates
        # nothing. "Last 20 %" of t ∈ [1, 30] is 24:30 — seven frames, three of
        # them still at the full 35° tilt — against 27:30 for the θ→0 window.
        @test pre.n_frames == 7
        @test fix.n_frames == 4
        @test pre.axis_order != fix.axis_order
        @test fix.misalign_deg > pre.misalign_deg

        # And the differential can FAIL — a comparison that cannot report a
        # disagreement is not a check.
        @test _K2022.reference_disagreement(ref_pre, fix) !== nothing

        # The frames files carry no producing commit, and the record says so
        # rather than leaving the vintage to be assumed.
        @test m.vintage.n_unstamped == 1
        @test any(r -> occursin("unstamped", r), m.inadmissible_because)
    end

    # `frame_metrics` still runs end to end on a saved frames file, and names its
    # own absence rather than throwing.
    mktempdir() do root
        p = _write_k2022_frames(root, "stripes"; times=[0.0, 1.0, 2.0])
        fr = _K2022.frame_metrics(p, "stripes", 0.5, 5.0)
        @test fr isa Vector && length(fr) == 3
        @test all(hasproperty(f, :axis_order) for f in fr)
        missing_msg = _K2022.frame_metrics(joinpath(root, "nope_frames.jld2"),
            "stripes", 0.5, 5.0)
        @test missing_msg isa String && occursin("no frames at", missing_msg)
    end

    # ...and `main` itself — read, reduce, difference, write — on a fixture. A
    # gate that stops one call short of the thing that writes the numbers has not
    # covered the driver.
    mktempdir() do root
        # Times spanning the control's θ ramp (0.6 → 0.7 s in internal units), so
        # the pre-registered "last 20 %" window still contains a TILTED frame and
        # the declared window does not. That difference is the driver's subject.
        times = [0.0, 60.0, 120.0, 180.0, 200.0, 250.0]
        for arm in ("stripes", "control")
            _write_k2022_frames(root, arm; times=times)
        end
        results = joinpath(root, "klaus2022_results.json")
        open(results, "w") do io
            JSON.print(io,
                Dict(
                    arm => Dict("k_lo" => 0.5, "k_hi" => 5.0,
                        "cloud_diameter_aho" => 12.0)
                    for arm in ("stripes", "control")
                ), 2)
        end

        txt = _capture(() -> _K2022.main(; results=results, frames=root))
        @test occursin("=== control ===", txt)
        @test occursin("ADMISSIBLE false", txt)

        out = JSON.parsefile(results)
        rec = out["reanalysis"]["control"]["reanalysis"]
        @test rec["admissible"] === false
        # The frames file carries no producing commit; the record says so instead
        # of leaving the vintage to be assumed.
        @test rec["n_unstamped"] == 1
        @test any(r -> occursin("unstamped", r), rec["inadmissible_because"])
        @test rec["observables"]["axis_order (declared)"]["reduction"] == "mean"
        # Both windows are reported, and on the control they really are different
        # windows.
        pre = out["reanalysis"]["control"]["pre_registered_window"]
        dec = out["reanalysis"]["control"]["declared_window"]
        @test pre["n_frames"] > dec["n_frames"]
        @test occursin("neither replaces the other", out["reanalysis"]["note"])
    end
end
