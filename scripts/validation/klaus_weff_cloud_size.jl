# Radial cloud size across an ω_eff scan — the observable that settled 10.4 nT.
#
# WHY A DIFFERENT QUANTITY RATHER THAN A BETTER READING
#
# At 10.4 nT the population observable (`P_adj`) was re-read many ways — peak,
# mean, final, three hold windows, two grid sizes — and every reading disagreed
# with the others about the ordering of the arms. What settled it was looking at
# the CLOUD instead: the quench excites a breathing mode, `ω_eff` sets its
# frequency, the hold has fixed length, so the endpoint size is a function of
# BREATHING PHASE. The four arms with least expansion are exactly the four whose
# `P_adj` peaks inside the hold, and doubling the hold moves the ratio — which a
# resonance could not do. That data had been in the cache since the first scan
# and nobody had looked at it (#443, #444).
#
# So this script reads `psi_snapshots_streamed` and reports the radial RMS, and
# the ordering advice is: look at another quantity before inventing another
# reading of the one you have.
#
#     r(t) = sqrt( Σ n_xy(x,y) (x² + y²) / Σ n_xy(x,y) ),  n_xy = Σ_z Σ_c |ψ|²
#
# TWO THINGS THIS FILE REFUSES TO DO
#
# 1. It does not index the snapshot axis by `times`. `component_populations`
#    (42 rows here) is derived from the psi snapshots and `times` (43) from the
#    scalar sampler. Those are DIFFERENT CADENCES, not an off-by-one. The hold
#    window is derived from the config — `nhold = floor(hold/(dt*save_every))` —
#    exactly as `klaus_weff_extract.jl` does, and the two agreeing on frame 32
#    for the 8 ms arms is the check.
#
# 2. It does not report a number for an arm it could not read. A missing point
#    file, a missing snapshot group, or a frame count that disagrees with
#    `component_populations` is printed as a named failure. An arm that silently
#    vanishes from a scan is how a structure becomes visible that is really a
#    gap in the corpus.
#
# MIGRATED TO `reanalyze` (#483, 2026-08-26). Nine numbers come off two series in
# ONE read of each arm — which is why the entry point grew `observables = [...]`
# rather than this file staying bespoke: reading streamed ψ snapshots once per
# observable would have cost nine passes over the expensive part.
#
#   * The window and the reductions are `ObservableDefinition`s, so the vintage of
#     the arms is recorded beside the table and the output says in
#     machine-readable form that it has not been through the ancestor gate.
#   * `reference_reduction` re-states the window and the reductions inline and is
#     differenced against `reanalyze` on every arm. Unlike `lt64_endpoint_verdict.jl`,
#     whose reference re-opens the file, this one reduces THE SAME arrays: a
#     differential over a shared read gates the window and the reduction, which is
#     what drifts, and CANNOT see an error in the extractor itself. Said plainly
#     rather than implied, because a differential that checks less than it looks
#     like is worse than none.
#   * The CSV is `stamped_csv`. It was a bare `open(csv, "w")` until 2026-08-26 —
#     a measurement file that could not say what produced it.
#
# USE
#   julia --project=. scripts/validation/klaus_weff_cloud_size.jl <runs-root> \
#         [--field B5p2nT] [--csv out.csv]

using JLD2
using JSON
using Printf
using SpinorBEC

"""Frame keys of a streamed-snapshot group, in frame order."""
function _frame_keys(grp)
    ks = filter(k -> startswith(k, "frame_"), keys(grp))
    sort!(ks; by=k -> parse(Int, split(k, '_')[2]))
    ks
end

"""
    radial_rms(psi, box) -> Float64

Density-weighted transverse RMS radius of a (nx, ny, nz, D) spinor, in the same
length units as `box`. Summed over BOTH the z axis and the spin index: the
breathing mode is a motion of the whole cloud, and picking one component would
mix the cascade's population transfer into a size measurement.
"""
function radial_rms(psi::AbstractArray{<:Complex, 4}, box)
    nx, ny, nz, _ = size(psi)
    x = range(-box[1] / 2, box[1] / 2; length=nx + 1)[1:nx]
    y = range(-box[2] / 2, box[2] / 2; length=ny + 1)[1:ny]
    num = 0.0
    den = 0.0
    @inbounds for j in 1:ny, i in 1:nx
        nxy = 0.0
        for c in axes(psi, 4), k in 1:nz
            nxy += abs2(psi[i, j, k, c])
        end
        num += nxy * (x[i]^2 + y[j]^2)
        den += nxy
    end
    den > 0 ? sqrt(num / den) : NaN
