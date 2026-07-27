#!/usr/bin/env julia
# docs/guides/figures/eu_shape_finite_t.jl
#
# Finite-temperature trap-shape optimization for ¹⁵¹Eu BEC formation (task #12) —
# the definitive version of the T=0 study in eu_shape_optimization.jl. At T>0 the
# shape optimum is set by a COMPETITION the T=0 GP cannot see:
#
#   • expanding the trap cuts three-body loss  (dN/dt ∝ ⟨n²⟩ ∝ ω̄^{12/5})  — favours expansion
#   • but T_c ∝ ℏω̄ N^{1/3} drops as the trap loosens, so the condensate MELTS   — penalises expansion
#
# We evolve the Stoof-form (full-Hamiltonian) Stochastic Projected GP: the unitary
# split-step + K₃ loss + a dissipative/thermal SGPE sub-step that relaxes toward
# the interacting thermal state at (μ, T). In norm-N units the condensate is the
# phase-fixed ENSEMBLE mean ⟨ψ⟩ (thermal cancels across trajectories), N₀=∫|⟨ψ⟩|²dV.
#
# Rigour (see docs/guides/eu_shape_finite_t.md): thermalisation is pinned by the
# existing test_sgpe_fdr.jl (Rayleigh-Jeans) and test_sgpe_stoof.jl (T→0→interacting
# GP GS); this driver adds V-T0 (N₀→N as T→0) and V-mono (condensate melts). HONEST
# limitation: the classical field is cutoff-dependent — over k_cut∈[4.6,8.0] the thermal
# cloud spreads ~79% while the condensate N₀ moves ~30%, i.e. N₀ is the MORE robust of
# the two but NOT cutoff-free. So absolute numbers are quoted at the physical cutoff
# (ε(k_cut)−μ≈T) and only comparisons at FIXED k_cut (the shape panel) are cutoff-clean.
# A realistic cooling trajectory T(t),μ(t) from the 0-D evaporation model is a later step.
#
# Run (CPU smoke):  julia --project=. docs/guides/figures/eu_shape_finite_t.jl --smoke
# Run (GPU):        LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#                     -e 'import CUDA; include("docs/guides/figures/eu_shape_finite_t.jl"); ft_smoke(backend=CUDABackend())'
#
# Provenance:
# - shows: DRIVER — computes the finite-T Stoof-SGPE CSVs behind the eu_ft_* figures (equilibrium, evap_noneq, decompress_refine, recipe, shape_cal); runs on TSUBAME H100
# - referenced by: docs/guides/eu_shape_finite_t.md
# - supersedes: none (driver)

include(joinpath(@__DIR__, "eu_shape_optimization.jl"))  # EuUnits, ground_state, harmonic_schedule, …

using SpinorBEC: apply_sgpe_step!, apply_operator_via_registry!, total_energy

# ---------------------------------------------------------------------------
# CONVENTION (load-bearing, from first principles). The T=0 driver uses norm-1
# (∫|ψ|²=1, N folded into c₀=g̃N). But the SGPE fluctuation-dissipation noise
# σ=√(2γT·dt/dV) assumes |ψ|² is the PHYSICAL density (∫|ψ|²=N). In norm-1 the
# noise would be √N too large ⇒ thermal cloud ~N× too heavy (total N came out
# ~1000× high). So the finite-T SGPE runs in NORM-N: seed ψ_N=√N·ψ₁, use the BARE
# couplings c₀=g̃ and K₃=K̃₃ (no N/N² fold-in). Mean field g̃|ψ_N|²=g̃N|ψ₁|² and the
# K₃ loss n=|ψ_N|² are then both correct, and ∫|ψ|² is the physical atom number.
# ---------------------------------------------------------------------------
c0_bare(u::EuUnits) = 4π * (u.a_s / a_ho(u))     # g̃  (norm-N contact)
k3_bare(u::EuUnits) = k3_tilde(u)                # K̃₃ (norm-N three-body)

# The finite-T model is single-component: all atoms in the stretched state with
# c₁=0, so the spin matrices never enter (diagonal contact only) and ANY F gives
# identical physics — only D=2F+1 (hence cost) changes. Use F=1 (D=3), 4.3× cheaper
# than ¹⁵¹Eu's D=13; the Eu units live entirely in the explicit c₀ and K₃. (A run at
# D=13 reproduces D=3 to sampling error, confirming the reduction.)
const FT_ATOM = Rb87

function ft_ground_state(u::EuUnits, grid; n_steps::Int, backend=CPUBackend())
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_coupling(u)))
    res = find_ground_state(; grid, atom=FT_ATOM, interactions,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), dt=0.002, n_steps, tol=1e-9,
        initial_state=:m_minus_F, backend, verbose=false)
    res.workspace.state.psi
end

# GP chemical potential μ = ⟨ψ|Ĥ|ψ⟩ / ⟨ψ|ψ⟩ of a state in a given trap.
function gp_chempot(u::EuUnits, grid, psi, potential; backend=CPUBackend())
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_coupling(u)))
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)
    ws = make_workspace(; grid, atom=FT_ATOM, interactions, potential, sim_params=sp,
        psi_init=psi, backend)
    hpsi = similar(ws.state.psi)
    apply_operator_via_registry!(hpsi, ws)
    ψ = ws.state.psi
    real(sum(conj.(ψ) .* hpsi)) / real(sum(abs2, ψ))
end

# One SGPE trajectory. γ is TIME-DEPENDENT via `gamma_of_t`: the bath damps+noises
# during preparation (γ>0) and is switched OFF (γ=0) for a closed-system shape ramp —
# a fixed-μ bath would otherwise PUMP atoms into the condensate as the trap loosens
# (grand-canonical, unphysical for atom survival). Under closed GP the gas cools
# adiabatically as it expands, so T/T_c is preserved (the physical picture).
function _sgpe_trajectory!(
    u, grid, psi0, potential_of_t, gamma_of_t, T_of_t, k_cut, μ_of_t,
    T_internal, dt, save_every, backend, seed_base,
    psi_sum, dens_sum, n_tot_sum, save_times, D, loss_on,
)
    n_steps = round(Int, T_internal / dt)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_bare(u)))   # norm-N
    loss = loss_on ? LossParams(; K3_cubic=k3_bare(u)) : nothing            # norm-N
    sp = SimParams(; dt, n_steps, imaginary_time=false, normalize_every=0, save_every)
    ws = make_workspace(; grid, atom=FT_ATOM, interactions,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        psi_init=copy(psi0), loss, backend)
    dV = cell_volume(grid)
    sidx = Ref(0)
    cb = SimulationCallbacks(
        on_step=(w, step, times, energies) -> begin
            # potential_of_t may return an AbstractPotential OR a ready V-array (used
            # by the adiabatic morph, which blends two potentials point-by-point).
            pv = potential_of_t(w.state.t)
            Varr = pv isa AbstractArray ? pv : evaluate_potential(pv, grid)
            copyto!(w.potential_values, Varr)
            γ = gamma_of_t(w.state.t)
            if γ > 0
                apply_sgpe_step!(w, γ, T_of_t(w.state.t), dt; μ=μ_of_t(w.state.t), k_cut=k_cut,
                    full_hamiltonian=true, seed=seed_base + step)
                # scalar model: only the stretched m=-F component is physical; zero the
                # rest so SGPE noise / μ-pumping cannot fill the empty spin channels.
                @views for c in 1:(D - 1)
                    w.state.psi[ntuple(_ -> Colon(), 3)..., c] .= 0
                end
            end
            if step % save_every == 0
                sidx[] += 1
                i = sidx[]
                i <= length(psi_sum) || return nothing
                ψc = Array(view(w.state.psi, ntuple(_ -> Colon(), 3)..., D))
                phase = angle(sum(ψc) * dV)          # global-phase gauge fix
                @. psi_sum[i] += ψc * cis(-phase)
                @. dens_sum[i] += abs2(ψc)           # ⟨|ψ|²⟩ accumulator (bias correction)
                n_tot_sum[i] += real(sum(abs2, w.state.psi)) * dV
                save_times[i] = w.state.t
            end
            nothing
        end,
    )
    run_simulation!(ws; callbacks=cb)
    nothing
