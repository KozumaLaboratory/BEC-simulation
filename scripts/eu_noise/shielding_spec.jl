# Turn the noise-hold ensembles into the one sentence the laboratory needs:
#
#     to hold this state at (κ, B) for N ms, keep the AC part of B⊥ below X µG
#
# X is a THRESHOLD CROSSING, so the two ways of getting it wrong are (a) reporting
# a number when the criterion was never violated in the scanned range — that is a
# lower bound, not a specification — and (b) reporting a number from one
# realisation when the arm is an ensemble with a spread. Both are refused here.
#
# The criterion is stated, not implied. "Holding the state" is made concrete two
# ways, because they can disagree and the disagreement is informative:
#
#   J_z   |ΔJ_z| must stay below `--dJz-max` (default 0.1). The two branches of
#         #335 differ by 2–4 in J_z, and a B_z ramp cannot cross between them, so
#         drifting a tenth of that is already an appreciable fraction of the way
#         out of the sector the state was prepared in.
#   n_pop the number of populated m_F levels must not change. This is the DISCRETE
#         observable — no error bar, no calibration — and it is #335's deliverable,
#         so the field at which IT breaks is the field at which #335's prediction
#         stops holding.
#
# The threshold is quoted from the ensemble MEAN + one sd, not the mean, because a
# specification that half the shots violate is not a specification.
#
# Usage (pure CSV post-processing; no SpinorBEC, no GPU):
#   julia --project=. scripts/eu_noise/shielding_spec.jl DIR [DIR...] \
#         [--dJz-max=0.1] [--out=spec.csv]

using Printf
using Statistics: mean, std

struct BlindSpec <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindSpec) = print(io, "BlindSpec: ", e.msg)

function read_tsv(path)
    lines = filter(!isempty, readlines(path))
    isempty(lines) && throw(BlindSpec("empty file: $path"))
    hdr = String.(split(lines[1], '\t'))
    rows = NamedTuple[]
    for ln in lines[2:end]
        c = split(ln, '\t')
        length(c) == length(hdr) || continue
        vals = [something(tryparse(Float64, String(x)), String(x)) for x in c]
        push!(rows, (; (Symbol(h) => v for (h, v) in zip(hdr, vals))...))
    end
    rows
end

"""Every `noise_hold.csv` under the given dirs."""
function load_all(dirs)
    rows = NamedTuple[]
    for d in dirs
        isdir(d) || throw(BlindSpec("not a directory: $d"))
        for (root, _, fs) in walkdir(d), f in fs
            f == "noise_hold.csv" || continue
            append!(rows, read_tsv(joinpath(root, f)))
        end
    end
    isempty(rows) && throw(BlindSpec("no noise_hold.csv under $(join(dirs, ", "))"))
    rows
end

"""Ensemble statistics for one (shape, hold, rms) cell."""
function cell_stats(g)
    sd1(v) = length(v) > 1 ? std(v) : 0.0
    aj = abs.(Float64.(getfield.(g, :dJz)))
    np0 = Float64.(getfield.(g, :n_pop0))
    np1 = Float64.(getfield.(g, :n_pop_end))
    (; n=length(g),
        dJz=mean(aj), dJz_sd=sd1(aj),
        dfperp=mean(Float64.(getfield.(g, :dfperp))),
        dfperp_sd=sd1(Float64.(getfield.(g, :dfperp))),
        npop_changed=mean(np1 .!= np0),          # fraction of shots that moved
        pr_end=mean(Float64.(getfield.(g, :pr_end))),
        pr_sd=sd1(Float64.(getfield.(g, :pr_end))))
end

