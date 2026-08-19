# The q-driven boundary in F=6 europium, scanned on a COMMON q grid for both
# isotopes — #341 stage 1. Campaign: docs/guides/eu_isotope_q_prediction.md.
#
# Why q and not B is the scan axis. The two isotopes differ, in the dimensionless
# Hamiltonian, by exactly three numbers: c_total ×1.00661, c_dd ×1.01996 and
# q ×2.27872 at the same field. Scanning B independently per isotope would fold the
# exactly-known factor 2.27872 into the measurement and then require it to be divided
# back out; scanning the SAME q grid isolates the part that is not known in advance —
# the 0.7 % / 2.0 % mass corrections — and the field ratio follows analytically:
#
#     B₁₅₃/B₁₅₁ = sqrt( (q_c,₁₅₃ / q_c,₁₅₁) / 2.27872 )
#
# so a 1 % error in q_c becomes 0.5 % in the deliverable.
#
# p = 0 is deliberate and is NOT "ignoring the linear Zeeman". At the fields where q
# matters (0.1–0.3 G) p ≈ 2400–7000, the Larmor frequency is ~2000× the trap, spin
# changing collisions are Zeeman-suppressed and the magnetization is conserved; inside
# a fixed-m_z sector the linear term is the constant −p·m_z and drops out of every
# energy DIFFERENCE this script takes. See the guide §1.1.
#
# Seeds: transverse (in-plane magnetized), polar (m=0) and flower (the weak-field
# texture, kept because #335 found it competitive). Min energy over seeds is the
# ground state; all seeds are written out, because a first-order boundary is invisible
# to a single seed and the per-seed energies ARE the evidence for which order it is.
#
# Env:
#   IQ_ATOM=Eu151|Eu153        which isotope (one per invocation; the arms are
#                              separate runs so a crash costs one arm)
#   IQ_C1RATIO=0.0277777778    c₁/c₀ (1/36 = Buchachenko AFM; negative = FM side)
#   IQ_AS_SCALE=1.0            multiplier on a_s. THE ¹⁵³Eu VALUE IS A PLACEHOLDER
#                              (= ¹⁵¹Eu's measured 110 a₀); this axis is how the
#                              campaign quantifies what that placeholder costs
#   IQ_KAPPA=1.8               ω_z/ω_⊥ — oblate, so the dipolar easy-plane exists
#   IQ_GRID=48  IQ_BOX=16.0
#   IQ_QLIST=""                explicit q list (comma OR semicolon separated)
#   IQ_QMIN=0.05 IQ_QMAX=2.0 IQ_NQ=10        log-spaced, used when IQ_QLIST is empty
#   IQ_QLIST_N=                asserted length of IQ_QLIST — `qsub -v` cuts a list at
#                              the first comma, and a truncated scan still runs and
#                              still looks converged
#   IQ_PIN=0.0                 transverse pin ε in p-units. DEFAULT 0, AND IT MUST
#                              STAY 0 WHENEVER q ≠ 0: the quadratic Zeeman is applied
#                              along the FIELD axis, q(b̂·F)², so with bz = 0 a pin of
#                              any size puts b̂ in the plane and the term becomes q F_x².
#                              The ground state then relaxes to the nematic along x
#                              (⟨F_z²⟩ = 21 at F=6, Zeeman energy ~1e-12) and the whole
#                              scan reads "q does nothing". Measured 2026-08-19; the
#                              script refuses the combination rather than documenting it.
#                              Symmetry breaking comes from the SEEDS instead
#   IQ_DDI=1  IQ_SECULAR=1     DDI on / secular form (the regime is ω_L/c_dd n ≈ 2000)
#   IQ_LBFGS=600 IQ_TOL=1e-6
#   IQ_SEEDS=transverse;polar;flower
#   IQ_OUT=figs/eu_isotope_q
#   IQ_TAG=""                  suffix on the output file name
#   IQ_SMOKE=1                 16³, 3 q points, tiny caps — every path in ≤ 2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_isotope_q/q_boundary.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu_preset, ATOM_REGISTRY, find_ground_state_lbfgs,
    init_psi, init_psi_spin_coherent, SpinSystem, static_zeeman, spin_scalars,
    component_populations, magnetization, orbital_angular_momentum,
    quadratic_zeeman_dimless_si, CUDABackend, CPUBackend
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)