end

# Ensemble SGPE run. Condensate N₀ = ∫|⟨ψ⟩|²dV is the phase-fixed ensemble mean of
# the stretched component (thermal fluctuations cancel across trajectories); total
# N = ⟨∫|ψ|²⟩. Both in physical atom units (norm-N). Returns time series.
function run_ensemble(
    u::EuUnits, grid, psi0;
    potential_of_t, gamma_of_t, T, k_cut::Float64,          # T: scalar OR t→T(t)
    mu::Float64, μ_of_t=(_ -> mu), loss_on::Bool=true,
    n_traj::Int=8, T_internal::Float64, dt::Float64,
    save_every::Int=20, backend=CPUBackend(), seed0::Int=1234,
)
    T_of_t = T isa Number ? (_ -> Float64(T)) : T
    n_steps = round(Int, T_internal / dt)
    n_save = fld(n_steps, save_every)
    D = SpinSystem(FT_ATOM.F).n_components
    gpts = grid.config.n_points
    psiN = copy(psi0) .* sqrt(u.N)                 # norm-1 GS → norm-N physical field
    psi_sum = [zeros(ComplexF64, gpts...) for _ in 1:n_save]
    dens_sum = [zeros(Float64, gpts...) for _ in 1:n_save]
    n_tot_sum = zeros(Float64, n_save)
    save_times = zeros(Float64, n_save)
    for tr in 1:n_traj
        _sgpe_trajectory!(u, grid, psiN, potential_of_t, gamma_of_t, T_of_t, k_cut, μ_of_t,
            T_internal, dt, save_every, backend, seed0 + tr * 1_000_003,
            psi_sum, dens_sum, n_tot_sum, save_times, D, loss_on)
    end
    dV = cell_volume(grid)
    M = n_traj
    t_ms = save_times ./ u.omega_ref .* 1e3
    N_tot = n_tot_sum ./ M                          # norm-N ⇒ already atom number
    # Bias-corrected condensate (Penrose-Onsager consistent): the raw coherent
    # density |⟨ψ⟩|² over-counts by the residual thermal variance /M, so subtract it:
    #   n_c = |⟨ψ⟩|² − (⟨|ψ|²⟩ − |⟨ψ⟩|²)/(M−1).  Makes N₀ unbiased / M-independent.
    N0 = map(1:n_save) do i
        coh = abs2.(psi_sum[i] ./ M)               # |⟨ψ⟩|²
        meandens = dens_sum[i] ./ M                 # ⟨|ψ|²⟩
        nc = M > 1 ? coh .- (meandens .- coh) ./ (M - 1) : coh
        max(sum(nc) * dV, 0.0)
    end
    (t_ms=t_ms, N=N_tot, N0=N0, frac=N0 ./ max.(N_tot, eps()))
end

kcut_for(mu, T) = sqrt(2 * (mu + T))                 # ε(k_cut) − μ ≈ T
Tc_harmonic(N, ωbar=1.0) = 0.94 * ωbar * N^(1 / 3)   # kT_c/ℏω_ref, ideal Bose 3D

function _setup(u, grid_n, box, gs_steps, backend)
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    psi0 = ft_ground_state(u, grid; n_steps=gs_steps, backend)
    mu = gp_chempot(u, grid, psi0, HarmonicTrap{3}((1.0, 1.0, 1.0)); backend)
    (grid=grid, psi0=psi0, mu=mu, k_max=π / (box / grid_n))
end

# V-T0 / V-mono: finite-T equilibrium condensate NUMBER N₀ + thermal N_th vs T/T_c.
# Static trap (HOLD, bath on, NO loss) → SGPE thermal equilibrium. N₀ (not the
# fraction) is the physical, cutoff-robust observable; N_th is classical-field (RJ).
function ft_equilibrium(; grid_n::Int=48, box::Float64=18.0,
    T_over_Tc_list::Vector{Float64}=[0.1, 0.3, 0.5, 0.7, 0.9],
    T_equil::Float64=30.0, dt::Float64=0.01, gs_steps::Int=2500,
    gamma::Float64=0.1, n_traj::Int=8, backend=CPUBackend(),
    csv::String=joinpath(@__DIR__, "eu_ft_equilibrium.csv"))
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    @printf "μ_GS=%.3f, T_c=%.2f ℏω_ref, k_max=%.2f\n" s.mu Tc s.k_max
    # PHYSICAL observable = condensate NUMBER N₀ (IR, cutoff-robust; see V-kcut).
    # The thermal N_th is a classical-field (Rayleigh-Jeans) quantity and is cutoff-
    # dependent, so f=N₀/N_tot sits BELOW the quantum 1−(T/Tc)³ (classical ≠ quantum
    # thermal); that reference is printed for orientation only, NOT as a pass gate.
    println("=== Finite-T equilibrium: condensate N₀ + thermal N_th vs T/T_c (HOLD) ===")
    @printf "  %-8s %-10s %-11s %-9s %-11s\n" "T/Tc" "N₀" "N_th" "N₀/N" "[1-(T/Tc)³]"
    rows = NTuple{5, Float64}[]
    for r in T_over_Tc_list
        T = r * Tc
        k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
        res = run_ensemble(u, s.grid, s.psi0;
            potential_of_t=harmonic_schedule(_ -> 1.0), gamma_of_t=(_ -> gamma),
            T, k_cut, mu=s.mu, loss_on=false, n_traj, T_internal=T_equil, dt, backend)
        i0 = max(1, fld(3 * length(res.frac), 5))          # plateau = last 40%
        n = length(i0:length(res.N0))
        N0 = sum(@view res.N0[i0:end]) / n
        Nt = sum(@view res.N[i0:end]) / n
        push!(rows, (r, N0, Nt - N0, N0 / u.N, 1 - r^3))
        @printf "  %-8.2f %-10.4g %-11.4g %-9.3f %-11.3f\n" r N0 (Nt - N0) (N0 / u.N) (1 - r^3)
    end
    open(csv, "w") do io
        println(io, "T_over_Tc,N0,N_thermal,N0_over_N,f_ideal_quantum")
        for r in rows
            @printf io "%.4f,%.6g,%.6g,%.6f,%.6f\n" r...
        end
    end
    n0_cold = rows[1][4]                                     # N₀/N at the lowest T
    nth_mono = all(rows[i][3] <= rows[i + 1][3] + 0.05 * u.N for i in 1:(length(rows) - 1))
    println()
    @printf "  V-T0   (N₀→N as T→0): N₀/N(%.2f)=%.3f  %s\n" rows[1][1] n0_cold (n0_cold > 0.93 ? "PASS" : "CHECK")
    @printf "  V-mono (N_th grows with T): %s\n" (nth_mono ? "PASS" : "CHECK")
    @printf "  CSV → %s   (condensate N₀ cutoff-robustness ⇒ run kcut mode)\n" csv
    (u=u, rows=rows, n0_cold=n0_cold, nth_mono=nth_mono)
