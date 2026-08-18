# Prepare the weak-field ¹⁵¹Eu chiral/flower phase as a GROUND state by crossing
# the tricritical point along κ (trap oblateness) instead of along B.
#
# Why this path. The field-driven route has to cross a barrier: above B_eq the
# flower is metastable, below it the polarised state is, and a mean-field T=0 ramp
# cannot leave a metastable minimum until its spinodal. Measured 2026-07-27 at
# κ=1.8 over 4–434 ms: the flower survives a B ramp to 100 µG at EVERY rate (the
# upper spinodal is outside the window), and the polarised branch converts on the
# way down only once the ramp reaches 434 ms — then sharply, at B = 27.4 µG
# (sharpness 8.0 vs 1.65 at 145 ms), but overshooting to ⟨F⊥⟩ = 3.72 with ringing.
# So the field route does reach the flower state, at ~0.4 s, and delivers it HOT.
#
# The κ route has no barrier to cross. Below the tricritical point (κ_tc ≈ 0.95)
# the transition is a CROSSOVER: one branch, δ⟨F⊥⟩ ≈ 10⁻³, so the ground state is
# reached by plain relaxation. So: converge the ground state at κ = 0.8 and a field
# BELOW B_eq (where the flower is the ground state on both sides), then hold B and
# ramp κ up past κ_tc to 1.8. The state should track the flower branch onto the
# first-order side without ever being metastable.
#
# What is measured
#   ⟨F⊥⟩(κ) along the ramp, at several rates → the adiabaticity threshold. The
#   ramp passes THROUGH the tricritical point, where the relevant mode softens, so
#   critical slowing down is the expected obstruction and it is rate-resolvable.
#   Round trip (κ: 0.8 → 1.8 → 0.8) tests reversibility: a state that does not
#   return has a κ-axis loop. `KR_REF=1` additionally converges the two reference
#   branches at (κ_end, B_hold) so the endpoint can be identified as flower or
#   polarised rather than just reported as a number.
#
# The trap is driven by overwriting `ws.potential_values`, which every trap face
# (`apply_step!` / `energy_contribution` / `apply_operator!`) reads — the single
# point of truth. `TimeDependentTrap` is NOT refreshed by the YAML runner, which
# only re-evaluates interactions and Zeeman, so a `potential:` block would silently
# stay at its t=0 value. V is set at the STEP MIDPOINT so the trap update is
# second-order in dt, matching the midpoint stepper.
#
# Env:
#   KR_B_HOLD=20            held field [µG] — must be < B_eq(κ_end) and have a
#                           converged κ_start seed in the library
#   KR_KAPPA_0=0.8  KR_KAPPA_1=1.8
#   KR_TAUS=3,10,30,100     ramp durations [ω_ref⁻¹]  (1 ω_ref⁻¹ = 1.447 ms)
#   KR_HOLD=0               dwell at κ_end before the return leg [ω_ref⁻¹]
#   KR_ROUND_TRIP=1         run κ_0 → κ_1 → κ_0 (else one-way)
#   KR_SHAPE=linear         ramp shape: linear | slow_at | const_dF
#   KR_SHAPE_KAPPA=0.95     :slow_at — where to dwell (default κ_tc)
#   KR_SHAPE_WIDTH=0.10     :slow_at — Gaussian width in κ
#   KR_SHAPE_AMP=9          :slow_at — peak slow-down factor − 1
#   KR_SHAPE_REF=<csv>      :const_dF — trajectory to read d⟨F⊥⟩/dκ from
#   KR_SEED_BRANCH=dn       library branch for the seed (equivalent at κ ≤ 0.9)
#   KR_SAVE_PSI=0           persist the final ψ (needed for phase-winding analysis)
#   KR_REF=0                also converge the two reference branches at κ_end
#   KR_DT=0.002  KR_FRAMES=200  KR_GRID=32  KR_BOX=24
#   KR_LIB=figs/eu_gs_library   KR_OUT=figs/eu_kappa_ramp
#   KR_SMOKE=1              τ=1, dt=0.004, one-way — every path in ≤ 2 min
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu_kappa_ramp_protocol.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    static_zeeman, split_step_midpoint!, evaluate_potential, HarmonicTrap,
    component_populations, total_energy, total_norm, magnetization,
    orbital_angular_momentum, find_ground_state, find_ground_state_lbfgs,
    init_psi, add_white_noise!, pin_transverse_field, cell_volume,
    CUDABackend, CPUBackend
