# Is a branch state a stable minimum at this field, or has the branch already
# ended? This decides whether a hysteresis edge is a SPINODAL or merely where a
# particular ramp happened to deliver enough excitation to cross a barrier — and
# those are different physics with different experimental signatures.
#
# Why |∇E| cannot answer it. L-BFGS converges to a STATIONARY point, and a saddle
# is stationary: a cell can sit at |∇E| ~ 1e-6, unmoved by further polishing,
# and still be a maximum along one direction. On this soft manifold that is not
# hypothetical — a gradient of 3.6e-4 was once 0.59 off in ⟨F⊥⟩. So stability is
# measured, twice, by two instruments that fail differently:
#
#   HOLD     propagate at CONSTANT B from ψ + noise, with the ramp's own
#            integrator and settings. An unstable state departs exponentially.
#            Blind to an instability whose growth time exceeds the hold.
#   REMIN    perturb and re-minimise at the same (B, ε). A minimum returns to
#            its own ⟨F⊥⟩; a saddle slides off. Blind to sliding along a flat
#            direction, which a Goldstone manifold has by construction.
#
# Neither alone is conclusive and they are reported separately, never merged into
# one verdict.
#
# CONTROLS — one state, two hold fields, straddling the known spinodal:
#   positive  the last converged flower ψ, held WELL past the end of its branch,
#             must depart
#   negative  the SAME ψ held at its own field must not
# "Well past" is not slack. A spinodal is where the unstable mode's growth rate
# passes through zero, so just past it nothing happens on any reasonable hold:
# measured, the flower ψ from 68.25 µG held at 70 µG moved 0.089 in 217 ms. The
# control uses +25 µG by default, and the departure TIME across a range of hold
# fields is itself a result — it is what reconciles a branch that ends at 68.4 µG
# with a ramp carrying flower-like ⟨F⊥⟩ well above it.
# The pair differs in exactly the variable under test. Holding two different
# states at two different fields would also have varied the branch and the
# field mismatch, so a departure could have been non-stationarity instead of
# instability. A stability test that cannot return "unstable" proves nothing,
# which is the degenerate-knob trap in yet another costume.
#
# Env:
#   SB_CELLS=a.jld2;b.jld2      cells to test (branch-scan psi.jld2 files)
#   SB_CELLS_N=                 expected count; guards the qsub -v comma cut
#   SB_HOLD_B=70;80;90          hold fields [µG]; default each cell's own. A LIST
#                               gives the departure time vs distance past the end
#                               of the branch.
#   SB_ETA=0.01                 perturbation as a FRACTION of ψ, density-weighted
#   SB_HOLD_TAU=60              hold duration [ω_ref⁻¹]  (60 ≈ 87 ms)
#   SB_DT=0.002  SB_FRAMES=120
#   SB_REMIN=600                LBFGS cap for the re-minimisation (0 = skip)
#   SB_KAPPA=1.8  SB_GRID=32  SB_BOX=24.0  SB_PIN=0.002  SB_PADDING=0
#   SB_CONTROL_FLOWER=          the last converged flower cell; BOTH controls
#   SB_CONTROL_UNSTABLE_B=      use it, held well past its spinodal (default +25)
#   SB_CONTROL_STABLE_B=        and at its own field, so the pair differs only in B
#   SB_DEPART=0.6               ⟨F⊥⟩ movement that counts as leaving the branch
#   SB_OUT=figs/eu_hysteresis/stability
#   SB_SKIP_CONTROLS=1          only for debugging; the result is then uncalibrated
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_hysteresis/branch_stability.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    TimeDependentZeeman, ConstantWaveform, split_step_midpoint!, static_zeeman,
    find_ground_state_lbfgs, total_norm, total_energy,
    magnetization, orbital_angular_momentum, CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf
using Random

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const KAPPA = getf("SB_KAPPA", 1.8)
const GRID_N = Int(getf("SB_GRID", 32))
const BOX = getf("SB_BOX", 24.0)
const PIN = getf("SB_PIN", 0.002)
const ETA = getf("SB_ETA", 0.01)
const HOLD_TAU = getf("SB_HOLD_TAU", 60.0)
const DT = getf("SB_DT", 0.002)
const FRAMES = Int(getf("SB_FRAMES", 120))
const REMIN = Int(getf("SB_REMIN", 600))
const PADDING = get(ENV, "SB_PADDING", "0") == "1"
const OUT = get(ENV, "SB_OUT", "figs/eu_hysteresis/stability")
mkpath(OUT)

# Dealiasing off, matching the ramps: the point of a hold is to be the ramp's own
# propagator with dB/dt set to zero.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "SB_DEALIAS", "0") == "1"

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const MS_PER_TAU = 1e3 / PRESET.omega_ref

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, PRESET.omega_ref)