end

# ANALYTIC fixed-N equilibrium from atom+trap+N properties — NO simulation. The real
# (quantum) thermal cloud is BOUNDED (unlike the classical field's Rayleigh-Jeans
# over-population), so a fixed-N Bose gas in a 3D harmonic trap has
#   T_c = ℏω̄(N/ζ(3))^{1/3},  N_th = ζ(3)(k_BT/ℏω̄)³ = N(T/T_c)³,  N₀ = N[1−(T/T_c)³],
# and the interacting μ tracks the condensate density (Thomas-Fermi):
#   μ(T) = μ_GP · (N₀/N)^{2/5},   μ_GP = ½ℏω̄(15 N a_s/a_ho)^{2/5}.
# This is the CLEAN equilibrium (no cutoff, no over-thermalisation); the SGPE is kept
# for the DYNAMICS (shape ramp) it alone can do. Note the leading result is ideal; the
# interacting + finite-N Tc shift is ΔTc/Tc ≈ −1.33(a_s/a_ho)N^{1/6} − 0.73 N^{−1/3}
# (Giorgini-Pitaevskii-Stringari), ~−14% here — printed but not folded into the curve.
function ft_equilibrium_analytic(;
    T_over_Tc_list::Vector{Float64}=collect(0.05:0.05:0.98),
    csv::String=joinpath(@__DIR__, "eu_ft_equilibrium_analytic.csv"))
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    ah = a_ho(u)
    ζ3 = 1.2020569031595942
    μ_GP = 0.5 * (15 * u.N * u.a_s / ah)^(2 / 5)          # Thomas-Fermi, atom props only
    Tc = (u.N / ζ3)^(1 / 3)                                # kT_c/ℏω_ref at ω̄=1
    dTc = -1.33 * (u.a_s / ah) * u.N^(1 / 6) - 0.73 * u.N^(-1 / 3)  # GPS correction
    @printf "μ_GP(TF)=%.3f, T_c(ideal)=%.2f ℏω_ref  (interacting+finite-N ΔTc/Tc≈%.1f%%)\n" μ_GP Tc 100 * dTc
    println("=== Analytic fixed-N Bose equilibrium (from atom+trap+N, NO simulation) ===")
    @printf "  %-8s %-10s %-11s %-9s %-9s\n" "T/Tc" "N₀" "N_th" "N₀/N" "μ(T)"
    open(csv, "w") do io
        println(io, "T_over_Tc,N0,N_thermal,N0_over_N,mu")
        for r in T_over_Tc_list
            f0 = max(1 - r^3, 0.0)
            N0 = u.N * f0
            Nth = u.N * r^3
            μ = μ_GP * f0^(2 / 5)
            @printf io "%.4f,%.6g,%.6g,%.6f,%.6f\n" r N0 Nth f0 μ
            (r in (0.1, 0.3, 0.5, 0.7, 0.9)) &&
                @printf "  %-8.2f %-10.4g %-11.4g %-9.3f %-9.3f\n" r N0 Nth f0 μ
        end
    end
    @printf "  CSV → %s\n" csv
    (u=u, mu_GP=μ_GP, Tc=Tc)
end

# 0-D RESERVOIR COUPLING. The evaporative cooling (seconds) is quasi-static relative
# to the SGPE dynamics (ms), so the 0-D two-component model provides the physically
# calibrated (ω̄, N, T/T_c) at BEC formation that the SGPE shape study should use —
# replacing the ad-hoc ω_ref=2π·420 Hz, N=1e4, T/T_c=0.5. Returns an EuUnits at the
# 0-D formation trap + N, and the formation T/T_c. (Full time-dependent T(t) SGPE is
# infeasible given the s-vs-ms timescale split; calibration is the honest coupling.)
function ft_reservoir_calibration(; N0_load::Float64=3.5e6, T0_load::Float64=50e-6,
    a_s::Float64=110 * Units.BOHR_RADIUS, tau_bg::Float64=15.0, K3::Float64=1.6e-40)
    trap = SpinorBEC.euv3_evap_trap()
    ramp = SpinorBEC.euv3_evaporation_ramp()          # researched ramp that reaches BEC onset
    p = SpinorBEC.EvapParams(; a_s=a_s, tau_bg=tau_bg, K3=K3)
    r = SpinorBEC.run_evaporation(trap, ramp, p; N0=N0_load, T0=T0_load)
    h = SpinorBEC.bec_handoff(trap, ramp, r)
    ωbar = h.omega_ref
    println("=== 0-D evaporation → SGPE reservoir calibration ===")
    @printf "  loaded N=%.2g @ T=%.1f µK ⇒ BEC onset:\n" N0_load T0_load * 1e6
    @printf "    ω̄(formation) = 2π·%.0f Hz   (ω_dimless per axis = %s)\n" ωbar / 2π string(round.(h.omega_dimless; digits=3))
    @printf "    N_BEC        = %.3g atoms\n" h.N_BEC
    @printf "    T_BEC        = %.0f nK   (T/T_c = %.2f at onset)\n" h.T_BEC * 1e9 h.T_over_Tc
    @printf "    a_ho         = %.3f µm\n" h.a_ho * 1e6
    # Build the calibrated EuUnits (formation trap as ω_ref, condensate N).
    u_cal = EuUnits(; omega_ref=ωbar, a_s=a_s, N=h.N_BEC)
    @printf "  ⇒ calibrated SGPE units: ω_ref=2π·%.0f Hz, N=%.3g, g̃=%.4g\n" ωbar / 2π h.N_BEC c0_bare(u_cal)
    (u=u_cal, T_over_Tc=h.T_over_Tc, N_BEC=h.N_BEC, omega_bar=ωbar, result=r)
