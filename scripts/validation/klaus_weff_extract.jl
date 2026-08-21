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
function peak_padj(dir::AbstractString; hold_duration::Float64=5.5292,
    dt::Float64=0.005, save_every::Int=100)
    f = joinpath(dir, "point_001.jld2")
    isfile(f) || return nothing
    JLD2.jldopen(f, "r") do g
        haskey(g, "dynamics") || return nothing
        d = g["dynamics"]
        haskey(d, "component_populations") || return nothing
        cp = d["component_populations"]
        P = cp isa AbstractMatrix ? cp : permutedims(reduce(hcat, cp))
        adj = [P[i, 2] + P[i, 3] for i in axes(P, 1)]
        # THE PEAK MUST BE TAKEN INSIDE THE HOLD. Over the whole trajectory the
        # maximum can be the PRE-HOLD TRANSIENT, and at 10.4 nT it is: §12.1 found
        # four arms differing only in the hold returning peak P_adj = 0.26050 to
        # five decimals, argmax at frame 29, hold starting at 32.
        #
        # THE WINDOW CANNOT COME FROM `times`. `component_populations` is derived
        # from the psi SNAPSHOTS and `times` from the scalar sampler; they are
        # different cadences, not an off-by-one (42 against 43 here). Indexing one
        # by the other is wrong in principle, and the first version of this fix
        # did exactly that and threw a BoundsError -- which is the lucky outcome,
        # because an alignment that merely LOOKED plausible would have produced
        # numbers.
        #
        # The hold is the last dynamics step, so its frames are the last
        #     floor(hold_duration / (dt * save_every))
        # of the array, which is derivable from the config alone. For the 8 ms
        # arms: 5.5292 / (0.005 * 100) = 11.06 -> 11 frames, 42 - 11 = 31, so the
        # hold starts at frame 32 -- the number §12.1 states independently. That
        # agreement is the check; without it this is another guess.
        nhold = max(1, Int(floor(hold_duration / (dt * save_every))))
        lo = max(1, length(adj) - nhold + 1)
        k = lo - 1 + argmax(@view adj[lo:end])
        (peak=adj[k], frame=k, nframes=length(adj), hold_from=lo,
            whole=maximum(adj), whole_frame=argmax(adj))
    end
end

"""Rank correlation between two readings — do they ORDER the arms alike?"""
function _spearman(a::AbstractVector, b::AbstractVector)
    n = length(a)
    n < 2 && return NaN
    ra = sortperm(sortperm(a))
    rb = sortperm(sortperm(b))
    ma, mb = sum(ra) / n, sum(rb) / n
    num = sum((ra[i] - ma) * (rb[i] - mb) for i in 1:n)
    da = sqrt(sum((ra[i] - ma)^2 for i in 1:n))
    db = sqrt(sum((rb[i] - mb)^2 for i in 1:n))
    (da == 0 || db == 0) ? NaN : num / (da * db)
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
        # hold_scale is in the directory name, and the window scales with it.
        hd = occursin("hold2p0x", basename(d)) ? 2 * 5.5292 : 5.5292
        p = peak_padj(d; hold_duration=hd)
        if p === nothing
            println("MISSING dynamics: ", basename(d))
            continue
        end
        push!(rows, (; c..., p...))
    end
    isempty(rows) && (println("no arms found under $root"); return nothing)

    for fld in sort(unique(r.field_nt for r in rows))
        sel = sort([r for r in rows if r.field_nt == fld]; by=r -> r.weff)
        println("\nB = $(fld) nT  ($(length(sel)) arms)")
        base = findfirst(r -> r.weff == 1.0, sel)
        for r in sel
            rel = base === nothing ? NaN : 100 * (r.peak - sel[base].peak) / sel[base].peak
            flag = r.peak == r.whole ? "  " : " *"   # * = whole-trajectory max was the transient
            @printf(
                "  weff %.3f   peak %.5f (f%2d)  mean %.5f  final %.5f%s  %+6.2f %%\n",
                r.weff, r.peak, r.frame, r.mean, r.final, flag, rel)
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

        # DOES THE ORDERING SURVIVE THE DEFINITION? Rank the arms by each reading.
        # If the three disagree, the ordering is a property of the extraction and
        # no optimum should be quoted from this field — which is the state 10.4 nT
        # was in when a number was published from it twice.
        if length(sel) > 2
            pv = [r.peak for r in sel]
            mv = [r.mean for r in sel]
            fv = [r.final for r in sel]
            topw(v) = sel[argmax(v)].weff
            agree = topw(pv) == topw(mv) == topw(fv)
            @printf("  argmax weff: peak %.3f  mean %.3f  final %.3f  -> %s\n",
                topw(pv), topw(mv), topw(fv),
                agree ? "AGREE" : "DISAGREE - quote no optimum at this field")
            @printf("  rank corr: (peak,mean) %.3f   (peak,final) %.3f\n",
                _spearman(pv, mv), _spearman(pv, fv))
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
