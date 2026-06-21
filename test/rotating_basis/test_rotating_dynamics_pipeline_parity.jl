# Pipeline-contract parity: the rotating-basis dynamics step records a
# `:rotating_basis_dynamics` dict of TIME-SERIES arrays (per_m_history [tilde],
# Lz, Fz) that every downstream consumer (thesis-Fig6 analyzers,
# save_rotating_result, bayesian_opt) reads. This test proves the STANDARD path
# reproduces those exact recorded arrays — the gate that lets the rotating
# dynamics handler be reimplemented on the standard path (then the engine
# retired) without changing any consumer.
#
# Standard side mirrors the migrated handler: run split_step! under a lab-frame
# TimeDependentZeeman(bx,by,bz from θ(t),φ(t)); at each save step record
#   per_m   = component norms of ψ̃(t) = U_B(t)† ψ_lab(t)   (tilde basis)
#   Lz      = orbital_angular_momentum(ψ_lab)   (spin-rotation invariant ⇒ lab)
#   Fz      = Σ_m m · per_m
# Rotating side is the handler's own recording (rotating_per_m_norms / rotating_Lz).

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, InteractionParams, HarmonicTrap,
    make_workspace, SimParams, TimeDependentZeeman, ConstantWaveform,
    FunctionWaveform, split_step!, make_rotating_basis_ws, evolve_rotating!,
    rotating_per_m_norms, rotating_Lz, orbital_angular_momentum, spin_matrices

@testset "rotating dynamics recorded-array parity (standard reproduces the dict)" begin
    F = 1
    D = 2F + 1
    n = 16
    L = 10.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    sm = spin_matrices(F)
    dV = prod(grid.dx)

    p = 4.0
    Ω = 0.6
    θ = π / 2
    c0, c1 = 10.0, 0.8
    dt = 0.005
    n_steps = 200
    save_every = 20

    θf(t) = θ
    φf(t) = Ω * t

    # Shared physical lab initial state (vortex-free Gaussian, asymmetric spin).
    σ = 1.0
    psi_lab0 = zeros(ComplexF64, n, n, n, D)
    @inbounds for I in CartesianIndices((n, n, n))
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        g = exp(-(x * x + y * y + z * z) / (2σ * σ))
        psi_lab0[I, 1] = g
        psi_lab0[I, 2] = 0.6 * g
        psi_lab0[I, 3] = 0.3 * g
    end
    psi_lab0 ./= sqrt(sum(abs2, psi_lab0) * dV)

    per_m_of(ψ) = [sum(abs2, @view ψ[:, :, :, c]) * dV for c in 1:D]
    fz_of(pm) = sum((F - (c - 1)) * pm[c] for c in 1:D)

    # ---- rotating path (the handler's recording) ----
    V = zeros(Float64, n, n, n)
    @inbounds for I in CartesianIndices(V)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V[I] = 0.5 * (x * x + y * y + z * z)
    end
    wsr = make_rotating_basis_ws(
        grid, F, V; p=p, q=0.0, c0=c0, c1=c1,
        theta_func=θf, phi_func=φf, theta_dot_func=t -> 0.0, phi_dot_func=t -> Ω,
        gauge_fix=false,
    )
    copyto!(wsr.psi_tilde, psi_lab0)
    SpinorBEC._apply_UB!(wsr.psi_tilde, sm, θ, 0.0, 3; inverse=true, scratch=wsr.rotation_scratch)
    rot_perm, rot_Lz, rot_Fz, rot_t = Vector{Float64}[], Float64[], Float64[], Float64[]
    evolve_rotating!(wsr, n_steps, dt; t0=0.0, on_step=(step, t, w) -> begin
        if step == 1 || step % save_every == 0
            pm = rotating_per_m_norms(w)
            push!(rot_perm, pm)
            push!(rot_Lz, rotating_Lz(w))
            push!(rot_Fz, fz_of(pm))
            push!(rot_t, t)
        end
    end)

    # ---- standard path (mirrors the migrated handler) ----
    zee = TimeDependentZeeman(
        ConstantWaveform(p * cos(θ)), ConstantWaveform(0.0),
        FunctionWaveform(t -> p * sin(θ) * cos(Ω * t)),
        FunctionWaveform(t -> p * sin(θ) * sin(Ω * t)),
    )
    wsl = make_workspace(;
        grid, atom=SpinorBEC.Na23,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=zee, potential=HarmonicTrap{3}((1.0, 1.0, 1.0)),
        sim_params=SimParams(dt=dt, n_steps=n_steps, save_every=save_every),
        psi_init=copy(psi_lab0),
    )
    std_perm, std_Lz, std_Fz = Vector{Float64}[], Float64[], Float64[]
    scratch = similar(wsl.state.psi)
    for step in 1:n_steps
        split_step!(wsl)
        if step == 1 || step % save_every == 0
            t = step * dt
            copyto!(scratch, wsl.state.psi)
            SpinorBEC._apply_UB!(scratch, sm, θ, Ω * t, 3; inverse=true)
            pm = per_m_of(scratch)
            push!(std_perm, pm)
            push!(std_Lz, orbital_angular_momentum(wsl.state.psi, grid, wsl.fft_plans))
            push!(std_Fz, fz_of(pm))
        end
    end

    @test length(std_perm) == length(rot_perm)

    # Non-triviality: the dynamics actually moved per-m over the run.
    @test maximum(abs.(rot_perm[end] .- rot_perm[1])) > 1e-3

    # Recorded-array time-series agree (the consumer-facing contract).
    perm_dev = maximum(maximum(abs.(std_perm[k] .- rot_perm[k])) for k in eachindex(rot_perm))
    fz_dev = maximum(abs.(std_Fz .- rot_Fz))
    lz_dev = maximum(abs.(std_Lz .- rot_Lz))
    @test perm_dev < 1e-3
    @test fz_dev < 1e-3
    @test lz_dev < 1e-6   # Lz ≈ 0 (no vortex) in both; spin-rotation invariant
end