end

# EVAPORATION RAMP optimization (0-D, CPU) — the FORT power schedule BEFORE the
# decompression. Bayesian-optimizes the researched euv3 ramp (3-param transform:
# duration / final-power / time-warp) to maximize the condensate at BEC onset.
# `bounds` widened from the default so the corner-optimum can move; the 1-D scans
# then show whether N_BEC has a real physical peak (spilling / too-short evaporation)
# or keeps rising to the bound (a model limit needing a constraint).
function ft_evap_ramp_optimize(; n_iter::Int=50, n_init::Int=10,
    bounds::Vector{Tuple{Float64, Float64}}=[(0.15, 3.0), (0.05, 2.0), (0.2, 2.0)],
    csv_prefix::String=joinpath(@__DIR__, "eu_ft_evap_ramp"))
    base = SpinorBEC.run_euv3_evaporation()
    @printf "baseline euv3 ramp: reached_bec=%s, N_BEC=%.3g, T_BEC=%.0f nK\n" base.reached_bec base.N_BEC base.T_BEC * 1e9
    print("Bayesian-optimizing the FORT ramp ($n_iter iters, widened bounds) ... ")
    t0 = time()
    opt = SpinorBEC.optimize_euv3_evaporation(; n_init=n_init, n_iter=n_iter, bounds=bounds)
    @printf "%.1f s\n" (time() - t0)
    @printf "  best params [dur, final-P, warp] = %s\n" string(round.(opt.bo.best_p; digits=3))
    # 1-D landscape scans (hold the other two params at the optimum) to locate the
    # physical peak of each parameter.
    trap = SpinorBEC.euv3_evap_trap()
    base_ramp = SpinorBEC.euv3_evaporation_ramp()
    p = SpinorBEC.EvapParams(; a_s=Eu151.a_s, tau_bg=15.0, K3=1.6107615346177146e-40)
    N0load, T0load = 3.5e6, 50e-6
    names = ("duration", "final_power", "warp")
    open("$(csv_prefix)_scan.csv", "w") do io
        println(io, "param,value,N_BEC,reached")
        for idx in 1:3
            lo, hi = bounds[idx]
            for v in range(lo, hi; length=13)
                sc = SpinorBEC.scan_ramp_param(trap, p, base_ramp; index=idx, values=[v],
                    base_params=collect(Float64, opt.bo.best_p), N0=N0load, T0=T0load)[1]
                @printf io "%s,%.4f,%.6g,%s\n" names[idx] v (isnan(sc.N_BEC) ? 0.0 : sc.N_BEC) sc.reached
            end
        end
    end
    @printf "  scan CSV → %s_scan.csv\n" csv_prefix
    ob, or = base, opt.result
    @printf "  baseline  N_BEC=%.4g  T_BEC=%.0f nK  t_BEC=%.2f s\n" ob.N_BEC ob.T_BEC * 1e9 ob.t_BEC
    @printf "  optimized N_BEC=%.4g  T_BEC=%.0f nK  t_BEC=%.2f s   (%.1f%% more BEC)\n" or.N_BEC or.T_BEC * 1e9 or.t_BEC 100 * (or.N_BEC / ob.N_BEC - 1)
    # write trajectory CSVs (time, N, T, total FORT power)
    trap = SpinorBEC.euv3_evap_trap()
    for (tag, res, ramp) in (("baseline", base, SpinorBEC.euv3_evaporation_ramp()),
        ("optimal", opt.result, opt.ramp))
        open("$(csv_prefix)_$(tag).csv", "w") do io
            println(io, "t_s,N,T_uK,power_W")
            for i in 1:length(res.t)
                P = sum(SpinorBEC.fort_power_at(ramp, res.t[i]))
                @printf io "%.5f,%.6g,%.6g,%.6g\n" res.t[i] res.N[i] res.T[i] * 1e6 P
            end
        end
    end
    @printf "  CSVs → %s_{baseline,optimal}.csv\n" csv_prefix
    (baseline=base, opt=opt)
end

# NON-EQUILIBRIUM evaluation of the duration knife-edge: scan the ramp-duration scale
# with the finite-evaporation-rate penalty OFF (quasi-static, "faster always better")
# and ON (fast ramps spill instead of evaporate → less cooling). Shows whether the
# penalty turns the bare reachability knife-edge into a real physical interior optimum.
function ft_evap_noneq_eval(; noneq_scale::Float64=1.0,
    durations=collect(range(0.25, 1.6; length=16)),
    csv::String=joinpath(@__DIR__, "eu_ft_evap_noneq.csv"))
    trap = SpinorBEC.euv3_evap_trap()
    base_ramp = SpinorBEC.euv3_evaporation_ramp()
    mk(s) = SpinorBEC.EvapParams(; a_s=Eu151.a_s, tau_bg=15.0,
        K3=1.6107615346177146e-40, noneq_scale=s)
    N0load, T0load = 3.5e6, 50e-6
    println("=== Non-equilibrium eval: N_BEC vs ramp-duration scale ===")
    @printf "  %-10s %-14s %-14s\n" "dur" "N_BEC(noneq off)" "N_BEC(noneq on)"
    rows = NTuple{3, Float64}[]
    for d in durations
        s0 = SpinorBEC.scan_ramp_param(trap, mk(0.0), base_ramp; index=1, values=[d],
            base_params=[1.0, 1.0, 1.0], N0=N0load, T0=T0load)[1]
        s1 = SpinorBEC.scan_ramp_param(trap, mk(noneq_scale), base_ramp; index=1, values=[d],
            base_params=[1.0, 1.0, 1.0], N0=N0load, T0=T0load)[1]
        n0 = s0.reached ? s0.N_BEC : 0.0
        n1 = s1.reached ? s1.N_BEC : 0.0
        push!(rows, (d, n0, n1))
        @printf "  %-10.3f %-14.5g %-14.5g\n" d n0 n1
    end
    open(csv, "w") do io
        println(io, "duration_scale,N_BEC_noneq_off,N_BEC_noneq_on")
        for r in rows
            @printf io "%.4f,%.6g,%.6g\n" r...
        end
    end
    off = [r[2] for r in rows]
    on = [r[3] for r in rows]
    i_off = argmax(off)
    i_on = argmax(on)
    println()
    @printf "  noneq OFF: peak at dur=%.2f (N_BEC=%.4g) — %s\n" rows[i_off][1] off[i_off] (i_off == 1 ? "MONOTONE to floor (knife-edge)" : "interior")
    @printf "  noneq ON : peak at dur=%.2f (N_BEC=%.4g) — %s\n" rows[i_on][1] on[i_on] (1 < i_on < length(on) ? "INTERIOR optimum (physical)" : "at boundary")
    @printf "  CSV → %s\n" csv
    (rows=rows,)