using DelimitedFiles: writedlm
using JLD2: jldsave, jldopen
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
const SMOKE = get(ENV, "KR_SMOKE", "") == "1"
const B_HOLD = getf("KR_B_HOLD", 20.0)
const K0 = getf("KR_KAPPA_0", 0.8)
const K1 = getf("KR_KAPPA_1", 1.8)
const TAUS = SMOKE ? [1.0] : let s = strip(get(ENV, "KR_TAUS", "3,10,30,100"))
    isempty(s) ? Float64[] : sort(parse.(Float64, split(s, ",")))   # empty ⇒ REF only
end
const HOLD = getf("KR_HOLD", 0.0)
const ROUND_TRIP = !SMOKE && get(ENV, "KR_ROUND_TRIP", "1") == "1"
const SEED_BRANCH = get(ENV, "KR_SEED_BRANCH", "dn")
const SAVE_PSI = get(ENV, "KR_SAVE_PSI", "0") == "1"
const REF = get(ENV, "KR_REF", "0") == "1"
const DT = SMOKE ? 0.004 : getf("KR_DT", 0.002)
const FRAMES = SMOKE ? 20 : Int(getf("KR_FRAMES", 200))
const GRID_N = Int(getf("KR_GRID", 32))
const BOX = getf("KR_BOX", 24.0)
const LIB = get(ENV, "KR_LIB", "figs/eu_gs_library")
const OUT = joinpath(get(ENV, "KR_OUT", "figs/eu_kappa_ramp"),
    @sprintf("B%03.0f", B_HOLD))
mkpath(OUT)

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()
# The preset's trap ratio is the ramp START; κ is driven through potential_values.
const PRESET = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, K0))
const ATOM = PRESET.atom
const SYS = SpinSystem(ATOM.F)
const ΩREF = PRESET.omega_ref
const MS_PER_TAU = 1e3 / ΩREF
const P_HOLD = Units.bfield_to_p(B_HOLD * 1e-6, ATOM.g_F, ΩREF)

# Dealias off: at 32³/box 24 the 2/3 cutoff (2.62) sits below the occupied band
# √(2µ) ≈ 4.3 and the filter removes real modes (~3e-6 per step of norm bleed).
SpinorBEC.DEALIAS_2_3_ENABLED[] = get(ENV, "KR_DEALIAS", "0") == "1"

# ------------------------------------------------------------ trap ramp driving

# --- ramp SHAPE -------------------------------------------------------------
#
# A constant dκ/dt spends equal time everywhere, which is the wrong allocation if
# the state's response is concentrated somewhere: the ramp is then effectively fast
# exactly where the physics is slow. Both shapes below are the same construction —
# a positive weight w(κ) saying "spend this much time per unit κ here" — turned
# into κ(t) by normalising and inverting its cumulative integral. Total duration is
# unchanged, so a shaped run costs the same as its linear counterpart and the
# comparison is like-for-like.
#
#   :linear    w = 1
#   :slow_at   w = 1 + A·exp(−((κ−κ_s)/σ)²)   — a Gaussian dwell at κ_s (default
#              κ_tc = 0.95), A = KR_SHAPE_AMP. Use when a specific κ is suspect.
#   :const_dF  w = |d⟨F⊥⟩/dκ| along a reference trajectory, floored so the ramp
#              never stalls. This is the assumption-free one: equal time per unit
#              of ORDER-PARAMETER change rather than per unit of κ.
const SHAPE = Symbol(get(ENV, "KR_SHAPE", "linear"))
const SHAPE_KAPPA = getf("KR_SHAPE_KAPPA", 0.95)     # κ_tc
const SHAPE_WIDTH = getf("KR_SHAPE_WIDTH", 0.10)
const SHAPE_AMP = getf("KR_SHAPE_AMP", 9.0)          # peak slow-down factor − 1
const SHAPE_REF = get(ENV, "KR_SHAPE_REF", "")

