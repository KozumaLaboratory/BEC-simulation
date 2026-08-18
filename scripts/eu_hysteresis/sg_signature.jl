# The Stern-Gerlach signature of the κ-dependent transition — a DISCRETE
# observable, which is why it is the deliverable rather than the loop width.
#
# A ring count, a winding number, a level count carries no error bar and needs no
# calibration. The loop width does: it is a difference of two fitted jump fields,
# each of which turned out to depend on the ramp's starting sector and on the
# residual transverse field. What survives all of that is how many Zeeman
# sublevels the cloud ends up in, which a Stern-Gerlach + TOF shot reads directly.
#
#   n_pop  = number of m_F levels holding ≥ `thresh` of the atoms
#   width  = participation ratio 1/Σp², the "effective number of levels", which
#            needs no threshold at all and is reported beside n_pop so the
#            conclusion cannot rest on where the threshold was put
#
# Usage (pure CSV post-processing; no SpinorBEC, no GPU):
#   julia --project=. scripts/eu_hysteresis/sg_signature.jl RAMP_DIR [--thresh=0.05]

using Printf

# Plain-Julia TSV I/O. NOT DelimitedFiles: it is not a direct dependency of this
# package, so it resolves under `--project=.` but NOT in the test environment that
# `Pkg.test()` builds — which is where this file is gated. A post-processing script
# reading tab-separated text does not need a package for it.
"""Read a `writedlm`-produced TSV: header row, then rows. Returns (matrix, colmap)
with numeric fields parsed to Float64 and everything else left as String."""
function read_tsv_matrix(path::AbstractString)
    lines = filter(!isempty, readlines(path))
    isempty(lines) && error("empty file: $path")
    hdr = String.(split(lines[1], '\t'))
    rows = Any[]
    for ln in lines[2:end]
        c = split(ln, '\t')
        length(c) < length(hdr) && continue
        push!(rows, Any[something(tryparse(Float64, String(x)), String(x)) for x in c[1:length(hdr)]])
    end
    isempty(rows) && error("no data rows in $path")
    A = Matrix{Any}(undef, length(rows), length(hdr))
    for (i, r) in enumerate(rows), j in 1:length(hdr)
        A[i, j] = r[j]
    end
    (A, Dict(strip(h) => i for (i, h) in enumerate(hdr)))
end

"""Write rows of NamedTuples as TSV with a header from the first row's keys."""
function write_tsv(path::AbstractString, rows::AbstractVector)
    isempty(rows) && return nothing
    ks = collect(keys(rows[1]))
    open(path, "w") do io
        println(io, join(String.(ks), '\t'))
        for r in rows
            println(io, join((string(getfield(r, k)) for k in ks), '\t'))
        end
    end
end

const DEFAULT_THRESH = 0.05

"""Populations of the LAST frame of one `*_pops.csv`, with the m values."""
function last_frame(path)
    A, ci = read_tsv_matrix(path)
    h = Vector{Any}(undef, length(ci))
    for (k, i) in ci
        h[i] = k
    end
    ms = Int[]
    cols = Int[]
    for (i, x) in enumerate(h)
        s = strip(String(x))
        startswith(s, "m") || continue
        v = tryparse(Int, s[2:end])
        v === nothing && continue
        push!(ms, v)
        push!(cols, i)
    end
    isempty(ms) && error("no m<N> columns in $path")
    p = Float64[A[end, c] for c in cols]
    s = sum(p)
    # Populations are fractions by construction; if they do not sum to 1 the file
    # is carrying something else and normalising it silently would hide that.
    isapprox(s, 1.0; atol=1e-6) ||
        @warn "populations in $(basename(path)) sum to $s, not 1 — normalising, but check the writer"
    (; ms, p=p ./ s)
end

n_populated(p; thresh) = count(>=(thresh), p)
participation(p) = 1 / sum(abs2, p)

function main(args)
    thresh = DEFAULT_THRESH
    dirs = String[]
    out = ""
    for a in args
        if startswith(a, "--thresh=")
            thresh = parse(Float64, split(a, '=')[2])
        elseif startswith(a, "--out=")
            out = split(a, '='; limit=2)[2]
        else
            push!(dirs, a)
        end
    end
    isempty(dirs) && error("give a ramp output dir (holding k*/ subdirs)")

    rows = NamedTuple[]
    for d in dirs, kd in sort(filter(isdir, readdir(d; join=true)))
        startswith(basename(kd), "k") || continue
        κ = parse(Float64, basename(kd)[2:end])
        for f in sort(readdir(kd; join=true))
            endswith(f, "_pops.csv") || continue
            label = replace(basename(f), "_pops.csv" => "")
            fr = last_frame(f)
            rate = let m = match(r"_rate([0-9.]+)$", label)
                m === nothing ? NaN : parse(Float64, m.captures[1])
            end
            push!(rows, (; kappa=κ, label, tag=split(label, "_")[1], rate,
                n_pop=n_populated(fr.p; thresh), pr=participation(fr.p),
                m_max=fr.ms[argmax(fr.p)], p_max=maximum(fr.p),
                p_positive_m=sum(fr.p[fr.ms .> 0])))
        end
    end
    isempty(rows) && error("no *_pops.csv found under $(join(dirs, ", "))")

    @printf("Stern-Gerlach signature (last frame of each leg, threshold %.2f):\n", thresh)
    println(rpad("κ", 6), rpad("leg", 6), rpad("rate", 9), rpad("n_pop", 7),
        rpad("1/Σp²", 8), rpad("peak m_F", 10), rpad("p_peak", 8), "Σp(m>0)")
    for r in sort(rows; by=x -> (x.kappa, x.tag, -x.rate))
        @printf("%-6.2f%-6s%-9.4g%-7d%-8.2f%-10d%-8.3f%.3f\n",
            r.kappa, r.tag, r.rate, r.n_pop, r.pr, r.m_max, r.p_max, r.p_positive_m)
    end

    # The contrast, stated as a separation rather than as two numbers side by side.
    slow = filter(r -> isfinite(r.rate) && r.rate <= 1.0, rows)
    if !isempty(slow)
        ks = sort(unique(getfield.(slow, :kappa)))
        println("\nat ramp rates ≤ 1 µG/ms:")
        for κ in ks
            s = filter(r -> r.kappa == κ, slow)
            @printf("  κ=%.2f  n_pop %d–%d   1/Σp² %.2f–%.2f\n", κ,
                minimum(getfield.(s, :n_pop)), maximum(getfield.(s, :n_pop)),
                minimum(getfield.(s, :pr)), maximum(getfield.(s, :pr)))
        end
        if length(ks) >= 2
            lo = filter(r -> r.kappa == minimum(ks), slow)
            hi = filter(r -> r.kappa == maximum(ks), slow)
            gap = minimum(getfield.(hi, :n_pop)) - maximum(getfield.(lo, :n_pop))
            @printf("  ⇒ separation in n_pop between κ=%.2f and κ=%.2f: %+d levels%s\n",
                maximum(ks), minimum(ks), gap,
                gap > 0 ? " (disjoint — a shot-by-shot discriminator)" :
                " (OVERLAPPING — not a discriminator at this threshold)")
        end
    end

    if !isempty(out)
        write_tsv(out, rows)
        println("\nwrote $out")
    end
    0
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    exit(main(ARGS))
end
