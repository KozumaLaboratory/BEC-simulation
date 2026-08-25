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
using JSON
using Printf
using SpinorBEC

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
        w = @view adj[lo:end]
        k = lo - 1 + argmax(w)
        # THREE READINGS OF ONE HOLD. At 10.4 nT the peak is not well-posed — its
        # maximum sits at the window's first frames, where the decaying pre-hold
        # transient still dominates, and the value moves 37 % with the cut. The
        # answer is not to pick a window but to keep all three and refuse an
        # ordering they disagree on. They fail differently: `peak` is contaminated
        # by the transient, `mean` is diluted by it, `final` is a single sample.
        (peak=adj[k], frame=k, nframes=length(adj), hold_from=lo,
            mean=sum(w) / length(w), final=adj[end],
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

"""
The per-frame `P_adj` series of one arm, for `reanalyze`. The window and the
reduction are NOT here — that is the point of routing through the entry point:
`peak_padj` above states them inline and is kept as the reference this is
differenced against, and only one of the two may own them.
"""
function padj_series(path::AbstractString)
    JLD2.jldopen(path, "r") do g
        haskey(g, "dynamics") || return nothing
        d = g["dynamics"]
        haskey(d, "component_populations") || return nothing
        cp = d["component_populations"]
        P = cp isa AbstractMatrix ? cp : permutedims(reduce(hcat, cp))
        [P[i, 2] + P[i, 3] for i in axes(P, 1)]
    end
end

# The hold window in FRAMES, derivable from the config alone:
# 5.5292 / (0.005 * 100) = 11.06 -> 11. See the note on `peak_padj`.
hold_frames(hold_duration::Float64; dt=0.005, save_every=100) =
    max(1, Int(floor(hold_duration / (dt * save_every))))

function main(args)
    root = isempty(args) ? "runs" : args[1]
    csv = nothing
    i = findfirst(==("--csv"), args)
    i === nothing || (csv = args[i + 1])

    # TWO HOLD SCALES ARE TWO OBSERVABLES. The `hold2p0x` arms are reduced over a
    # window twice as long, so they are grouped and declared separately instead of
    # sharing one column — mixing two window definitions under one heading is the
    # defect §12.1 corrected, one level up.
    arms = Dict{Float64, Vector{String}}()
    for d in sort(readdir(root; join=true))
        isdir(d) || continue
        coords(basename(d)) === nothing && continue
        hd = occursin("hold2p0x", basename(d)) ? 2 * 5.5292 : 5.5292
        push!(get!(arms, hd, String[]), d)
    end
    isempty(arms) && (println("no arms found under $root"); return nothing)

    rows = NamedTuple[]
    records = Dict{String, Any}()
    for hd in sort(collect(keys(arms)))
        dirs = arms[hd]
        obs = SpinorBEC.ObservableDefinition(
            "peak P_adj in hold (hold_duration=$hd)";
            window=:last, window_frames=hold_frames(hd),
            # `accept`, not `reject`: at 10.4 nT the in-hold argmax DOES sit at
            # the window's first frame and the number was still reported, with
            # `mean` and `final` beside it. Withholding it here would delete the
            # evidence the three-reading disagreement is read off. Declared, so
            # nobody has to infer it.
            reduction=:max, boundary="accept")
        ra = SpinorBEC.reanalyze(padj_series, dirs;
            observable=obs, declare=SpinorBEC.REANALYSIS_DECLARATION)
        records["hold_$hd"] = SpinorBEC.reanalysis_record(ra)

        for d in dirs
            label = basename(d)
            r = get(ra.readings, label, nothing)
            if r === nothing
                println("MISSING dynamics: ", label)
                continue
            end
            # THE REFERENCE, KEPT. `peak_padj` states the window and the reduction
            # itself; `reanalyze` states them in the ObservableDefinition. Two
            # independent statements of one observable, differenced on every run
            # — the same discipline the Hamiltonian terms are under, and the only
            # thing that makes a routing change safe on arms nobody can re-run.
            ref = peak_padj(d; hold_duration=hd)
            got = ra.values[label]
            if ref === nothing || got === nothing || ref.peak != got
                println("!! REFERENCE DISAGREES on $label: " *
                        "peak_padj=$(ref === nothing ? "nothing" : ref.peak) " *
                        "reanalyze=$(got === nothing ? "withheld" : got)")
                println("!! One of the two window definitions is wrong. Do not " *
                        "quote either number until they agree.")
                continue
            end
            push!(rows, (; coords(label)..., ref...))
        end
    end
    isempty(rows) && (println("no arms produced a value under $root"); return nothing)

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
        # STAMPED, not `open(csv, "w")`. This wrote a bare CSV until 2026-08-26,
        # which is exactly what `measurement_provenance.jl` exists to stop: a file
        # that cannot say what produced it, aggregated later as if it could.
        SpinorBEC.stamped_csv(csv,
            ("scripts/validation/klaus_weff_extract.jl",);
            header="field_nT,weff,peak_padj,frame,nframes") do io
            for r in sort(rows; by=r -> (r.field_nt, r.weff))
                @printf(io, "%.1f,%.3f,%.6f,%d,%d\n",
                    r.field_nt, r.weff, r.peak, r.frame, r.nframes)
            end
        end
        # The vintage of the arms these numbers came off, and the machine-readable
        # statement that a re-read has not been through the ancestor gate. Beside
        # the CSV, because that is the file a document will cite.
        sidecar = replace(csv, r"\.csv$" => "") * "_reanalysis.json"
        open(sidecar, "w") do io
            JSON.print(io, records, 2)
        end
        println("\nwrote $csv")
        println("wrote $sidecar  (vintage + `admissible: false`)")
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
