# How much transverse field noise can a weak-field ¹⁵¹Eu state be held in?
#
# #340: turn the shielding number from a by-product footnote into a
# specification the laboratory can act on. The deliverable has the shape
#
#     to hold this state at (κ, B) for N ms, keep the AC part of B⊥ below X µG
#
# and it has to be an ENSEMBLE statement. One realisation of a noise process is
# not a specification: the phases are random, so a single seed reports one draw
# from a distribution whose spread is part of the answer. Every point here is
# ≥ 20 seeds with mean AND spread.
#
# What is deliberately NOT sampled: the STATIC offset. A constant transverse
# field is a different value of the field, not noise — it is one scalar, so
# scanning it gives the response function directly while drawing it randomly
# gives a smeared average that then has to be deconvolved. `FieldNoiseSpec` is
# zero-mean by construction and says the same thing in its own docstring. The
# DC axis is `NH_PIN`, scanned explicitly, and the two are reported in separate
# columns because compensating a DC offset and shielding an AC field are
# different pieces of hardware.
#
# THE POSITIVE CONTROL IS NOT OPTIONAL. An arm at rms = 0 must reproduce the
# known static-pin result (|ΔJ_z| ≲ 3e-3 over the hold). Without it, a run in
# which the noise was never actually wired into the propagator reports "noise
# does not matter" — the most comfortable possible failure. The script refuses
# to write results unless that arm is present and passes.
#
# Env:
#   NH_KAPPA=1.8  NH_B=20            state and hold field [µG]
#   NH_SEED_FILE=…                   converged ψ to hold (its own pin is read)
#   NH_HOLD_MS=145                   hold time(s) [ms], `;`-separated
#   NH_RMS_UG=0;0.05;0.15;0.5;1.5    AC rms of EACH transverse component [µG]
#   NH_SHAPE=white                   white | pink | lines | brown | lorentzian
#   NH_LINES=50;150;250              line frequencies [Hz] when shape=lines
#   NH_SEEDS=20                      ensemble size
#   NH_F_LO=1  NH_F_HI=1000          broadband band [Hz]
#   NH_F_CORNER=1                    pink/brown knee [Hz]
#   NH_PIN=                          static transverse pin [p-units]; default the
#                                    seed's own, so the DC axis is explicit
#   NH_GRID=32  NH_BOX=24  NH_DT=0.002  NH_FRAMES=120
#   NH_OUT=figs/eu_noise
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_noise/noise_hold.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    Waveform, TimeDependentZeeman, ConstantWaveform, CompositeWaveform,
    split_step_midpoint!,
    FieldNoiseSpec, field_noise_waveform, max_frequency,
    component_populations, total_norm, magnetization, orbital_angular_momentum,
    CUDABackend, CPUBackend
using JLD2: jldopen
using Printf
using Statistics: mean, std

