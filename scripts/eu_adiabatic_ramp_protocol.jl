# Adiabatic-passage protocol for the weak-field ¹⁵¹Eu (F=6) GS transition:
# real-time B_z ramps at several rates, in BOTH directions, seeded from the
# converged GS library — the dynamics half of scripts/eu_adiabatic_window.jl.
#
# What this measures, and why it is not just "hysteresis".
#   Two converged branches with a barrier are BISTABILITY; a first-order
#   transition additionally requires the equilibrium state to jump. A ramp
#   experiment sees a loop for either reason, plus a third: it may simply be
#   too fast (dynamical lag). The discriminator is the RATE DEPENDENCE —
#
#     lag        loop width shrinks as τ grows, → 0
#     bistable   loop width saturates at the mean-field spinodal separation
#     crossover  no loop at any τ
#
#   so the deliverable is loop-width(τ) at two trap oblatenesses: κ ≳ 1.0
#   (first-order side of the tricritical point κ_tc ≈ 0.95) and κ ≤ 0.9
#   (crossover control). The control leg is what makes the prediction
#   falsifiable: the same protocol run at κ = 0.8 must show NO loop.
#
# Two legs per κ, each started from the branch that is metastable in its
# ramp direction:
#   rise  flower  (library branch "up") at low  B → ramp B UP    → upper spinodal
#   fall  polar   (library branch "dn") at high B → ramp B DOWN   → lower spinodal
#
# The Goldstone pin b_x = ε is held at the value the seed was computed with, so
# the seed is stationary at t=0 (no spurious transient) and ε doubles as the
# residual transverse lab field. `eu_adiabatic_window.jl` reports the Larmor
# bound it implies — at these fields it is ~µs, i.e. never the binding
# constraint; the collective texture timescale measured here is.
#
# Integrator: `split_step_midpoint!`, NOT the default `split_step!` — plain
# Strang is FIRST-order in time when DDI is active (mean field frozen at the
# V-step boundary), which a long ramp would accumulate. Orszag 2/3 dealiasing is
# OFF here; see the DEALIAS_2_3_ENABLED comment below for why on this grid.
#
# Env:
#   AR_KAPPA=1.8            trap oblateness ω_z/ω_⊥ (library key)
#   AR_TAUS=3,10,30,100     ramp durations [ω_ref⁻¹]  (1 ω_ref⁻¹ = 1.447 ms)
#   AR_B_LO=20  AR_B_HI=100 ramp endpoints [µG]
#   AR_SEED_RISE_B=         seed field for the flower leg  (default: max B on "up")
#   AR_SEED_FALL_B=         seed field for the polar leg   (default: max B on "dn")
#   AR_LEGS=rise,fall       which legs to run
#   AR_DT=0.002  AR_FRAMES=200
#   AR_LIB=figs/eu_gs_library   AR_OUT=figs/eu_adiabatic_ramp
#   AR_SAVE_PSI=0           persist the final ψ per run
#   AR_SMOKE=1              τ=1, dt=0.004, 20 frames — every path in ≤ 2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_adiabatic_ramp_protocol.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    TimeDependentZeeman, RampWaveform, ConstantWaveform, split_step_midpoint!,
    _spin_expectation_fields, cell_volume, component_populations, total_energy,
    total_norm, magnetization, orbital_angular_momentum,
    CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave, jldopen
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "AR_SMOKE", "") == "1"
const KAPPA = getf("AR_KAPPA", 1.8)
const TAUS = SMOKE ? [1.0] :
             sort(parse.(Float64, split(get(ENV, "AR_TAUS", "3,10,30,100"), ",")))
const B_LO = getf("AR_B_LO", 20.0)
const B_HI = getf("AR_B_HI", 100.0)
const LEGS = split(get(ENV, "AR_LEGS", "rise,fall"), ",")
const DT = SMOKE ? 0.004 : getf("AR_DT", 0.002)
const FRAMES = SMOKE ? 20 : Int(getf("AR_FRAMES", 200))
const LIB = get(ENV, "AR_LIB", "figs/eu_gs_library")
const GRID_N = Int(getf("AR_GRID", 32))
const BOX = getf("AR_BOX", 24.0)
const SAVE_PSI = get(ENV, "AR_SAVE_PSI", "0") == "1"
const OUT = joinpath(get(ENV, "AR_OUT", "figs/eu_adiabatic_ramp"),
    @sprintf("k%.2f", KAPPA))
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const ΩREF = PRESET.omega_ref
const MS_PER_TAU = 1e3 / ΩREF                       # ω_ref⁻¹ → ms

