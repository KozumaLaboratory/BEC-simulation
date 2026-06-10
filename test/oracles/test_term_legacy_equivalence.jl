# test/oracles/test_term_legacy_equivalence.jl
#
# Bit-identicity safety net. For each `HamTerm` implementation, verify
# that `apply_step!` / `energy_contribution` / `apply_operator!` agree
# with an INDEPENDENT inline statement of the same physics to F64 ULP
# scale. The retired hand-written zeeman routines (_diagonal_step,
# _zeeman_energy diagonal loop, _grad_zeeman!) are gone after the 2026
# ZeemanTerm unification; the references below are restated locally so
# the gate no longer depends on the retired code.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: ZeemanTerm, apply_step!, energy_contribution,
    apply_operator!

@testset "HamTerm ↔ independent statement bit-identity" begin
    @testset "ZeemanTerm (diagonal) vs inline -p·m + q·m² statement" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        atom = Rb87
        F = atom.F
        D = 2F + 1
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        zeeman = ZeemanParams(0.7, 0.2)  # p=0.7, q=0.2 (both non-zero)
        sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
        ws = make_workspace(;
            grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, fft_flags=FFTW.ESTIMATE,
        )

        import Random
        Random.seed!(42)
        psi_ref = randn(ComplexF64, 8, 8, 8, D)
        psi_ref ./= sqrt(sum(abs2, psi_ref) * cell_volume(grid))

        p, q = 0.7, 0.2
        coefs = [(-p * (F - (c - 1)) + q * (F - (c - 1))^2) for c in 1:D]

        # --- Energy bit-identity ---
        copyto!(ws.state.psi, psi_ref)
        E_decomp = SpinorBEC.energy_decomposition(ws).zeeman
        term = ZeemanTerm(0.0, 0.0, p, q)
        E_new = energy_contribution(term, psi_ref, ws)
        @test isapprox(E_decomp, E_new; rtol=1e-14, atol=1e-15)

        E_inline = sum(coefs[c] * sum(abs2, psi_ref[:, :, :, c]) for c in 1:D) *
                   cell_volume(grid)
        @test isapprox(E_new, E_inline; rtol=1e-14, atol=1e-15)

        # --- Gradient bit-identity ---
        grad_inline = zero(psi_ref)
        for c in 1:D
            grad_inline[:, :, :, c] .= coefs[c] .* psi_ref[:, :, :, c]
        end
        grad_new = zero(psi_ref)
        apply_operator!(grad_new, term, ws, psi_ref)
        @test maximum(abs, grad_new .- grad_inline) < 1e-14

        # --- Propagator bit-identity (ITP one step, diagonal fast path) ---
        zee_shift = minimum(coefs)
        psi_inline_step = copy(psi_ref)
        for c in 1:D
            psi_inline_step[:, :, :, c] .*= exp(-(coefs[c] - zee_shift) * 0.01)
        end
        psi_new_step = copy(psi_ref)
        apply_step!(term, psi_new_step, 0.01, true, ws)
        @test maximum(abs, psi_new_step .- psi_inline_step) < 1e-14
    end
end
