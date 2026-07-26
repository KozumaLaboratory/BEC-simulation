#!/usr/bin/env julia
# docs/guides/figures/eu_shape_optimization.jl
#
# Dynamic trap-SHAPE optimization for ¹⁵¹Eu BEC formation (extends the P(t)
# ramp study, issue #75, to the trap geometry V(r,t)).
#
# Physics: docs/theory/eu_evaporation_three_body_theory.md. Condensate 3-body
# loss dN₀/dt = -γ N₀^{9/5} has an attractor N₀ ∝ ω̄⁻³, so a LOOSER trap at BEC
# formation keeps more condensate. This driver runs a scalar-equivalent GP
# (all atoms in the stretched |m=-6⟩ component, c₁=0 so no spin mixing) with
# physical K₃ three-body loss and compares a HOLD vs a DECOMPRESSION ramp.
#
# CONVENTION (the bug that bit the first smoke): `find_ground_state`
# normalizes ∫|ψ|²=1 (norm-1), with the interaction coupling carrying N
# (c₀ = 4π a_s/a_ho · N). The loss kernel `exp(-K3_cubic·|ψ|²·|ψ|²·dt/2)`
# reads |ψ|² directly as the density. To make it the PHYSICAL density
# n = N|ψ|², we absorb the N² into the coefficient:
#
#     K3_cubic = K̃₃ · N²,   K̃₃ = K₃_SI / (a_ho⁶ · ω_ref)     (a_ho⁶ power
#                                                              derived below)
#
# and the surviving atom number is N · ∫|ψ|²(t)  (starts at N, decays via loss).
#
# TimeDependentTrap is NOT re-evaluated by the standard runner (t_eval drives
# only interactions/Zeeman). The trap shape is therefore driven by an on_step
# callback overwriting `ws.potential_values` each step.
#
# Run (CPU smoke):  julia --project=. docs/guides/figures/eu_shape_optimization.jl --smoke
# Run (GPU):        LD_LIBRARY_PATH=/usr/lib/wsl/lib julia --project=. \
#                     -e 'import CUDA; include("docs/guides/figures/eu_shape_optimization.jl")'

using SpinorBEC
using SpinorBEC: Units, cell_volume, evaluate_potential, split_step!
using Printf

# ---------------------------------------------------------------------------
# Units — Eu-scaled internal units (ℏ = m = ω_ref = 1)
# ---------------------------------------------------------------------------
Base.@kwdef struct EuUnits
    omega_ref::Float64                 # tight FORMATION trap ω [rad/s] → ω=1 internal
    mass::Float64  = Units.AMU * 151.0 # ¹⁵¹Eu
    a_s::Float64   = 135.0 * Units.BOHR_RADIUS  # Miyazawa 2021 thesis (registry 110 a₀ = Matsui)
    K3_si::Float64 = 1.0e-41           # m⁶/s, atoms-lost convention (issue #75)
    N::Float64     = 1.0e4             # condensate atoms
end

a_ho(u::EuUnits) = sqrt(Units.HBAR / (u.mass * u.omega_ref))
# scalar contact, norm-1 convention (nonlinearity = g̃·N)
c0_coupling(u::EuUnits) = 4π * (u.a_s / a_ho(u)) * u.N
# three-body: dñ/dt̃ = -K̃₃ ñ³ with K̃₃ = K₃/(a_ho⁶ ω_ref); norm-1 → ×N²
k3_tilde(u::EuUnits) = u.K3_si / (a_ho(u)^6 * u.omega_ref)
k3_cubic_norm1(u::EuUnits) = k3_tilde(u) * u.N^2

function print_units(u::EuUnits)
    println("=== Eu units (ℏ=m=ω_ref=1) ===")
    @printf "  ω_ref       = %.4g rad/s  (= %.1f Hz, tight formation trap)\n" u.omega_ref u.omega_ref / 2π
    @printf "  a_ho        = %.4g m  (= %.3f µm)\n" a_ho(u) a_ho(u) * 1e6
    @printf "  a_s         = %.1f a₀\n" u.a_s / Units.BOHR_RADIUS
    @printf "  N           = %.3g atoms\n" u.N
    @printf "  g̃ = 4πa_s/a_ho = %.4g   → c₀ = g̃·N = %.4g\n" 4π * u.a_s / a_ho(u) c0_coupling(u)
    @printf "  K̃₃          = %.4g   → K3_cubic = K̃₃·N² = %.4g\n" k3_tilde(u) k3_cubic_norm1(u)
    println()
end

# ---------------------------------------------------------------------------
# Ground state in a tight (ω=1) trap — norm-1, single m=-6 component, c₀ only
# ---------------------------------------------------------------------------
function ground_state(u::EuUnits, grid; n_steps::Int, backend=CPUBackend(), verbose=false)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_coupling(u)))
    pot = HarmonicTrap{3}((1.0, 1.0, 1.0))
    res = find_ground_state(;
        grid, atom=Eu151, interactions, potential=pot,
        dt=0.002, n_steps, tol=1e-9,
        initial_state=:m_minus_F, backend, verbose)
    res.workspace.state.psi