# Orszag 2/3 dealiasing is OFF by default here, against the general Eu-DDI
# recommendation, and the reason is grid-specific: at 32³ in a box of 24 the 2/3
# cutoff is k_cut = (32÷3)·2π/24 = 2.62, while the occupied band reaches
# k ≈ √(2µ) ≈ 4.3 (µ ≈ 9.3 in ω_ref units). The filter therefore removes
# PHYSICALLY OCCUPIED modes, and measurably so: with it on, |ψ|² bleeds at
# ≈ 3e-6 per step with no sign of front-loading — ~17 % over the 5·10⁴ steps of
# a τ = 100 ramp. The library seeds were also converged without it, so filtering
# only the dynamics would be inconsistent. Turn on via AR_DEALIAS=1 (and keep
# dt·k_cut ≲ 0.1) only on a grid whose 2/3 cutoff clears the occupied band.
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "AR_DEALIAS", "0") == "1"

p_of(B_uG) = Units.bfield_to_p(B_uG * 1e-6, ATOM.g_F, ΩREF)

"""Seed ψ + metadata for one library branch, ASSERTING that the stored
(c0, c1, c_dd, p) match the preset this driver rebuilds. A silent mismatch would
seed one epoch's state into another epoch's Hamiltonian: the seed would not be
stationary and the whole rate scan would be measuring that transient instead of
the ramp. Also returns the pin ε the seed was converged with."""
function seed(branch, B_uG)
    e = load_gs(; κ=KAPPA, B_uG, branch=String(branch), grid=GRID_N, lib=LIB)
    abs(e.meta.B - B_uG) < 0.5 ||
        @warn "requested seed B=$B_uG µG; nearest library state is $(e.meta.B) µG"
    m = jldopen(e.meta.path, "r") do f
        (; c0=f["c0"], c1=f["c1"], c_dd=f["c_dd"], p=f["zeeman_p"],
            pin=f["pin_bx"], box=f["grid_box_size"], n=f["grid_n_points"])
    end
    for (name, got, want, tol) in (
        ("c0", m.c0, PRESET.interactions.c[0], 1e-8),
        ("c1", m.c1, PRESET.interactions.c[1], 1e-8),
        ("c_dd", m.c_dd, PRESET.c_dd, 1e-8),
        ("p(B_seed)", m.p, p_of(e.meta.B), 1e-6),
    )
        rel = abs(got - want) / max(abs(want), 1e-30)
        rel < tol || error("""
            seed/preset mismatch on $name: stored $got vs preset $want (rel $rel).
            The library state was computed with a different parameter epoch —
            fix the preset (n_atoms / box / ω_ref / trap ratios) before ramping.
            seed = $(e.meta.path)""")
    end
    (m.n == (GRID_N, GRID_N, GRID_N) && all(≈(BOX), m.box)) ||
        error("seed grid $(m.n) box $(m.box) ≠ requested $((GRID_N, GRID_N, GRID_N)) / $BOX")
    @printf("  seed: %s branch at B=%.1f µG  (E=%.6f  |∇E|=%.1e  ε=%.0e)  %s\n",
        branch, e.meta.B, e.meta.E, e.meta.grad, m.pin, e.meta.path)
    (; psi=e.psi, B=e.meta.B, E=e.meta.E, grad=e.meta.grad, path=e.meta.path,
        pin=m.pin, c0_ref=m.c0, c1_ref=m.c1)
end

"""Extreme converged field on one branch (`which` = :max or :min)."""
function branch_edge(branch, which::Symbol; gtol=1e-4)
    csv = joinpath(LIB, "library.csv")
    lines = readlines(csv)
    hdr = split(lines[1], '\t')
    col = Dict(strip(h) => i for (i, h) in enumerate(hdr))
    Bs = Float64[]
    for ln in lines[2:end]
        c = split(ln, '\t')
        length(c) < length(hdr) && continue
        (
            parse(Int, c[col["grid"]]) == GRID_N &&
            abs(parse(Float64, c[col["κ"]]) - KAPPA) < 1e-3 &&
            strip(c[col["branch"]]) == String(branch) &&
            parse(Float64, c[col["grad_norm"]]) < gtol
        ) || continue
        push!(Bs, parse(Float64, c[col["B"]]))
    end
    isempty(Bs) && error("no converged states for κ=$KAPPA branch=$branch")
    which === :max ? maximum(Bs) : minimum(Bs)
