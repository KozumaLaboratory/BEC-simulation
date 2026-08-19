# The k=0 magnon spectrum of the F=6 europium condensate vs q, for both isotopes —
# #341 stage 1. Campaign: docs/guides/eu_isotope_q_prediction.md.
#
# Why this exists. The ground-state scan (`q_boundary.jl`) found that on the AFM side —
# Eu's expected sign — the ground state is the m=0 polar state at EVERY q, with
# ⟨F_z²⟩ = 0 exactly, so its energy is q-independent to machine precision and the two
# isotopes have literally identical ground states at the same field. A null in the
# ground state is not a null in the physics: the polar state's EXCITATIONS carry q
# even where its energy does not, and a frequency is the best-calibrated quantity the
# lab owns. This script measures those frequencies.
#
# What it emits, per (isotope, q): every positive k=0 BdG eigenvalue, plus the
# assignment of each to a Zeeman index m by the closed form the spectrum turns out to
# obey. Nothing is fitted; the assignment is checked, and the residual is a column, so
# a mode that stops obeying the form is visible rather than absorbed.
#
# The instrument is gated by an exact positive control before it reports anything: the
# F=1 polar magnon has the closed form ω = √(q(q + 2c₁n₀)), and `--selftest` refuses to
# continue unless the BdG path reproduces it. An uncalibrated spectrum extractor
# reports a clean number whether or not it is reading the right eigenvalue.
#
# Env:
#   MG_C1RATIO=0.0277777778   c₁/c₀ (1/36 AFM = Buchachenko; negative = FM side)
#   MG_AS_SCALE=1.0           multiplier on a_s — the ¹⁵³Eu value is a PLACEHOLDER
#   MG_DDI=1                  include the DDI BdG matrices
#   MG_N0=                    uniform density; default = the trapped-GS peak, passed in
#   MG_QMIN=1e-3 MG_QMAX=10 MG_NQ=25   log-spaced q grid
#   MG_KDIR=z                 k̂ for the DDI tensor (z|x)
#   MG_OUT=figs/eu_isotope_q
#
#   julia --project=. scripts/eu_isotope_q/magnon_gap.jl [--selftest]

using SpinorBEC
using SpinorBEC: Units, eu_preset, ATOM_REGISTRY, Eu151, Eu153, bogoliubov_spectrum,
    InteractionParams, ZeemanParams, quadratic_zeeman_dimless_si
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)

const C1RATIO = getf("MG_C1RATIO", 1 / 36)
const AS_SCALE = getf("MG_AS_SCALE", 1.0)
const DDI = gets("MG_DDI", "1") == "1"
const N0 = getf("MG_N0", 0.005)
const KDIR = gets("MG_KDIR", "z") == "z" ? (0.0, 0.0, 1.0) : (1.0, 0.0, 0.0)
const OMEGA_REF = getf("MG_OMEGA_REF", 2π * 110.0)
const N_ATOMS = Int(getf("MG_N_ATOMS", 50_000))
const OUT = gets("MG_OUT", "figs/eu_isotope_q")
# Higher-rank channels. Eu has SEVEN unknown even channels (S = 0,2,…,12) and the
# c₀/c₁ truncation is a choice, not a measurement. `q·m²` comes out exact under that
# truncation because `F·F` connects m = 0 only to m = ±1; a rank-2 or rank-4 coupling
# has no such selection rule, so this is the axis that decides whether the isotope
# prediction is exact or merely close. Keys are ranks (the Dict API; the old
# `even_c_extra` positional helper was deleted 2026-05-25 with the misindexing it
# guarded against).
const C_EXTRA = let d = Dict{Int, Float64}()
    for k in (2, 4)
        v = getf("MG_C$k", 0.0)
        v == 0.0 || (d[k] = v)
    end
    d
end
const QGRID = let
    qmin, qmax, nq = getf("MG_QMIN", 1e-3), getf("MG_QMAX", 10.0), Int(getf("MG_NQ", 25))
    exp.(range(log(qmin), log(qmax); length=nq))
end

"""Positive k=0 eigenvalues, deduplicated to `(value, multiplicity)`.

`omega[:, 1]` is k-mode 1 — the COLUMN index. Reading `omega[1, :]` gives the first
BdG branch across k instead, which is a different object and looks equally plausible
(CLAUDE.md, Bogoliubov k=0 Goldstone convention)."""
function k0_positive(r; atol=1e-8)
    w = sort(real.(r.omega[:, 1]))
    pos = filter(>(atol), w)
    out = Tuple{Float64, Int}[]
    for v in pos
        if !isempty(out) && isapprox(v, out[end][1]; rtol=1e-8, atol=atol)
            out[end] = (out[end][1], out[end][2] + 1)
        else
            push!(out, (v, 1))
        end
    end
    out
