#!/usr/bin/env julia
# #334 — does a growing ¹⁵¹Eu condensate at (κ = 1.8, B = 20 µG) pick up the flower
# texture, or stay on the polarised branch? One SPGPE trajectory per invocation.
#
# WHAT IS BEING CROSSED, AND WHY IT IS NOT THE THERMAL TRANSITION
#
# #334 proposes starting "above the transition — polarised side, B > B_eq, or
# thermally above T_c" and cooling through at fixed κ. Both of those literal
# readings are closed, and the measurements that close them are cheap:
#
#   • the FIELD route was measured by #335: a B_z ramp conserves J_z, the two
#     branches sit in different J_z sectors at every field, and no rate converts
#     between them (`docs/guides/eu_kappa_hysteresis_loop.md` §5.4).
#   • the THERMAL route is not representable. `scripts/eu334/window.jl` measures
#     µ = 14.90 at this point, so the C region floor alone is k_cut = 5.46 —
#     already above the 32³ campaign grid's k_max = 4.19 — and
#     `classical_field_equilibrium` puts the classical-field transition at fixed
#     µ near T ≈ 110, needing ϵ_cut ≈ 125, k_cut ≈ 16 and a 192³ grid at 13
#     components. Not for an ensemble.
#
# The third reading is the one that is both physical and affordable. At fixed
# field the couplings scale with the condensate: (c₀, c₁, c_dd) ∝ N₀ while the
# Zeeman term does not, so a growing condensate traverses a one-parameter family
# in f = N₀/N. `scripts/eu334/nucleation_bifurcation.jl` measures where the flower
# branch is BORN on that family (f_sp) and where the two branches cross (f_eq).
# Below f_sp the flower state does not exist — the condensate is polarised because
# there is nothing else to be. That IS the disordered side of the texture
# transition, reached without any thermal cloud. So:
#
#     seed a converged polarised condensate at f₀ < f_sp, hold (κ, B, T) fixed,
#     ramp the reservoir µ so the condensate GROWS through the window, and see
#     which branch it lands in.
#
# The reservoir is what makes this a measurement rather than a re-run of #335's
# blocked ramp: SPGPE growth exchanges atoms with an unpolarised I region at one
# µ, so it does NOT conserve M_z or J_z. That is not a numerical convenience — it
# is the physical statement that spin-exchange with the thermal cloud is what
# lets the cloud leave its J_z sector, and it is why nucleation-in-place can work
# where transport cannot.
#
# WHAT THIS SCRIPT DOES NOT DECIDE
#
# The branch is NOT read off the c-field's total energy. `window.jl` measures the
# C region's thermal energy at 10³–10⁴ times the branch separation, so that
# comparison is noise. The trajectory writes ψ; `scripts/eu334/classify.jl` does
# the assignment by quench-and-relax against the two #335 references, and carries
# its own calibration.
#
# NORMALISATION — the one conversion that has to be right
#
# The #335 epoch is unit-norm: ∫|ψ|²dV = 1 with N folded into (c₀, c₁, c_dd). The
# SPGPE noise amplitude √(2γT dt/dV) assumes |ψ|² is the PHYSICAL density, so this
# run is norm-N: couplings from `eu151_preset(n_atoms=1)` and ψ scaled by √N₀. The
# two are the same mean field — ψ_N = √N ψ₁ with c⁽ᴺ⁾ = c⁽¹⁾/N leaves Ĥ[ψ]
# invariant, hence µ and every per-atom observable — and the equivalence holds
# only while LHY is off, since an n^(5/2) term does not scale. `magnetization` and
# `orbital_angular_momentum` are EXTENSIVE, so everything reported here is divided
# by ∫|ψ|²dV explicitly; the seed assertion below checks that per-atom pipeline
# against the stored reference before the trajectory starts.
#
# Env (all in internal units unless marked):
#   NU_KAPPA=1.8  NU_B=20.0        the target point
#   NU_GRID=64  NU_BOX=24.0  NU_PIN=0.002
#   NU_T=5.0                       reservoir temperature k_BT/ℏω_ref
#   NU_MU0= NU_MU1=                µ ramp endpoints; MU0 from the seed's own µ
#   NU_MU1_FROM=<cell.jld2>        …or MEASURE MU1 on the branch cell the growth
#                                  should end at, which is what makes the ramp a
#                                  statement about condensate fraction
#   NU_TAU_MS=200.0                ramp duration [ms]
#   NU_HOLD_MS=0.0                 hold at µ = MU1 after the ramp
#   NU_NT=1.0                      C-region depth, ϵ_cut = µ + n_T·T
#   NU_DT=0.002  NU_EVERY=5        unitary step / reservoir sub-step interval
#   NU_SEED=1                      trajectory seed (the ensemble axis)
#   NU_NOISE=1                     0 ⇒ quiet SPGPE — the positive control
#   NU_NO_ED=1                     drop the scattering reservoir (growth-only)
#   NU_MU1_EQ_MU0=1                hold µ at the seed's own — the zero-drive null
#   NU_SEED_FILE=                  converged unit-norm ψ + its f (bifurcation cell)
#   NU_FRAMES=200  NU_OUT=figs/eu334/nucleate  NU_SMOKE=1
#
#   [GPU]  LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#            scripts/eu334/nucleate.jl