end

"""
    arm_series(path) -> Dict | String

The two per-frame series of one stored point — radial RMS of the cloud and
`P_adj` — or a String naming why the arm could not be read. No window and no
reduction: those are the `ObservableDefinition`s below.

`P_adj` is `nothing` rather than absent when the populations were not saved, so a
snapshot-only arm still yields its cloud sizes and is visibly missing only the
population numbers.
"""
function arm_series(path::AbstractString)
    JLD2.jldopen(path, "r") do g
        haskey(g, "dynamics") || return "no dynamics block"
        d = g["dynamics"]
        haskey(d, "psi_snapshots_streamed") || return "no psi_snapshots_streamed"
        box = g["grid_box_size"]
        grp = d["psi_snapshots_streamed"]
        fk = _frame_keys(grp)
        isempty(fk) && return "snapshot group carries no frames"

        r = [radial_rms(grp[k], box) for k in fk]

        # P_adj on the SAME axis as the snapshots, since both are snapshot-derived.
        adj = nothing
        if haskey(d, "component_populations")
            P = d["component_populations"]
            P = P isa AbstractMatrix ? P : permutedims(reduce(hcat, P))
            size(P, 1) == length(fk) ||
                return "cadence mismatch: $(size(P,1)) population rows vs " *
                       "$(length(fk)) snapshot frames — do not index one by the other"
            adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        end
        Dict{String, Any}("r" => r, "P_adj" => adj)
    end
end

"The base hold of the ω_eff scan, in internal time units. `hold2p0x` arms hold twice that."
const HOLD_BASE = 5.5292

hold_frames(hold_duration::Real) =
    SpinorBEC.hold_window_frames(hold_duration; dt=0.005, save_every=100)

"""
    observables(nhold; legacy_nhold=nothing) -> Vector{ObservableDefinition}

The nine quantities this driver reduces, declared before any of them exists, all
off ONE read per arm.

`legacy_nhold` adds the window this file used for EVERY arm until 2026-08-26: a
fixed 11 frames, taken from the base hold even on the `hold2p0x` arms, whose hold
is twice as long. That is the defect §12.1 corrected one level up and
`klaus_weff_extract.jl` already carries the fix for ("two hold scales are two
observables"), and the two drivers read the same arms and disagreed about it. The
old window is REPORTED rather than deleted, because the hold-doubling comparison
below was read off it — but the per-arm hold is the one to quote.
"""
function observables(nhold::Int; legacy_nhold::Union{Nothing, Int}=nothing)
    obs = SpinorBEC.ObservableDefinition[
        SpinorBEC.ObservableDefinition("r at hold start"; series="r",
            window=:last, window_frames=nhold, reduction=:first, boundary="n/a"),
        SpinorBEC.ObservableDefinition("r at end"; series="r",
            window=:all, reduction=:final, boundary="n/a"),
        SpinorBEC.ObservableDefinition("r min"; series="r",
            window=:all, reduction=:min, boundary="n/a"),
        SpinorBEC.ObservableDefinition("r max"; series="r",
            window=:all, reduction=:max, boundary="n/a"),
        # `accept`, not `reject`: the flag this driver reads is `peaks_inside`,
        # which is precisely a statement about where the argmax fell, so
        # withholding the edge cases would delete the evidence.
        SpinorBEC.ObservableDefinition("peak P_adj in hold"; series="P_adj",
            window=:last, window_frames=nhold, reduction=:max, boundary="accept"),
        SpinorBEC.ObservableDefinition("P_adj argmax over whole trajectory";
            series="P_adj", window=:all, reduction=:argmax, boundary="n/a"),
        SpinorBEC.ObservableDefinition("final P_adj"; series="P_adj",
            window=:all, reduction=:final, boundary="n/a"),
    ]
    legacy_nhold === nothing || legacy_nhold == nhold ||
        push!(obs, SpinorBEC.ObservableDefinition(
            "peak P_adj in last $legacy_nhold frames (pre-2026-08-26 window)";
            series="P_adj", window=:last, window_frames=legacy_nhold,
            reduction=:max, boundary="accept"))
    obs