"""Weight → κ(t/τ) table. Returns (fracs, kappas), both ascending, for interpolation."""
function build_shape()
    n = 2001
    ks = collect(range(K0, K1; length=n))
    w = if SHAPE === :linear
        ones(n)
    elseif SHAPE === :slow_at
        @. 1.0 + SHAPE_AMP * exp(-((ks - SHAPE_KAPPA) / SHAPE_WIDTH)^2)
    elseif SHAPE === :const_dF
        isfile(SHAPE_REF) ||
            error(
                "KR_SHAPE=const_dF needs KR_SHAPE_REF=<a kramp_tau*.csv to read " *
                "d⟨F⊥⟩/dκ from>; got '$SHAPE_REF'",
            )
        rows = readlines(SHAPE_REF)
        hdr = split(rows[1], '\t')
        ci = Dict(strip(h) => i for (i, h) in enumerate(hdr))
        kk, ff = Float64[], Float64[]
        for ln in rows[2:end]
            c = split(ln, '\t')
            length(c) < length(hdr) && continue
            push!(kk, parse(Float64, c[ci["kappa"]]))
            push!(ff, parse(Float64, c[ci["fperp"]]))
        end
        # outbound leg only, then |dF/dκ| resampled onto ks
        i = argmax(kk)
        kk, ff = kk[1:i], ff[1:i]
        o = sortperm(kk)
        kk, ff = kk[o], ff[o]
        f_on_ks = [
            begin
                j = searchsortedfirst(kk, κ)
                j = clamp(j, 2, length(kk))
                ff[j - 1] + (ff[j] - ff[j - 1]) *
                (κ - kk[j - 1]) / max(kk[j] - kk[j - 1], eps())
            end for κ in ks
        ]
        d = abs.(diff(f_on_ks) ./ diff(ks))
        d = vcat(d, d[end])
        # floor at 15 % of the mean: without it a flat stretch would take zero time
        # and the ramp would jump discontinuously there.
        max.(d, 0.15 * sum(d) / n)
    else
        error("unknown KR_SHAPE=$SHAPE (linear | slow_at | const_dF)")
    end
    c = cumsum(w)
    c .-= c[1]
    c ./= c[end]
    (c, ks)
end

const SHAPE_FRAC, SHAPE_KS = build_shape()

"""κ at ramp fraction u ∈ [0,1], following the shape."""
function kappa_of_frac(u)
    u <= 0 && return K0
    u >= 1 && return K1
    j = searchsortedfirst(SHAPE_FRAC, u)
    j = clamp(j, 2, length(SHAPE_FRAC))
    f0, f1 = SHAPE_FRAC[j - 1], SHAPE_FRAC[j]
    k0, k1 = SHAPE_KS[j - 1], SHAPE_KS[j]
    k0 + (k1 - k0) * (u - f0) / max(f1 - f0, eps())
end

"""κ(t) for the ramp: up over τ, optional dwell, optional return leg. The return
leg mirrors the same shape so the path is retraced, not just reversed in time."""
function kappa_at(t, τ)
    if t <= τ
        kappa_of_frac(t / τ)
    elseif t <= τ + HOLD
        K1
    elseif ROUND_TRIP
        kappa_of_frac(1.0 - clamp((t - τ - HOLD) / τ, 0.0, 1.0))
    else
        K1
    end
end

