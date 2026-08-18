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
#   AR_RATES=               |dB/dt| [µG/ms]; sets τ per leg from ITS OWN span, so
#                           the rate axis is not confounded by the window width.
#                           Overrides AR_TAUS when set. Prefer this whenever the
#                           two legs are compared: at fixed τ a wider window is a
#                           faster ramp, and loop width grows with ramp speed, so
#                           a τ-indexed scan over an asymmetric window compares
#                           two different rates and calls the difference physics.
#   AR_B_LO=20  AR_B_HI=100 ramp endpoints [µG]
#   AR_SEED_RISE_B=         seed field for the flower leg  (default: max B on "up")
#   AR_SEED_FALL_B=         seed field for the polar leg   (default: max B on "dn")
#   AR_SEED_RISE_FILE=      explicit seed jld2 for the flower leg (bypasses the
#   AR_SEED_FALL_FILE=      library index). Use when the seeds were converged at
#                           a pin ε the merged library does not carry — the pin
#                           must be ONE value across both legs and both κ, or the
#                           loop is being attributed to κ while ε also moved.
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
using DelimitedFiles: writedlm, readdlm
using JLD2: jldsave, jldopen
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d

"""Parse a list-valued env var, and REFUSE a silent truncation.

UGE's `qsub -v` separates variables with commas, so a comma inside a value ends
it: `-v AR_RATES=40,12,4` sets AR_RATES=40 and then creates variables named `12`
and `4`. That is not a hypothetical — it cost this campaign a full rate scan that
came back looking like a clean single-rate run. Semicolons are accepted for that
reason, and `<name>_N` states how many entries the caller meant, so a truncation
becomes an error instead of a plausible answer."""
function getlist(k, default)
    s = get(ENV, k, default)
    v = isempty(strip(s)) ? Float64[] : parse.(Float64, split(s, r"[,;]"))
    n = get(ENV, k * "_N", "")
    isempty(n) || length(v) == parse(Int, n) || error("""
        $k parsed $(length(v)) entries but $(k)_N says $n: $(repr(s)).
        A list passed through `qsub -v` is cut at the first comma — use `;`.""")
    v
end
const SMOKE = get(ENV, "AR_SMOKE", "") == "1"
const KAPPA = getf("AR_KAPPA", 1.8)
const TAUS = SMOKE ? [1.0] : sort(getlist("AR_TAUS", "3,10,30,100"))
# |dB/dt| in µG/ms. Non-empty ⇒ each leg derives its own τ from its own span, so
# both legs of one loop are ramped at the SAME field rate even when the window is
# traversed in opposite directions from different seed fields.
const RATES = SMOKE ? Float64[] : sort(getlist("AR_RATES", ""); rev=true)
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
function seed(branch, B_uG; file="")
    e = if isempty(file)
        x = load_gs(; κ=KAPPA, B_uG, branch=String(branch), grid=GRID_N, lib=LIB)
        abs(x.meta.B - B_uG) < 0.5 ||
            @warn "requested seed B=$B_uG µG; nearest library state is $(x.meta.B) µG"
        x
    else
        isfile(file) || error("seed file $file does not exist")
        jldopen(file, "r") do f
            g(k, d) = haskey(f, k) ? f[k] : d
            (; psi=Array{ComplexF64}(f["psi"]),
                meta=(; B=g("B_uG", B_uG), path=file,
                    E=g("E_total", g("E", NaN)), grad=g("grad_norm", NaN)))
        end
    end
    m = jldopen(e.meta.path, "r") do f
        g(k, d) = haskey(f, k) ? f[k] : d
        # `pin_bx` is the continuation driver's name, `pin_eps` the reference
        # solver's, for the same ε. Neither may default: a missing pin silently
        # becoming 0 would unpin the Goldstone and the seed would not be
        # stationary at t=0, which is the transient the whole rate scan would
        # then be measuring.
        pin = g("pin_bx", g("pin_eps", nothing))
        pin === nothing && error("seed $(e.meta.path) records no pin (pin_bx / pin_eps)")
        (; c0=f["c0"], c1=f["c1"], c_dd=f["c_dd"], p=f["zeeman_p"],
            pin=pin, box=f["grid_box_size"], n=f["grid_n_points"])
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