"""ψ and its recorded (B, ε), with the parameter-epoch check every consumer of a
stored state owes: a state from another epoch is not stationary here and its
departure would be that mismatch rather than an instability."""
function load_cell(path)
    isfile(path) || error("no such cell: $path")
    jldopen(path, "r") do f
        g(k, d) = haskey(f, k) ? f[k] : d
        for (nm, got, want) in (("c0", g("c0", NaN), PRESET.interactions.c[0]),
            ("c1", g("c1", NaN), PRESET.interactions.c[1]),
            ("c_dd", g("c_dd", NaN), PRESET.c_dd))
            isnan(got) && continue
            abs(got - want) / max(abs(want), 1e-30) < 1e-8 ||
                error("cell/preset mismatch on $nm: $got vs $want — $path")
        end
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            error("cell grid $(first(n)) ≠ $GRID_N — $path")
        (; psi=Array{ComplexF64}(f["psi"]), B=Float64(g("B_uG", NaN)),
            pin=Float64(g("pin_bx", g("pin_eps", PIN))),
            fperp0=Float64(g("fperp", NaN)), E0=Float64(g("E_total", g("E", NaN))))
    end
end

# A departure has to be large enough that it is a branch change and not the
# breathing a perturbation excites on ANY state. A branch change moves ⟨F⊥⟩ by
# ≈ 1.4 here (2.27 → 0.9); the threshold sits well below that and well above the
# 0.001 a converged cell shows at its own field.
const DEPART = getf("SB_DEPART", 0.6)

struct BlindStability <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindStability) = print(io, "BlindStability: ", e.msg)

"""Perturb ψ by a fraction η OF ITSELF, weighted by the local density.

Not `add_white_noise!`: its `amp` is an ABSOLUTE per-point amplitude applied to
every one of 32³×13 entries and then renormalised, so η = 0.01 adds noise of norm²
≈ 36 against the state's 1 — the "perturbed" state is 97 % noise. That is not a
hypothetical: the first run of this script fed both controls such a state and they
came back reading ⟨F⊥⟩ ≈ 1.25 apiece, from branches whose true values are 2.478 and
0.637. The controls refused, which is why the number was never quoted.

Density-weighted, because a stability test wants the perturbation where the atoms
are; amplitude spread into vacuum does not couple to the mode under test."""
function perturb!(ψ, η, seed)
    η > 0 || return ψ
    rng = Random.MersenneTwister(seed)
    @inbounds for i in eachindex(ψ)
        ψ[i] += η * abs(ψ[i]) * (randn(rng) + im * randn(rng)) / sqrt(2)
    end
    ψ ./= sqrt(sum(abs2, ψ) * SpinorBEC.cell_volume(PRESET.grid))
    ψ
end

"""Hold at constant `B_uG` from `psi` perturbed by a fraction η. Returns the ⟨F⊥⟩
trace and the largest excursion from t=0. Uses the ramp's integrator with
dB/dt = 0."""
function hold(psi, B_uG, ε; η=ETA, τ=HOLD_TAU, seed=1)
    ψ = Array{ComplexF64}(psi)
    perturb!(ψ, η, seed)
    n_steps = max(1, ceil(Int, τ / DT))
    save_every = max(1, n_steps ÷ FRAMES)
    zee = TimeDependentZeeman(ConstantWaveform(p_of(B_uG)), ConstantWaveform(0.0),
        ConstantWaveform(ε), nothing)
    ws = make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=zee, sim_params=SimParams(; dt=DT, n_steps, imaginary_time=false,
            save_every), psi_init=ψ,
        enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND,
        ddi_padding=PADDING, ddi_trunc_radius=-1.0)
    trace = Tuple{Float64, Float64, Float64, Float64}[]   # t_ms, fperp, fz, norm
    rec!() = begin
        h = Array(ws.state.psi)
        s = spin_scalars(h, PRESET.grid)
        push!(trace, (ws.state.t * MS_PER_TAU, s.fperp, s.fz,
            total_norm(ws.state.psi, PRESET.grid)))
    end
    rec!()
    for step in 1:n_steps
        split_step_midpoint!(ws)
        (step % save_every == 0 || step == n_steps) && rec!()
    end
    f0 = trace[1][2]
    # First time the order parameter has moved by DEPART. NaN when it never does —
    # which is the answer "it did not depart within this hold", not "it is stable":
    # the hold is finite and the caller is told its length.
    idx = findfirst(t -> abs(t[2] - f0) >= DEPART, trace)
    (; trace, f0, fperp_end=trace[end][2],
        max_excursion=maximum(abs(t[2] - f0) for t in trace),
        t_depart_ms=idx === nothing ? NaN : trace[idx][1],
        drift_norm=trace[end][4] - trace[1][4])
