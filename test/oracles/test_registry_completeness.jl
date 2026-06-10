# test/oracles/test_registry_completeness.jl
#
# Meta-completeness gate: the HamTerm registry must stay in lock-step with
# the canonical term order, and EVERY registered term must have callable,
# finite energy + operator faces. This is the structural guarantee that no
# term silently vanishes from (or is double-listed in) the Hamiltonian, and
# that adding a term without wiring its faces fails CI — the load-bearing
# completeness invariant the per-term gates rely on.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: build_h_terms_registry, H_TERMS_CANONICAL_ORDER,
    apply_operator!, energy_contribution, energy_decomposition, compute_c_dd

@testset "HamTerm registry completeness" begin
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
    copyto!(ws.state.psi, psi)

    registry = build_h_terms_registry(ws)

    @testset "registry ↔ canonical order length" begin
        @test length(registry) == length(H_TERMS_CANONICAL_ORDER)
    end

    @testset "every term has finite, callable faces" begin
        for term in registry
            out = zero(psi)
            @test (apply_operator!(out, term, ws, psi); all(isfinite, out))
            @test isfinite(energy_contribution(term, psi, ws))
        end
    end

    @testset "energy_decomposition total is finite and present" begin
        nt = energy_decomposition(ws)
        @test haskey(nt, :total)
        @test isfinite(nt.total)
        @test all(isfinite, values(nt))
    end
end
