# Can a rotating transverse field move the weak-field ¹⁵¹Eu state between J_z
# sectors — the one thing no ramp can do?
#
# Established (2026-07-28, PR #114): at (κ=1.8, B=20 µG) the flower ground state has
# J_z = −1.087 while every preparable ramp endpoint sits at J_z = −3.15, because a
# κ ramp and a B_z ramp are both axially symmetric and conserve J_z. The remaining
# route is to apply a TORQUE about z. A transverse field b_⊥ does exactly that: it
# does not commute with F_z, so it exchanges angular momentum with the state.
#
# This drives b_⊥ in a circle at rate Ω:  b_x = ε cos(Ω t),  b_y = ε sin(Ω t),
# holding κ and B_z fixed, starting from the state the κ ramp actually produces.
# The verdict is a single number: **does J_z leave −3.15, and does it move toward
# −1.09 while E falls toward 10.73?**
#
# Scale-setting. The Larmor frequency at B = 20 µG is |p| = 0.296 ω_ref, so Ω ≈ 0.3
# is resonant; the scan straddles it and includes the counter-rotating sign, since
# which sense of rotation ADDS J_z is not predictable in advance. ε is quoted in the
# same dimensionless p-units as the Goldstone pin: ε = 0.002 ↔ 0.135 µG, so ε = 0.05
# ↔ 3.4 µG, the scale of a realistic un-nulled residual field. That makes this scan
# do double duty as the magnetic-shielding specification — the ε at which the state
# stops being inert is also the ε an experiment must null below.
#
# FREQUENCY CONVENTION. `SinusoidalWaveform` evaluates
# `center + amplitude·sin(2π·frequency·t + phase)`, so a rotation at ANGULAR rate Ω
# (ω_ref units) needs `frequency = Ω/2π`. Passing Ω directly is the Klaus-2022
# magnetostir footgun and gives a 2π-too-fast drive.
#
# Env:
#   TQ_SEED=<jld2>          state to torque (default: the κ-ramp endpoint at κ=1.8)
#   TQ_EPS=0.02,0.05        transverse amplitudes [p-units]; 0 ⇒ inert control
#   TQ_OMEGA=0.1,0.3,1.0,-0.3   rotation rates [ω_ref]; sign = sense of rotation
#   TQ_TAU=100              drive duration [ω_ref⁻¹]  (1 ω_ref⁻¹ = 1.447 ms)
#   TQ_KAPPA=1.8  TQ_B_HOLD=20
#   TQ_DT=0.002  TQ_FRAMES=200  TQ_GRID=32  TQ_BOX=24
#   TQ_OUT=figs/eu_torque   TQ_SAVE_PSI=0
#   TQ_SMOKE=1              τ=2, dt=0.004, one cell — every path in ≤ 2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_torque_protocol.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    TimeDependentZeeman, ConstantWaveform, SinusoidalWaveform,
    split_step_midpoint!, HarmonicTrap, component_populations, total_energy,
    total_norm, magnetization, orbital_angular_momentum,
    CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave, jldopen
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "TQ_SMOKE", "") == "1"
const KAPPA = getf("TQ_KAPPA", 1.8)
const B_HOLD = getf("TQ_B_HOLD", 20.0)
const EPS = SMOKE ? [0.05] :
            parse.(Float64, split(get(ENV, "TQ_EPS", "0.02,0.05"), ","))
const OMEGAS = SMOKE ? [0.3] :
               parse.(Float64, split(get(ENV, "TQ_OMEGA", "0.1,0.3,1.0,-0.3"), ","))
const TAU = SMOKE ? 2.0 : getf("TQ_TAU", 100.0)
const DT = SMOKE ? 0.004 : getf("TQ_DT", 0.002)
const FRAMES = SMOKE ? 20 : Int(getf("TQ_FRAMES", 200))
const GRID_N = Int(getf("TQ_GRID", 32))
const BOX = getf("TQ_BOX", 24.0)
const SAVE_PSI = get(ENV, "TQ_SAVE_PSI", "0") == "1"
const SEED_PATH = get(ENV, "TQ_SEED",
    "figs/eu_kappa_scan/k1.8/B020/kramp_tau100_final.jld2")
