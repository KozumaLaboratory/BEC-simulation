# test/oracles/test_global_phase_covariance.jl
#
# A global U(1) phase ψ → e^{iθ}ψ is unphysical: every Hamiltonian term
# (linear or mean-field) must be phase-COVARIANT, H[e^{iθ}ψ]·(e^{iθ}ψ)
# = e^{iθ}·(H[ψ]·ψ). Mean-field terms qualify because the densities
# (|ψ|², ⟨F⟩) are phase-invariant. Any stray conj(ψ) on the wrong factor
# (the kind of slip the tensor anomalous face is prone to) breaks this.
# Run over the full registry so every active term is covered at once.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: build_h_terms_registry, apply_operator!, compute_c_dd

@testset "Global phase covariance of all HamTerms" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.2)),
        zeeman=ZeemanParams(0.4, 0.1), potential=HarmonicTrap((1.0, 1.2, 0.8)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false,
            rotating_frame_omega=0.3),
        enable_ddi=true, c_dd=compute_c_dd(Eu151),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    dV = cell_volume(grid)
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * dV)

    θ = 0.7
    psiθ = cis(θ) .* psi
    for term in build_h_terms_registry(ws)
        H1 = zero(psi);
        apply_operator!(H1, term, ws, psi)
        H2 = zero(psi);
        apply_operator!(H2, term, ws, psiθ)
        # skip inactive terms (both ~0); test covariance on active ones
        if maximum(abs, H1) > 1e-10
            @testset "$(typeof(term))" begin
                @test isapprox(H2, cis(θ) .* H1; rtol=1e-9, atol=1e-10)
            end
        end
    end
end
