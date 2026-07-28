using Test
using FFTW
using LinearAlgebra
using Random
using SpinorBEC

# Stoof-form (full-Hamiltonian) SGPE damping — the `full_hamiltonian=true` path of
# `apply_sgpe_step!`. Two gates:
#
#   (1) Free-limit regression: with no interactions (c₀=c₁=0) Ĥ[ψ]ψ = kinetic ψ, so the
#       Stoof Euler drift equals the simple-growth kinetic drift to first order in dt. One
#       damping-only (T=0) step of each must agree to O((γ·½k²·dt)²).
#
#   (2) Interacting relaxation (the capability the kinetic-only form lacks): with c₀>0 and
#       T=0, γ>0, the Stoof drift is imaginary-time relaxation under the FULL GP operator,
#       so the GP residual ‖(Ĥ−μ)ψ‖/‖ψ‖ → 0 (relaxes to the interacting ground state). The
#       simple-growth (kinetic-only) drift leaves the interaction residual and stalls.

function _gp_residual(ws)
    hpsi = similar(ws.state.psi)
    SpinorBEC.apply_operator_via_registry!(hpsi, ws)
    ψ = ws.state.psi
    μ = real(sum(conj.(ψ) .* hpsi)) / real(sum(abs2, ψ))
    sqrt(real(sum(abs2, hpsi .- μ .* ψ))) / sqrt(real(sum(abs2, ψ)))
end

@testset "SGPE Stoof-form full-Hamiltonian kernel" begin
    @testset "free limit reduces to simple-growth" begin
        n_pts = (16, 16)
        box = (8.0, 8.0)
        grid = make_grid(GridConfig(n_pts, box))
        ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))   # free field ⇒ Ĥ = kinetic
        sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)

        seed = zeros(ComplexF64, n_pts..., 1)
        Random.seed!(3)
        for I in CartesianIndices(n_pts)
            seed[I, 1] = randn() + im * randn()
        end

        γ, μ, dt = 0.2, -0.3, 5e-4      # small γ·dt ⇒ first-order agreement is tight
        ws_s = make_workspace(;
            grid, atom=Rb87, interactions=ip, sim_params=sp, fft_flags=FFTW.ESTIMATE
        )
        ws_f = make_workspace(;
            grid, atom=Rb87, interactions=ip, sim_params=sp, fft_flags=FFTW.ESTIMATE
        )
        copyto!(ws_s.state.psi, seed)
        copyto!(ws_f.state.psi, seed)

        # T=0 ⇒ damping only, no noise
        apply_sgpe_step!(ws_s, γ, 0.0, dt; μ=μ, full_hamiltonian=false)
        apply_sgpe_step!(ws_f, γ, 0.0, dt; μ=μ, full_hamiltonian=true)

        scale = maximum(abs, seed)
        @test maximum(abs, ws_f.state.psi .- ws_s.state.psi) < 1e-3 * scale   # O((γ½k²dt)²)
    end

    @testset "interacting: Stoof relaxes to GP ground state, kinetic-only stalls" begin
        n_pts = (24, 24)
        box = (10.0, 10.0)
        grid = make_grid(GridConfig(n_pts, box))
        ip = InteractionParams(Dict(0 => 50.0, 1 => 0.0))  # strongly interacting scalar
        sp = SimParams(; dt=0.002, n_steps=1, imaginary_time=false, save_every=1, normalize_every=0)

        function fresh()
            ws = make_workspace(;
                grid, atom=Rb87, interactions=ip, sim_params=sp, fft_flags=FFTW.ESTIMATE
            )
            Random.seed!(7)
            ψ = ws.state.psi
            fill!(ψ, 0)
            for I in CartesianIndices(n_pts)
                ψ[I, 1] = 1.0 + 0.3 * (randn() + im * randn())
            end
            ψ .*= sqrt(1000.0 / (real(sum(abs2, ψ)) * cell_volume(grid)))
            ws
        end

        ws_stoof = fresh()
        ws_simple = fresh()
        r0 = _gp_residual(ws_stoof)
        for _ in 1:4000
            apply_sgpe_step!(ws_stoof, 0.3, 0.0, 0.002; μ=0.0, k_cut=6.0, full_hamiltonian=true)
            apply_sgpe_step!(ws_simple, 0.3, 0.0, 0.002; μ=0.0, k_cut=6.0, full_hamiltonian=false)
        end
        r_stoof = _gp_residual(ws_stoof)
        r_simple = _gp_residual(ws_simple)

        @test r0 > 10.0                    # seeded far from the ground state
        @test r_stoof < 0.1                # Stoof relaxes to Ĥψ = μψ
        @test r_simple > 1.0               # kinetic-only cannot; leaves interaction residual
        @test r_stoof < 0.05 * r_simple    # the qualitative gap
    end
end