end

spectrum(atom, q; c1_ratio=C1RATIO, as_scale=AS_SCALE, ddi=DDI, n0=N0) = begin
    P = eu_preset(atom; n_atoms=N_ATOMS, n_pts=(8, 8, 8), box=(16.0, 16.0, 16.0),
        omega_ref=OMEGA_REF, c1_ratio=c1_ratio, a_s=as_scale * atom.a_s, c_extra=C_EXTRA)
    z = zeros(ComplexF64, 2 * atom.F + 1)
    z[atom.F + 1] = 1.0                     # polar, m = 0
    r = bogoliubov_spectrum(; spinor=z, n0=n0, F=atom.F, interactions=P.interactions,
        zeeman=ZeemanParams(0.0, q), c_dd=ddi ? P.c_dd : 0.0, k_max=1.0, n_k=3,
        k_direction=KDIR)
    (; modes=k0_positive(r), preset=P)
end

"""
    fit_q_eff(modes, F; min_support) -> (q_eff, support)

Consensus fit of the EFFECTIVE quadratic-Zeeman coefficient from the |m| ≥ 2 magnons.

Those modes come out as `ω_m = q_eff · m²`, and `q_eff` is **not** `q`: a higher-rank
interaction channel adds an isotope-independent offset δ, so `q_eff = q + δ`. Fitting
means measuring δ, which is the point.

Consensus, not a picked mode. Every (mode, m) pair proposes a `q_eff` and the winner is
the one the most modes agree with, because the interaction-shifted |m| = 1 branch
MIGRATES through the sorted list as q grows — at c₂ = c₁ it lands in the middle — and
any fit that assumes "the largest mode is m = F" reads it as the answer in exactly the
cells where the answer matters. `min_support` refuses a fit explaining fewer than that
many of the F−1 expected modes: two agreeing modes out of six is a coincidence.
"""
function fit_q_eff(modes, F; rtol=1e-6, min_support::Int=4)
    best_q, best_n = NaN, 0
    for (w, _) in modes, m in 2:F
        qc = w / m^2
        qc > 0 || continue
        n = count(2:F) do mm
            any(x -> isapprox(x[1], qc * mm^2; rtol=rtol, atol=1e-14), modes)
        end
        n > best_n && ((best_q, best_n) = (qc, n))
    end
    best_n >= min_support || error("""
        fit_q_eff: best consensus explains only $best_n of the $(F - 1) expected
        |m| ≥ 2 magnons — the spectrum is not ω = q_eff·m² here, so no effective q
        exists to report. modes = $modes""")
    (best_q, best_n)
end

"""Exact positive control. F=1 polar with AFM c₁ has ω = √(q(q + 2c₁n₀)); if the
extractor cannot reproduce that, every F=6 number below is unverified."""
function selftest()
    ip = InteractionParams(Dict(0 => 10.0, 1 => 0.5))
    z = ComplexF64[0, 1, 0]
    worst = 0.0
    for q in (0.01, 0.05, 0.2, 1.0, 5.0)
        r = bogoliubov_spectrum(; spinor=z, n0=1.0, F=1, interactions=ip,
            zeeman=ZeemanParams(0.0, q), c_dd=0.0, k_max=1.0, n_k=3)
        want = sqrt(q * (q + 2 * 0.5 * 1.0))
        got = k0_positive(r)
        # the magnon is the doubly-degenerate gapped pair; the phonon sits at 0
        idx = findfirst(m -> m[2] == 2, got)
        idx === nothing && error("selftest: no doubly-degenerate k=0 mode at q=$q — " *
                                 "the extractor is not reading the magnon; got $got")
        worst = max(worst, abs(got[idx][1] - want) / want)
    end
    worst < 1e-8 || error("selftest: F=1 closed form missed by $worst")
    # Negative control: at q=0 the same mode must be GAPLESS. Without this, an
    # extractor that always returned the density mode would pass the check above
    # for the wrong reason at large q.
    r0 = bogoliubov_spectrum(; spinor=z, n0=1.0, F=1, interactions=ip,
        zeeman=ZeemanParams(0.0, 0.0), c_dd=0.0, k_max=1.0, n_k=3)
    any(m -> m[2] == 2 && m[1] > 1e-6, k0_positive(r0)) &&
        error("selftest: a degenerate k=0 mode is gapped at q=0 — wrong branch")
    @printf("selftest OK: F=1 polar magnon matches √(q(q+2c₁n₀)) to %.1e, gapless at q=0\n",
        worst)