end

"""
    reference_reduction(r, adj; nhold) -> NamedTuple

The reduction this file performed inline until 2026-08-26, kept and differenced
against `reanalyze` on every arm.

It reduces THE SAME arrays rather than re-opening the file: what drifts between a
bespoke driver and an entry point is the window and the reduction, and that is
what this gates. It cannot see an error in `arm_series` itself — stated here
because a differential that checks less than it appears to is worse than none.
"""
function reference_reduction(r::AbstractVector, adj; nhold::Int)
    lo = max(1, length(r) - nhold + 1)
    has = adj !== nothing && !isempty(adj)
    w = has ? (@view adj[lo:end]) : nothing
    k_hold = has ? lo - 1 + argmax(w) : 0
    k_whole = has ? argmax(adj) : 0
    # "Peaks INSIDE the hold" means the maximum over the whole trajectory lands in
    # the hold window — not that the windowed argmax exists, which it always does.
    # At 10.4 nT this is the flag that split the arms.
    (; nframes=length(r), hold_from=lo,
        r_hold_start=r[lo], r_end=r[end], r_min=minimum(r), r_max=maximum(r),
        expansion=r[end] / r[lo],
        padj_peak=has ? adj[k_hold] : NaN,
        padj_frame=k_whole, peaks_inside=has && k_whole >= lo,
        padj_final=has ? adj[end] : NaN)
end

"The hold multiplier `1p0` / `2p0` in a run-directory name, as a number."
hold_multiplier(s::AbstractString) = parse(Float64, replace(s, "p" => "."))

"""ω_eff and hold multiplier parsed out of a run-directory name."""
function label(dir)
    b = basename(dir)
    m = match(r"klaus_weff(\d)p(\d+)_B([\dp]+nT)(_hold([\dp]+)x)?(_n(\d+))?", b)
    m === nothing && return (; weff=NaN, field="?", hold="1p0", n="32")
    (; weff=parse(Float64, m[1] * "." * m[2]), field=m[3],
        hold=something(m[5], "1p0"), n=something(m[7], "32"))
end

