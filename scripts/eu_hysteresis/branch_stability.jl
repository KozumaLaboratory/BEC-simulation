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
# CONTROLS. The script refuses to report unless it has shown that HOLD can see an
# instability and can also stay quiet on a state that is definitely stable:
#   positive  the flower ψ held ABOVE its spinodal must depart
#   negative  the polarised ψ held at high field must not
# A stability test that cannot return "unstable" proves nothing, which is the
# degenerate-knob trap in yet another costume.
#
# Env:
#   SB_CELLS=a.jld2,b.jld2      cells to test (branch-scan psi.jld2 files)
#   SB_HOLD_B=                  per-cell hold field [µG]; default each cell's own
#   SB_ETA=0.01                 noise amplitude (fraction, add_white_noise!)
#   SB_HOLD_TAU=60              hold duration [ω_ref⁻¹]  (60 ≈ 87 ms)
#   SB_DT=0.002  SB_FRAMES=120
#   SB_REMIN=600                LBFGS cap for the re-minimisation (0 = skip)
#   SB_KAPPA=1.8  SB_GRID=32  SB_BOX=24.0  SB_PIN=0.002  SB_PADDING=0
#   SB_CONTROL_FLOWER=  SB_CONTROL_POLAR=   ψ for the two controls
#   SB_CONTROL_UNSTABLE_B=90    field at which the flower ψ must be unstable
#   SB_CONTROL_STABLE_B=200     field at which the polarised ψ must be stable
#   SB_OUT=figs/eu_hysteresis/stability
#   SB_SKIP_CONTROLS=1          only for debugging; the result is then uncalibrated
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_hysteresis/branch_stability.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    TimeDependentZeeman, ConstantWaveform, split_step_midpoint!, static_zeeman,
    find_ground_state_lbfgs, add_white_noise!, total_norm, total_energy,
    magnetization, orbital_angular_momentum, CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldopen
using Printf

include(joinpath(@__DIR__, "..", "eu_ramp_common.jl"))   # spin_scalars

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

"""Hold at constant `B_uG` from `psi + noise(η)`. Returns the ⟨F⊥⟩ trace and the
largest excursion from t=0. Uses the ramp's integrator with dB/dt = 0."""
function hold(psi, B_uG, ε; η=ETA, τ=HOLD_TAU, seed=1)
    ψ = Array{ComplexF64}(psi)
    η > 0 && add_white_noise!(ψ, η, seed, PRESET.grid)
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
    (; trace, f0, fperp_end=trace[end][2],
        max_excursion=maximum(abs(t[2] - f0) for t in trace),
        drift_norm=trace[end][4] - trace[1][4])
end

"""Perturb and re-minimise at the same (B, ε). A minimum returns to its own
⟨F⊥⟩; a saddle slides off."""
function remin(psi, B_uG, ε; η=ETA, cap=REMIN, seed=2)
    ψ = Array{ComplexF64}(psi)
    η > 0 && add_white_noise!(ψ, η, seed, PRESET.grid)
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

# A departure has to be large enough that it is a branch change and not the
# breathing a noise kick excites on ANY state. A branch change moves ⟨F⊥⟩ by ≈ 2;
# the threshold is set well below that and well above the ~0.05 a stable hold
# shows, and the two controls demonstrate both sides.
const DEPART = getf("SB_DEPART", 0.6)

struct BlindStability <: Exception
    msg::String
end
Base.showerror(io::IO, e::BlindStability) = print(io, "BlindStability: ", e.msg)

"""Show that HOLD can report unstable AND can report stable, before any cell's
verdict is believed."""
function calibrate_hold()
    fl = get(ENV, "SB_CONTROL_FLOWER", "")
    po = get(ENV, "SB_CONTROL_POLAR", "")
    (isempty(fl) || isempty(po)) && throw(BlindStability(
        "SB_CONTROL_FLOWER and SB_CONTROL_POLAR are required: without them this " *
        "script cannot show that it is able to return `unstable`, and a " *
        "stability test that can only say `stable` is not a measurement"))
    Bu = getf("SB_CONTROL_UNSTABLE_B", 90.0)
    Bs = getf("SB_CONTROL_STABLE_B", 200.0)
    bad = String[]

    c = load_cell(fl)
    pos = hold(c.psi, Bu, c.pin)
    @printf("  positive control: flower ψ(B=%.0f) held at %.0f µG → ⟨F⊥⟩ %.3f → %.3f (max excursion %.3f)\n",
        c.B, Bu, pos.f0, pos.fperp_end, pos.max_excursion)
    pos.max_excursion >= DEPART || push!(bad,
        "POSITIVE control did not depart (excursion $(round(pos.max_excursion; digits=4)) < $DEPART): " *
        "the flower state held ABOVE its spinodal must go unstable, so this " *
        "instrument cannot currently detect instability at all")

    c2 = load_cell(po)
    neg = hold(c2.psi, Bs, c2.pin)
    @printf("  negative control: polarised ψ(B=%.0f) held at %.0f µG → ⟨F⊥⟩ %.3f → %.3f (max excursion %.3f)\n",
        c2.B, Bs, neg.f0, neg.fperp_end, neg.max_excursion)
    neg.max_excursion < DEPART || push!(bad,
        "NEGATIVE control departed (excursion $(round(neg.max_excursion; digits=4)) ≥ $DEPART): " *
        "the polarised state at high field is not in question, so the threshold " *
        "or the noise amplitude is calling ordinary breathing an instability")

    isempty(bad) || throw(BlindStability(join(bad, "\n  ")))
    println("  controls passed: the hold can report both unstable and stable\n")
    (; pos, neg, Bu, Bs)
end

# --------------------------------------------------------------------- driver

cells = let s = get(ENV, "SB_CELLS", "")
    isempty(s) ? String[] : String.(split(s, ","))
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

rows = NamedTuple[]
for (i, p) in enumerate(cells)
    c = load_cell(p)
    B = haskey(ENV, "SB_HOLD_B") ? getf("SB_HOLD_B", c.B) : c.B
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
        norm_drift=h.drift_norm,
        fperp_remin=r === nothing ? NaN : r.fperp,
        remin_grad=r === nothing ? NaN : r.grad,
        remin=verdict_remin, wall_s=round(time() - t0; digits=1)))
    @printf("[%2d] B=%6.1f µG  ⟨F⊥⟩0=%.4f   HOLD %s (end %.4f, max Δ %.4f, |ψ|² drift %.1e)   REMIN %s (%.4f)  %.0fs\n",
        i, B, rows[end].fperp0, verdict_hold, h.fperp_end, h.max_excursion,
        h.drift_norm, verdict_remin, rows[end].fperp_remin, time() - t0)
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
