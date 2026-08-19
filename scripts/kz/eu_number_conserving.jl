#!/usr/bin/env julia
# What condensate number does the euv3 evaporation give, with mu determined by the
# total rather than prescribed?
#
# The previous answer was withdrawn because mu was an input: in a grand-canonical
# SPGPE mu < eps_0 forbids a condensate and mu > eps_0 fixes its size through
# mu = eps_0 + c_0 n_0, so the verdict tracked a one-parameter K_3 fit and flipped at
# K_3/fit ~ 0.3. Here N_C is read from the field every step and mu is solved from
# N_I(mu,T) = N_total(t) - N_C, so N_0 is an output and K_3 moves the total instead of
# deciding whether a condensate exists.
#
# The grid has to be able to hold the answer, and 3D at F=6 with the DDI costs
# 460 ms/step at 48^3 — a KZ-length run is out of reach. This is not a KZ run: it is
# a single evaporation trajectory, so the cost is set by the ramp duration, and the
# scalar limit is used first because the question is the atom number and not the spin
# texture. Both simplifications are stated in the output so no reader has to infer
# them.
using SpinorBEC, FFTW, Printf, Statistics
# zero_d_trajectory lives in the evaporation figure driver, not the package.
include(joinpath(@__DIR__, "..", "..", "docs", "guides", "figures",
    "eu_evaporation_spgpe.jl"))

const OUTDIR = get(ENV, "SPINORBEC_FIGS_ROOT", "runs/eu_number_conserving")

"""
    _n0_tf_projection(psi, grid, c0) -> Float64

`N₀ = |⟨φ_TF|ψ⟩|²` with `φ_TF` the normalised Thomas–Fermi mode whose chemical
potential is read from the field's own peak density, `μ = c₀ n_peak`.

The obvious estimator, the `k = 0` weight `|∫ψ|²/V`, is exact for a uniform field —
and returns 0.816 of a trapped TF condensate. Measured in
`scripts/kz/n0_estimator_check.jl`, where this one returns 1.0000 on the same state
and the uniform case is kept as the control. An earlier single-k-mode estimator in
this branch understated `N₀` by 22×, so the check is a gate rather than a comment.
"""
function _n0_tf_projection(psi::AbstractArray{<:Complex}, grid::Grid{3}, c0::Real;
    comp::Int=size(psi, 4))
    # `comp` defaults to the LAST component, which is where thermal_cfield! seeds
    # (`comp = size(psi, N+1)`). Hard-coding component 1 read an EMPTY array on every
    # Eu151 run — D = 13 — so N_0 came back ~0 whatever the reservoir or gamma did,
    # while N_C summed all components and looked healthy. That is the entire "the field
    # does not condense" observation: four gamma arms were queued to discriminate a lag
    # from a defect when the defect was that the estimator was not reading the field.
    ψ = @view psi[:, :, :, comp]
    dV = cell_volume(grid)
    n_peak = maximum(abs2, ψ)
    n_peak > 0 || return 0.0
    mu_loc = Float64(c0) * n_peak
    num = zero(ComplexF64)
    nrm = 0.0
    for I in CartesianIndices(size(ψ))
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        d = mu_loc - 0.5 * (x^2 + y^2 + z^2)
        d > 0 || continue
        φ = sqrt(d / Float64(c0))
        num += φ * ψ[I]
        nrm += φ^2
    end
    nrm > 0 || return 0.0
    abs2(num) * dV / nrm            # |<phi|psi>|^2 with phi normalised
end

