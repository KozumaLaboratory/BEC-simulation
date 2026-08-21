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
# USE
#   julia --project=. scripts/validation/klaus_weff_cloud_size.jl <runs-root> \
#         [--field B5p2nT] [--csv out.csv]

using JLD2
using Printf

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
    arm(dir; hold_duration, dt, save_every) -> NamedTuple | String

Cloud-size and `P_adj` summary for one run directory, or a String naming why it
could not be read.
"""
function arm(dir::AbstractString; hold_duration::Float64=5.5292,
    dt::Float64=0.005, save_every::Int=100)
    f = joinpath(dir, "point_001.jld2")
    isfile(f) || return "no point_001.jld2"
    JLD2.jldopen(f, "r") do g
        haskey(g, "dynamics") || return "no dynamics block"
        d = g["dynamics"]
        haskey(d, "psi_snapshots_streamed") || return "no psi_snapshots_streamed"
        box = g["grid_box_size"]
        grp = d["psi_snapshots_streamed"]
        fk = _frame_keys(grp)
        isempty(fk) && return "snapshot group carries no frames"

        r = [radial_rms(grp[k], box) for k in fk]

        # P_adj on the SAME axis as the snapshots, since both are snapshot-derived.
        adj = Float64[]
        if haskey(d, "component_populations")
            P = d["component_populations"]
            P = P isa AbstractMatrix ? P : permutedims(reduce(hcat, P))
            size(P, 1) == length(fk) ||
                return "cadence mismatch: $(size(P,1)) population rows vs " *
                       "$(length(fk)) snapshot frames — do not index one by the other"
            adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        end

        nhold = max(1, Int(floor(hold_duration / (dt * save_every))))
        lo = max(1, length(fk) - nhold + 1)

        w = @view adj[lo:end]
        k_hold = isempty(adj) ? 0 : lo - 1 + argmax(w)
        k_whole = isempty(adj) ? 0 : argmax(adj)
        # "Peaks INSIDE the hold" means the maximum over the whole trajectory
        # lands in the hold window — not that the windowed argmax exists, which
        # it always does. At 10.4 nT this is the flag that split the arms.
        peaks_inside = !isempty(adj) && k_whole >= lo

        (; nframes=length(fk), hold_from=lo,
            r_hold_start=r[lo], r_end=r[end], r_min=minimum(r), r_max=maximum(r),
            expansion=r[end] / r[lo],
            padj_peak=isempty(adj) ? NaN : adj[k_hold],
            padj_frame=k_whole, peaks_inside,
            padj_final=isempty(adj) ? NaN : adj[end], r)
    end
end

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
    for d in dirs
        L = label(d)
        a = arm(d)
        if a isa String
            push!(failures, @sprintf("  w=%.3f hold=%s n=%s : %s", L.weff, L.hold, L.n, a))
            continue
        end
        @printf("%-7.3f %-5s %-4s | %6d %8.4f %8.4f %8.4f | %8.5f %6d %-6s\n",
            L.weff, L.hold, L.n, a.nframes, a.r_hold_start, a.r_end, a.expansion,
            a.padj_peak, a.padj_frame, a.peaks_inside ? "YES" : "no")
        push!(rows, (L, a))
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
        for (L, a) in sort(dbl; by=x -> x[1].weff)
            m = findfirst(r -> r[1].weff ≈ L.weff && r[1].hold == "1p0" &&
                    r[1].n == L.n, rows)
            if m === nothing
                @printf("  w_eff=%.3f hold=%s : %.5f  (no 1x partner to compare)\n",
                    L.weff, L.hold, a.padj_peak)
            else
                b = rows[m][2]
                @printf("  w_eff=%.3f : 1x %.5f -> %s %.5f   (ratio %.4f) | " *
                        "expansion %.4f -> %.4f\n",
                    L.weff, b.padj_peak, L.hold, a.padj_peak,
                    a.padj_peak / b.padj_peak, b.expansion, a.expansion)
            end
        end
    end

    if csv !== nothing
        open(csv, "w") do io
            println(io, "weff,field,hold,n,frames,hold_from,r_hold_start,r_end," *
                        "expansion,padj_peak,padj_frame,peaks_inside,padj_final")
            for (L, a) in rows
                @printf(io, "%.3f,%s,%s,%s,%d,%d,%.6f,%.6f,%.6f,%.6f,%d,%s,%.6f\n",
                    L.weff, L.field, L.hold, L.n, a.nframes, a.hold_from,
                    a.r_hold_start, a.r_end, a.expansion, a.padj_peak,
                    a.padj_frame, a.peaks_inside, a.padj_final)
            end
        end
        println("\nwrote ", csv)
    end
end

abspath(PROGRAM_FILE) == @__FILE__ && main(ARGS)