end

# ---------------------------------------------------------------------------
# Real-time dynamics under a trap-shape schedule ω(t), with physical K₃ loss.
# `omega_of_t(t)` returns the (isotropic) trap frequency at internal time t.
# Returns (t_ms, surviving_N) time series.
# ---------------------------------------------------------------------------
function run_shape(
    u::EuUnits, grid, psi0;
    omega_of_t, T_internal::Float64, dt::Float64,
    save_every::Int=10, backend=CPUBackend(),
)
    n_steps = Int(round(T_internal / dt))
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_coupling(u)))
    loss = LossParams(; K3_cubic=k3_cubic_norm1(u))
    sp = SimParams(; dt, n_steps, imaginary_time=false, normalize_every=0, save_every)
    # static base trap; the on_step callback drives the shape
    pot = HarmonicTrap{3}((1.0, 1.0, 1.0))
    ws = make_workspace(;
        grid, atom=Eu151, interactions, potential=pot, sim_params=sp,
        psi_init=psi0, loss, backend)

    dV = cell_volume(grid)
    N0 = u.N * sum(abs2, ws.state.psi) * dV      # = u.N (∫|ψ|²=1)
    ts_ms = Float64[0.0]
    Ns = Float64[N0]
    Vbuf = similar(ws.potential_values)

    cb = SimulationCallbacks(
        on_step=(w, step, times, energies) -> begin
            # drive next step's trap shape from the (already advanced) time
            ω = omega_of_t(w.state.t)
            copyto!(Vbuf, evaluate_potential(HarmonicTrap{3}((ω, ω, ω)), grid))
            copyto!(w.potential_values, Vbuf)
            if step % save_every == 0
                frac = real(sum(abs2, w.state.psi)) * dV
                push!(ts_ms, w.state.t / u.omega_ref * 1e3)
                push!(Ns, u.N * frac)
            end
            nothing
        end,
    )
    run_simulation!(ws; callbacks=cb)
    (t_ms=ts_ms, N=Ns)
end

# ---------------------------------------------------------------------------
# Smoke: HOLD (ω=1) vs DECOMPRESS (ω: 1 → ω_final) — surviving N must DIFFER,
# with decompression retaining MORE (looser ⇒ lower density ⇒ less 3-body).
# This proves both the K3_cubic=K̃₃N² fix and the physics direction.
# ---------------------------------------------------------------------------
function smoke(; grid_n::Int=16, box::Float64=12.0, T_internal::Float64=8.0,
    dt::Float64=0.01, gs_steps::Int=1500, omega_final::Float64=0.5,
    backend=CPUBackend())
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))

    print("Ground state (ω=1, tight) ... ")
    t0 = time()
    psi0 = ground_state(u, grid; n_steps=gs_steps, backend)
    dV = cell_volume(grid)
    npeak = maximum(abs2, psi0) * u.N / (a_ho(u)^3)   # physical peak density [m⁻³]
    @printf "%.1f s | ∫|ψ|²=%.4f, peak n=%.3g m⁻³\n" (time() - t0) sum(abs2, psi0)*dV npeak

    print("HOLD (ω=1) dynamics ... ")
    t0 = time()
    hold = run_shape(u, grid, copy(psi0); omega_of_t=_ -> 1.0, T_internal, dt, backend)
    @printf "%.1f s | N: %.4g → %.4g\n" (time() - t0) hold.N[1] hold.N[end]

    print("DECOMPRESS (ω: 1→$omega_final) dynamics ... ")
    t0 = time()
    ramp = t -> max(omega_final, 1.0 - (1.0 - omega_final) * (t / T_internal))
    dec = run_shape(u, grid, copy(psi0); omega_of_t=ramp, T_internal, dt, backend)
    @printf "%.1f s | N: %.4g → %.4g\n" (time() - t0) dec.N[1] dec.N[end]

    println()
    println("=== Smoke verdict ===")
    @printf "  surviving N   hold=%.4g  decompress=%.4g\n" hold.N[end] dec.N[end]
    @printf "  loss frac     hold=%.3f%%  decompress=%.3f%%\n" 100*(1-hold.N[end]/hold.N[1]) 100*(1-dec.N[end]/dec.N[1])
    if hold.N[end] < 0.999 * hold.N[1] && dec.N[end] > hold.N[end]
        println("  PASS: loss is active (bug fixed) AND decompression retains more (physics ✓).")
    elseif hold.N[end] >= 0.999 * hold.N[1]
        println("  FAIL: no loss under HOLD — density/N convention still wrong (the original bug).")
    else
        println("  CHECK: loss active but decompression did not help — inspect ramp / timescales.")
    end
    (u=u, hold=hold, dec=dec)
end