const OUT = joinpath(get(ENV, "TQ_OUT", "figs/eu_torque"),
    @sprintf("k%.2f_B%03.0f", KAPPA, B_HOLD))
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const ΩREF = PRESET.omega_ref
const MS_PER_TAU = 1e3 / ΩREF
const P_HOLD = Units.bfield_to_p(B_HOLD * 1e-6, ATOM.g_F, ΩREF)

# Dealias off: at 32³/box 24 the 2/3 cutoff (2.62) sits below the occupied band
# √(2µ) ≈ 4.3 and the filter removes real modes.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "TQ_DEALIAS", "0") == "1"

eps_to_uG(ε) = abs(ε) * Units.HBAR * ΩREF / (ATOM.g_F * Units.BOHR_MAGNETON) * 1e10

"""Seed to torque, with the same epoch assertion the ramp drivers use."""
function seed()
    isfile(SEED_PATH) || error("no seed at $SEED_PATH — run the κ_1 scan with KR_SAVE_PSI=1")
    d = jldopen(SEED_PATH, "r") do f
        (; psi=Array{ComplexF64}(f["psi"]), c0=f["c0"], c1=f["c1"], c_dd=f["c_dd"],
            p=f["zeeman_p"], box=f["grid_box_size"], n=f["grid_n_points"],
            kappa=haskey(f, "kappa_1") ? f["kappa_1"] : NaN)
    end
    assert_seed_epoch(SEED_PATH, (; d.c0, d.c1, d.c_dd, d.p, d.box, d.n);
        c0=PRESET.interactions.c[0], c1=PRESET.interactions.c[1],
        c_dd=PRESET.c_dd, p=P_HOLD,
        n_points=(GRID_N, GRID_N, GRID_N), box=BOX)
    isnan(d.kappa) || abs(d.kappa - KAPPA) < 1e-6 ||
        error(
            "seed was produced at κ=$(d.kappa) but TQ_KAPPA=$KAPPA — the trap " *
            "would differ from the one the state is stationary in",
        )
    d.psi
end