end

function main(args)
    "--selftest" in args && (selftest(); return 0)
    selftest()
    mkpath(OUT)
    stem = @sprintf("magnon_c1%+.4f_as%.2f_ddi%d_n%.4f_x%s", C1RATIO, AS_SCALE, DDI, N0, isempty(C_EXTRA) ? "0" : join(["c$k=$v" for (k, v) in sort(collect(C_EXTRA))], "_"))
    path = joinpath(OUT, stem * ".tsv")

    println("# c1_ratio=$C1RATIO a_s_scale=$AS_SCALE ddi=$DDI n0=$N0 kdir=$KDIR")
    for a in (Eu151, Eu153)
        P = eu_preset(a; n_atoms=N_ATOMS, c1_ratio=C1RATIO, a_s=AS_SCALE * a.a_s,
            omega_ref=OMEGA_REF)
        @printf("# %s c0=%.6g c1=%.6g c_dd=%.6g  q/h@1G=%.6g Hz\n", a.name,
            P.interactions.c[0], P.interactions.c[1], P.c_dd,
            quadratic_zeeman_dimless_si(a, 1.0e-4, OMEGA_REF) * OMEGA_REF / 2π)
    end

    open(path, "w") do io
        println(io, join(["atom", "q", "B_gauss", "mode", "mult", "omega",
                "omega_hz", "over_q", "resid_vs_qm2"], '\t'))
        for a in (Eu151, Eu153)
            per_G = quadratic_zeeman_dimless_si(a, 1.0e-4, OMEGA_REF)
            for q in QGRID
                s = spectrum(a, q)
                for (i, (w, mult)) in enumerate(s.modes)
                    # The F=6 polar spectrum turns out to be ω = q·m² for |m| ≥ 2 and
                    # an interaction-shifted branch for |m| = 1; `resid` is what is left
                    # after the nearest q·m² is removed, so a mode that leaves the form
                    # shows up as a large residual instead of being relabelled.
                    m_best = argmin(abs(w - q * m^2) for m in 1:(a.F))
                    resid = w - q * m_best^2
                    println(io, join((a.name, @sprintf("%.10g", q),
                            @sprintf("%.10g", sqrt(q / per_G)), i, mult,
                            @sprintf("%.10g", w), @sprintf("%.10g", w * OMEGA_REF / 2π),
                            @sprintf("%.8g", w / q), @sprintf("%.6g", resid)), '\t'))
                end
            end
        end
    end
    println("wrote $path")

    # The deliverable, printed rather than left to the reader. Both isotopes AT THE
    # SAME FIELD, each reduced to its effective quadratic Zeeman q_eff = q + δ.
    #
    #   δ is what the interaction adds. It is isotope-independent up to the mass
    #   corrections, so the two measurements invert for BOTH unknowns:
    #       q₁₅₁ = (q_eff,₁₅₃ − q_eff,₁₅₁) / (r_q − 1),   δ = q_eff,₁₅₁ − q₁₅₁
    #   i.e. the isotope pair measures the field (self-calibrating, no magnetometer)
    #   AND the higher-rank channel combination that δ encodes.
    per_G151 = quadratic_zeeman_dimless_si(Eu151, 1.0e-4, OMEGA_REF)
    rq = Eu151.Delta_E_hf / Eu153.Delta_E_hf
    @printf("\nsame-field comparison (r_q = q₁₅₃/q₁₅₁ = %.6f, exact from Δ_hf):\n", rq)
    println(rpad("B [G]", 9), rpad("q151", 12), rpad("q_eff151", 12), rpad("q_eff153", 12),
        rpad("ratio", 10), rpad("δ151", 12), rpad("δ153", 12), rpad("supp", 6),
        "q151 recovered")
    for B in (0.01, 0.05, 0.1, 0.3, 1.0)
        q1 = per_G151 * B^2
        (qe1, n1) = fit_q_eff(spectrum(Eu151, q1).modes, Eu151.F)
        (qe3, n3) = fit_q_eff(spectrum(Eu153, rq * q1).modes, Eu153.F)
        q1_rec = (qe3 - qe1) / (rq - 1)
        @printf("%-9.4g%-12.5g%-12.5g%-12.5g%-10.6f%-12.4g%-12.4g%-6s%.6g (%.2f%% off)\n",
            B, q1, qe1, qe3, qe3 / qe1, qe1 - q1, qe3 - rq * q1, "$n1/$n3",
            q1_rec, 100 * (q1_rec - q1) / q1)
    end
    0
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    exit(main(ARGS))
end