end

"""Perturb and re-minimise at the same (B, ε). A minimum returns to its own
⟨F⊥⟩; a saddle slides off."""
function remin(psi, B_uG, ε; η=ETA, cap=REMIN, seed=2)
    ψ = Array{ComplexF64}(psi)
    perturb!(ψ, η, seed)
    g = find_ground_state_lbfgs(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=static_zeeman(; Bz=p_of(B_uG), Bx=ε, q=0.0),
        psi_init=ψ, n_steps=cap, tol=1e-5, m_lbfgs=10, newton_polish=false,
        verbose=false, enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false,
        backend=BACKEND, ddi_padding=PADDING, ddi_trunc_radius=-1.0)
    s = spin_scalars(Array{ComplexF64}(g.workspace.state.psi), PRESET.grid)
    (; s.fperp, s.fz, E=g.energy, grad=g.grad_norm, stop=String(g.stop_reason))
end

# ----------------------------------------------------------------- calibration

"""Show that HOLD can report unstable AND can report stable, before any cell's
verdict is believed.

**One state, two hold fields, straddling the known spinodal.** The controls use
the SAME ψ — the last converged flower cell — held at its own field and a few µG
past the spinodal, so the pair differs in exactly the variable under test. An
earlier design held the flower ψ far above the spinodal and the polarised ψ at
high field; that pair also varied the state, the field mismatch and the branch at
once, so a departure could have been non-stationarity rather than instability.
Here the field mismatch is a few percent in p for both arms, and only one of them
crosses the branch's end."""
function calibrate_hold()
    fl = get(ENV, "SB_CONTROL_FLOWER", "")
    isempty(fl) && throw(BlindStability(
        "SB_CONTROL_FLOWER is required: without it this script cannot show that " *
        "it is able to return `unstable`, and a stability test that can only say " *
        "`stable` is not a measurement"))
    c = load_cell(fl)
    # WELL past the spinodal, not just past it. An instability's growth rate
    # vanishes at the spinodal (generically as √(B − B_sp)), so a hold a couple of
    # µG beyond the branch's end sees almost nothing: measured, the flower ψ from
    # 68.25 µG held at 70 µG moved by 0.089 in 217 ms and the control correctly
    # refused. That is physics, not a broken instrument — and §5.2 turns it into
    # the departure-time scan. The control needs a field where the growth is fast
    # enough to be unambiguous within the hold.
    Bu = getf("SB_CONTROL_UNSTABLE_B", c.B + 25)
    Bs = getf("SB_CONTROL_STABLE_B", c.B)           # its own field
    bad = String[]

    pos = hold(c.psi, Bu, c.pin)
    @printf("  positive control: flower ψ(B=%.2f, ⟨F⊥⟩=%.3f) held at %.2f µG (past the spinodal) → ⟨F⊥⟩ %.3f → %.3f (max excursion %.3f)\n",
        c.B, c.fperp0, Bu, pos.f0, pos.fperp_end, pos.max_excursion)
    pos.max_excursion >= DEPART || push!(bad,
        "POSITIVE control did not depart (excursion $(round(pos.max_excursion; digits=4)) < $DEPART): " *
        "the flower state held past the end of its own branch must go unstable, " *
        "so this instrument cannot currently detect instability at all. Either " *
        "the hold is shorter than the growth time, or the perturbation is too " *
        "small to seed the unstable mode")

    neg = hold(c.psi, Bs, c.pin)
    @printf("  negative control: the SAME ψ held at its own field %.2f µG → ⟨F⊥⟩ %.3f → %.3f (max excursion %.3f)\n",
        Bs, neg.f0, neg.fperp_end, neg.max_excursion)
    neg.max_excursion < DEPART || push!(bad,
        "NEGATIVE control departed (excursion $(round(neg.max_excursion; digits=4)) ≥ $DEPART): " *
        "a converged cell held at its own field is not in question, so the " *
        "threshold or the perturbation is calling ordinary breathing an instability")

    # The perturbation must also not have swamped the state: if it did, both arms
    # start from the same noise-dominated ⟨F⊥⟩ and neither verdict is about ψ.
    isnan(c.fperp0) || abs(pos.f0 - c.fperp0) < 0.05 * max(c.fperp0, 1) ||
        push!(bad,
        "the perturbation moved ⟨F⊥⟩ from $(round(c.fperp0; digits=4)) to " *
        "$(round(pos.f0; digits=4)) BEFORE any propagation — η is too large and " *
        "the hold would be measuring the noise, not the state")

    isempty(bad) || throw(BlindStability(join(bad, "\n  ")))
    println("  controls passed: the hold can report both unstable and stable\n")
    (; pos, neg, Bu, Bs)
end

# --------------------------------------------------------------------- driver