"""The pin ε a seed was converged with, read WITHOUT loading ψ (used to fill the
manifest row of a cached arm; a NaN there would be an unknown masquerading as a
number in the one column that says which Hamiltonian was ramped)."""
function seed_pin(branch, B_uG; file="")
    path = isempty(file) ?
           load_gs(; κ=KAPPA, B_uG, branch=String(branch), grid=GRID_N, lib=LIB).meta.path :
           file
    jldopen(path, "r") do f
        haskey(f, "pin_bx") ? f["pin_bx"] :
        haskey(f, "pin_eps") ? f["pin_eps"] :
        error("seed $path records no pin (pin_bx / pin_eps)")
    end
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
function run_ramp(; branch, B_seed, B_end, τ, tag, seed_file="")
    s = seed(branch, B_seed; file=seed_file)
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
    # `B_at` reconstructs the ramp's field from the recorded time rather than
    # reading the waveform, so a change to the waveform and a change here can
    # disagree — keep it linear-in-t to match `RampWaveform(..., :linear)`.
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
    base = joinpath(OUT, tag)
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

# A seed is stationary only at ITS OWN field, so an explicit seed file DICTATES
# where its leg starts. Assert that field is the window end the leg is supposed to
# start from: handing the fall leg a 100 µG seed while declaring the window top as
# 200 leaves the two legs spanning different windows, which is the exact defect
# this campaign exists to remove — and it would show up only as a suspiciously
# narrow loop.
function seed_start(file, B_want, branch)
    isempty(file) && return getf(
        branch == "up" ? "AR_SEED_RISE_B" : "AR_SEED_FALL_B",
        branch_edge(branch, :max))
    isfile(file) || error("seed file $file does not exist")
    B = jldopen(file, "r") do f
        haskey(f, "B_uG") ? Float64(f["B_uG"]) :
        error("seed $file records no B_uG, so its ramp start is unknown")
    end
    tol = getf("AR_SEED_B_TOL", 0.5)
    abs(B - B_want) < tol || error("""
        seed file is at B=$B µG but this leg must start at $B_want µG (the window
        end), so the two legs would not span one field window.
          seed = $file
        Set AR_SEED_B_TOL to widen, or AR_B_LO/AR_B_HI to match the seeds.""")
    B
end

legs = Any[]
for leg in LEGS
    if leg == "rise"          # flower, metastable ABOVE B_eq → ramp up
        f = get(ENV, "AR_SEED_RISE_FILE", "")
        push!(legs, (; tag="rise", branch="up", B_seed=seed_start(f, B_LO, "up"),
            B_end=B_HI, file=f))
    elseif leg == "fall"      # polarised, metastable BELOW B_eq → ramp down
        f = get(ENV, "AR_SEED_FALL_FILE", "")
        push!(legs, (; tag="fall", branch="dn", B_seed=seed_start(f, B_HI, "dn"),
            B_end=B_LO, file=f))
    else
        error("unknown leg '$leg' (expected rise / fall)")
    end
end

# One job per (rate, leg) or (τ, leg). With AR_RATES the two legs of a loop get
# DIFFERENT τ — whatever each needs to cross its own span at the same |dB/dt| —
# and the pairing key for the analysis is the rate, so the label carries it.
jobs = Any[]
if isempty(RATES)
    @printf("τ grid: %s ω_ref⁻¹ = %s ms\n",
        join(TAUS, ", "), join(round.(TAUS .* MS_PER_TAU; digits=2), ", "))
    for τ in TAUS, L in legs
        push!(jobs, (; L..., τ, rate=abs(L.B_end - L.B_seed) / (τ * MS_PER_TAU),
            label=@sprintf("%s_tau%g", L.tag, τ)))
    end