# ---------------------------------------------------------------------------
# Validation gate (task #10) — the physics units check.
# For a Thomas-Fermi condensate at FIXED N, looser trap ⇒ lower density:
#   peak density n₀ ∝ ω̄^{6/5}   (slope 1.2 on log-log)
#   ⟨n²⟩ = ∫n³/∫n ∝ ω̄^{12/5}    (slope 2.4) — the 3-body loss-rate scaling.
# In norm-1 units ⟨(|ψ|²)²⟩ = ∫|ψ|⁶ dṼ (since ∫|ψ|²=1). No dynamics needed:
# the loss RATE is K̃₃N²·∫|ψ|⁶ and its ω̄-scaling is what must match theory.
# If the exponents miss 1.2 / 2.4, the units are wrong.
# ---------------------------------------------------------------------------
function validation_gate(;
    grid_n::Int=40, box::Float64=14.0,
    omegas::Vector{Float64}=[1.0, 1.3, 1.6, 2.0, 2.4, 3.0],
    gs_steps::Int=4000, backend=CPUBackend(),
    csv::String=joinpath(@__DIR__, "eu_shape_validation.csv"),
)
    u = EuUnits(; omega_ref=2π * 420.0)
    print_units(u)
    grid = make_grid(GridConfig((grid_n, grid_n, grid_n), (box, box, box)))
    dV = cell_volume(grid)
    interactions = InteractionParams(Dict{Int, Float64}(0 => c0_coupling(u)))
    ah = a_ho(u)
    dx = box / grid_n
    half = box / 2

    rows = NTuple{6, Float64}[]  # (ω̄, peak|ψ|², ∫|ψ|⁶, n₀_phys, ⟨n²⟩_phys, edge_frac)
    println("=== Validation gate: TF moments vs trap ω̄ (grid $(grid_n)³, box $box) ===")
    @printf "  %-6s %-11s %-11s %-11s %-11s %-9s\n" "ω̄" "peak|ψ|²" "∫|ψ|⁶" "n₀[m⁻³]" "⟨n²⟩[m⁻⁶]" "edge"
    for ω in omegas
        pot = HarmonicTrap{3}((ω, ω, ω))
        res = find_ground_state(;
            grid, atom=Eu151, interactions, potential=pot,
            dt=0.002, n_steps=gs_steps, tol=1e-9,
            initial_state=:m_minus_F, backend, verbose=false)
        psi = Array(res.workspace.state.psi)
        rho = dropdims(sum(abs2, psi; dims=4); dims=4)   # |ψ|² summed over m (only m=-6 populated)
        peak = maximum(rho)
        int6 = sum(x -> x^3, rho) * dV                    # ∫|ψ|⁶ = ∫ρ³ (ρ=|ψ|²)
        n0_phys = u.N * peak / ah^3
        n2_phys = (u.N / ah^3)^2 * int6                   # ⟨n²⟩ = (N/a_ho³)² ∫ρ³ (norm-1, ∫ρ=1)
        # edge fraction: norm within the outer 15% shell of the box (spill check)
        edge = 0.0
        @inbounds for I in CartesianIndices(rho)
            r = sqrt(sum(d -> (grid.x[d][I[d]])^2, 1:3))
            r > 0.85 * half && (edge += rho[I])
        end
        edge *= dV
        push!(rows, (ω, peak, int6, n0_phys, n2_phys, edge))
        @printf "  %-6.2f %-11.4g %-11.4g %-11.3g %-11.3g %-9.1e\n" ω peak int6 n0_phys n2_phys edge
    end

    # Fit log-log slopes over well-contained points (edge < 1e-3).
    good = [r for r in rows if r[6] < 1e-3]
    length(good) >= 3 || @warn "fewer than 3 well-contained points (edge<1e-3); slope unreliable"
    logω = [log(r[1]) for r in good]
    slope(y) = let x = logω, ly = log.(y)
        n = length(x); sx = sum(x); sy = sum(ly)
        (n * sum(x .* ly) - sx * sy) / (n * sum(abs2, x) - sx^2)
    end
    s_n0 = slope([r[4] for r in good])
    s_n2 = slope([r[5] for r in good])

    open(csv, "w") do io
        println(io, "omega,peak_psi2,int_psi6,n0_phys_m3,n2_phys_m6,edge_frac")
        for r in rows
            @printf io "%.4f,%.6g,%.6g,%.6g,%.6g,%.6g\n" r...
        end
    end

    println()
    println("=== Slopes (log-log, well-contained points) ===")
    @printf "  n₀  ∝ ω̄^%.3f   (theory 6/5 = 1.200)\n" s_n0
    @printf "  ⟨n²⟩∝ ω̄^%.3f   (theory 12/5 = 2.400)\n" s_n2
    ok = abs(s_n0 - 1.2) < 0.15 && abs(s_n2 - 2.4) < 0.25
    println(ok ? "  PASS: TF moment scaling matches theory ⇒ units correct." :
                 "  FAIL: scaling off ⇒ recheck units / grid resolution / box spill.")
    @printf "  CSV → %s\n" csv
    (u=u, rows=rows, s_n0=s_n0, s_n2=s_n2, pass=ok)
end

if abspath(PROGRAM_FILE) == @__FILE__
    mode = isempty(ARGS) ? "smoke" : ARGS[1]
    if mode == "validate"
        validation_gate()
    else
        smoke()
    end
end
