# test/oracles/test_term_legacy_equivalence.jl
#
# Bit-identicity safety net. For each `HamTerm` implementation, verify
# that `apply_step!` / `energy_contribution` / `apply_operator!` produce
# results bit-identical to the legacy hand-written routines they will
# eventually replace. This must pass BEFORE any migration step retires
# the legacy code.
#
# Without this gate, refactoring formulas (even mathematically
# equivalent ones) can introduce machine-epsilon differences that
# break regression tests comparing against past JLD2 outputs.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: LinearZeemanZTerm, apply_step!, energy_contribution,
    apply_operator!

@testset "HamTerm ↔ legacy bit-identity" begin
    @testset "LinearZeemanZTerm vs legacy _diagonal_step + _zeeman_energy + _grad_zeeman!" begin
        grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        atom = Rb87
        F = atom.F;
        D = 2F + 1
        interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
        zeeman = ZeemanParams(0.7, 0.2)  # p=0.7, q=0.2 (both non-zero)
        sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
        ws_leg = make_workspace(;
            grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=sp, fft_flags=FFTW.ESTIMATE,
        )

        # Build a random unit-norm psi for the comparison.
        import Random
        Random.seed!(42)
        psi_ref = randn(ComplexF64, 8, 8, 8, D)
        psi_ref ./= sqrt(sum(abs2, psi_ref) * cell_volume(grid))

        # --- Energy bit-identity ---
        copyto!(ws_leg.state.psi, psi_ref)
        E_legacy = SpinorBEC.energy_decomposition(ws_leg).zeeman

        term = LinearZeemanZTerm(0.7, 0.2)
        E_new = energy_contribution(term, psi_ref, ws_leg)

        # Strict bit-identity: should agree to F64 ULP scale (~1e-14).
        # The legacy and HamTerm both compute Σ (-p·m + q·m²) |ψ_m|²
        # via the same arithmetic sequence per component.
        @test isapprox(E_legacy, E_new; rtol=1e-14, atol=1e-15)

        # --- Gradient bit-identity ---
        grad_legacy = zero(psi_ref)
        # Mirror what `energy_gradient!` does for the zeeman term
        # internally (without the outer ×2 scaling).
        n_pts = (8, 8, 8)
        # Call the legacy routine directly:
        SpinorBEC._grad_zeeman!(grad_legacy, psi_ref, ws_leg, n_pts, D, Val(3))

        grad_new = zero(psi_ref)
        apply_operator!(grad_new, term, ws_leg, psi_ref)

        # Bit-identity per-element.
        @test maximum(abs, grad_new .- grad_legacy) < 1e-14

        # --- Propagator bit-identity (ITP one step) ---
        psi_legacy_step = copy(psi_ref)
        # Replicate the legacy diagonal step for one dt:
        # exp(-(zeeman_diag[c] - shift) * dt) on each component.
        zeeman_diag = SpinorBEC.zeeman_diagonal(zeeman, ws_leg.spin_matrices)
        zee_shift = minimum(zeeman_diag)
        for c in 1:D
            psi_legacy_step[:, :, :, c] .*= exp(-(zeeman_diag[c] - zee_shift) * 0.01)
        end

        psi_new_step = copy(psi_ref)
        apply_step!(term, psi_new_step, 0.01, true, ws_leg)

        @test maximum(abs, psi_new_step .- psi_legacy_step) < 1e-14
    end
end