end

# kcut sensitivity: quantify how the condensate N₀ and thermal N_th depend on the
# classical-field cutoff. Both do (it is a classical field), but the condensate is
# much less sensitive (~30% vs ~79% over k_cut∈[4.6,8.0]). Absolute numbers hold at
# the physical cutoff ε(k_cut)−μ≈T; the shape comparison runs at FIXED k_cut so it
# is cutoff-clean. This is the honest statement of the classical-field limitation.
function ft_kcut_convergence(; grid_n::Int=48, box::Float64=18.0, T_over_Tc::Float64=0.5,
    kcut_fracs::Vector{Float64}=[0.55, 0.65, 0.75, 0.85, 0.95],
    T_equil::Float64=30.0, dt::Float64=0.01, gs_steps::Int=2500,
    gamma::Float64=0.1, n_traj::Int=8, backend=CPUBackend(),
    csv::String=joinpath(@__DIR__, "eu_ft_kcut.csv"))
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    @printf "μ=%.3f, T=%.2f (T/Tc=%.2f), k_max=%.2f\n" s.mu T T_over_Tc s.k_max
    println("=== k_cut convergence of condensate N₀ (T/Tc=$T_over_Tc, HOLD, no loss) ===")
    @printf "  %-10s %-11s %-11s %-11s\n" "k_cut" "N₀" "N_thermal" "N_tot"
    rows = NTuple{4, Float64}[]
    for frac in kcut_fracs
        k_cut = frac * s.k_max
        res = run_ensemble(u, s.grid, s.psi0;
            potential_of_t=harmonic_schedule(_ -> 1.0), gamma_of_t=(_ -> gamma),
            T, k_cut, mu=s.mu, loss_on=false, n_traj, T_internal=T_equil, dt, backend)
        i0 = max(1, fld(3 * length(res.frac), 5))
        N0 = sum(@view res.N0[i0:end]) / length(i0:length(res.N0))
        Nt = sum(@view res.N[i0:end]) / length(i0:length(res.N))
        push!(rows, (k_cut, N0, Nt - N0, Nt))
        @printf "  %-10.3f %-11.4g %-11.4g %-11.4g\n" k_cut N0 (Nt - N0) Nt
    end
    open(csv, "w") do io
        println(io, "k_cut,N0,N_thermal,N_tot")
        for r in rows
            @printf io "%.4f,%.6g,%.6g,%.6g\n" r...
        end
    end
    N0s = [r[2] for r in rows]
    Nths = [r[3] for r in rows]
    spread0 = (maximum(N0s) - minimum(N0s)) / (sum(N0s) / length(N0s))
    spreadth = (maximum(Nths) - minimum(Nths)) / (sum(Nths) / length(Nths))
    println()
    @printf "  cutoff sensitivity: condensate N₀ spread=%.0f%%  vs  thermal N_th spread=%.0f%%\n" 100 * spread0 100 * spreadth
    @printf "  ⇒ N₀ is the MORE robust observable (quote at physical k_cut=√(2(μ+T)); compare at FIXED k_cut).\n"
    @printf "  CSV → %s\n" csv
    (u=u, rows=rows, spread0=spread0, spreadth=spreadth)
end

# The finite-T SHAPE result: prepare a finite-T state (bath on, HOLD), then a
# CLOSED-system shape ramp (bath off, loss on). HOLD vs DECOMPRESS vs BOX.
function ft_shape_compare(; grid_n::Int=48, box::Float64=24.0, T_over_Tc::Float64=0.5,
    prep_time::Float64=20.0, ramp_time::Float64=60.0, dt::Float64=0.01,
    gs_steps::Int=2500, omega_final::Float64=0.5, box_edge::Float64=16.0,
    gamma::Float64=0.1, n_traj::Int=8, backend=CPUBackend(),
    u::Union{Nothing, EuUnits}=nothing,   # optional 0-D-calibrated units (else default)
    csv_prefix::String=joinpath(@__DIR__, "eu_ft_shape"))
    u === nothing && (u = EuUnits(; omega_ref=2π * 420.0))
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
    @printf "μ=%.3f, T=%.2f (T/Tc=%.2f), k_cut=%.2f, k_max=%.2f\n" s.mu T T_over_Tc k_cut s.k_max
    Tot = prep_time + ramp_time
    gamma_of_t = t -> t < prep_time ? gamma : 0.0     # bath during prep, closed during ramp
    # Precompute the harmonic and box V-arrays once; the ADIABATIC box morphs between
    # them (V = (1−s)·V_harm + s·V_box, s: 0→1 over the ramp) so the condensate can
    # follow its instantaneous ground state — vs the SUDDEN box which switches at once.
    V_harm = evaluate_potential(HarmonicTrap{3}((1.0, 1.0, 1.0)), s.grid)
    V_box = evaluate_potential(BoxPotential((box_edge, box_edge, box_edge);
        wall_strength=2000.0, wall_width=0.4), s.grid)
    morph(t) = begin
        sfrac = clamp((t - prep_time) / ramp_time, 0.0, 1.0)
        @. (1 - sfrac) * V_harm + sfrac * V_box
    end
    schedules = (
        hold=harmonic_schedule(_ -> 1.0),
        decompress=harmonic_schedule(t -> t < prep_time ? 1.0 :
                                          max(omega_final, 1.0 - (1.0 - omega_final) * ((t - prep_time) / ramp_time))),
        box_sudden=(t -> t < prep_time ? HarmonicTrap{3}((1.0, 1.0, 1.0)) :
                  BoxPotential((box_edge, box_edge, box_edge); wall_strength=2000.0, wall_width=0.4)),
        box_adiabatic=(t -> t < prep_time ? V_harm : morph(t)),
    )
    out = Dict{Symbol, Any}()
    for (name, sched) in pairs(schedules)
        print("$name (prep $prep_time + ramp $ramp_time) ... ")
        t0 = time()
        res = run_ensemble(u, s.grid, s.psi0; potential_of_t=sched, gamma_of_t,
            T, k_cut, mu=s.mu, loss_on=true, n_traj, T_internal=Tot, dt, backend)
        @printf "%.1f s | N₀ %.4g→%.4g, N %.4g→%.4g\n" (time() - t0) res.N0[1] res.N0[end] res.N[1] res.N[end]
        out[name] = res
        open("$(csv_prefix)_$(name).csv", "w") do io
            println(io, "t_ms,N,N0")
            for i in 1:length(res.t_ms)
                @printf io "%.5f,%.6g,%.6g\n" res.t_ms[i] res.N[i] res.N0[i]
            end
        end
    end
    println("\n=== Finite-T shape verdict (final condensate N₀) ===")
    for name in (:hold, :decompress, :box_sudden, :box_adiabatic)
        @printf "  %-14s N₀=%.4g  (N=%.4g)\n" name out[name].N0[end] out[name].N[end]
    end
    (u=u, out=out)