end

"""Density-weighted spin scalars + orbital/total angular momentum + populations
at the current ψ. All on CPU (the Lz kernel is a CPU FFT path); the copy is
6.8 MB at 32³×13 and happens once per frame."""
function frame_scalars(ws)
    psi = Array(ws.state.psi)
    dV = cell_volume(PRESET.grid)
    dens = dropdims(sum(abs2, psi; dims=4); dims=4)
    fx, fy, fz = _spin_expectation_fields(psi, PRESET.grid)
    ntot = sum(dens) * dV
    Lz = orbital_angular_momentum(psi, PRESET.grid, ws.fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    # component_populations returns (populations, m_values) — take the vector, or
    # a splat into the CSV row writes the whole NamedTuple into one column.
    pops = component_populations(psi, PRESET.grid, SYS).populations
    (; fz=sum(fz) * dV / ntot,
        fperp=sum(sqrt.(fx .^ 2 .+ fy .^ 2)) * dV / ntot,
        Lz, Sz, Jz=Lz + Sz,
        E=total_energy(ws), norm=total_norm(ws.state.psi, PRESET.grid),
        pops=pops, psi=psi)
end

"""One ramp: `B_start → B_end` over `τ` (ω_ref units), seeded from `branch`.
Returns the recorded trajectory."""
function run_ramp(; branch, B_seed, B_end, τ, tag)
    s = seed(branch, B_seed)
    ε = s.pin
    n_steps = max(1, ceil(Int, τ / DT))
    save_every = max(1, n_steps ÷ FRAMES)

    zee = TimeDependentZeeman(
        RampWaveform(p_of(s.B), p_of(B_end), τ, :linear),   # p ∝ −B (Kawaguchi–Ueda)
        ConstantWaveform(0.0),                              # q: auto-derived q ≪ everything here
        ConstantWaveform(ε),                                # pin / residual b_x
        nothing,
    )
    sp = SimParams(; dt=DT, n_steps, imaginary_time=false, save_every)
    ws = make_workspace(; grid=PRESET.grid, atom=ATOM,
        interactions=PRESET.interactions, potential=PRESET.potential,
        zeeman=zee, sim_params=sp, psi_init=s.psi,
        enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND)

    @printf(
        "  ramp %s: B %.1f → %.1f µG over τ=%.3g ω_ref⁻¹ (%.1f ms), %d steps × dt=%g, %d frames\n",
        tag, s.B, B_end, τ, τ * MS_PER_TAU, n_steps, DT, n_steps ÷ save_every)
    flush(stdout)

    rows = Any[]
    B_at(t) = s.B + (B_end - s.B) * clamp(t / τ, 0.0, 1.0)
    record!(step) = begin
        f = frame_scalars(ws)
        push!(
            rows,
            (; step, t=ws.state.t, t_ms=ws.state.t * MS_PER_TAU,
                B_uG=B_at(ws.state.t), f.fz, f.fperp, f.Lz, f.Sz, f.Jz, f.E, f.norm,
                pops=f.pops),
        )
        f
    end

    t0 = time()
    record!(0)
    last = nothing
    for step in 1:n_steps
        split_step_midpoint!(ws)
        if step % save_every == 0 || step == n_steps
            last = record!(step)
            if step % (10 * save_every) == 0 || step == n_steps
                r = rows[end]
                @printf(
                    "    step %d/%d  B=%.2f µG  ⟨F⊥⟩=%.3f  ⟨F_z⟩=%.3f  E=%.6f  |ψ|²=%.6f  %.0fs\n",
                    step, n_steps, r.B_uG, r.fperp, r.fz, r.E, r.norm, time() - t0)
                flush(stdout)
            end
        end
    end

    # trajectory CSV (scalars) + per-frame populations CSV
    base = joinpath(OUT, @sprintf("%s_tau%g", tag, τ))
    scalar_keys = (:step, :t, :t_ms, :B_uG, :fz, :fperp, :Lz, :Sz, :Jz, :E, :norm)
    open(base * ".csv", "w") do io
        writedlm(io, reshape(String.(collect(scalar_keys)), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in scalar_keys], 1, :))
        end
    end
    open(base * "_pops.csv", "w") do io
        # header from SYS.m_values, not an assumed ordering: column c ↔ m_values[c]
        writedlm(io, reshape(vcat(["B_uG", "t_ms"],
                ["m$(Int(m))" for m in SYS.m_values]), 1, :))
        for r in rows
            writedlm(io, reshape(Any[r.B_uG, r.t_ms, r.pops...], 1, :))
        end
    end
    SAVE_PSI && jldsave(base * "_final.jld2";
        psi=last.psi, t=rows[end].t, B_uG=rows[end].B_uG, kappa=KAPPA,
        tau=τ, branch=String(branch), pin_bx=ε, seed_path=s.path,
        c0=s.c0_ref, c1=s.c1_ref, c_dd=PRESET.c_dd,
        grid_n_points=(GRID_N, GRID_N, GRID_N), grid_box_size=(BOX, BOX, BOX),
        dt=DT, imaginary_time=false)

    (; tag, branch=String(branch), τ, B_seed=s.B, B_end, ε, rows,
        wall_s=time() - t0)