include(joinpath(@__DIR__, "..", "eu_ramp_common.jl"))   # spin_scalars

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
function getlist(k, d)
    s = get(ENV, k, d)
    v = isempty(strip(s)) ? Float64[] : parse.(Float64, split(s, r"[,;]"))
    n = get(ENV, k * "_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        $k parsed $(length(v)) entries but $(k)_N says $n: $(repr(s)).
        A list through `qsub -v` is cut at the first comma — use `;`.""")
    v
end

const KAPPA = getf("NH_KAPPA", 1.8)
const B_HOLD = getf("NH_B", 20.0)
const GRID_N = Int(getf("NH_GRID", 32))
const BOX = getf("NH_BOX", 24.0)
const DT = getf("NH_DT", 0.002)
const FRAMES = Int(getf("NH_FRAMES", 120))
const HOLDS_MS = getlist("NH_HOLD_MS", "145")
const RMS_UG = getlist("NH_RMS_UG", "0;0.05;0.15;0.5;1.5")
const SHAPE = Symbol(get(ENV, "NH_SHAPE", "white"))
const LINES_HZ = getlist("NH_LINES", "50;150;250")
const N_SEEDS = Int(getf("NH_SEEDS", 20))
const F_LO = getf("NH_F_LO", 1.0)
const F_HI = getf("NH_F_HI", 1000.0)
const F_CORNER = getf("NH_F_CORNER", 1.0)
const OUT = get(ENV, "NH_OUT", "figs/eu_noise")
mkpath(OUT)

# Dealiasing off, matching every other driver in this arc: at 32³ / box 24 the
# 2/3 cutoff sits below the occupied band.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "NH_DEALIAS", "0") == "1"

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const MS_PER_TAU = 1e3 / PRESET.omega_ref
const HZ_PER_UNIT = PRESET.omega_ref            # f_sim = f_Hz / ω_ref

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, PRESET.omega_ref)
# p-units per µG. The lab speaks µG, the propagator speaks p; everything the
# deliverable quotes is µG and every conversion goes through this one line.
const P_PER_UG = abs(p_of(1.0))
ug_to_p(b_ug) = b_ug * P_PER_UG
p_to_ug(p) = p / P_PER_UG

struct BlindNoise <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindNoise) = print(io, "BlindNoise: ", e.msg)

"""ψ and its recorded pin, with the parameter-epoch check every consumer of a
stored state owes."""
function load_seed(path)
    isfile(path) || throw(BlindNoise("no such seed: $path"))
    jldopen(path, "r") do f
        g(k, d) = haskey(f, k) ? f[k] : d
        for (nm, got, want) in (("c0", g("c0", NaN), PRESET.interactions.c[0]),
            ("c1", g("c1", NaN), PRESET.interactions.c[1]),
            ("c_dd", g("c_dd", NaN), PRESET.c_dd))
            isnan(got) && continue
            abs(got - want) / max(abs(want), 1e-30) < 1e-8 ||
                throw(BlindNoise("seed/preset mismatch on $nm: $got vs $want — $path"))
        end
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            throw(BlindNoise("seed grid $(first(n)) ≠ $GRID_N — $path"))
        B = Float64(g("B_uG", NaN))
        isnan(B) || abs(B - B_HOLD) < 0.5 ||
            throw(BlindNoise("seed is at B=$B µG but the hold is at $B_HOLD µG; " *
                             "a seed is stationary only at its own field, and the " *
                             "transient would be read as a noise effect"))
        (; psi=Array{ComplexF64}(f["psi"]), B,
            pin=Float64(g("pin_bx", g("pin_eps", NaN))),
            fperp0=Float64(g("fperp", NaN)), Jz0=Float64(g("Jz", NaN)))
    end
end

"""The AC waveform for one transverse component: `rms_ug` of `SHAPE`, seeded."""
function noise_wf(rms_ug, seed, dur_tau)
    rms_ug <= 0 && return nothing
    r = ug_to_p(rms_ug)
    spec = if SHAPE === :lines
        # All the power in the mains harmonics, split equally, so the total rms
        # matches the broadband arms it is compared against.
        per = r / sqrt(length(LINES_HZ))
        FieldNoiseSpec(; seed, lines=[(f / HZ_PER_UNIT, per) for f in LINES_HZ],
            shape=:none, rms=0.0)
    else
        FieldNoiseSpec(; seed, shape=SHAPE, rms=r,
            f_lo=F_LO / HZ_PER_UNIT, f_hi=F_HI / HZ_PER_UNIT,
            f_corner=F_CORNER / HZ_PER_UNIT, n_components=256)
    end
    field_noise_waveform(spec, dur_tau)
end

"""Hold at constant B_z with a static pin plus AC noise on both transverse
components. Returns the trajectory summary."""
function hold(psi, pin_p, rms_ug, seed, τ)
    n_steps = max(1, ceil(Int, τ / DT))
    save_every = max(1, n_steps ÷ FRAMES)
    # Two INDEPENDENT realisations: a residual transverse field has two
    # components, and using one waveform for both would make it a fixed-azimuth
    # oscillation rather than a wandering direction. The seeds are offset rather
    # than reused so x and y are not the same trace.
    wx = noise_wf(rms_ug, seed, τ)
    wy = noise_wf(rms_ug, seed + 100_000, τ)
    # dt must resolve the fastest component, or the noise ALIASES to some other
    # frequency instead of averaging out — a silent change of the spectrum being
    # tested. Guard rather than assume.
    fmax = max(wx === nothing ? 0.0 : max_frequency(wx),
        wy === nothing ? 0.0 : max_frequency(wy))
    fmax > 0 && DT > 1 / (10 * fmax) && throw(BlindNoise(
        "dt=$DT does not resolve f_max=$(round(fmax; digits=3)) (ω_ref units, " *
        "$(round(fmax * HZ_PER_UNIT; digits=1)) Hz): need dt ≲ $(round(1/(10fmax); sigdigits=3)). " *
        "The noise would alias to a different spectrum than the one requested."))

    bx = wx === nothing ? ConstantWaveform(pin_p) :
         CompositeWaveform(Waveform[ConstantWaveform(pin_p), wx]; operation=:add)
    by = wy === nothing ? ConstantWaveform(0.0) : wy

    ws = make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=TimeDependentZeeman(ConstantWaveform(p_of(B_HOLD)),
            ConstantWaveform(0.0), bx, by),
        sim_params=SimParams(; dt=DT, n_steps, imaginary_time=false, save_every),
        psi_init=Array{ComplexF64}(psi),
        enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
        ddi_padding=false, ddi_trunc_radius=-1.0)

    local first_s, last_s
    rec() = begin
        h = Array(ws.state.psi)
        s = spin_scalars(h, PRESET.grid)
        Lz = orbital_angular_momentum(h, PRESET.grid, ws.fft_plans)
        Sz = magnetization(h, PRESET.grid, SYS)
        p = component_populations(h, PRESET.grid, SYS).populations
        pn = p ./ sum(p)
        (; s.fperp, s.fz, Lz, Sz, Jz=Lz + Sz,
            n_pop=count(>=(0.05), pn), pr=1 / sum(abs2, pn),
            norm=total_norm(ws.state.psi, PRESET.grid))
    end
    first_s = rec()
    fperp_max = first_s.fperp
    for step in 1:n_steps
        split_step_midpoint!(ws)
        if step % save_every == 0 || step == n_steps
            last_s = rec()
            fperp_max = max(fperp_max, abs(last_s.fperp - first_s.fperp))
        end
    end
    (; first_s, last_s, fperp_excursion=fperp_max,
        dJz=last_s.Jz - first_s.Jz, dfperp=last_s.fperp - first_s.fperp,
        dn_pop=last_s.n_pop - first_s.n_pop, dpr=last_s.pr - first_s.pr,
        norm_drift=last_s.norm - first_s.norm,
        f_max_hz=fmax * HZ_PER_UNIT)
end

# --------------------------------------------------------------------- driver

const SEED_FILE = get(ENV, "NH_SEED_FILE", "")
isempty(SEED_FILE) && throw(BlindNoise("NH_SEED_FILE is required"))
const S = load_seed(SEED_FILE)
const PIN_P = haskey(ENV, "NH_PIN") ? getf("NH_PIN", 0.0) : S.pin
isnan(PIN_P) && throw(BlindNoise("seed records no pin and NH_PIN was not given"))

0.0 in RMS_UG || throw(BlindNoise(
    "NH_RMS_UG must contain 0 — the zero-noise arm is the positive control that " *
    "shows the noise is wired in at all. Without it, a run where the waveform " *
    "never reached the propagator reports `noise does not matter`."))

@printf("""
Eu noise hold: κ=%.2f B=%.1f µG grid=%d³ box=%.1f  %s
  seed        %s  (pin %.4g p-units = %.4f µG, ⟨F⊥⟩=%.4f)
  hold times  %s ms
  AC rms      %s µG per transverse component, shape=%s%s
  ensemble    %d seeds   dt=%g   band %.0f–%.0f Hz
""", KAPPA, B_HOLD, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU",
    SEED_FILE, PIN_P, p_to_ug(PIN_P), S.fperp0,
    join(HOLDS_MS, ", "), join(RMS_UG, ", "), SHAPE,
    SHAPE === :lines ? " @ $(join(LINES_HZ, "/")) Hz" : "",
    N_SEEDS, DT, F_LO, F_HI)
flush(stdout)

const COLS = (:kappa, :B_uG, :hold_ms, :shape, :rms_uG, :pin_uG, :seed,
    :Jz0, :Jz_end, :dJz, :fperp0, :fperp_end, :dfperp, :fperp_excursion,
    :n_pop0, :n_pop_end, :pr0, :pr_end, :norm_drift, :f_max_hz, :wall_s)

rows = NamedTuple[]
write_rows() = open(joinpath(OUT, "noise_hold.csv"), "w") do io
    println(io, join(String.(collect(COLS)), '\t'))
    for r in rows
        println(io, join((string(getfield(r, k)) for k in COLS), '\t'))
    end
end

for hold_ms in HOLDS_MS, rms in RMS_UG
    τ = hold_ms / MS_PER_TAU
    # rms = 0 is deterministic: one seed IS the ensemble, and running 20
    # identical holds would only inflate the wall clock and fake a spread of 0
    # that was never sampled.
    seeds = rms == 0 ? [1] : collect(1:N_SEEDS)
    for sd in seeds
        t0 = time()
        h = hold(S.psi, PIN_P, rms, sd, τ)
        push!(rows, (; kappa=KAPPA, B_uG=B_HOLD, hold_ms, shape=String(SHAPE),
            rms_uG=rms, pin_uG=p_to_ug(PIN_P), seed=sd,
            Jz0=h.first_s.Jz, Jz_end=h.last_s.Jz, dJz=h.dJz,
            fperp0=h.first_s.fperp, fperp_end=h.last_s.fperp, dfperp=h.dfperp,
            fperp_excursion=h.fperp_excursion,
            n_pop0=h.first_s.n_pop, n_pop_end=h.last_s.n_pop,
            pr0=h.first_s.pr, pr_end=h.last_s.pr,
            norm_drift=h.norm_drift, f_max_hz=h.f_max_hz,
            wall_s=round(time() - t0; digits=1)))
        write_rows()
        @printf("[%5.0f ms  rms=%5.3f µG  seed %3d]  ΔJ_z=%+9.2e  Δ⟨F⊥⟩=%+8.4f  n_pop %d→%d  1/Σp² %.2f→%.2f  |ψ|² %+.1e  %.0fs\n",
            hold_ms, rms, sd, h.dJz, h.dfperp, h.first_s.n_pop, h.last_s.n_pop,
            h.first_s.pr, h.last_s.pr, h.norm_drift, time() - t0)
        flush(stdout)
    end
end

# ------------------------------------------------------- control + ensemble

ctrl = filter(r -> r.rms_uG == 0, rows)
isempty(ctrl) && throw(BlindNoise("no rms=0 arm ran; nothing calibrates this run"))
worst = maximum(abs(r.dJz) for r in ctrl)
@printf("\npositive control (rms = 0, static pin only): max |ΔJ_z| = %.2e over %s ms\n",
    worst, join(unique(getfield.(ctrl, :hold_ms)), "/"))
tol = getf("NH_CONTROL_TOL", 5e-3)
worst <= tol || throw(BlindNoise(
    "the zero-noise arm drifted |ΔJ_z| = $(round(worst; sigdigits=3)) > $tol, so this " *
    "state is NOT stationary under the static pin alone and every noise number " *
    "below would be measuring that drift instead. Fix the seed or the pin first."))
println("  ⇒ reproduces the static-pin result; the noise arms are measured against a stationary state\n")

println("ensemble summary (mean ± sd over seeds):")
println(rpad("hold[ms]", 10), rpad("rms[µG]", 10), rpad("|ΔJ_z|", 22),
    rpad("Δ⟨F⊥⟩", 22), rpad("n_pop end", 12), "1/Σp² end")
for hold_ms in sort(unique(getfield.(rows, :hold_ms))),
    rms in sort(unique(getfield.(rows, :rms_uG)))

    g = filter(r -> r.hold_ms == hold_ms && r.rms_uG == rms, rows)
    isempty(g) && continue
    sd1(v) = length(v) > 1 ? std(v) : 0.0
    aj = abs.(getfield.(g, :dJz))
    df = getfield.(g, :dfperp)
    np = Float64.(getfield.(g, :n_pop_end))
    pr = getfield.(g, :pr_end)
    @printf("%-10.0f%-10.3f%-22s%-22s%-12s%s\n", hold_ms, rms,
        @sprintf("%.3e ± %.1e", mean(aj), sd1(aj)),
        @sprintf("%+.4f ± %.4f", mean(df), sd1(df)),
        @sprintf("%.2f ± %.2f", mean(np), sd1(np)),
        @sprintf("%.2f ± %.2f", mean(pr), sd1(pr)))
end

println("\nALLDONE  $(length(rows)) holds → $OUT/noise_hold.csv")