import CUDA
using SpinorBEC
using SpinorBEC: Units, eu151_preset, SpinSystem, make_workspace, SimParams,
    static_zeeman, split_step_midpoint!, spin_scalars, magnetization,
    orbital_angular_momentum, cell_volume, total_norm, apply_operator_via_registry!,
    SPGPEReservoir, apply_spgpe_step!, spgpe_rates, PiecewiseLinearWaveform,
    ConstantWaveform, seed_device_rng!, CUDABackend, CPUBackend
using JLD2: jldopen, jldsave
using DelimitedFiles: writedlm
using Printf

getf(k, d) = haskey(ENV, k) ? parse(Float64, ENV[k]) : d
gets(k, d) = get(ENV, k, d)

const SMOKE = gets("NU_SMOKE", "") == "1"
const KAPPA = getf("NU_KAPPA", 1.8)
const B_UG = getf("NU_B", 20.0)
const GRID_N = SMOKE ? Int(getf("NU_GRID", 32)) : Int(getf("NU_GRID", 64))
const BOX = getf("NU_BOX", 24.0)
const PIN = getf("NU_PIN", 0.002)
const T_RES = getf("NU_T", 5.0)
const N_T = getf("NU_NT", 1.0)
const DT = getf("NU_DT", 0.002)
const EVERY = Int(getf("NU_EVERY", 5))
const SEED = Int(getf("NU_SEED", 1))
const NOISE = gets("NU_NOISE", "1") == "1"
const FRAMES = Int(getf("NU_FRAMES", 50))
const SEED_FILE = gets("NU_SEED_FILE", "")
const OUT = gets("NU_OUT", joinpath("figs", "eu334", "nucleate"))
mkpath(OUT)

# Dealiasing OFF, matching #335 §2: at this box the 2/3 cutoff sits below the
# occupied band and the filter removes physically occupied modes. The projector
# at k_cut is the band limit this run does have, and it is the physical one.
SpinorBEC.DEALIAS_2_3_ENABLED[] = gets("NU_DEALIAS", "0") == "1"

const HAS_GPU = CUDA.functional()
const BACKEND = HAS_GPU ? CUDABackend() : CPUBackend()

# Two presets of the SAME physics: PRESET1 is the #335 unit-norm epoch a seed is
# checked against; PRESET_N is the per-atom (norm-N) form this run integrates.
const PRESET1 = eu151_preset(; n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, KAPPA))
const PRESET_N = eu151_preset(; n_atoms=1, n_pts=(GRID_N, GRID_N, GRID_N),
    box=(BOX, BOX, BOX), trap_ratios=(1.0, 1.0, KAPPA))
const ATOM = PRESET1.atom
const SYS = SpinSystem(ATOM.F)
const NATOMS = PRESET1.n_atoms
const A_HO = sqrt(Units.HBAR / (ATOM.mass * PRESET1.omega_ref))
const A_S_HO = ATOM.a_s / A_HO
const MS_PER_TAU = 1e3 / PRESET1.omega_ref
const K_MAX = π / (BOX / GRID_N)