"""
    run_nc(; n, box, K3, steps_per_unit, eps_cut_nT, seed) -> NamedTuple

One closed-loop trajectory. `N_total(t)` and `T(t)` come from the 0-D model;
everything else is measured from the field.
"""
function run_nc(; n::Int=48, box::Float64=16.0, K3::Float64=1.61e-40,
    eps_cut_nT::Float64=3.0, seed::Int=9001, dt::Float64=0.02,
    t_frac::Float64=1.0, t_start_s::Float64=1.85, backend=CPUBackend(),
    number_damping::Bool=true, energy_damping::Bool=true,
    gamma_mult::Float64=1.0, cayley_iters::Int=2)
    traj = zero_d_trajectory(; K3)
    r = traj.r
    # Internal units: the 0-D model is in SI, the field is in units of omega_ref.
    ω_ref = traj.omega_of(r.t[1])
    t_int = (r.t .- r.t[1]) .* ω_ref
    T_int = r.T .* (Units.KB / (Units.HBAR * ω_ref))
    N_of = let ts = t_int, Ns = r.N
        tq -> begin
            tq <= ts[1] && return Ns[1]
            tq >= ts[end] && return Ns[end]
            j = searchsortedlast(ts, tq)
            f = (tq - ts[j]) / (ts[j + 1] - ts[j])
            Ns[j] * (1 - f) + Ns[j + 1] * f
        end
    end
    T_of = let ts = t_int, Ts = T_int
        tq -> begin
            tq <= ts[1] && return Ts[1]
            tq >= ts[end] && return Ts[end]
            j = searchsortedlast(ts, tq)
            f = (tq - ts[j]) / (ts[j + 1] - ts[j])
            Ts[j] * (1 - f) + Ts[j + 1] * f
        end
    end

    # The c-field CANNOT start at the beginning of the ramp. At 50 uK the internal
    # temperature is 1762, so eps_cut ~ 5290, k_cut = 103, and resolving that needs
    # ~520^3 — 1300x the cost of the 48^3 that runs at 460 ms/step with the DDI. Not a
    # tuning problem: a classical field describes modes with occupation of order one,
    # and at 50 uK the entire cloud is in the I region.
    #
    # So the 0-D model carries the cooling and this carries the formation. Affordable
    # window, measured in scripts/kz/handoff_window.jl:
    #
    #   t (s)   N        T (nK)   T_int   grid needed   cost/step
    #   0.87    2.0e5    2479     87      234^3         3.9 s
    #   1.52    9.6e4    931      33      144^3         832 ms
    #   1.85    1.4e4    207      7.3      70^3          82 ms
    #   2.07    4552     103      3.6      51^3          29 ms
    #
    # t_start_s is a CHOICE with a consequence: the ramp before it enters only through
    # (N, T) at the handoff, so a condensate that would have formed earlier is
    # excluded by construction.
    t0_int = t_start_s * ω_ref
    T_hot = T_of(t0_int)
    # eps_cut must TRACK T. Fixing it at the handoff value leaves the cutoff at 23.3
    # while T falls 7.28 -> 2.28, i.e. ten thermal energies above mu by the end, and
    # both reservoir coefficients depend on the cutoff only through (eps_cut - mu)/T —
    # so a fixed cutoff drives that ratio up and decouples the reservoir. This repo
    # already gates that failure ("a FIXED cutoff decouples the reservoir as T falls")
    # and tracking_cutoff exists for it; the first version of this driver used a fixed
    # one anyway, and mu pinned at 21.3 against a cutoff of 23.3 was the tell.
    #
    # The GRID is sized by the hot end, since k_max cannot grow mid-run.
    eps_cut_of = tq -> 1.5 + eps_cut_nT * T_of(tq)
    eps_cut_hot = eps_cut_of(t0_int)
    k_cut = sqrt(2 * eps_cut_hot)
    ts_ec = collect(range(t0_int, t_int[end]; length=64))
    k_cut_wave = PiecewiseLinearWaveform(ts_ec,
        [sqrt(2 * eps_cut_of(tq)) for tq in ts_ec])
    eps_cut = eps_cut_hot
    grid = make_grid(GridConfig((n, n, n), (box, box, box)))
    k_max = π * n / box
    cap = incoherent_population(eps_cut - 1e-9, T_hot, eps_cut)

    @printf("=== euv3 evaporation, mu from the total (SCALAR limit, no DDI) ===\n")
    @printf("  0-D: N %.4g -> %.4g   T %.3g -> %.3g K   duration %.3g s\n",
        r.N[1], r.N[end], r.T[1], r.T[end], r.t[end] - r.t[1])
    @printf("  HANDOFF at %.3f s: N = %.4g, T = %.4g nK (T_int = %.4g)\n",
        t_start_s, N_of(t0_int),
        1e9 * T_hot * Units.HBAR * ω_ref / Units.KB, T_hot)
    @printf("  internal: T %.4g -> %.4g   eps_cut %.3g (%.1f T_hot above eps_0)\n",
        T_int[1], T_int[end], eps_cut, eps_cut_nT)
    @printf("  grid %d^3 box %.1f  k_cut %.2f -> %.2f (TRACKING)  k_max %.2f (%.1fx)  I-cap %.4g\n",
        n, box, k_cut, sqrt(2 * eps_cut_of(t_int[end])), k_max, k_max / k_cut, cap)
    k_max > k_cut ||
        error("grid cannot resolve k_cut: k_max=$k_max <= k_cut=$k_cut")
    # Compared against the cloud AT THE HANDOFF, not at the start of the ramp: the
    # 0-D model carries the first 1.85 s and 3.5e6 atoms were never this field's to
    # hold. The first version compared against r.N[1] and warned on every run.
    cap > 0.05 * N_of(t0_int) ||
        @warn "the I region cannot hold the initial cloud; mu will be unsatisfiable " *
              "for a while" cap N0 = r.N[1]

    sp = SimParams(; dt, n_steps=1, imaginary_time=false, save_every=1,
        normalize_every=0)
    c0_field = 0.02
    ws = make_workspace(; grid, atom=Eu151,
        interactions=InteractionParams(Dict{Int, Float64}(0 => c0_field)),
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp, backend,
        fft_flags=FFTW.MEASURE)
    seed_device_rng!(backend, seed)
    # Seeded at the handoff equilibrium, NOT from vacuum. Filling an empty C region
    # under derived rates does not converge — a mode relaxes at 2 gamma (eps - mu),
    # which vanishes exactly where the Rayleigh-Jeans occupation puts the atoms, and
    # measured earlier this branch reached 1.85e4 against an equilibrium 1.52e5 after
    # ten response times. From vacuum the first part of this run would be a spurious
    # filling transient rather than the formation being asked about.
    hplans = make_fft_plans(grid.config.n_points; flags=FFTW.ESTIMATE)
    host = zeros(ComplexF64, size(ws.state.psi))
    N_seed = thermal_cfield!(host, grid, hplans; T=T_hot, mu=1.5, c0=0.02,
        k_cut, seed)
    copyto!(ws.state.psi, host)
    # INTO C before the run starts. thermal_cfield! low-passes at k_cut and then applies
    # the density envelope in REAL space, which broadens the spectrum past the cutoff —
    # over half the seed can sit outside C — and the first projection would otherwise
    # remove it in one step and be read as a loss rate. That confound is what made the
    # energy-damping loss look independent of dt for most of this arc.
    apply_projected_gp!(ws, k_cut)
    N_seed_C = real(sum(abs2, ws.state.psi)) * cell_volume(grid)
    @printf("  seeded with the handoff equilibrium: N_seed = %.4g -> %.4g in C (%.1f%%)\n",
        N_seed, N_seed_C, 100 * N_seed_C / max(N_seed, 1))

    mu_ref = Ref(0.0);
    bad = Ref(0)
    # The controller must use the SAME cutoff the projector does, or it solves for a
    # mu against an I region that is not the one the field sees.
    cb = number_conserving_callback(mu_ref, N_of, T_of, eps_cut_of; every=25,
        counter=bad, t_offset=t0_int, c0_lda=c0_field)
    res = SPGPEReservoir(; T=FunctionWaveform(T_of), mu=FeedbackWaveform(mu_ref),
        a_s=0.007 * gamma_mult, k_cut=k_cut_wave, gamma=NaN, M=NaN,  # DERIVED
        number_damping, energy_damping, allow_unphysical_rates=(gamma_mult != 1.0))

    dV = cell_volume(grid)
    n_steps = round(Int, t_frac * (t_int[end] - t0_int) / dt)
    marks = round.(Int, n_steps .* (0.1:0.1:1.0))
    hist = NamedTuple[]
    for s in 1:n_steps
        split_step!(ws)
        # Absolute ramp time: N_of and T_of must be read where the run actually is.
        apply_spgpe_step!(ws, res, dt; t=t0_int + s * dt, seed=seed + s,
            cayley_iters=cayley_iters)
        cb(ws, s)
        if s in marks
            NC = real(sum(abs2, ws.state.psi)) * dV
            # N_C is the whole C region, thermal atoms included. The condensate number
            # is a projection onto the coherent mode, and WHICH mode matters: the k = 0
            # weight |int psi|^2/V is exact for a uniform field but returns 0.816 of a
            # trapped Thomas-Fermi condensate, measured in
            # scripts/kz/n0_estimator_check.jl. So project onto the TF mode instead,
            # with mu taken from the field's own peak density so nothing external is
            # assumed — on a pure TF state that estimator returns N to 1.0000.
            N0 = _n0_tf_projection(ws.state.psi, grid, c0_field)
            # Every component, so a defect that puts atoms somewhere unexpected shows up
            # as a disagreement rather than as a silent zero.
            N0_all = sum(_n0_tf_projection(ws.state.psi, grid, c0_field; comp=c)
                         for c in 1:size(ws.state.psi, 4))
            push!(hist, (; t=t0_int + s * dt, N_C=NC, N0=N0_all, N0_seedcomp=N0,
                N_tot=N_of(t0_int + s * dt),
                mu=mu_ref[], T=T_of(t0_int + s * dt)))
            ta = t0_int + s * dt
            @printf("  t=%8.1f N_tot=%-10.4g N_C=%-10.4g N0=%-10.4g f0=%-6.3f mu=%-8.3f T=%-7.3f eps_cut=%-7.2f unsat=%d\n",
                ta, N_of(ta), NC, N0_all, N0_all / max(NC, 1), mu_ref[], T_of(ta),
                eps_cut_of(ta), bad[])
            flush(stdout)
        end
    end
    (; hist, unsat=bad[], n_cb=n_steps ÷ 25, eps_cut, cap, k_cut)
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = get(ARGS, 1, "smoke")
    if mode == "smoke"
        out = run_nc(; n=44, box=10.0, t_frac=0.05)
        @printf("\nunsatisfiable: %d of %d\n", out.unsat, out.n_cb)

    elseif mode == "gammascan"
        # Is N_0 = 0 a finite-gamma LAG or a defect?
        #
        # Growth alone GROWS the field — N_C rises 1716 -> 3110 — so atoms arrive. What
        # does not happen is condensation: N_0 stays at 0.004 while mu sits at 5.3-7.4
        # against eps_0 = 1.5, where Thomas-Fermi says a condensate should exist. The
        # N_0 estimator is not the suspect; it returns 1.00000 on a known TF state
        # (scripts/kz/n0_estimator_check.jl).
        #
        # The discriminator is gamma. If a larger gamma condenses, the zero is the lag
        # this run exists to measure — the reservoir simply has not had time to build
        # coherence. If it does not condense at any gamma, the zero is a defect. This is
        # the same positive-control shape as the KZ gamma x3 invariance check, and gamma
        # is raised through a_s since the rates are DERIVED and pinning them is what the
        # unphysical-rate gate refuses.
        for gm in (1.0, 3.0, 10.0, 30.0)
            @printf("\n########## gamma multiplier %.0fx (growth only) ##########\n", gm)
            o = run_nc(; n=44, box=10.0, dt=0.02, t_frac=0.25, t_start_s=1.73,
                number_damping=true, energy_damping=false, gamma_mult=gm)
            h = isempty(o.hist) ? nothing : o.hist[end]
            if h !== nothing
                g = mu_from_total_lda(h.N_tot; T=h.T, c0=0.02, eps_cut=1.5 + 3 * h.T)
                @printf("  END  N_C=%.4g  field N0=%.4g  equilibrium N0=%.4g  ratio=%.5f\n",
                    h.N_C, h.N0, g.N0, h.N0 / max(g.N0, 1))
            end
            flush(stdout)
        end

    elseif mode == "which"
        # The field EMPTIES where it should grow: seeded at 1716, N_C falls monotonically
        # to 14.9 while mu stays at 2.9-6.1 — above eps_0 = 1.5 throughout — and the
        # constraint is satisfiable at all 4977 callbacks. The equilibrium it is being
        # driven toward is N_0 = 3498. So something is removing atoms, not failing to
        # add them, and that is a defect rather than a finite-gamma lag.
        #
        # Two candidates and one run each settles it: growth alone must GROW toward the
        # equilibrium, and energy damping alone conserves number by construction (it is
        # the number-conserving reservoir) so any drift there is the defect.
        for (nd, ed, label) in ((true, false, "growth only"),
            (false, true, "energy damping only"), (true, true, "both"))
            @printf("\n########## %s ##########\n", label)
            o = run_nc(; n=44, box=10.0, dt=0.02, t_frac=0.3, t_start_s=1.73,
                number_damping=nd, energy_damping=ed)
            @printf("  unsatisfiable: %d of %d\n", o.unsat, o.n_cb)
            flush(stdout)
        end

    elseif mode == "lag"
        # Does the field reach the equilibrium the constraint names, and how far
        # behind is it?
        #
        # The constraint says N_0 = 1.15e4 at the 1.85 s handoff and the field reports
        # 0 through the first 5% of its window. That gap is the physics the SPGPE
        # exists to compute: a finite gamma decides whether a condensate the
        # thermodynamics allows actually forms in the time available. An equilibrium
        # table cannot answer it and neither can a run that stops at 5%.
        #
        # Handed off at three points spanning the peak, since where the field is
        # started changes how much time it has: 1.73 s is where N_0^eq peaks at 4.0e4,
        # 1.85 s is the earliest affordable grid, 1.99 s is comfortably inside.
        for ts in (1.73, 1.85, 1.99)
            @printf("\n########## handoff at %.2f s ##########\n", ts)
            o = run_nc(; n=44, box=10.0, dt=0.02, t_frac=1.0, t_start_s=ts)
            h = isempty(o.hist) ? nothing : o.hist[end]
            if h !== nothing
                # The equilibrium the field was being driven toward, at the same point.
                g = mu_from_total_lda(h.N_tot; T=h.T, c0=0.02,
                    eps_cut=1.5 + 3 * h.T)
                @printf("  END  N_tot=%.4g  field N0=%.4g  equilibrium N0=%.4g  ratio=%.4f\n",
                    h.N_tot, h.N0, g.N0, h.N0 / max(g.N0, 1))
            end
            @printf("  unsatisfiable: %d of %d\n", o.unsat, o.n_cb)
            flush(stdout)
        end

    elseif mode == "dtbox"
        # The two factors, measured before an 11-hour run rather than assumed.
        #
        # dt: 2e-3 was habit. The fastest timescale here is eps_cut = 1.5 + 3 T_int =
        # 22.5, so dt <~ 0.044, and 2e-3 is twenty times smaller than needed. The
        # figure of merit is N_C, not sigma(W) — this is not a KZ run.
        #
        # box: at T_int = 7.3 the thermal cloud reaches r ~ sqrt(2T) = 3.7 a_ho, so
        # box = 16 (+-8) is more than twice what is needed. Shrinking it at fixed dx
        # buys n^3.
        #
        # Held to a fifth of the ramp so the sweep is minutes. Whether the FULL ramp
        # tolerates the same dt is a separate question, and the answer here does not
        # settle it.
        @printf("\n%-8s %-7s %-6s %-12s %-10s %-8s\n",
            "dt", "box", "n", "N_C final", "mu final", "unsat")
        for (dt, box, nn) in ((0.002, 16.0, 70), (0.02, 16.0, 70), (0.05, 16.0, 70),
            (0.02, 10.0, 44), (0.02, 8.0, 36))
            o = run_nc(; n=nn, box, dt, t_frac=0.2)
            h = isempty(o.hist) ? nothing : o.hist[end]
            @printf("%-8.4g %-7.1f %-6d %-12.5g %-10.3f %-8d\n",
                dt, box, nn, h === nothing ? NaN : h.N_C,
                h === nothing ? NaN : h.mu, o.unsat)
            flush(stdout)
        end

    else
        # Optimised: dt = 0.02 against the 22.5 set by eps_cut, and box = 10 against a
        # thermal cloud reaching r ~ sqrt(2T) = 3.7 a_ho. 44^3 at the same dx.
        out = run_nc(; n=44, box=10.0, dt=0.02, t_frac=1.0)
        @printf("\nunsatisfiable: %d of %d\n", out.unsat, out.n_cb)
    end
end