"""Largest rms whose ensemble stays inside the criterion, and the smallest that
breaks it. Returns `nothing` for the break when nothing in the scanned range
breaks — a bound is not a threshold and must not be printed as one."""
function threshold(cells, dJz_max)
    ok = [c for c in cells if c.dJz + c.dJz_sd <= dJz_max]
    bad = [c for c in cells if c.dJz + c.dJz_sd > dJz_max]
    (; last_ok=isempty(ok) ? nothing : maximum(c -> c.rms, ok),
        first_bad=isempty(bad) ? nothing : minimum(c -> c.rms, bad))
end

function main(args)
    dJz_max = 0.1
    outfile = ""
    dirs = String[]
    for a in args
        if startswith(a, "--dJz-max=")
            dJz_max = parse(Float64, split(a, '=')[2])
        elseif startswith(a, "--out=")
            outfile = split(a, '='; limit=2)[2]
        elseif startswith(a, "--")
            throw(BlindSpec("unknown flag $a"))
        else
            push!(dirs, a)
        end
    end
    isempty(dirs) && throw(BlindSpec("give at least one output dir"))
    rows = load_all(dirs)

    # ---- the control, first. Without it nothing below is about the noise. ----
    ctrl = filter(r -> r.rms_uG == 0, rows)
    isempty(ctrl) && throw(BlindSpec(
        "no rms=0 rows anywhere: nothing shows the noise was wired into the " *
        "propagator, so a small effect here is indistinguishable from no effect " *
        "having been applied"))
    cworst = maximum(abs(Float64(r.dJz)) for r in ctrl)
    @printf("control (rms = 0, %d arm(s)): max |ΔJ_z| = %.2e\n", length(ctrl), cworst)
    cworst <= 5e-3 || throw(BlindSpec(
        "the zero-noise arms drift |ΔJ_z| = $(round(cworst; sigdigits=3)); the state " *
        "is not stationary under the static pin alone and every number below " *
        "would be measuring that instead"))
    # And the noise must actually do something SOMEWHERE, or the wiring is dead
    # in a way the zero arm cannot reveal.
    loud = maximum(abs(Float64(r.dJz)) for r in rows)
    loud > 10 * max(cworst, 1e-12) || throw(BlindSpec(
        "the loudest arm ($(round(loud; sigdigits=3))) is within 10× of the silent " *
        "one ($(round(cworst; sigdigits=3))): either every rms scanned is far below " *
        "threshold, or the noise never reached the field. Scan higher before " *
        "concluding that noise does not matter"))
    @printf("loudest arm: |ΔJ_z| = %.2e (%.0f× the control) — the noise is live\n\n",
        loud, loud / max(cworst, 1e-30))

    # ---------------------------- per-cell table ----------------------------
    key(r) = (String(r.shape), Float64(r.hold_ms), Float64(r.rms_uG))
    cells = NamedTuple[]
    for k in sort(unique(key.(rows)))
        g = filter(r -> key(r) == k, rows)
        s = cell_stats(g)
        push!(cells, (; shape=k[1], hold_ms=k[2], rms=k[3], s...))
    end

    println("ensemble (mean ± sd over seeds):")
    println(rpad("shape", 10), rpad("hold[ms]", 10), rpad("rms[µG]", 10), rpad("n", 4),
        rpad("|ΔJ_z|", 24), rpad("Δ⟨F⊥⟩", 22), "n_pop moved")
    for c in cells
        @printf("%-10s%-10.0f%-10.3f%-4d%-24s%-22s%.0f %%\n", c.shape, c.hold_ms, c.rms,
            c.n, @sprintf("%.3e ± %.1e", c.dJz, c.dJz_sd),
            @sprintf("%+.4f ± %.4f", c.dfperp, c.dfperp_sd), 100 * c.npop_changed)
    end

    # ------------------- does the SHAPE matter at fixed rms? -----------------
    println("\nsame rms, different spectrum — is an rms specification enough?")
    shapes = unique(getfield.(cells, :shape))
    rand_shapes = filter(s -> s != "rotating", shapes)
    verdict_shape = "not tested"
    if length(rand_shapes) >= 2
        worst_ratio, worst_at = 1.0, ""
        for hold in unique(getfield.(cells, :hold_ms)),
            rms in unique(getfield.(cells, :rms))

            g = [c for c in cells if c.hold_ms == hold && c.rms == rms &&
                     c.shape in rand_shapes]
            length(g) >= 2 && rms > 0 || continue
            lo, hi = minimum(c -> c.dJz, g), maximum(c -> c.dJz, g)
            # Compare the gap with the ensemble spread: two shapes differ only if
            # the difference is larger than the scatter within each of them.
            spread = maximum(c -> c.dJz_sd, g)
            sep = (hi - lo) > 2 * spread
            @printf("  %4.0f ms  rms=%-6.3f  %s   spread within arms ±%.1e  ⇒ %s\n",
                hold, rms,
                join((@sprintf("%s %.2e", c.shape, c.dJz) for c in g), "  "),
                spread, sep ? "DIFFERENT" : "indistinguishable")
            if lo > 0 && hi / lo > worst_ratio
                worst_ratio = hi / lo
                worst_at = @sprintf("%.0f ms, rms=%.3g", hold, rms)
            end
        end
        verdict_shape = worst_ratio <= 2 ?
            @sprintf("an rms specification is SUFFICIENT (worst spread between shapes %.2f×, at %s)", worst_ratio, worst_at) :
            @sprintf("an rms specification is NOT sufficient (%.2f× between shapes at %s) — quote the worst shape", worst_ratio, worst_at)
        println("  ⇒ ", verdict_shape)
    end

    # ---------------------------- the specification ---------------------------
    println("\nspecification: |ΔJ_z| must stay below $dJz_max (mean + 1 sd)")
    spec = NamedTuple[]
    for sh in shapes, hold in sort(unique(c.hold_ms for c in cells if c.shape == sh))
        g = [c for c in cells if c.shape == sh && c.hold_ms == hold]
        length(g) >= 2 || continue
        t = threshold(g, dJz_max)
        push!(spec, (; shape=sh, hold_ms=hold,
            last_ok=t.last_ok === nothing ? NaN : t.last_ok,
            first_bad=t.first_bad === nothing ? NaN : t.first_bad,
            bounded=t.first_bad === nothing))
        if t.first_bad === nothing
            @printf("  %-9s %4.0f ms:  LOWER BOUND ONLY — every rms up to %.3g µG stays inside; scan higher\n",
                sh, hold, maximum(c -> c.rms, g))
        else
            @printf("  %-9s %4.0f ms:  B⊥(AC) < %.3g µG   (breaks between %.3g and %.3g)\n",
                sh, hold, t.last_ok === nothing ? 0.0 : t.last_ok,
                t.last_ok === nothing ? 0.0 : t.last_ok, t.first_bad)
        end
    end

    # ------------------------- the discrete observable ------------------------
    println("\nthe discrete observable (#335's deliverable): where does n_pop move?")
    moved = [c for c in cells if c.npop_changed > 0]
    if isempty(moved)
        @printf("  never, up to rms = %.3g µG in every arm — the level count is the robust readout\n",
            maximum(getfield.(cells, :rms)))
    else
        for c in sort(moved; by=x -> x.rms)
            @printf("  %-9s %4.0f ms  rms=%-6.3f  moved in %.0f %% of shots\n",
                c.shape, c.hold_ms, c.rms, 100 * c.npop_changed)
        end
        @printf("  ⇒ lowest rms at which the level count moves: %.3g µG\n",
            minimum(getfield.(moved, :rms)))
    end

    if !isempty(outfile) && !isempty(spec)
        ks = collect(keys(spec[1]))
        open(outfile, "w") do io
            println(io, join(String.(ks), '\t'))
            for r in spec
                println(io, join((string(getfield(r, k)) for k in ks), '\t'))
            end
        end
        println("\nwrote $outfile")
    end
    0
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    exit(main(ARGS))
end