p_of(B) = Units.bfield_to_p(B * 1e-6, ATOM.g_F, PRESET1.omega_ref)

const TAU_MS = getf("NU_TAU_MS", SMOKE ? 2.0 : 200.0)
const HOLD_MS = getf("NU_HOLD_MS", 0.0)
const TAU = TAU_MS / MS_PER_TAU
const HOLD = HOLD_MS / MS_PER_TAU

"""Per-atom scalars, with the extensive observables divided by the actual norm.

`magnetization` and `orbital_angular_momentum` return ∫·dV, so on a norm-N field
they are N₀ times the per-atom value the #335 references are quoted in. Dividing
here, once, is the whole conversion — and `assert_seed_epoch_scalars` checks it
against a stored unit-norm cell before any trajectory runs."""
function per_atom(psi_dev, grid, plans)
    # Host-side once: `_spin_expectation_fields` walks voxels, so a device array
    # reaches it as scalar indexing — which CUDA.jl refuses rather than silently
    # running 10⁵ kernel launches.
    psi = psi_dev isa Array ? psi_dev : Array(psi_dev)
    n = total_norm(psi, grid)
    s = spin_scalars(psi, grid)          # already ∫f dV / ∫n dV
    Lz = orbital_angular_momentum(psi, grid, plans) / n
    Sz = magnetization(psi, grid, SYS) / n
    (; N=n, s.fz, s.fperp, Lz, Sz, Jz=Lz + Sz)
end

"""µ = Re⟨ψ, Ĥ[ψ]ψ⟩ / ⟨ψ,ψ⟩ — normalisation-independent, and the number the
reservoir has to be told."""
function chemical_potential(ws)
    dV = cell_volume(ws.grid)
    hpsi = similar(ws.state.psi)
    apply_operator_via_registry!(hpsi, ws)
    real(sum(conj(ws.state.psi) .* hpsi)) * dV / (real(sum(abs2, ws.state.psi)) * dV)
end

make_ws(psi, interactions, c_dd; n_steps=0) = make_workspace(;
    grid=PRESET_N.grid, atom=ATOM, interactions=interactions,
    potential=PRESET_N.potential,
    zeeman=static_zeeman(; Bz=p_of(B_UG), Bx=PIN, q=0.0),
    sim_params=SimParams(; dt=DT, n_steps, imaginary_time=false, save_every=1,
        normalize_every=0),
    psi_init=psi, enable_ddi=true, c_dd=c_dd, secular_ddi=false, backend=BACKEND,
    ddi_padding=false, ddi_trunc_radius=-1.0)

"""The seed: a converged unit-norm ψ from a bifurcation cell, its f, and the
epoch check. Returned already scaled to ∫|ψ|²dV = f·N."""
function load_seed()
    isempty(SEED_FILE) && error("NU_SEED_FILE is required — a bifurcation cell jld2")
    isfile(SEED_FILE) || error("no such seed: $SEED_FILE")
    jldopen(SEED_FILE, "r") do h
        g(k, d) = haskey(h, k) ? h[k] : d
        psi1 = Array{ComplexF64}(h["psi"])
        f = Float64(g("f", NaN))
        isnan(f) && error("seed carries no `f` — it is not a bifurcation cell")
        n = g("grid_n_points", nothing)
        n === nothing || first(n) == GRID_N ||
            error("seed grid $(first(n)) ≠ $GRID_N — $SEED_FILE")
        for (nm, got, want) in (("B_uG", Float64(g("B_uG", NaN)), B_UG),
            ("kappa", Float64(g("kappa", NaN)), KAPPA),
            ("pin_bx", Float64(g("pin_bx", NaN)), PIN))
            isnan(got) && continue
            abs(got - want) < 1e-9 ||
                error("seed/run mismatch on $nm: $got vs $want — $SEED_FILE")
        end
        N0 = f * NATOMS
        (; psi=psi1 .* sqrt(N0), psi1, f, N0, fperp_stored=Float64(g("fperp", NaN)))
    end
end