function main(args)
    root = args[1]
    field = "B5p2nT"
    csv = nothing
    i = 2
    while i <= length(args)
        if args[i] == "--field"
            field = args[i + 1]
            i += 2
        elseif args[i] == "--csv"
            csv = args[i + 1]
            i += 2
        else
            i += 1
        end
    end

    dirs = sort(filter(readdir(root; join=true)) do d
        isdir(d) && occursin("klaus_weff", basename(d)) && occursin(field, basename(d))
    end; by=d -> (label(d).hold, label(d).n, label(d).weff))

    isempty(dirs) && error("no run directories matching $field under $root")

    @printf("\n%s — %d arms\n", field, length(dirs))
    println("="^108)
    @printf("%-7s %-5s %-4s | %6s %8s %8s %8s | %8s %6s %-6s\n",
        "w_eff", "hold", "n", "frames", "r(hold0)", "r(end)", "r_end/r0",
        "P_adj", "frame", "inside")
    println("-"^108)

    rows = []
    failures = String[]
    records = Dict{String, Any}()

    # ONE read per arm, every observable off it. Grouped by hold scale, because
    # two hold scales are two windows and one heading over both is the defect
    # §12.1 corrected — see `observables`.
    groups = Dict{Float64, Vector{String}}()
    for d in dirs
        push!(get!(groups, hold_multiplier(label(d).hold), String[]), d)
    end

    for mult in sort(collect(keys(groups)))
        gdirs = groups[mult]
        nhold = hold_frames(mult * HOLD_BASE)
        legacy = hold_frames(HOLD_BASE)
        obs = observables(nhold; legacy_nhold=legacy)
        # The extraction is cached so the reference reduction below can re-reduce
        # THE SAME arrays without a second pass over the ψ snapshots.
        cache = Dict{String, Any}()
        m = SpinorBEC.reanalyze(p -> (cache[p] = arm_series(p)), gdirs;
            observables=obs, declare=SpinorBEC.REANALYSIS_DECLARATION, verbose=false)
        records["hold_$(mult)x"] = SpinorBEC.reanalysis_record(m)
        legacy_name = "peak P_adj in last $legacy frames (pre-2026-08-26 window)"

        for d in gdirs
            L = label(d)
            b = basename(d)
            lbl = haskey(m["r at end"].values, b) ? b :
                  first(sort!([k for k in keys(m["r at end"].values)
                               if startswith(k, b * "/")]; lt=isless))
            # An arm that could not be read at all, OR one where a declared
            # window does not fit its frame count — a hold longer than the array
            # is refused rather than clamped, and that refusal is a fact about
            # the arm, so it is named here rather than crashing the scan.
            refused = [n for n in keys(m) if haskey(m[n].failures, lbl)]
            if !haskey(m.paths, lbl) || !isempty(refused)
                why = isempty(refused) ? "no value" :
                      "$(first(refused)): $(m[first(refused)].failures[lbl])"
                push!(failures,
                    @sprintf("  w=%.3f hold=%s n=%s : %s", L.weff, L.hold, L.n, why))
                continue
            end

            v(name) = m[name].values[lbl]
            r_start, r_end = v("r at hold start"), v("r at end")
            a = (; nframes=m["r at end"].readings[lbl].n,
                hold_from=first(m["r at hold start"].windows[lbl]),
                r_hold_start=r_start, r_end=r_end,
                r_min=v("r min"), r_max=v("r max"),
                expansion=r_end / r_start,
                padj_peak=something(v("peak P_adj in hold"), NaN),
                padj_frame=something(v("P_adj argmax over whole trajectory"), 0.0) |> Int,
                # "Peaks INSIDE the hold": the WHOLE-trajectory maximum lands in
                # the hold window, not merely that a windowed argmax exists.
                peaks_inside=v("P_adj argmax over whole trajectory") !== nothing &&
                             v("P_adj argmax over whole trajectory") >=
                             first(m["peak P_adj in hold"].windows[lbl]),
                padj_final=something(v("final P_adj"), NaN),
                padj_peak_legacy=haskey(m, legacy_name) ? v(legacy_name) : nothing)

            # THE REFERENCE. The window and the reductions, re-stated inline and
            # differenced — over the same arrays, so this gates the reduction and
            # not the read (see `reference_reduction`).
            pay = cache[m.paths[lbl]]
            ref = reference_reduction(pay["r"], pay["P_adj"]; nhold=nhold)
            same = ref.nframes == a.nframes && ref.hold_from == a.hold_from &&
                   ref.r_hold_start == a.r_hold_start && ref.r_end == a.r_end &&
                   ref.r_min == a.r_min && ref.r_max == a.r_max &&
                   ref.padj_frame == a.padj_frame &&
                   ref.peaks_inside == a.peaks_inside &&
                   isequal(ref.padj_peak, a.padj_peak) &&
                   isequal(ref.padj_final, a.padj_final)
            if !same
                push!(failures,
                    @sprintf("  w=%.3f hold=%s n=%s : REFERENCE DISAGREES — ",
                        L.weff, L.hold, L.n) *
                    @sprintf("inline (peak %.6f f%d inside %s) vs reanalyze ",
                        ref.padj_peak, ref.padj_frame, ref.peaks_inside) *
                    @sprintf("(peak %.6f f%d inside %s). Quote neither.",
                        a.padj_peak, a.padj_frame, a.peaks_inside))
                continue
            end

            @printf("%-7.3f %-5s %-4s | %6d %8.4f %8.4f %8.4f | %8.5f %6d %-6s\n",
                L.weff, L.hold, L.n, a.nframes, a.r_hold_start, a.r_end, a.expansion,
                a.padj_peak, a.padj_frame, a.peaks_inside ? "YES" : "no")
            if a.padj_peak_legacy !== nothing && a.padj_peak_legacy != a.padj_peak
                @printf("        ^ hold is %.1fx the base; over the %d-frame window this file used until 2026-08-26 the peak reads %.5f\n",
                    mult, legacy, a.padj_peak_legacy)
            end
            push!(rows, (L, a))
        end
    end

    if !isempty(failures)
        println("\nARMS THAT COULD NOT BE READ (named, not skipped):")
        foreach(println, failures)
    end

    # The two structures the prediction is about, side by side.
    base = filter(r -> r[1].hold == "1p0" && r[1].n == "32", rows)
    if length(base) >= 3
        println("\nEXPANSION ORDERING (least-expanded first) — the breathing-phase reading")
        println("predicts these coincide with the arms whose P_adj peaks inside the hold.")
        for (L, a) in sort(base; by=x -> x[2].expansion)
            @printf("  w_eff=%.3f  r_end/r0=%.4f  peaks_inside=%s\n",
                L.weff, a.expansion, a.peaks_inside ? "YES" : "no")
        end
        ins = [L.weff for (L, a) in base if a.peaks_inside]
        @printf("\n  arms peaking inside the hold: %s\n",
            isempty(ins) ? "NONE — the 10.4 nT two-group structure is absent here" :
            string(ins))
    end

    # Hold-doubling: the discriminator. A resonance cannot move.
    dbl = filter(r -> r[1].hold != "1p0", rows)
    if !isempty(dbl)
        println("\nHOLD DOUBLING — a resonance does not move, a phase does")
        println("  Two windows are quoted for the doubled arms. `hold` reduces each")
        println("  arm over ITS OWN hold; `fixed` is the base-hold window this file")
        println("  used for both until 2026-08-26 — the one the earlier reading was")
        println("  taken off. They answer different questions and neither replaces")
        println("  the other: same-window is the like-for-like comparison, own-hold")
        println("  is the observable the name claims.")
        for (L, a) in sort(dbl; by=x -> x[1].weff)
            k = findfirst(r -> r[1].weff ≈ L.weff && r[1].hold == "1p0" &&
                    r[1].n == L.n, rows)
            if k === nothing
                @printf("  w_eff=%.3f hold=%s : %.5f  (no 1x partner to compare)\n",
                    L.weff, L.hold, a.padj_peak)
                continue
            end
            b = rows[k][2]
            @printf("  w_eff=%.3f : 1x %.5f -> %s %.5f   (ratio %.4f, own hold) | expansion %.4f -> %.4f\n",
                L.weff, b.padj_peak, L.hold, a.padj_peak,
                a.padj_peak / b.padj_peak, b.expansion, a.expansion)
            a.padj_peak_legacy === nothing && continue
            @printf("               fixed base-hold window: %s %.5f (ratio %.4f)\n",
                L.hold, a.padj_peak_legacy, a.padj_peak_legacy / b.padj_peak)
        end
    end

    if csv !== nothing
        # STAMPED, not `open(csv, "w")`. This wrote a bare CSV until 2026-08-26,
        # which is what `measurement_provenance.jl` exists to stop: a file that
        # cannot say what produced it, aggregated later as if it could.
        SpinorBEC.stamped_csv(csv,
            ("scripts/validation/klaus_weff_cloud_size.jl",);
            header="weff,field,hold,n,frames,hold_from,r_hold_start,r_end," *
                   "expansion,padj_peak,padj_frame,peaks_inside,padj_final," *
                   "r_min,r_max,padj_peak_fixed_base_window") do io
            for (L, a) in rows
                @printf(io, "%.3f,%s,%s,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%s,%.6f,%.6f,%.6f,%s\n",
                    L.weff, L.field, L.hold, L.n, a.nframes, a.hold_from,
                    a.r_hold_start, a.r_end, a.expansion, a.padj_peak,
                    a.padj_frame, a.peaks_inside, a.padj_final, a.r_min, a.r_max,
                    a.padj_peak_legacy === nothing ? "" :
                    @sprintf("%.6f", a.padj_peak_legacy))
            end
        end
        # The vintage of the arms, and the machine-readable statement that a
        # re-read has not been through the ancestor gate. Beside the CSV, because
        # that is the file a document will cite.
        sidecar = replace(csv, r"\.csv$" => "") * "_reanalysis.json"
        open(sidecar, "w") do io
            JSON.print(io, records, 2)
        end
        println("\nwrote ", csv)
        println("wrote ", sidecar, "  (vintage + `admissible: false`)")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
