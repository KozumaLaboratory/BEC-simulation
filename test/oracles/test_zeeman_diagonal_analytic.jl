# test/oracles/test_zeeman_diagonal_analytic.jl
#
# Analytic pin of the linear-Zeeman diagonal convention (the source of
# truth is `_diag_coef(LinearZeemanZTerm,m) = -p·m + q·m²`, itself
# derived from H_Zeeman = -(g_F μ_B B·F) + q F_z²). `apply_operator!`
# must reproduce that diagonal exactly, component by component, for every
# F. Catches any per-component index / sign / q-term drift.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: LinearZeemanZTerm, apply_operator!

function _zee_ws(atom)
    grid = make_grid(GridConfig((6, 6, 6), (4.0, 4.0, 4.0)))
    make_workspace(;
        grid, atom,
        interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
        zeeman=ZeemanParams(0.0, 0.0),
        potential=NoPotential(),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
        fft_flags=FFTW.ESTIMATE,
    )
end

@testset "LinearZeeman diagonal = (-p·m + q·m²)·ψ_m" begin
    for (atom, F) in ((Rb87, 1), (Na23, 1), (Eu151, 6))
        ws = _zee_ws(atom)
        D = 2F + 1
        @assert ws.spin_matrices.system.n_components == D
        p, q = 0.73, 0.21
        term = LinearZeemanZTerm(p, q)
        psi = randn(ComplexF64, 6, 6, 6, D)
        out = zero(psi)
        apply_operator!(out, term, ws, psi)
        @testset "F=$F" begin
            for c in 1:D
                m = F - (c - 1)                  # c=1 → m=+F, c=D → m=−F
                coef = -p * m + q * m^2
                @test isapprox(out[:, :, :, c], coef .* psi[:, :, :, c];
                    rtol=1e-12, atol=1e-12)
            end
        end
    end
end
