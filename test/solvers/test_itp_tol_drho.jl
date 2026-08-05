# `tol_drho`: an OPTIONAL second ITP convergence gate on the density.
#
# Why it exists: on a soft (Goldstone) manifold — the weak-field Eu textures are
# the motivating case — ψ keeps drifting along the gauge orbit long after the
# state has stopped changing physically. A ψ-based convergence measure reads that
# drift as non-convergence and burns the remaining iterations. ρ(r) = Σ_c |ψ_c|²
# is invariant under a global U(1) phase and under a spin rotation about z, so it
# does not.
#
# Two properties are gated here:
#   1. the invariance the gate's whole value rests on, checked directly on ρ;
#   2. `tol_drho = 0` is exactly the old behaviour (opt-in, not a silent change),
#      and a positive `tol_drho` can only make convergence HARDER, never easier.

using Test
using SpinorBEC

@testset "ITP tol_drho density gate" begin
    @testset "ρ is invariant where ψ is not" begin
        n, D = 8, 3
        psi = randn(ComplexF64, n, n, n, D)
        rho(p) = dropdims(sum(abs2, p; dims=4); dims=4)

        rho0 = rho(psi)

        # global U(1) phase
        psi_phase = psi .* cis(0.7)
        @test rho(psi_phase) ≈ rho0
        @test !isapprox(psi_phase, psi; rtol=1e-8)

        # spin rotation about z: ψ_m → e^{-i m φ} ψ_m  (m = F, …, −F for c = 1…D)
        F = (D - 1) ÷ 2
        phi = 0.31
        psi_rot = similar(psi)
        for c in 1:D
            m = F - (c - 1)
            @views psi_rot[:, :, :, c] .= psi[:, :, :, c] .* cis(-m * phi)
        end
        @test rho(psi_rot) ≈ rho0
        @test !isapprox(psi_rot, psi; rtol=1e-8)
    end

    # A small scalar-limit ITP; cheap and deterministic.
    base = (; grid=make_grid(GridConfig((16, 16, 16), (8.0, 8.0, 8.0))),
        atom=AtomSpecies("Rb87", 1.44e-25, 1, 0.0, 0.0, 0.0),
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.0)),
        dt=0.001, n_steps=400, tol=1e-6, save_every=20,
        initial_state=:polar, verbose=false)

    @testset "tol_drho = 0 leaves the old path bit-identical" begin
        a = find_ground_state(; base...)
        b = find_ground_state(; base..., tol_drho=0.0)
        @test a.converged == b.converged
        @test a.last_step == b.last_step
        @test a.energy == b.energy          # bit-identical, not approx
    end

    @testset "a positive tol_drho can only make convergence harder" begin
        loose = find_ground_state(; base..., tol_drho=1.0)     # never binds
        tight = find_ground_state(; base..., tol_drho=1e-30)   # never satisfiable

        @test loose.last_step == find_ground_state(; base...).last_step
        # The impossible density gate must veto the energy gate, so the loop runs
        # to n_steps instead of stopping where dE alone would have stopped.
        @test !tight.converged
        @test tight.last_step >= loose.last_step
        @test tight.last_step == base.n_steps
    end
end
