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
    u, grid, psi0, potential_of_t, gamma_of_t, T, k_cut, μ_of_t,
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
            copyto!(w.potential_values, evaluate_potential(potential_of_t(w.state.t), grid))
            γ = gamma_of_t(w.state.t)
            if γ > 0
                apply_sgpe_step!(w, γ, T, dt; μ=μ_of_t(w.state.t), k_cut=k_cut,
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
    potential_of_t, gamma_of_t, T::Float64, k_cut::Float64,
    mu::Float64, μ_of_t=(_ -> mu), loss_on::Bool=true,
    n_traj::Int=8, T_internal::Float64, dt::Float64,
    save_every::Int=20, backend=CPUBackend(), seed0::Int=1234,
)
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
        _sgpe_trajectory!(u, grid, psiN, potential_of_t, gamma_of_t, T, k_cut, μ_of_t,
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
    csv_prefix::String=joinpath(@__DIR__, "eu_ft_shape"))
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    s = _setup(u, grid_n, box, gs_steps, backend)
    Tc = Tc_harmonic(u.N)
    T = T_over_Tc * Tc
    k_cut = min(kcut_for(s.mu, T), 0.95 * s.k_max)
    @printf "μ=%.3f, T=%.2f (T/Tc=%.2f), k_cut=%.2f, k_max=%.2f\n" s.mu T T_over_Tc k_cut s.k_max
    Tot = prep_time + ramp_time
    gamma_of_t = t -> t < prep_time ? gamma : 0.0     # bath during prep, closed during ramp
    schedules = (
        hold=harmonic_schedule(_ -> 1.0),
        decompress=harmonic_schedule(t -> t < prep_time ? 1.0 :
                                          max(omega_final, 1.0 - (1.0 - omega_final) * ((t - prep_time) / ramp_time))),
        box=(t -> t < prep_time ? HarmonicTrap{3}((1.0, 1.0, 1.0)) :
                  BoxPotential((box_edge, box_edge, box_edge); wall_strength=2000.0, wall_width=0.4)),
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
    for name in (:hold, :decompress, :box)
        @printf "  %-11s N₀=%.4g  (N=%.4g)\n" name out[name].N0[end] out[name].N[end]
    end
    (u=u, out=out)
end

# Quick local logic smoke (small, fast — NOT physical resolution).
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
    elseif mode == "kcut"
        ft_kcut_convergence(; backend=bk)
    elseif mode == "shape"
        ft_shape_compare(; backend=bk)
    else
        ft_smoke(; backend=bk)
    end
end