end

# Task B end-to-end: 0-D evaporation calibration → SGPE shape study at the physical
# (ω_ref, N) the experiment forms the BEC in. T/T_c is set just below the 0-D formation
# value (=1.0 at onset); the shape optimisation lives in the post-formation regime.
function ft_shape_calibrated(; T_over_Tc::Float64=0.6, grid_n::Int=64, box::Float64=20.0,
    backend=CPUBackend(), csv_prefix::String=joinpath(@__DIR__, "eu_ft_shape_cal"))
    cal = ft_reservoir_calibration()
    println()
    ft_shape_compare(; u=cal.u, T_over_Tc, grid_n, box, gs_steps=3000, gamma=0.1,
        n_traj=8, backend, csv_prefix)
end

# HARMONIC-ONLY decompression optimization (no box — the experimentally available
# lever is lowering the ODT power). 2-D sweep over (ω_final, ramp duration τ) of the
# closed-system decompression from the 0-D-calibrated BEC-formation trap; reports the
# final condensate N₀ heatmap and the optimum — the ODT ramp recipe that keeps the
# most BEC. bias-corrected N₀ is M-independent, so a modest ensemble suffices.
function ft_decompress_optimize(; T_over_Tc::Float64=0.5, use_calibration::Bool=true,
    grid_n::Int=64, box::Float64=20.0, prep_time::Float64=12.0, hold_time::Float64=48.0,
    dt::Float64=0.01, gs_steps::Int=3000, gamma::Float64=0.1, n_traj::Int=6,
    omega_finals::Vector{Float64}=[0.35, 0.5, 0.65, 0.8],
    taus::Vector{Float64}=[0.0, 12.0, 30.0, 48.0],   # ramp duration (internal units)
    backend=CPUBackend(), csv::String=joinpath(@__DIR__, "eu_ft_decompress_opt.csv"))
    u = use_calibration ? ft_reservoir_calibration().u : EuUnits(; omega_ref=2π * 420.0)
    println()
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
    Tot = prep_time + hold_time
    to_ms(τ) = τ / u.omega_ref * 1e3
    @printf "μ=%.3f, T=%.2f (T/Tc=%.2f), k_cut=%.2f, k_max=%.2f, window=%.0f ms\n" s.mu T T_over_Tc k_cut s.k_max to_ms(Tot)
    gamma_of_t = t -> t < prep_time ? gamma : 0.0
    # HOLD baseline (no decompression) for reference.
    hold = run_ensemble(u, s.grid, s.psi0; potential_of_t=harmonic_schedule(_ -> 1.0),
        gamma_of_t, T, k_cut, mu=s.mu, loss_on=true, n_traj, T_internal=Tot, dt, backend)
    N0_hold = hold.N0[end]
    println("=== Harmonic decompression optimization (final condensate N₀) ===")
    @printf "  HOLD baseline N₀=%.5g\n" N0_hold
    @printf "  %-8s %-8s %-11s %-9s\n" "ω_final" "τ[ms]" "N₀" "gain/hold"
    rows = NTuple{4, Float64}[]
    for ωf in omega_finals, τ in taus
        ramp = t -> t < prep_time ? 1.0 :
                    (τ <= 0 ? ωf : max(ωf, 1.0 - (1.0 - ωf) * ((t - prep_time) / τ)))
        r = run_ensemble(u, s.grid, s.psi0; potential_of_t=harmonic_schedule(ramp),
            gamma_of_t, T, k_cut, mu=s.mu, loss_on=true, n_traj, T_internal=Tot, dt, backend)
        N0 = r.N0[end]
        push!(rows, (ωf, to_ms(τ), N0, N0 / N0_hold))
        @printf "  %-8.2f %-8.1f %-11.5g %-9.3f\n" ωf to_ms(τ) N0 (N0 / N0_hold)
    end
    open(csv, "w") do io
        println(io, "omega_final,tau_ms,N0,gain_over_hold,N0_hold")
        for r in rows
            @printf io "%.4f,%.4f,%.6g,%.6f,%.6g\n" r[1] r[2] r[3] r[4] N0_hold
        end
    end
    best = rows[argmax([r[3] for r in rows])]
    println()
    @printf "  OPTIMUM: ω_final=%.2f, τ=%.1f ms → N₀=%.5g (%.1f%% over HOLD)\n" best[1] best[2] best[3] 100 * (best[4] - 1)
    @printf "  CSV → %s\n" csv
    (u=u, rows=rows, N0_hold=N0_hold, best=best)
end

