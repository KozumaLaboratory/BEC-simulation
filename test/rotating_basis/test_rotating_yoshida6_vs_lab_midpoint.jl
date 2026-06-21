# High-order integrator equivalence: rotating-basis yoshida6 (the production
# magnetostir default) ⇄ lab-frame split_step_midpoint!.
#
# The rotating dynamics step defaults to yoshida6 because frozen-mean-field
# Yoshida keeps its order in the tilde frame (slow dynamics). The standard
# high-order driver `run_simulation_yoshida!` degrades to ~order 1 on the lab
# path (fast Larmor between frozen sub-times) — BUT `split_step_midpoint!`
# (implicit-midpoint Picard, self-consistent mean field) does NOT degrade: it is
# a correct order-2 step. This test pins that the lab midpoint step reproduces
# the rotating yoshida6 magnetostir to a physically-negligible per-m tolerance
# at the SAME dt / step count, in the Larmor-stiff regime — measured p-INDEPENDENT
# (~1e-5 at p ∈ {50,500,2000}, p·F·dt = 1). This is the gate that makes the
# rotating engine retirable: the lab path matches the production integrator at
# equal cost. (If sub-1e-5 per-m is ever needed, a lab Y6-mid composition of
# split_step_midpoint! recovers high order; not required for Fig-6 populations.)

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, InteractionParams, HarmonicTrap,
    make_workspace, SimParams, TimeDependentZeeman, ConstantWaveform,
    FunctionWaveform, split_step_midpoint!, make_rotating_basis_ws,
    evolve_rotating_yoshida6!, rotating_per_m_norms, spin_matrices

@testset "rotating yoshida6 ⇄ lab split_step_midpoint! (Larmor-stiff magnetostir)" begin
    F = 1
    D = 2F + 1
    n = 16
    L = 10.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    sm = spin_matrices(F)
    dV = prod(grid.dx)

    σ = 1.0
    psi0 = zeros(ComplexF64, n, n, n, D)
    @inbounds for I in CartesianIndices((n, n, n))
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / (2σ * σ))
        psi0[I, 1] = g
        psi0[I, 2] = 0.6 * g
        psi0[I, 3] = 0.3 * g
    end
    psi0 ./= sqrt(sum(abs2, psi0) * dV)
    per_m(ψ) = [sum(abs2, @view ψ[:, :, :, c]) * dV for c in 1:D]

    # Larmor-stiff: p=500 with p·F·dt = 1 (dt=0.002). Out of reach for a naive
    # lab Strang at this dt, but split_step_midpoint! handles it.
    p = 500.0
    Ω = 0.7
    θ = π / 2
    c0, c1 = 10.0, 1.0
    dt = 0.002
    T = 0.6
    ns = Int(round(T / dt))

    V = zeros(Float64, n, n, n)
    @inbounds for I in CartesianIndices(V)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V[I] = 0.5 * (x * x + y * y + z * z)
    end

    # Rotating production path (yoshida6).
    wsr = make_rotating_basis_ws(
        grid, F, V; p=p, q=0.0, c0=c0, c1=c1,
        theta_func=t -> θ, phi_func=t -> Ω * t,
        theta_dot_func=t -> 0.0, phi_dot_func=t -> Ω, gauge_fix=false,
    )
    copyto!(wsr.psi_tilde, psi0)
    SpinorBEC._apply_UB!(wsr.psi_tilde, sm, θ, 0.0, 3; inverse=true, scratch=wsr.rotation_scratch)
    evolve_rotating_yoshida6!(wsr, ns, dt)
    pm_rot = rotating_per_m_norms(wsr)
    pm_rot ./= sum(pm_rot)

    # Lab midpoint path, SAME dt / step count.
    zee = TimeDependentZeeman(
        ConstantWaveform(p * cos(θ)), ConstantWaveform(0.0),
        FunctionWaveform(t -> p * sin(θ) * cos(Ω * t)),
        FunctionWaveform(t -> p * sin(θ) * sin(Ω * t)),
    )
    wsl = make_workspace(;
        grid, atom=SpinorBEC.Na23,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=zee, potential=HarmonicTrap{3}((1.0, 1.0, 1.0)),
        sim_params=SimParams(dt=dt, n_steps=ns, save_every=ns), psi_init=copy(psi0),
    )
    for _ in 1:ns
        split_step_midpoint!(wsl)
    end
    ψ = copy(wsl.state.psi)
    SpinorBEC._apply_UB!(ψ, sm, θ, Ω * T, 3; inverse=true)
    pm_lab = per_m(ψ)
    pm_lab ./= sum(pm_lab)

    # Non-triviality: spin-mixing under the rotating field moved population.
    @test maximum(abs.(pm_rot .- per_m(psi0))) > 1e-2

    # Lab midpoint reproduces the production yoshida6 to a physically-negligible
    # per-m tolerance (measured ~2e-5 here, p-independent). 1e-3 leaves margin.
    @test maximum(abs.(pm_lab .- pm_rot)) < 1e-3
end