else
    @printf("rate grid: %s µG/ms\n", join(RATES, ", "))
    for R in RATES, L in legs
        τ = abs(L.B_end - L.B_seed) / (R * MS_PER_TAU)
        push!(jobs, (; L..., τ, rate=R,
            label=@sprintf("%s_rate%g", L.tag, R)))
    end
end

# One manifest file PER LEG, not one per directory. The legs of a loop are
# submitted as separate jobs writing into the same output dir, and each rewrites
# its manifest whole from its own rows — so a single `manifest.csv` means whichever
# job finished last silently deleted the other leg's rows. Readers glob
# `manifest*.csv`.
const MANIFEST = joinpath(OUT, "manifest_" * join(sort(collect(LEGS)), "_") * ".csv")

manifest = Any[]
write_manifest() = isempty(manifest) ? nothing : open(MANIFEST, "w") do io
    ks = collect(keys(manifest[1]))
    writedlm(io, reshape(String.(ks), 1, :))
    for m in manifest
        writedlm(io, reshape(Any[getfield(m, k) for k in ks], 1, :))
    end
end

for J in jobs
    println()
    τ = J.τ
    # Resume: the slowest arm of a rate scan is hours, and a wall-clock kill part
    # way through must not cost the arms that already finished. A run is complete
    # iff BOTH its CSVs exist (the pops file is written second).
    base = joinpath(OUT, J.label)
    if isfile(base * ".csv") && isfile(base * "_pops.csv") &&
       get(ENV, "AR_FORCE", "0") != "1"
        # Rebuild the manifest row FROM the cached trajectory rather than from the
        # previous manifest.csv: the manifest is rewritten whole each iteration,
        # so a skipped arm that contributed no row would be silently dropped from
        # the file — a resumed job would then report a rate scan missing exactly
        # the arms that had already succeeded.
        d = readdlm(base * ".csv", '\t'; header=true)
        A, h = d[1], vec(d[2])
        ci = Dict(strip(String(x)) => i for (i, x) in enumerate(h))
        gv(r, k) = Float64(A[r, ci[k]])
        n = size(A, 1)
        push!(manifest,
            (; kappa=KAPPA, grid=GRID_N, tag=J.tag, label=J.label, branch=J.branch,
                rate_uG_per_ms=J.rate, tau=τ, tau_ms=τ * MS_PER_TAU,
                B_seed=gv(1, "B_uG"), B_end=J.B_end,
                pin=seed_pin(J.branch, J.B_seed; file=J.file),
                fperp_start=gv(1, "fperp"), fperp_end=gv(n, "fperp"),
                fz_start=gv(1, "fz"), fz_end=gv(n, "fz"),
                Lz_end=gv(n, "Lz"), Jz_end=gv(n, "Jz"),
                Jz_drift=gv(n, "Jz") - gv(1, "Jz"),
                E_end=gv(n, "E"), norm_drift=gv(n, "norm") - gv(1, "norm"),
                n_frames=n, wall_s=NaN))
        @printf("SKIP %s (cached, %d frames; AR_FORCE=1 to redo)\n", J.label, n)
        flush(stdout)
        write_manifest()
        continue
    end
    r = run_ramp(; branch=J.branch, B_seed=J.B_seed, B_end=J.B_end, τ,
        tag=J.label, seed_file=J.file)
    last = r.rows[end]
    first_ = r.rows[1]
    push!(
        manifest,
        (; kappa=KAPPA, grid=GRID_N, tag=J.tag, label=J.label, branch=r.branch,
            rate_uG_per_ms=J.rate, tau=τ,
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

    write_manifest()
end

println("\nwrote $MANIFEST + per-run trajectory/population CSVs")
println("""
Loop width from these runs: for each τ, the field at which ⟨F⊥⟩ jumps on the
`rise` leg minus the field at which it jumps on `fall`. Saturating with τ ⇒
bistability; shrinking ⇒ dynamical lag; absent at κ ≤ 0.9 ⇒ crossover control
holds. Plot with scripts/viz_eu_adiabatic_ramp.py.
""")