# ===========================================================================
# NUMBER-CONSERVING evaporation SGPE (issue #75, Approach A = Blakie PGPE
# evaporative cooling, PRA 72 063608). A hot thermal cloud is seeded by an SGPE
# prep at T_prep, then evolved with the μ-bath OFF (γ=0 ⇒ atom number set by
# PHYSICS, not a grand-canonical reservoir — avoids the pumping artifact of the
# fixed-μ formation run). Cooling is by EVAPORATION: in the harmonic trap V=½r²
# an atom of energy E has classical turning radius r_t=√(2E), so removing |r|>R(t)
# removes E>½R(t)² — a shrinking R(t) IS the lowering trap depth U(t)=½R(t)².
# K₃ depletes the dense condensate. Number is conserved up to the two physical
# loss channels, tracked separately (dN_evap, dN_K3) → a closed budget is the
# number-conservation check. Refs: Blakie PRA 72 063608; Rooney/Blakie/Bradley
# arXiv:1210.0952. (GPU note: rr is a host array — for a CUDA backend move it to
# the device before the knife broadcast.)
# ===========================================================================
function _evap_trajectory!(
    u, grid, psiN, T_prep, k_cut, mu, gamma, prep_time, evap_time,
    R_init, R_final, evap_rate, dt, save_every, backend, seed_base,
    psi_sum, dens_sum, n_tot_sum, dN_evap, dN_k3, save_times, D,
)
    T_internal = prep_time + evap_time
    n_steps = round(Int, T_internal / dt)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_bare(u)))   # norm-N
    loss = LossParams(; K3_cubic=k3_bare(u))                                # norm-N K₃
    sp = SimParams(; dt, n_steps, imaginary_time=false, normalize_every=0, save_every)
    ws = make_workspace(; grid, atom=FT_ATOM, interactions,
        potential=HarmonicTrap{3}((1.0, 1.0, 1.0)), sim_params=sp,
        psi_init=copy(psiN), loss, backend)
    dV = cell_volume(grid)
    sidx = Ref(0)
    N_prev = Ref(real(sum(abs2, ws.state.psi)) * dV)
    cb = SimulationCallbacks(
        on_step=(w, step, times, energies) -> begin
            t = w.state.t
            γ = t < prep_time ? gamma : 0.0
            if γ > 0
                # PREP: grand-canonical bath thermalises a hot cloud at (μ, T_prep).
                apply_sgpe_step!(w, γ, T_prep, dt; μ=mu, k_cut=k_cut,
                    full_hamiltonian=true, seed=seed_base + step)
                @views for c in 1:(D - 1)
                    w.state.psi[ntuple(_ -> Colon(), 3)..., c] .= 0
                end
                N_prev[] = real(sum(abs2, w.state.psi)) * dV        # baseline for the budget
            else
                # CLOSED EVAPORATION (γ=0). K₃ was already applied this step by the
                # split-step ⇒ account it, then apply the radial energy-knife.
                N_mid = real(sum(abs2, w.state.psi)) * dV
                dN_k3[] += max(N_prev[] - N_mid, 0.0)
                frac = clamp((t - prep_time) / max(evap_time, eps()), 0.0, 1.0)
                R = R_init + (R_final - R_init) * frac              # shrinking knife
                # V=½r² (harmonic, already on the backend) ⇒ |r|>R ⟺ V>½R². Using
                # w.potential_values keeps the knife device-resident (GPU-safe) with
                # no host rr array. The trap is never overwritten in this mode.
                ψc = view(w.state.psi, ntuple(_ -> Colon(), 3)..., D)
                Vh = w.potential_values
                cutV = 0.5 * R^2
                @. ψc *= ifelse(Vh > cutV, exp(-evap_rate * dt), one(eltype(ψc)))
                N_now = real(sum(abs2, w.state.psi)) * dV
                dN_evap[] += max(N_mid - N_now, 0.0)
                N_prev[] = N_now
            end
            if step % save_every == 0
                sidx[] += 1
                i = sidx[]
                i <= length(psi_sum) || return nothing
                ψc = Array(view(w.state.psi, ntuple(_ -> Colon(), 3)..., D))
                phase = angle(sum(ψc) * dV)
                @. psi_sum[i] += ψc * cis(-phase)
                @. dens_sum[i] += abs2(ψc)
                n_tot_sum[i] += real(sum(abs2, w.state.psi)) * dV
                save_times[i] = t
            end
            nothing
        end,
    )
    run_simulation!(ws; callbacks=cb)
    nothing
end

function run_evaporation_ensemble(
    u::EuUnits, grid, psi0;
    T_prep::Float64, k_cut::Float64, mu::Float64, gamma::Float64,
    prep_time::Float64, evap_time::Float64, R_init::Float64, R_final::Float64,
    evap_rate::Float64, dt::Float64, save_every::Int=20, n_traj::Int=8,
    backend=CPUBackend(), seed0::Int=1234,
)
    n_steps = round(Int, (prep_time + evap_time) / dt)
    n_save = fld(n_steps, save_every)
    D = SpinSystem(FT_ATOM.F).n_components
    gpts = grid.config.n_points
    psiN = copy(psi0) .* sqrt(u.N)
    psi_sum = [zeros(ComplexF64, gpts...) for _ in 1:n_save]
    dens_sum = [zeros(Float64, gpts...) for _ in 1:n_save]
    n_tot_sum = zeros(Float64, n_save)
    save_times = zeros(Float64, n_save)
    dN_evap = Ref(0.0);
    dN_k3 = Ref(0.0)
    for tr in 1:n_traj
        _evap_trajectory!(u, grid, psiN, T_prep, k_cut, mu, gamma, prep_time, evap_time,
            R_init, R_final, evap_rate, dt, save_every, backend, seed0 + tr * 1_000_003,
            psi_sum, dens_sum, n_tot_sum, dN_evap, dN_k3, save_times, D)
    end
    dV = cell_volume(grid)
    M = n_traj
    t_ms = save_times ./ u.omega_ref .* 1e3
    N_tot = n_tot_sum ./ M
    N0 = map(1:n_save) do i
        coh = abs2.(psi_sum[i] ./ M)
        meandens = dens_sum[i] ./ M
        nc = M > 1 ? coh .- (meandens .- coh) ./ (M - 1) : coh
        max(sum(nc) * dV, 0.0)
    end
    (t_ms=t_ms, N=N_tot, N0=N0, frac=N0 ./ max.(N_tot, eps()),
        dN_evap=dN_evap[] / M, dN_k3=dN_k3[] / M)
end

# Driver: closed-system evaporation → condensate, with a per-channel atom budget.
function ft_evaporation_sgpe(; grid_n::Int=48, box::Float64=20.0,
    T_prep_over_Tc::Float64=1.3, R_final_frac::Float64=0.55,
    prep_time::Float64=15.0, evap_time::Float64=40.0, evap_rate::Float64=5.0,
    dt::Float64=0.01, gs_steps::Int=2500, gamma::Float64=0.1, n_traj::Int=8,
    save_every::Int=20, backend=CPUBackend(), u::Union{EuUnits, Nothing}=nothing,
    N0_ref::Float64=0.0,                       # 0-D reference N₀ for the arbiter print
    csv::String=joinpath(@__DIR__, "eu_ft_evap_sgpe.csv"))
    u = u === nothing ? EuUnits(; omega_ref=2π * 420.0) : u
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T_prep = T_prep_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T_prep), 0.95 * s.k_max)
    R_init = 0.9 * box / 2
    R_final = R_final_frac * box / 2
    @printf "μ=%.3f  T_c=%.2f  T_prep=%.2f (%.1f T_c)  k_cut=%.2f  R: %.2f→%.2f\n" s.mu Tc T_prep T_prep_over_Tc k_cut R_init R_final
    println("=== Closed-system evaporation SGPE (γ=0; evaporate via radial energy-knife + K₃) ===")
    res = run_evaporation_ensemble(u, s.grid, s.psi0; T_prep, k_cut, mu=s.mu, gamma,
        prep_time, evap_time, R_init, R_final, evap_rate, dt, save_every, n_traj, backend)
    # closed phase starts at the first save with t≥prep_time
    i0 = findfirst(t -> t * 1e3 / u.omega_ref >= 0, res.t_ms)  # all saved; report full series
    @printf "  %-9s %-11s %-11s %-9s\n" "t[ms]" "N" "N₀" "N₀/N"
    for i in 1:length(res.t_ms)
        @printf "  %-9.2f %-11.5g %-11.5g %-9.3f\n" res.t_ms[i] res.N[i] res.N0[i] res.frac[i]
    end
    # Budget baseline = N at the START OF THE CLOSED PHASE (t≥prep_time), not the
    # first save (which is during prep, where the grand-canonical bath still sets N).
    # dN_evap/dN_k3 accumulate only in the closed phase, so by telescoping
    # N_end + dN_evap + dN_k3 = N(closed-start) exactly — that is the conservation check.
    prep_ms = prep_time / u.omega_ref * 1e3
    ic = something(findlast(<(prep_ms), res.t_ms), 1)   # last PREP save = atoms entering the closed phase
    N_start = res.N[ic]
    N_end = res.N[end]
    budget = N_end + res.dN_evap + res.dN_k3
    @printf "\n  ATOM BUDGET (closed phase): N_end=%.5g + evap=%.5g + K₃=%.5g = %.5g  vs  N(closed-start)=%.5g  (Δ=%.2g%%)\n" N_end res.dN_evap res.dN_k3 budget N_start 100 * (budget - N_start) / max(N_start, eps())
    @printf "  N₀ (closed phase): %.5g → %.5g   (cond. frac %.3f → %.3f)\n" res.N0[ic] res.N0[end] res.frac[ic] res.frac[end]
    if N0_ref > 0
        @printf "  ARBITER: SGPE final N₀=%.4g  vs  0-D reference N₀=%.4g  (ratio %.2f×)\n" res.N0[end] N0_ref res.N0[end] / N0_ref
    end
    open(csv, "w") do io
        println(io, "t_ms,N,N0,frac")
        for i in 1:length(res.t_ms)
            @printf io "%.4f,%.6g,%.6g,%.6f\n" res.t_ms[i] res.N[i] res.N0[i] res.frac[i]
        end
    end
    @printf "  CSV → %s\n" csv
    (u=u, res=res)