total_duration(τ) = τ + HOLD + (ROUND_TRIP ? τ : 0.0)

"""Split the harmonic trap into its κ-independent and κ-dependent halves,
`V(κ) = A + κ² B` with `A = ½(x²+y²)`, `B = ½z²`, as device arrays shaped like
`ws.potential_values`. Verified against `evaluate_potential` so the decomposition
cannot drift from the audited trap evaluator."""
function trap_parts(ws)
    A_cpu = evaluate_potential(HarmonicTrap((1.0, 1.0, 0.0)), PRESET.grid)
    B_cpu = evaluate_potential(HarmonicTrap((0.0, 0.0, 1.0)), PRESET.grid)
    A = similar(ws.potential_values)
    B = similar(ws.potential_values)
    copyto!(A, A_cpu)
    copyto!(B, B_cpu)
    # gate: A + κ²B must reproduce the audited evaluator at the endpoints. Not bit
    # equality — the two sum in a different order, so a few ULP apart is expected.
    for κ in (K0, K1)
        ref = evaluate_potential(HarmonicTrap((1.0, 1.0, κ)), PRESET.grid)
        err = maximum(abs.(A_cpu .+ κ^2 .* B_cpu .- ref)) / maximum(abs.(ref))
        err < 1e-14 || error("trap decomposition A + κ²B ≠ evaluate_potential " *
              "at κ=$κ (rel err $err)")
    end
    (A, B)
end

set_kappa!(ws, A, B, κ) = (@. ws.potential_values = A + κ^2 * B; nothing)

# ---------------------------------------------------------------------- seeding

"""Converged κ_start ground state at the held field, with the epoch assertion."""
function seed()
    e = load_gs(; κ=K0, B_uG=B_HOLD, branch=SEED_BRANCH, grid=GRID_N, lib=LIB)
    abs(e.meta.B - B_HOLD) < 0.5 ||
        error(
            "no converged κ=$K0 library state at B=$B_HOLD µG " *
            "(nearest $(e.meta.B) µG) — pick KR_B_HOLD on the library grid",
        )
    m = seed_meta(e.meta.path)
    assert_seed_epoch(e.meta.path, m; c0=PRESET.interactions.c[0],
        c1=PRESET.interactions.c[1], c_dd=PRESET.c_dd, p=P_HOLD,
        n_points=(GRID_N, GRID_N, GRID_N), box=BOX)
    s = spin_scalars(e.psi, PRESET.grid)
    @printf("seed: κ=%.2f %s branch, B=%.1f µG  E=%.6f |∇E|=%.1e ε=%.0e  ⟨F⊥⟩=%.3f ⟨F_z⟩=%.3f\n",
        K0, SEED_BRANCH, e.meta.B, e.meta.E, e.meta.grad, m.pin, s.fperp, s.fz)
    (; psi=e.psi, E=e.meta.E, grad=e.meta.grad, pin=m.pin, path=e.meta.path)
end

base_kw(κ, ε) = (; grid=PRESET.grid, atom=ATOM, interactions=PRESET.interactions,
    potential=HarmonicTrap((1.0, 1.0, κ)),
    zeeman=static_zeeman(; Bz=P_HOLD, Bx=ε, q=0.0),
    enable_ddi=true, c_dd=PRESET.c_dd, secular_ddi=false, backend=BACKEND)