"""The per-atom pipeline, checked against the seed's own stored ⟨F⊥⟩ AND against
the unit-norm state it came from.

This is the conversion that silently breaks: an extensive observable read off a
norm-N field is N₀ times too large and still looks like a plausible number. Both
readings must agree, so a missing division cannot pass."""
function assert_seed_epoch_scalars(seed, ws_n, ws_1)
    a = per_atom(ws_n.state.psi, PRESET_N.grid, ws_n.fft_plans)
    b = per_atom(ws_1.state.psi, PRESET1.grid, ws_1.fft_plans)
    @printf("  seed per-atom check: norm-N ⟨F⊥⟩ %.6f / J_z %.6f  vs  unit-norm %.6f / %.6f\n",
        a.fperp, a.Jz, b.fperp, b.Jz)
    isapprox(a.fperp, b.fperp; rtol=1e-8) && isapprox(a.Jz, b.Jz; rtol=1e-6) || error(
        "per-atom conversion disagrees between the two normalisations — an " *
        "extensive observable is being reported without its 1/N₀")
    isnan(seed.fperp_stored) || isapprox(a.fperp, seed.fperp_stored; rtol=1e-6) ||
        error("seed ⟨F⊥⟩ $(a.fperp) ≠ stored $(seed.fperp_stored)")
    a
end

const COLS = ["t_ms", "N_C", "mu", "T", "eps_cut", "k_cut", "gamma", "M_bar",
    "fperp", "fz", "Lz", "Sz", "Jz", "cutoff_outflow", "noise_truncated"]