"""Parse a numeric list from an env var, refusing a silent truncation.

`qsub -v` separates variables with commas, so a comma inside a value ends it and the
rest of the list becomes variables with numeric names — the 2026-08-18 incident.
Semicolons are accepted for that reason, and `<name>_N` states the intended length so
a cut list is an error rather than a shorter scan that still looks fine."""
function getlist(k, d)
    s = get(ENV, k, d)
    isempty(strip(s)) && return Float64[]
    v = parse.(Float64, split(s, r"[,;]"))
    n = get(ENV, k * "_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        $k parsed $(length(v)) entries but $(k)_N says $n: $(repr(s)).
        A list passed through `qsub -v` is cut at the first comma — use `;`.""")
    v
end

const SMOKE = gets("IQ_SMOKE", "") == "1"
const ATOM_NAME = gets("IQ_ATOM", "Eu151")
const ATOM = get(ATOM_REGISTRY, Symbol(ATOM_NAME)) do
    error("IQ_ATOM=$ATOM_NAME not in ATOM_REGISTRY: $(sort(string.(keys(ATOM_REGISTRY))))")
end
const C1RATIO = getf("IQ_C1RATIO", 1 / 36)
const AS_SCALE = getf("IQ_AS_SCALE", 1.0)
const KAPPA = getf("IQ_KAPPA", 1.8)
const GRID_N = SMOKE ? 16 : Int(getf("IQ_GRID", 48))
const BOX = getf("IQ_BOX", 16.0)
const PIN = getf("IQ_PIN", 0.0)
const DDI = gets("IQ_DDI", "1") == "1"
const SECULAR = gets("IQ_SECULAR", "1") == "1"
const LBFGS = SMOKE ? 60 : Int(getf("IQ_LBFGS", 600))
const TOL = getf("IQ_TOL", 1e-6)
const N_ATOMS = Int(getf("IQ_N_ATOMS", 50_000))
const OMEGA_REF = getf("IQ_OMEGA_REF", 2π * 110.0)
const SEEDS = split(gets("IQ_SEEDS", "transverse;polar;flower"), r"[,;]")
const OUT = gets("IQ_OUT", "figs/eu_isotope_q")
const TAG = gets("IQ_TAG", "")

const QLIST = let v = getlist("IQ_QLIST", "")
    if !isempty(v)
        sort(v)
    else
        qmin, qmax = getf("IQ_QMIN", 0.05), getf("IQ_QMAX", 2.0)
        nq = SMOKE ? 3 : Int(getf("IQ_NQ", 10))
        exp.(range(log(qmin), log(qmax); length=nq))
    end
end

# A transverse pin does not "slightly break the symmetry" when q ≠ 0 — it moves the
# quadratic Zeeman onto a different axis (see the header). Refuse, rather than emit a
# scan in which q is silently inert.
PIN == 0.0 || maximum(QLIST) == 0.0 || error("""
    IQ_PIN=$PIN with a nonzero q: the quadratic Zeeman is applied along the field
    axis, q(b̂·F)², so with bz=0 the pin rotates it into the plane and the scan
    measures nothing. Leave IQ_PIN=0 and let the seeds break the symmetry.""")

mkpath(OUT)
const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu_preset(ATOM; n_atoms=N_ATOMS, n_pts=(GRID_N, GRID_N, GRID_N),
    box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, KAPPA), omega_ref=OMEGA_REF,
    c1_ratio=C1RATIO, a_s=AS_SCALE * ATOM.a_s)
const SYS = SpinSystem(ATOM.F)

"""Physical field (Gauss) at which this isotope sees dimensionless `q`.

The inverse of `quadratic_zeeman_dimless_si`, which is exactly quadratic in B, so
one evaluation at 1 G fixes the whole curve."""
q_to_gauss(q) = sqrt(q / quadratic_zeeman_dimless_si(ATOM, 1.0e-4, OMEGA_REF))

base_kw(q) = (; grid=PRESET.grid, atom=ATOM,
    interactions=PRESET.interactions, potential=PRESET.potential,
    zeeman=static_zeeman(; Bz=0.0, Bx=PIN, q=q),
    enable_ddi=DDI, c_dd=PRESET.c_dd, secular_ddi=SECULAR, backend=BACKEND,
    ddi_padding=false, ddi_trunc_radius=-1.0)

function seed_psi(name)
    n = strip(String(name))
    n == "transverse" && return init_psi_spin_coherent(PRESET.grid, SYS; theta=π / 2, phi=0.0)
    n == "polar" && return init_psi(PRESET.grid, SYS; state=:polar)
    n == "flower" && return init_psi(PRESET.grid, SYS; state=:flower)
    n == "m_plus_F" && return init_psi(PRESET.grid, SYS; state=:m_plus_F)
    error("unknown seed `$n` (transverse|polar|flower|m_plus_F)")
end

"""Discrete + continuous observables at one ψ.

`n_pop` (levels above 5 % of the atoms) and the participation ratio 1/Σp² are the
DISCRETE pair #335 settled on: no error bar, no calibration, read off one
Stern-Gerlach shot. They are reported together so no conclusion rests on where the
5 % threshold was put."""
function observables(psi, fft_plans)
    s = spin_scalars(psi, PRESET.grid)
    cp = component_populations(psi, PRESET.grid, SYS)
    p = cp.populations ./ sum(cp.populations)
    ms = cp.m_values
    Lz = orbital_angular_momentum(psi, PRESET.grid, fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    # ⟨F_z²⟩ is the quantity q multiplies. Reporting it beside the energy is what
    # separates "q is inert here" from "q is not reaching the Hamiltonian" — the two
    # look identical in E alone, and on 2026-08-19 they were confused for an hour.
    (; s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz, fz2=sum(p .* ms .^ 2),
        n_pop=count(>=(0.05), p), pr=1 / sum(abs2, p),
        m_peak=ms[argmax(p)], p_peak=maximum(p), p=p)
end

function solve(q, seed)
    psi0 = seed_psi(seed)
    gl = find_ground_state_lbfgs(; base_kw(q)..., psi_init=psi0, n_steps=LBFGS,
        tol=TOL, m_lbfgs=10, newton_polish=false, verbose=false)
    psi = Array{ComplexF64}(gl.workspace.state.psi)
    (; gl.energy, gl.grad_norm, gl.converged, gl.stop_reason,
        observables(psi, gl.workspace.fft_plans)...)
end

function main()
    stem = @sprintf("%s_c1%+.4f_as%.2f_k%.1f_g%d%s", ATOM_NAME, C1RATIO, AS_SCALE,
        KAPPA, GRID_N, isempty(TAG) ? "" : "_" * TAG)
    path = joinpath(OUT, stem * ".tsv")

    println("# atom=$ATOM_NAME  c1_ratio=$C1RATIO  a_s_scale=$AS_SCALE " *
            "(a_s=$(AS_SCALE * ATOM.a_s / Units.BOHR_RADIUS) a0)")
    println("# kappa=$KAPPA grid=$GRID_N box=$BOX pin=$PIN ddi=$DDI secular=$SECULAR")
    println("# c0=$(PRESET.interactions.c[0]) c1=$(PRESET.interactions.c[1]) " *
            "c_dd=$(PRESET.c_dd) N=$N_ATOMS omega_ref=$OMEGA_REF")
    println("# backend=$(HAS_GPU ? "CUDA" : "CPU")  seeds=$(join(SEEDS, ","))")
    println("# q grid ($(length(QLIST))): $(join(round.(QLIST; digits=5), ", "))")

    cols = ["q", "B_gauss", "seed", "E", "grad", "conv", "stop", "fz", "fperp",
        "fz2", "Lz", "Sz", "Jz", "n_pop", "pr", "m_peak", "p_peak"]
    open(path, "w") do io
        println(io, join(cols, '\t'))
        for q in QLIST, seed in SEEDS
            t = @elapsed r = solve(q, strip(String(seed)))
            println(io, join((
                    @sprintf("%.10g", q), @sprintf("%.10g", q_to_gauss(q)), strip(String(seed)),
                    @sprintf("%.12g", r.energy), @sprintf("%.4g", r.grad_norm),
                    r.converged, r.stop_reason,
                    @sprintf("%.8g", r.fz), @sprintf("%.8g", r.fperp), @sprintf("%.8g", r.fz2),
                    @sprintf("%.8g", r.Lz), @sprintf("%.8g", r.Sz), @sprintf("%.8g", r.Jz),
                    r.n_pop, @sprintf("%.5g", r.pr), r.m_peak, @sprintf("%.6g", r.p_peak),
                ), '\t'))
            flush(io)
            @printf("q=%-9.5g B=%-9.5g %-11s E=%-14.8g |g|=%-9.3g conv=%-5s f⊥=%-7.4f fz=%-7.4f fz²=%-7.3f n_pop=%d pr=%.2f  (%.1f s)\n",
                q, q_to_gauss(q), strip(String(seed)), r.energy, r.grad_norm,
                r.converged, r.fperp, r.fz, r.fz2, r.n_pop, r.pr, t)
        end
    end
    println("\nwrote $path")
    0
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    exit(main())
end