function frame(ws)
    psi = Array(ws.state.psi)
    s = spin_scalars(psi, PRESET.grid)
    Lz = orbital_angular_momentum(psi, PRESET.grid, ws.fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    (; s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz, E=total_energy(ws),
        norm=total_norm(ws.state.psi, PRESET.grid),
        pops=component_populations(psi, PRESET.grid, SYS).populations)
end

"""One drive: b_⊥ of amplitude ε rotating at angular rate Ω for τ."""
function run_torque(psi0, ε, Ω)
    n_steps = max(1, ceil(Int, TAU / DT))
    save_every = max(1, n_steps ÷ FRAMES)
    # frequency = Ω/2π: SinusoidalWaveform carries its own 2π (see header).
    f = Ω / (2π)
    zee = TimeDependentZeeman(
        ConstantWaveform(P_HOLD), ConstantWaveform(0.0),
        SinusoidalWaveform(; amplitude=ε, frequency=f, phase=π / 2),   # b_x = ε cos Ωt
        SinusoidalWaveform(; amplitude=ε, frequency=f, phase=0.0),     # b_y = ε sin Ωt
    )
    sp = SimParams(; dt=DT, n_steps, imaginary_time=false, save_every)
    ws = make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=zee, sim_params=sp, psi_init=psi0,
        enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND)

    @printf("\nε = %.3f (%.2f µG)  Ω = %+.2f ω_ref (%.1f Hz)  τ = %.0f ω_ref⁻¹ (%.0f ms)\n",
        ε, eps_to_uG(ε), Ω, Ω * ΩREF / 2π, TAU, TAU * MS_PER_TAU)
    flush(stdout)

    rows = Any[]
    rec!(step) = begin
        fr = frame(ws)
        push!(
            rows,
            (; step, t=ws.state.t, t_ms=ws.state.t * MS_PER_TAU,
                fr.fz, fr.fperp, fr.Lz, fr.Sz, fr.Jz, fr.E, fr.norm, pops=fr.pops),
        )
        rows[end]
    end

    t0 = time()
    rec!(0)
    for step in 1:n_steps
        split_step_midpoint!(ws)
        if step % save_every == 0 || step == n_steps
            r = rec!(step)
            if step % (10 * save_every) == 0 || step == n_steps
                @printf(
                    "    step %d/%d  t=%.1f ms  J_z=%+.4f  L_z=%+.4f  ⟨F⊥⟩=%.3f  E=%.6f  |ψ|²=%.6f  %.0fs\n",
                    step, n_steps, r.t_ms, r.Jz, r.Lz, r.fperp, r.E, r.norm, time() - t0)
                flush(stdout)
            end
        end
    end

    base = joinpath(OUT, @sprintf("torque_eps%g_om%g", ε, Ω))
    ks = (:step, :t, :t_ms, :fz, :fperp, :Lz, :Sz, :Jz, :E, :norm)
    open(base * ".csv", "w") do io
        writedlm(io, reshape(String.(collect(ks)), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
        end
    end
    SAVE_PSI && jldsave(base * "_final.jld2";
        psi=Array(ws.state.psi), eps=ε, omega=Ω, kappa=KAPPA, B_uG=B_HOLD,
        tau=TAU, seed=SEED_PATH,
        c0=PRESET.interactions.c[0], c1=PRESET.interactions.c[1], c_dd=PRESET.c_dd,
        c_lhy=0.0, zeeman_p=P_HOLD, zeeman_q=0.0, t=rows[end].t, step=rows[end].step,
        c_dict=Dict(0 => PRESET.interactions.c[0], 1 => PRESET.interactions.c[1]),
        grid_n_points=(GRID_N, GRID_N, GRID_N), grid_box_size=(BOX, BOX, BOX),
        dt=DT, imaginary_time=false)
    (; ε, Ω, rows, wall_s=time() - t0)
end

# --------------------------------------------------------------------- driver

@printf("Eu z-torque protocol: κ=%.2f, B=%.1f µG held, grid=%d³ box=%.1f  %s%s\n",
    KAPPA, B_HOLD, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU", SMOKE ? "  [SMOKE]" : "")
@printf("seed: %s\n", SEED_PATH)
@printf("Larmor at this field: |p| = %.3f ω_ref (%.1f Hz) — Ω near it is resonant\n",
    abs(P_HOLD), abs(P_HOLD) * ΩREF / 2π)

const PSI0 = seed()
const S0 = spin_scalars(PSI0, PRESET.grid)
@printf("seed state: ⟨F⊥⟩=%.3f ⟨F_z⟩=%.3f\n", S0.fperp, S0.fz)

manifest = Any[]
for ε in EPS, Ω in OMEGAS
    r = run_torque(PSI0, ε, Ω)
    a, b = r.rows[1], r.rows[end]
    push!(
        manifest,
        (; kappa=KAPPA, B_uG=B_HOLD, eps=ε, eps_uG=eps_to_uG(ε), omega=Ω,
            omega_hz=Ω * ΩREF / 2π, tau=TAU, tau_ms=TAU * MS_PER_TAU,
            Jz_start=a.Jz, Jz_end=b.Jz, dJz=b.Jz - a.Jz,
            Lz_end=b.Lz, Sz_end=b.Sz, fperp_end=b.fperp,
            E_start=a.E, E_end=b.E, norm_drift=b.norm - a.norm,
            wall_s=round(r.wall_s; digits=1)),
    )
    @printf("  ⇒ J_z %+.4f → %+.4f  (ΔJ_z = %+.4f)   ⟨F⊥⟩ %.3f → %.3f   E %.4f → %.4f   %.0fs\n",
        a.Jz, b.Jz, b.Jz - a.Jz, a.fperp, b.fperp, a.E, b.E, r.wall_s)
    flush(stdout)

    ks = collect(keys(manifest[1]))
    open(joinpath(OUT, "manifest.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for m in manifest
            writedlm(io, reshape(Any[getfield(m, k) for k in ks], 1, :))
        end
    end
end

println("\nwrote $(OUT)/manifest.csv + per-cell trajectory CSVs")
println("""
Verdict: ΔJ_z. The ramps hold J_z to 3e-3; anything materially larger here means a
transverse field opens the sector, and the target is ΔJ_z = +2.07 with E falling
toward the flower ground state's 10.73. ΔJ_z ≈ 0 at every (ε, Ω) means the
transverse field is not the knob and the rotating anisotropic trap is next.
""")
