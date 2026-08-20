# Read peak P_adj out of the ω_eff scan arms and print the curve.
#
# SEPARATE FROM THE TRAJECTORY JOBS ON PURPOSE. A shard reaped at h_rt never
# reads its own completed work, so classification must be a step that runs after
# and reads whatever landed — not the tail of each arm.
#
# `P_adj` is defined RELATIVE TO THE PREPARED STATE. These arms seed `m_plus_F`,
# which is component 1, so the two rungs down the cascade are components 2 and 3.
# Hard-coding it to (D-1, D-2) is correct only for an m = -F seed and once
# produced `P_adj = 0.00000` on the one arm built to test for a null.
#
# USE
#   julia --project=. scripts/validation/klaus_weff_extract.jl runs [--csv out.csv]

using JLD2
using Printf

"""
    peak_padj(dir) -> NamedTuple

`(peak, frame, nframes, weff, field_nt)` for one run directory, or `nothing` when
the point file is absent or carries no dynamics — a missing arm must be visibly
missing rather than silently skipped.
"""
function peak_padj(dir::AbstractString)
    f = joinpath(dir, "point_001.jld2")
    isfile(f) || return nothing
    JLD2.jldopen(f, "r") do g
        haskey(g, "dynamics") || return nothing
        d = g["dynamics"]
        haskey(d, "component_populations") || return nothing
        cp = d["component_populations"]
        P = cp isa AbstractMatrix ? cp : permutedims(reduce(hcat, cp))
        adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        (peak=maximum(adj), frame=argmax(adj), nframes=size(P, 1))
    end
end

"""Parse `klaus_weff0p714_B5p2nT_<hash>` back into its two scan coordinates."""
function coords(name::AbstractString)
    m = match(r"klaus_weff(\d+p\d+)_B(\d+p\d+)nT", name)
    m === nothing && return nothing
    (weff=parse(Float64, replace(m.captures[1], "p" => ".")),
        field_nt=parse(Float64, replace(m.captures[2], "p" => ".")))
end

function main(args)
    root = isempty(args) ? "runs" : args[1]
    csv = nothing
    i = findfirst(==("--csv"), args)
    i === nothing || (csv = args[i + 1])

    rows = NamedTuple[]
    for d in sort(readdir(root; join=true))
        isdir(d) || continue
        c = coords(basename(d))
        c === nothing && continue
        p = peak_padj(d)
        if p === nothing
            println("MISSING dynamics: ", basename(d))
            continue
        end
        push!(rows, (; c..., p...))
    end
    isempty(rows) && (println("no arms found under $root"); return)

    for fld in sort(unique(r.field_nt for r in rows))
        sel = sort([r for r in rows if r.field_nt == fld]; by=r -> r.weff)
        println("\nB = $(fld) nT  ($(length(sel)) arms)")
        base = findfirst(r -> r.weff == 1.0, sel)
        for r in sel
            rel = base === nothing ? NaN : 100 * (r.peak - sel[base].peak) / sel[base].peak
            @printf("  weff %.3f   peak P_adj %.5f   frame %2d/%2d   %+6.2f %% vs weff=1\n",
                r.weff, r.peak, r.frame, r.nframes, rel)
        end
        # The positive control. If the per-step `potential:` override were
        # ignored, every arm would return the SAME number -- so a flat scan is a
        # plumbing failure, not a physical null, and must not be read as one.
        spread = maximum(r.peak for r in sel) - minimum(r.peak for r in sel)
        if length(sel) > 1 && spread < 1e-6
            println("  !! CONTROL FAILED: spread $(spread) over $(length(sel)) arms.")
            println("  !! Every arm returned the same value. The `potential:` override")
            println("  !! is not reaching the hold step. This is NOT a physical null.")
        elseif length(sel) > 1
            @printf("  control OK: spread %.5f over %d arms\n", spread, length(sel))
        end
    end

    if csv !== nothing
        open(csv, "w") do io
            println(io, "field_nT,weff,peak_padj,frame,nframes")
            for r in sort(rows; by=r -> (r.field_nt, r.weff))
                @printf(io, "%.1f,%.3f,%.6f,%d,%d\n",
                    r.field_nt, r.weff, r.peak, r.frame, r.nframes)
            end
        end
        println("\nwrote $csv")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
