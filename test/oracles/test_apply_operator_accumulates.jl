# test/oracles/test_apply_operator_accumulates.jl
#
# The apply_operator! contract (CLAUDE.md HamTerm protocol): it ACCUMULATES
# `out .+= H·ψ` and must never `fill!(out)` internally — callers zero `out`
# for the bare action. Applying the same term twice into one buffer must
# give exactly 2·H·ψ.
#
# Registry-DRIVEN: iterate the WHOLE `build_h_terms_registry` rather than a
# hand-picked list, so every present term (and any future term) is checked
# by construction. Active terms are pinned non-trivially; inactive terms
# satisfy the contract trivially (2·0 = 0) while still exercising the path.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: build_h_terms_registry, apply_operator!, compute_c_dd

@testset "apply_operator! accumulates — full registry" begin
    grid = make_grid(GridConfig((8, 8, 8), (6.0, 6.0, 6.0)))
    ws = make_workspace(;
        grid, atom=Eu151,
        interactions=InteractionParams(Dict(0 => 1.0, 1 => 0.2)),
        zeeman=ZeemanParams(0.4, 0.1), potential=HarmonicTrap((1.0, 1.2, 0.8)),
        sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=false,
            rotating_frame_omega=0.3),
        enable_ddi=true, c_dd=compute_c_dd(Eu151),
        loss=SpinorBEC.LossParams(; K3_per_m_cubic=fill(0.5, 13)),
        fft_flags=FFTW.ESTIMATE,
    )
    D = ws.spin_matrices.system.n_components
    psi = randn(ComplexF64, 8, 8, 8, D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))

    n_active = 0
    for term in build_h_terms_registry(ws)
        once = zero(psi);
        apply_operator!(once, term, ws, psi)
        twice = zero(psi)
        apply_operator!(twice, term, ws, psi)
        apply_operator!(twice, term, ws, psi)
        @testset "$(nameof(typeof(term)))" begin
            @test isapprox(twice, 2 .* once; rtol=1e-12, atol=1e-12)
        end
        maximum(abs, once) > 1e-10 && (n_active += 1)
    end
    # guard against a degenerate all-inactive workspace silently passing
    @test n_active >= 6
end
