# Rotating-basis ⇄ standard-path DYNAMICS equivalence (Option γ).
#
# The rotating-basis path exists to evolve a time-dependent field direction B̂(t)
# (magnetostir). This test proves the STANDARD split-step path reproduces the
# SAME dynamics when driven by the equivalent lab-frame TimeDependentZeeman
# (bx,by,bz from θ(t),φ(t)) — the eigen-exact Zeeman step makes the two frames
# numerically equivalent. It is the safety net for retiring the rotating
# subsystem: as long as this holds, a magnetostir run can be routed through the
# standard path instead of RotatingBasisWS.
#
# Comparison is on basis-invariant observables (the two paths represent the same
# physical state in different spin frames): total density n(r), |⟨F⟩| magnitude,
# norm, and the lab-frame per-m populations (rotating ψ̃ → ψ_lab via U_B(T)).
#
# Measured: per-m Δ ≲ 1e-4, density overlap 1 − O(1e-7), |⟨F⟩| Δ ≲ 1e-5 for the
# config below (and ≲ 3e-4 at p up to 200 / with DDI — same dt for both paths,
# no rotating-frame efficiency advantage). Tolerances are left generous.

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, InteractionParams, HarmonicTrap,
    make_workspace, run_simulation!, SimParams, TimeDependentZeeman,
    ConstantWaveform, FunctionWaveform, make_rotating_basis_ws, evolve_rotating!,
    spin_matrices

@testset "Option γ rotating ⇄ standard dynamics (time-dependent B̂)" begin
    F = 1
    D = 2F + 1
    n = 16
    L = 10.0
    grid = make_grid(GridConfig((n, n, n), (L, L, L)))
    sm = spin_matrices(F)
    Fx, Fy, Fz = sm.Fx, sm.Fy, sm.Fz
    dV = prod(grid.dx)

    # Asymmetric multi-component seed so the spin dynamics is non-trivial.
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
    function absF(ψ)
        fx = fy = fz = 0.0 + 0im
        @inbounds for I in CartesianIndices((n, n, n)), i in 1:D, j in 1:D
            a = conj(ψ[I, i])
            fx += a * Fx[i, j] * ψ[I, j]
            fy += a * Fy[i, j] * ψ[I, j]
            fz += a * Fz[i, j] * ψ[I, j]
        end
        sqrt(real(fx)^2 + real(fy)^2 + real(fz)^2) * dV
    end

    # In-plane rotating field B̂(t): θ=π/2, φ(t)=Ω t. Lab components
    # bx=p cos(Ωt), by=p sin(Ωt), bz=0.
    p = 5.0
    Ω = 0.7
    T = 2.0
    c0, c1 = 10.0, 1.0
    dt = 0.004
    ns = Int(round(T / dt))

    # Standard lab-frame path.
    zee = TimeDependentZeeman(
        ConstantWaveform(0.0), ConstantWaveform(0.0),
        FunctionWaveform(t -> p * cos(Ω * t)), FunctionWaveform(t -> p * sin(Ω * t)),
    )
    wsl = make_workspace(;
        grid, atom=SpinorBEC.Na23,
        interactions=InteractionParams(Dict(0 => c0, 1 => c1)),
        zeeman=zee, potential=HarmonicTrap{3}((1.0, 1.0, 1.0)),
        sim_params=SimParams(dt=dt, n_steps=ns, save_every=ns), psi_init=copy(psi0),
    )
    run_simulation!(wsl)
    pl = wsl.state.psi

    # Rotating-basis path: ψ̃(0) = U_B(0)† ψ_lab(0); evolve; map back to lab.
    V = zeros(Float64, n, n, n)
    @inbounds for I in CartesianIndices(V)
        x = grid.x[1][I[1]]
        y = grid.x[2][I[2]]
        z = grid.x[3][I[3]]
        V[I] = 0.5 * (x * x + y * y + z * z)
    end
    wsr = make_rotating_basis_ws(
        grid, F, V;
        p=p, q=0.0, c0=c0, c1=c1,
        theta_func=t -> π / 2, phi_func=t -> Ω * t,
        theta_dot_func=t -> 0.0, phi_dot_func=t -> Ω, gauge_fix=false,
    )
    copyto!(wsr.psi_tilde, psi0)
    SpinorBEC._apply_UB!(wsr.psi_tilde, sm, π / 2, 0.0, 3; inverse=true, scratch=wsr.rotation_scratch)
    evolve_rotating!(wsr, ns, dt)
    SpinorBEC._apply_UB!(wsr.psi_tilde, sm, π / 2, Ω * T, 3; inverse=false, scratch=wsr.rotation_scratch)
    pr = wsr.psi_tilde

    # Sanity: the dynamics actually moved population (spin-mixing under the
    # rotating field), so the agreement below is non-trivial.
    @test maximum(abs.(per_m(pl) .- per_m(psi0))) > 1e-3

    @test maximum(abs.(per_m(pl) .- per_m(pr))) < 1e-3
    @test abs(absF(pl) - absF(pr)) < 1e-3

    nl = dropdims(sum(abs2, pl; dims=4); dims=4)
    nr = dropdims(sum(abs2, pr; dims=4); dims=4)
    overlap = sum(sqrt.(max.(nl, 0.0) .* max.(nr, 0.0))) /
              (sqrt(sum(nl)) * sqrt(sum(nr)))
    @test overlap > 0.9999
end