function main()
    seed = load_seed()
    @printf("#334 nucleate: κ=%.2f B=%.1f µG grid %d³ box %.1f pin %g  [%s]%s\n",
        KAPPA, B_UG, GRID_N, BOX, PIN, HAS_GPU ? "CUDA" : "CPU", SMOKE ? "  SMOKE" : "")
    @printf("  seed %s: f = %.4f, N₀ = %.0f\n", basename(SEED_FILE), seed.f, seed.N0)

    # The same physics in the seed's own unit-norm epoch, kept only to check the
    # conversion: its couplings carry N₀ = f·N, ψ is unit-norm, and every per-atom
    # observable must come out identical to the norm-N field's.
    pf = eu151_preset(; n_atoms=max(1, round(Int, seed.f * NATOMS)),
        n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
        trap_ratios=(1.0, 1.0, KAPPA))
    ws1 = make_workspace(; grid=pf.grid, atom=ATOM, interactions=pf.interactions,
        potential=pf.potential, zeeman=static_zeeman(; Bz=p_of(B_UG), Bx=PIN, q=0.0),
        sim_params=SimParams(; dt=DT, n_steps=0, imaginary_time=false),
        psi_init=seed.psi1, enable_ddi=true, c_dd=pf.c_dd, secular_ddi=false,
        backend=BACKEND, ddi_padding=false, ddi_trunc_radius=-1.0)

    ws = make_ws(seed.psi, PRESET_N.interactions, PRESET_N.c_dd)
    s0 = assert_seed_epoch_scalars(seed, ws, ws1)
    mu0_measured = chemical_potential(ws)
    mu1_measured = chemical_potential(ws1)
    @printf("  µ(seed) = %.4f  (unit-norm epoch gives %.4f — the same Hamiltonian)\n",
        mu0_measured, mu1_measured)
    isapprox(mu0_measured, mu1_measured; rtol=1e-6) ||
        error("µ disagrees between normalisations — the norm-N couplings are wrong")

    # The ramp's endpoint is a condensate fraction, not a number someone picked:
    # `NU_MU1_FROM` names the branch cell the growth should end at and µ is
    # MEASURED on it, in the same Hamiltonian, by the same routine that measured
    # the seed's. Writing 14.897 by hand instead would silently target f = 1 even
    # when the window stops at 0.52.
    MU1_FROM = gets("NU_MU1_FROM", "")
    mu1_target = if isempty(MU1_FROM)
        getf("NU_MU1", 14.897)
    else
        isfile(MU1_FROM) || error("NU_MU1_FROM=$MU1_FROM does not exist")
        jldopen(MU1_FROM, "r") do h
            ft = Float64(h["f"])
            pt = eu151_preset(; n_atoms=max(1, round(Int, ft * NATOMS)),
                n_pts=(GRID_N, GRID_N, GRID_N), box=(BOX, BOX, BOX),
                trap_ratios=(1.0, 1.0, KAPPA))
            wt = make_workspace(; grid=pt.grid, atom=ATOM, interactions=pt.interactions,
                potential=pt.potential,
                zeeman=static_zeeman(; Bz=p_of(B_UG), Bx=PIN, q=0.0),
                sim_params=SimParams(; dt=DT, n_steps=0, imaginary_time=false),
                psi_init=Array{ComplexF64}(h["psi"]), enable_ddi=true, c_dd=pt.c_dd,
                secular_ddi=false, backend=BACKEND, ddi_padding=false,
                ddi_trunc_radius=-1.0)
            m = chemical_potential(wt)
            @printf("  µ target from %s (f = %.4f): %.4f\n", basename(MU1_FROM), ft, m)
            m
        end
    end
    MU0 = getf("NU_MU0", mu0_measured)
    # `NU_MU1_EQ_MU0=1` is the NULL arm: the reservoir sits at the field's own µ,
    # so the growth drive is zero by construction and N_C must not move. Anything
    # that does move it is bookkeeping — the noise/projector pair, or the
    # energy-damping term's approximate number conservation — and without this arm
    # a loss and a drive are indistinguishable in the trajectory.
    MU1 = gets("NU_MU1_EQ_MU0", "") == "1" ? MU0 : mu1_target
    MU1 >= MU0 ||
        error("NU_MU1 ($MU1) must be ≥ the seed's µ ($MU0) — this is a growth ramp")

    # The C region has to clear µ at BOTH ends and stay inside the grid. Refusing
    # here is the point: a k_cut above k_max makes the projector a no-op and the
    # "C region" whatever the grid happens to be, which is how a cutoff-dependent
    # result becomes a grid-dependent one without saying so.
    for (nm, mu) in (("start", MU0), ("end", MU1))
        kc = sqrt(2 * (mu + N_T * T_RES))
        kc < K_MAX || error("""
            C region does not fit: at the $nm of the ramp µ = $(round(mu; digits=3))
            and T = $T_RES give k_cut = $(round(kc; digits=3)) against the grid's
            k_max = $(round(K_MAX; digits=3)). Raise NU_GRID (n ≥ $(ceil(Int, BOX*kc/π)))
            or lower NU_T. `scripts/eu334/window.jl` tabulates this.""")
    end

    n_ramp = max(1, round(Int, TAU / DT))
    n_hold = round(Int, HOLD / DT)
    n_steps = n_ramp + n_hold
    t_end = n_steps * DT
    tw = [0.0, TAU, max(TAU + HOLD, TAU + 1e-9)]
    muw = PiecewiseLinearWaveform(tw, [MU0, MU1, MU1])
    Tw = ConstantWaveform(T_RES)
    # `NU_KCUT_FIXED=1` pins the C region at its END value instead of tracking µ.
    #
    # This is the arm that attributes the energy-damped run's suppressed growth.
    # The projected scattering step's number loss is ONE-OFF in the seed's
    # out-of-C weight (measured; see the retraction in `src/solvers/spgpe.jl`), so
    # a STATIONARY cutoff pays it once. A cutoff that ramps manufactures fresh
    # out-of-C content every step, which re-imposes the one-off step after step
    # and is indistinguishable from a rate in the trajectory alone.
    #
    # The existing NULL arm (`NU_MU1_EQ_MU0`) cannot separate this: with the two
    # µ equal the cutoff is constant by construction, so the very motion under
    # suspicion is absent. Pinning the cutoff while the DRIVE still runs is what
    # isolates it. The end value is used because `k_cut < K_MAX` is already
    # checked at both ends above, so pinning cannot silently leave the grid.
    kc_of = mu -> sqrt(2 * (mu + N_T * T_RES))
    kcw = if gets("NU_KCUT_FIXED", "") == "1"
        ConstantWaveform(kc_of(MU1))
    else
        PiecewiseLinearWaveform(tw, [kc_of(mu) for mu in (MU0, MU1, MU1)])
    end
    # `NU_NO_ED=1` selects the growth-only sub-theory (Rooney Eq. 20). Not a
    # convenience switch: the scattering term is number-conserving only BEFORE the
    # projector, and turning it off is how its residual is attributed rather than
    # argued about.
    res = SPGPEReservoir(; T=Tw, mu=muw, a_s=A_S_HO, k_cut=kcw,
        energy_damping=gets("NU_NO_ED", "") != "1")

    r0 = spgpe_rates(res, 0.0)
    r1 = spgpe_rates(res, TAU)
    @printf("  ramp: µ %.3f → %.3f over %.1f ms (+%.1f ms hold), T = %.2f, n_T = %.1f\n",
        MU0, MU1, TAU_MS, HOLD_MS, T_RES, N_T)
    @printf("  γ %.3e → %.3e   ℳ̄ %.3e → %.3e   1/(γµ) = %.0f → %.0f ms\n",
        r0.gamma, r1.gamma, r0.M, r1.M,
        MS_PER_TAU / (r0.gamma * MU0), MS_PER_TAU / (r1.gamma * MU1))
    @printf("  %d steps of dt = %g, reservoir every %d  (noise %s)\n",
        n_steps, DT, EVERY, NOISE ? "ON" : "OFF — quiet SPGPE")

    HAS_GPU && seed_device_rng!(BACKEND, SEED)
    save_every = max(1, n_steps ÷ FRAMES)
    rows = Vector{Any}[]
    rec!(step, r) = begin
        h = Array(ws.state.psi)
        a = per_atom(h, PRESET_N.grid, ws.fft_plans)
        push!(rows, Any[ws.state.t * MS_PER_TAU, a.N, r.mu, r.T, r.eps_cut, r.k_cut,
            r.gamma, r.M, a.fperp, a.fz, a.Lz, a.Sz, a.Jz,
            get(r, :cutoff_outflow, NaN), get(r, :noise_truncated, NaN)])
    end
    rec!(0, merge(r0, (; cutoff_outflow=NaN, noise_truncated=NaN)))

    t_wall = time()
    local last_r = r0
    for step in 1:n_steps
        split_step_midpoint!(ws)
        if step % EVERY == 0
            last_r = apply_spgpe_step!(ws, res, DT * EVERY;
                t=ws.state.t, seed=SEED * 1_000_003 + step, noise=NOISE)
        end
        if step % save_every == 0 || step == n_steps
            rec!(step, last_r)
            # One line per frame. A trajectory is ~an hour and the CSV is only
            # written at the end, so without this the log is empty for the whole
            # run and a stalled job is indistinguishable from a slow one.
            r = rows[end]
            @printf("    %6.1f%%  t=%7.1f ms  N_C=%8.0f (f=%.4f)  µ=%.3f  ⟨F⊥⟩=%.4f  J_z=%+.4f\n",
                100 * step / n_steps, r[1], r[2], r[2] / NATOMS, r[3], r[9], r[13])
            flush(stdout)
        end
    end
    wall = time() - t_wall

    a = rows[end]
    @printf("  done in %.0f s (%.2f ms/step).  N_C %.0f → %.0f   ⟨F⊥⟩ %.4f → %.4f   J_z %+.4f → %+.4f\n",
        wall, 1e3 * wall / n_steps, rows[1][2], a[2], rows[1][9], a[9], rows[1][13], a[13])

    tag = @sprintf("k%.1f_T%.1f_tau%.0f_seed%03d%s", KAPPA, T_RES, TAU_MS, SEED,
        NOISE ? "" : "_quiet")
    writedlm(joinpath(OUT, "traj_$tag.csv"),
        vcat(permutedims(COLS), permutedims.(rows)...), '\t')
    jldsave(joinpath(OUT, "psi_$tag.jld2");
        psi=Array(ws.state.psi), N_C=a[2], kappa=KAPPA, B_uG=B_UG, pin_bx=PIN,
        T=T_RES, mu0=MU0, mu1=MU1, tau_ms=TAU_MS, hold_ms=HOLD_MS, seed=SEED,
        noise=NOISE, f_seed=seed.f, grid_n_points=(GRID_N, GRID_N, GRID_N),
        grid_box_size=(BOX, BOX, BOX), n_atoms_norm=NATOMS, dt=DT, every=EVERY,
        wall_s=wall, seed_file=SEED_FILE)
    @printf("  wrote %s/{traj,psi}_%s\n", OUT, tag)
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    main()
end