end

# --------------------------------------------------------------------- driver

@printf("Eu adiabatic ramp protocol: κ=%.2f  grid=%d³ box=%.1f  %s%s\n",
    KAPPA, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU", SMOKE ? "  [SMOKE]" : "")
@printf("τ grid: %s ω_ref⁻¹ = %s ms\n",
    join(TAUS, ", "), join(round.(TAUS .* MS_PER_TAU; digits=2), ", "))

legs = Any[]
for leg in LEGS
    if leg == "rise"          # flower, metastable ABOVE B_eq → ramp up
        B_seed = getf("AR_SEED_RISE_B", branch_edge("up", :max))
        push!(legs, (; tag="rise", branch="up", B_seed, B_end=B_HI))
    elseif leg == "fall"      # polarised, metastable BELOW B_eq → ramp down
        B_seed = getf("AR_SEED_FALL_B", branch_edge("dn", :max))
        push!(legs, (; tag="fall", branch="dn", B_seed, B_end=B_LO))
    else
        error("unknown leg '$leg' (expected rise / fall)")
    end
end

manifest = Any[]
for τ in TAUS, L in legs
    println()
    r = run_ramp(; branch=L.branch, B_seed=L.B_seed, B_end=L.B_end, τ, tag=L.tag)
    last = r.rows[end]
    first_ = r.rows[1]
    push!(
        manifest,
        (; kappa=KAPPA, tag=r.tag, branch=r.branch, tau=τ,
            tau_ms=τ * MS_PER_TAU, B_seed=r.B_seed, B_end=r.B_end, pin=r.ε,
            fperp_start=first_.fperp, fperp_end=last.fperp,
            fz_start=first_.fz, fz_end=last.fz,
            Lz_end=last.Lz, Jz_end=last.Jz, Jz_drift=last.Jz - first_.Jz,
            E_end=last.E, norm_drift=last.norm - first_.norm,
            n_frames=length(r.rows), wall_s=round(r.wall_s; digits=1)),
    )
    @printf("  ⇒ ⟨F⊥⟩ %.3f → %.3f   ⟨F_z⟩ %.3f → %.3f   J_z drift %.2e   |ψ|² drift %.2e   %.0fs\n",
        first_.fperp, last.fperp, first_.fz, last.fz,
        last.Jz - first_.Jz, last.norm - first_.norm, r.wall_s)
    flush(stdout)

    ks = collect(keys(manifest[1]))
    open(joinpath(OUT, "manifest.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for m in manifest
            writedlm(io, reshape(Any[getfield(m, k) for k in ks], 1, :))
        end
    end
end

println("\nwrote $(OUT)/manifest.csv + per-run trajectory/population CSVs")
println("""
Loop width from these runs: for each τ, the field at which ⟨F⊥⟩ jumps on the
`rise` leg minus the field at which it jumps on `fall`. Saturating with τ ⇒
bistability; shrinking ⇒ dynamical lag; absent at κ ≤ 0.9 ⇒ crossover control
holds. Plot with scripts/viz_eu_adiabatic_ramp.py.
""")