end

# Quick local logic smoke (small, fast — NOT physical resolution).
function ft_evap_smoke(; backend=CPUBackend())
    ft_evaporation_sgpe(; grid_n=24, box=16.0, T_prep_over_Tc=1.2, prep_time=4.0,
        evap_time=8.0, gs_steps=400, n_traj=2, save_every=40, backend)
end

# CALIBRATED ARBITER: seed the closed evaporation SGPE at the 0-D formation handoff
# (ω̄, N_BEC, T/T_c from ft_reservoir_calibration) and compare the ab-initio absolute
# N₀ to the 0-D formation number — the number-conserving check on the 0-D ~2× systematic.
function ft_evap_sgpe_cal(; grid_n::Int=48, box::Float64=20.0, n_traj::Int=8,
    prep_time::Float64=15.0, evap_time::Float64=40.0, gs_steps::Int=2500,
    T_prep_over_Tc::Float64=1.15, backend=CPUBackend())
    cal = ft_reservoir_calibration()
    ft_evaporation_sgpe(; grid_n, box, n_traj, prep_time, evap_time, gs_steps,
        T_prep_over_Tc, u=cal.u, N0_ref=cal.N_BEC, backend,
        csv=joinpath(@__DIR__, "eu_ft_evap_sgpe_cal.csv"))
end

function ft_evap_cal_smoke(; backend=CPUBackend())
    ft_evap_sgpe_cal(; grid_n=24, box=16.0, prep_time=4.0, evap_time=8.0,
        gs_steps=400, n_traj=2, backend)
end

function ft_smoke(; backend=CPUBackend())
    ft_equilibrium(; grid_n=32, box=16.0, T_over_Tc_list=[0.1, 0.6],
        T_equil=6.0, gs_steps=800, n_traj=2, backend)
end

# TSUBAME timing probe: one small real-resolution run to measure H100 per-step cost
# before committing the multi-hour campaign (smoke discipline).
function probe(; backend=CPUBackend())
    ft_equilibrium(; grid_n=48, box=18.0, T_over_Tc_list=[0.2, 0.6],
        T_equil=15.0, gs_steps=2000, gamma=0.1, n_traj=4, backend)
end

# Production campaign for TSUBAME H100. Sized for ≲5 h on one H100 at 48³, D=13
# (probe: ~25 ms/step ⇒ ~63 s per 2500-step trajectory).
function campaign(; backend=CPUBackend())
    println("######## V-T0 / V-mono: equilibrium condensate N₀ + thermal ########")
    ft_equilibrium(; grid_n=48, box=18.0,
        T_over_Tc_list=[0.15, 0.3, 0.45, 0.6, 0.75, 0.9],
        T_equil=25.0, gs_steps=3000, gamma=0.1, n_traj=10, backend)
    println("\n######## V-kcut: condensate cutoff-independence ########")
    ft_kcut_convergence(; grid_n=48, box=18.0, T_over_Tc=0.5,
        T_equil=25.0, gs_steps=3000, gamma=0.1, n_traj=10, backend)
    println("\n######## Finite-T shape trade-off ########")
    ft_shape_compare(; grid_n=48, box=24.0, T_over_Tc=0.5, prep_time=20.0, ramp_time=60.0,
        gs_steps=3000, gamma=0.1, n_traj=10, backend)
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = isempty(ARGS) ? "smoke" : ARGS[1]
    want_gpu = get(ENV, "SBEC_FT_BACKEND", "cpu") == "gpu"
    want_gpu && @eval import CUDA          # loads SpinorBECCUDAExt; enables CUDABackend
    bk = want_gpu ? CUDABackend() : CPUBackend()
    if mode == "campaign"
        campaign(; backend=bk)
    elseif mode == "probe"
        probe(; backend=bk)
    elseif mode == "equilibrium"
        ft_equilibrium(; backend=bk)
    elseif mode == "analytic"
        ft_equilibrium_analytic()
    elseif mode == "reservoir"
        ft_reservoir_calibration()
    elseif mode == "shape_cal"
        ft_shape_calibrated(; backend=bk)
    elseif mode == "decompress_opt"
        ft_decompress_optimize(; backend=bk)
    elseif mode == "decompress_refine"
        ft_decompress_optimize(; backend=bk, n_traj=12,
            omega_finals=[0.45, 0.5, 0.55, 0.6, 0.65, 0.7, 0.75], taus=[0.0],
            csv=joinpath(@__DIR__, "eu_ft_decompress_refine.csv"))
    elseif mode == "evap_ramp"
        ft_evap_ramp_optimize()
    elseif mode == "evap_sgpe"
        ft_evaporation_sgpe(; backend=bk)
    elseif mode == "evap_sgpe_smoke"
        ft_evap_smoke(; backend=bk)
    elseif mode == "evap_sgpe_cal"
        ft_evap_sgpe_cal(; backend=bk)
    elseif mode == "evap_sgpe_cal_smoke"
        ft_evap_cal_smoke(; backend=bk)
    elseif mode == "kcut"
        ft_kcut_convergence(; backend=bk)
    elseif mode == "shape"
        ft_shape_compare(; backend=bk)
    else
        ft_smoke(; backend=bk)
    end
end