cells = let s = get(ENV, "SB_CELLS", "")
    # `;` as well as `,`: qsub -v separates VARIABLES with commas, so a
    # comma-joined cell list arrives as its first element only — silently, and a
    # one-cell run looks exactly like a one-cell run that was asked for.
    v = isempty(s) ? String[] : String.(split(s, r"[,;]"))
    n = get(ENV, "SB_CELLS_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        SB_CELLS parsed $(length(v)) entries but SB_CELLS_N says $n.
        A list passed through `qsub -v` is cut at the first comma — use `;`.""")
    v
end
isempty(cells) && error("SB_CELLS is empty — nothing to test")

@printf("""
Branch stability: κ=%.2f grid=%d³ box=%.1f  %s
  hold τ=%.4g ω_ref⁻¹ (%.1f ms) dt=%g   noise η=%.3g   remin cap=%d
  departure threshold %.3g in ⟨F⊥⟩   DDI padding=%s
  %d cell(s)
""", KAPPA, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU",
    HOLD_TAU, HOLD_TAU * MS_PER_TAU, DT, ETA, REMIN, DEPART, PADDING,
    length(cells))
flush(stdout)

if get(ENV, "SB_SKIP_CONTROLS", "0") == "1"
    @warn "SB_SKIP_CONTROLS=1: the verdicts below are UNCALIBRATED and must not be quoted"
else
    println("calibrating the hold:")
    flush(stdout)
    calibrate_hold()
end

# SB_HOLD_B may be a LIST. Holding one state at several fields past its spinodal
# is how the departure TIME is measured, and the departure time is what reconciles
# a branch that ends at 68.4 µG with a ramp that carries flower-like ⟨F⊥⟩ well
# above it: the branch is gone, but the mode that destroys it grows slowly near
# the end of the branch.
hold_fields = let s = get(ENV, "SB_HOLD_B", "")
    isempty(strip(s)) ? Float64[] : parse.(Float64, split(s, r"[,;]"))
end

rows = NamedTuple[]
for (i, p) in enumerate(cells), B in (isempty(hold_fields) ? [NaN] : hold_fields)
    c = load_cell(p)
    B = isnan(B) ? c.B : B
    t0 = time()
    h = hold(c.psi, B, c.pin)
    r = REMIN > 0 ? remin(c.psi, B, c.pin) : nothing
    # The two instruments are reported side by side and never merged: HOLD is
    # blind to an instability slower than the hold, REMIN is blind to sliding
    # along a flat direction, and a single word would hide which one spoke.
    verdict_hold = h.max_excursion >= DEPART ? "DEPARTS" : "stays"
    verdict_remin = r === nothing ? "-" :
                    abs(r.fperp - c.fperp0) >= DEPART ? "SLIDES" : "returns"
    push!(rows, (; cell=i, path=p, B_uG=B, B_cell=c.B, pin=c.pin,
        fperp0=isnan(c.fperp0) ? h.f0 : c.fperp0, fperp_hold_end=h.fperp_end,
        hold_max_excursion=h.max_excursion, hold=verdict_hold,
        t_depart_ms=h.t_depart_ms, hold_ms=HOLD_TAU * MS_PER_TAU,
        norm_drift=h.drift_norm,
        fperp_remin=r === nothing ? NaN : r.fperp,
        remin_grad=r === nothing ? NaN : r.grad,
        remin=verdict_remin, wall_s=round(time() - t0; digits=1)))
    @printf("[%2d] cell B=%6.2f held at %6.2f µG  ⟨F⊥⟩0=%.4f   HOLD %s (end %.4f, max Δ %.4f, t_depart %s ms of %.0f, |ψ|² drift %.1e)   REMIN %s (%.4f)  %.0fs\n",
        i, c.B, B, rows[end].fperp0, verdict_hold, h.fperp_end, h.max_excursion,
        isnan(h.t_depart_ms) ? "never" : string(round(h.t_depart_ms; digits=1)),
        HOLD_TAU * MS_PER_TAU, h.drift_norm, verdict_remin,
        rows[end].fperp_remin, time() - t0)
    flush(stdout)
    ks = collect(keys(rows[1]))
    open(joinpath(OUT, "stability.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for r2 in rows
            writedlm(io, reshape(Any[getfield(r2, k) for k in ks], 1, :))
        end
    end
end

println("\nALLDONE  $(length(rows)) cell(s) → $OUT/stability.csv")
println("""
Read it as: a cell whose HOLD stays and whose REMIN returns is a genuine local
minimum, so the branch still exists there and a ramp edge at that field is NOT a
spinodal — it is barrier crossing driven by whatever excitation the ramp
delivered, and it will move with rate without saturating. A cell that DEPARTS is
past its spinodal, and the field where that starts IS a rate-independent
prediction.
""")