"""Reference branches at (κ_end, B_hold): independent ITP+LBFGS solves from the
flower and the fully-polarised anchor. Without these the ramp endpoint is just a
number — the library has no κ=κ_end state at this field.

Plain LBFGS does NOT converge here: at these fields the Eu+DDI ground state sits on
a soft (Goldstone) manifold and a fixed pin stalls at |∇E| ~ 1e-2, four orders above
the library's gate. Measured 2026-07-27 at (κ=1.8, B=20 µG): 400 iterations at a
fixed ε left grad_norm 1.1e-2 (flower) and 2.5e-2 (polarised), both `converged=false`
— unusable for identifying a branch. The cure is the ε-ladder continuation: solve at
a strong pin, then step ε down, each stage warm-started from the last. An
unconverged reference is worse than none, so the result carries `converged`."""
function reference_branches(ε)
    itp = SMOKE ? 150 : 2000
    lb = SMOKE ? 60 : Int(getf("KR_REF_LBFGS", 1500))
    ramp = if SMOKE
        Float64[]
    else
        sort(parse.(Float64, split(get(ENV, "KR_REF_RAMP", "0.02,0.01,0.005"), ","));
            rev=true)
    end
    rows = Any[]
    for anchor in (:flower, :m_minus_F)
        psi0 = init_psi(PRESET.grid, SYS; state=anchor)
        add_white_noise!(psi0, 0.02, 1, PRESET.grid)
        kw = base_kw(K1, ε)
        gs = find_ground_state(; kw..., psi_init=psi0, dt=0.002, n_steps=itp,
            tol=1e-12, save_every=max(1, itp ÷ 4), verbose=false)
        gl = if isempty(ramp)
            find_ground_state_lbfgs(; kw...,
                psi_init=Array{ComplexF64}(gs.workspace.state.psi),
                n_steps=lb, tol=1e-5, m_lbfgs=10, newton_polish=false, verbose=false)
        else
            find_ground_state_lbfgs(; kw...,
                psi_init=Array{ComplexF64}(gs.workspace.state.psi),
                n_steps=lb, tol=1e-5, m_lbfgs=10, newton_polish=false, verbose=false,
                pin=pin_transverse_field(; Bz=P_HOLD, q=0.0), epsilon_ramp=ramp)
        end
        psi = Array{ComplexF64}(gl.workspace.state.psi)
        s = spin_scalars(psi, PRESET.grid)
        # J_z of each branch is the load-bearing number, not a nicety: the κ ramp
        # conserves J_z (a trap deformation about z is axially symmetric; only the
        # pin breaks it), so it can only reach states in the seed's J_z sector. If a
        # reference branch sits in a different sector, NO ramp rate or shape reaches
        # it — that is a selection rule, not a speed problem.
        Lz = orbital_angular_momentum(psi, PRESET.grid, gl.workspace.fft_plans)
        Sz = magnetization(psi, PRESET.grid, SYS)
        @printf(
            "  reference %-10s κ=%.2f B=%.1f µG: E=%.6f |∇E|=%.1e ⟨F⊥⟩=%.3f ⟨F_z⟩=%.3f J_z=%+.4f%s\n",
            anchor, K1, B_HOLD, gl.energy, gl.grad_norm, s.fperp, s.fz, Lz + Sz,
            gl.converged ? " ✓" : " (cap)")
        jldsave(joinpath(OUT, "reference_$(anchor).jld2");
            psi, kappa=K1, B_uG=B_HOLD, pin_eps=isempty(ramp) ? ε : minimum(ramp),
            E=gl.energy, grad_norm=gl.grad_norm, converged=gl.converged,
            c0=PRESET.interactions.c[0], c1=PRESET.interactions.c[1],
            c_dd=PRESET.c_dd, grid_n_points=(GRID_N, GRID_N, GRID_N),
            grid_box_size=(BOX, BOX, BOX), zeeman_p=P_HOLD, zeeman_q=0.0,
            dt=DT, imaginary_time=true, t=0.0, step=0, c_lhy=0.0,
            c_dict=Dict(0 => PRESET.interactions.c[0], 1 => PRESET.interactions.c[1]))
        push!(
            rows,
            (; anchor=String(anchor), kappa=K1, B_uG=B_HOLD, E=gl.energy,
                grad_norm=gl.grad_norm, converged=gl.converged, s.fperp, s.fz,
                Lz, Sz, Jz=Lz + Sz,
                pin_eps=isempty(ramp) ? ε : minimum(ramp)),
        )
    end
    ks = collect(keys(rows[1]))
    open(joinpath(OUT, "reference_branches.csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in ks], 1, :))
        end
    end
    rows
end

# ------------------------------------------------------------------- the ramp

function frame(ws)
    psi = Array(ws.state.psi)
    s = spin_scalars(psi, PRESET.grid)
    Lz = orbital_angular_momentum(psi, PRESET.grid, ws.fft_plans)
    Sz = magnetization(psi, PRESET.grid, SYS)
    (; s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz, E=total_energy(ws),
        norm=total_norm(ws.state.psi, PRESET.grid),
        pops=component_populations(psi, PRESET.grid, SYS).populations)
end

function run_kappa_ramp(s, τ)
    T = total_duration(τ)
    n_steps = max(1, ceil(Int, T / DT))
    save_every = max(1, n_steps ÷ FRAMES)
    sp = SimParams(; dt=DT, n_steps, imaginary_time=false, save_every)
    ws = make_workspace(; base_kw(K0, s.pin)..., sim_params=sp, psi_init=s.psi)
    A, B = trap_parts(ws)
    set_kappa!(ws, A, B, K0)

    @printf("\nκ ramp %.2f → %.2f%s over τ=%.3g ω_ref⁻¹ (%.1f ms)%s, B held at %.1f µG\n",
        K0, K1, ROUND_TRIP ? @sprintf(" → %.2f", K0) : "", τ, τ * MS_PER_TAU,
        HOLD > 0 ? @sprintf(", dwell %.3g", HOLD) : "", B_HOLD)
    @printf("  %d steps × dt=%g, %d frames\n", n_steps, DT, n_steps ÷ save_every)
    flush(stdout)

    rows = Any[]
    record!(step) = begin
        f = frame(ws)
        push!(
            rows,
            (; step, t=ws.state.t, t_ms=ws.state.t * MS_PER_TAU,
                kappa=kappa_at(ws.state.t, τ), f.fz, f.fperp, f.Lz, f.Sz, f.Jz,
                f.E, f.norm, pops=f.pops),
        )
        rows[end]
    end

    t0 = time()
    record!(0)
    for step in 1:n_steps
        # V at the STEP MIDPOINT: second-order in dt, matching the stepper.
        set_kappa!(ws, A, B, kappa_at(ws.state.t + DT / 2, τ))
        split_step_midpoint!(ws)
        if step % save_every == 0 || step == n_steps
            r = record!(step)
            if step % (10 * save_every) == 0 || step == n_steps
                @printf("    step %d/%d  κ=%.3f  ⟨F⊥⟩=%.3f  ⟨F_z⟩=%.3f  E=%.6f  |ψ|²=%.6f  %.0fs\n",
                    step, n_steps, r.kappa, r.fperp, r.fz, r.E, r.norm, time() - t0)
                flush(stdout)
            end
        end
    end

    tag = SHAPE === :linear ? "" : "_$(SHAPE)"
    base = joinpath(OUT, @sprintf("kramp%s_tau%g", tag, τ))
    keys_s = (:step, :t, :t_ms, :kappa, :fz, :fperp, :Lz, :Sz, :Jz, :E, :norm)
    open(base * ".csv", "w") do io
        writedlm(io, reshape(String.(collect(keys_s)), 1, :))
        for r in rows
            writedlm(io, reshape(Any[getfield(r, k) for k in keys_s], 1, :))
        end
    end
    open(base * "_pops.csv", "w") do io
        writedlm(io, reshape(vcat(["kappa", "t_ms"],
                ["m$(Int(m))" for m in SYS.m_values]), 1, :))
        for r in rows
            writedlm(io, reshape(Any[r.kappa, r.t_ms, r.pops...], 1, :))
        end
    end
    SAVE_PSI && jldsave(base * "_final.jld2";
        psi=Array(ws.state.psi), t=rows[end].t, kappa=rows[end].kappa,
        kappa_0=K0, kappa_1=K1, B_uG=B_HOLD, tau=τ, shape=String(SHAPE),
        pin_bx=s.pin, seed_path=s.path,
        c0=PRESET.interactions.c[0], c1=PRESET.interactions.c[1],
        c_dd=PRESET.c_dd, c_lhy=0.0,
        c_dict=Dict(0 => PRESET.interactions.c[0], 1 => PRESET.interactions.c[1]),
        zeeman_p=P_HOLD, zeeman_q=0.0,
        grid_n_points=(GRID_N, GRID_N, GRID_N), grid_box_size=(BOX, BOX, BOX),
        dt=DT, imaginary_time=false, step=rows[end].step)

    (; τ, rows, wall_s=time() - t0)
end

# --------------------------------------------------------------------- driver

@printf("Eu κ-ramp protocol: B held %.1f µG, κ %.2f → %.2f, grid=%d³ box=%.1f  %s%s\n",
    B_HOLD, K0, K1, GRID_N, BOX, HAS_GPU ? "CUDA" : "CPU", SMOKE ? "  [SMOKE]" : "")
@printf("τ grid: %s ω_ref⁻¹ = %s ms%s\n", join(TAUS, ", "),
    join(round.(TAUS .* MS_PER_TAU; digits=2), ", "),
    ROUND_TRIP ? "  (round trip ⇒ 2× wall each)" : "")

const S = seed()
REF && (println("\nreference branches at the ramp endpoint:"); reference_branches(S.pin))

manifest = Any[]
for τ in TAUS
    r = run_kappa_ramp(S, τ)
    first_, last_ = r.rows[1], r.rows[end]
    # the κ_end state is the ramp's product; on a round trip also check the return
    at_end = argmin(abs.(getfield.(r.rows, :kappa) .- K1))
    push!(
        manifest,
        (; B_uG=B_HOLD, kappa_0=K0, kappa_1=K1, tau=τ,
            tau_ms=τ * MS_PER_TAU, round_trip=ROUND_TRIP, hold=HOLD, pin=S.pin,
            fperp_start=first_.fperp, fperp_at_k1=r.rows[at_end].fperp,
            fperp_return=last_.fperp,
            fz_start=first_.fz, fz_at_k1=r.rows[at_end].fz, fz_return=last_.fz,
            E_at_k1=r.rows[at_end].E, Jz_drift=last_.Jz - first_.Jz,
            norm_drift=last_.norm - first_.norm,
            reversibility=abs(last_.fperp - first_.fperp),
            n_frames=length(r.rows), wall_s=round(r.wall_s; digits=1)),
    )
    @printf("  ⇒ ⟨F⊥⟩ %.3f →(κ=%.2f) %.3f%s   J_z drift %.2e   |ψ|² drift %.2e   %.0fs\n",
        first_.fperp, K1, r.rows[at_end].fperp,
        ROUND_TRIP ? @sprintf(" →(back) %.3f", last_.fperp) : "",
        last_.Jz - first_.Jz, last_.norm - first_.norm, r.wall_s)
    flush(stdout)

    ks = collect(keys(manifest[1]))
    open(joinpath(OUT, SHAPE === :linear ? "manifest.csv" :
                       "manifest_$(SHAPE).csv"), "w") do io
        writedlm(io, reshape(String.(ks), 1, :))
        for m in manifest
            writedlm(io, reshape(Any[getfield(m, k) for k in ks], 1, :))
        end
    end
end

println("\nwrote $(OUT)/manifest.csv + per-run trajectory/population CSVs")
println("""
Read it as: ⟨F⊥⟩ at κ_end vs the two reference branches (KR_REF=1) says whether the
ramp delivered the flower ground state or fell onto the polarised one; the τ
dependence of that gives the adiabaticity threshold at the tricritical crossing;
`reversibility` (|⟨F⊥⟩_return − ⟨F⊥⟩_start|) says whether the κ path is closed.
""")
