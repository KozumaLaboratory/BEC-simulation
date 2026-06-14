# test/oracles/test_term_consistency.jl
#
# Per-HamTerm consistency check (the structural anti-recurrence gate
# for sign-bug class). For every HamTerm, we verify:
#
#   1. `energy_contribution` and `apply_operator!` are FD-consistent:
#         (E(ψ + ε·δψ) - E(ψ)) / ε ≈ Re⟨grad, δψ⟩
#      This catches any sign/missing-term mismatch between energy and
#      gradient — the bug class found in 2026-06-04 GAP-1.
#
#   2. The directional sign_oracle predicate evaluates true after ITP
#      with the term active. This catches sign-inversion bugs of the
#      kind found in 2026-06-03 Coriolis + 2026-06-04 transverse Zeeman.
#
# Running this for every term in the HamTerm registry is the CI gate
# that makes the bug class structurally impossible.

using Test
using FFTW
using SpinorBEC
using SpinorBEC: HamTerm, ZeemanTerm,
    apply_step!, energy_contribution, apply_operator!, sign_oracle
using Random

# Reference test setup used by every term-consistency test.
function _ref_workspace(F::Int=1)
    grid = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
    interactions = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    zeeman = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    atom = F == 1 ? Rb87 : error("F=$F atom not parametrised yet in test fixture")
    ws = make_workspace(;
        grid, atom, interactions, zeeman,
        potential=HarmonicTrap((1.0, 1.0, 1.0)),
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )
    return ws
end

function _random_state(ws, seed::Int=42)
    Random.seed!(seed)
    D = ws.spin_matrices.system.n_components
    n_pts = (8, 8, 8)
    psi = randn(ComplexF64, n_pts..., D)
    psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
    return psi
end

function _random_perturbation(psi_ref, seed::Int=99)
    Random.seed!(seed)
    δψ = randn(ComplexF64, size(psi_ref))
    δψ ./= sqrt(sum(abs2, δψ) * cell_volume(make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))))
    return δψ
end

"""
FD consistency check: for a HamTerm and a reference state, verify
that the FD slope of energy_contribution matches Re⟨apply_operator!, δψ⟩.
Returns (fd_slope, inner_product, ratio).
"""
function _fd_vs_inner(term::HamTerm, ws, psi_ref, δψ; ε=1e-7)
    dV = cell_volume(ws.grid)
    E_0 = energy_contribution(term, psi_ref, ws)
    E_ε = energy_contribution(term, psi_ref .+ ε .* δψ, ws)
    fd_slope = (E_ε - E_0) / ε

    grad = zero(psi_ref)
    apply_operator!(grad, term, ws, psi_ref)
    # Convention: energy_gradient! later scales `grad` by 2 (Wirtinger).
    # So the inner product against δψ that matches dE/dε is
    # `2 · Re⟨grad, δψ⟩` (since `grad` here is δE/δψ*).
    inner = 2 * real(sum(conj.(grad) .* δψ)) * dV

    return (fd_slope, inner, fd_slope / inner)
end

@testset "HamTerm consistency: energy ≡ ∂(gradient) via FD" begin
    ws = _ref_workspace()
    psi_ref = _random_state(ws)
    δψ = _random_perturbation(psi_ref)

    @testset "ZeemanTerm (diagonal)" begin
        term = ZeemanTerm(0.0, 0.0, 0.7, 0.2)
        fd, inner, ratio = _fd_vs_inner(term, ws, psi_ref, δψ)
        @test isapprox(fd, inner; rtol=1e-3)
    end

    @testset "ZeemanTerm (transverse)" begin
        term = ZeemanTerm(0.5, 0.3, 0.0, 0.0)
        fd, inner, ratio = _fd_vs_inner(term, ws, psi_ref, δψ)
        @test isapprox(fd, inner; rtol=1e-3)
    end

    @testset "ZeemanTerm (full: diagonal + transverse)" begin
        term = ZeemanTerm(0.5, 0.3, 0.7, 0.2)
        fd, inner, ratio = _fd_vs_inner(term, ws, psi_ref, δψ)
        @test isapprox(fd, inner; rtol=1e-3)
    end

    # TensorTerm: c₂ singlet-pair + higher-rank tensor channels. The gradient
    # face is ANOMALOUS (conj(ψ)) and was a KNOWN-LIMIT no-op until 2026-06-09;
    # this gate pins the FD consistency that unlocks Newton-CG/LBFGS on tensor
    # physics. Needs tensor-active workspaces (F≥2), built inline.
    @testset "TensorTerm (c2 singlet + tensor channels)" begin
        gr = make_grid(GridConfig((4, 4, 4), (4.0, 4.0, 4.0)))
        cases = (
            (Rb85, 2, Dict(0 => 1.0, 1 => 0.2, 2 => 0.5)),
            (Cr52, 3, Dict(0 => 1.0, 1 => 0.2, 4 => 0.3)),
            (Eu151, 6, Dict(0 => 1.0, 1 => 0.1, 4 => 0.2, 6 => 0.15, 10 => 0.1, 12 => 0.08)),
        )
        for (atom, F, chans) in cases
            wst = make_workspace(; grid=gr, atom,
                interactions=InteractionParams(chans),
                zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
                sim_params=SimParams(; dt=0.005, n_steps=1, imaginary_time=true),
                fft_flags=FFTW.ESTIMATE)
            Random.seed!(7)
            psi = randn(ComplexF64, 4, 4, 4, 2F + 1)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(gr))
            δ = randn(ComplexF64, 4, 4, 4, 2F + 1)
            δ ./= sqrt(sum(abs2, δ) * cell_volume(gr))
            fd, inner, _ = _fd_vs_inner(SpinorBEC.TensorTerm(), wst, psi, δ)
            @test isapprox(fd, inner; rtol=1e-3)
        end
    end

    # SpatialZeemanTerm: arbitrary B(r). Energy ↔ gradient FD consistency with
    # a non-trivial varying field (diagonal + transverse + q all spatial).
    @testset "SpatialZeemanTerm (arbitrary B(r))" begin
        gr = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        field = spatial_zeeman_field(gr;
            bz=(x, y, z) -> 0.5 + 0.1x,
            bx=(x, y, z) -> 0.3 - 0.05y,
            by=(x, y, z) -> 0.05z,
            q=(x, y, z) -> 0.1 + 0.02x^2)
        wsz = make_workspace(; grid=gr, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            spatial_zeeman=field, fft_flags=FFTW.ESTIMATE)
        Random.seed!(7)
        psi = randn(ComplexF64, 8, 8, 8, 3)
        psi ./= sqrt(sum(abs2, psi) * cell_volume(gr))
        δ = randn(ComplexF64, 8, 8, 8, 3)
        δ ./= sqrt(sum(abs2, δ) * cell_volume(gr))
        fd, inner, _ = _fd_vs_inner(SpinorBEC.SpatialZeemanTerm(), wsz, psi, δ)
        @test isapprox(fd, inner; rtol=1e-3)
    end
end

@testset "HamTerm directional sign oracles" begin
    @testset "ZeemanTerm: +bz ⇒ ⟨F_z⟩ > 0" begin
        ws = _ref_workspace()
        term = ZeemanTerm(0.0, 0.0, 2.0, 0.0)
        # ITP loop only this term — start from m_plus_F, apply 500 steps
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        for _ in 1:500
            apply_step!(term, psi, 0.005, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        oracle = sign_oracle(ZeemanTerm)
        @test oracle.predicate(psi, ws)
    end

    @testset "ZeemanTerm: +bx ⇒ ⟨F_x⟩ > 0" begin
        ws = _ref_workspace()
        # Transverse +bx with a small +bz parity breaker in ONE term
        # (transverse alone from m_plus_F can leave ⟨F_x⟩ = 0 by symmetry).
        term = ZeemanTerm(2.0, 0.0, 0.5, 0.0)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:m_plus_F)
        for _ in 1:500
            apply_step!(term, psi, 0.005, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        sm = ws.spin_matrices
        fx, _, _ = SpinorBEC.spin_density_vector(psi, sm, ndims(psi) - 1)
        @test sum(fx) * cell_volume(ws.grid) > 0.0
    end

    @testset "SpatialZeemanTerm: uniform +bz ⇒ ⟨F_z⟩ > 0" begin
        # Constant +bz spatial field ≡ uniform Zeeman; ITP from m_plus_F
        # must preserve ⟨F_z⟩ > 0 (the directional sign of the field).
        gr = make_grid(GridConfig((8, 8, 8), (4.0, 4.0, 4.0)))
        field = spatial_zeeman_field(gr; bz=2.0)
        ws = make_workspace(; grid=gr, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=HarmonicTrap((1.0, 1.0, 1.0)),
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            spatial_zeeman=field, fft_flags=FFTW.ESTIMATE)
        term = SpinorBEC.SpatialZeemanTerm()
        psi = init_psi(gr, SpinSystem(1); state=:m_plus_F)
        for _ in 1:500
            apply_step!(term, psi, 0.005, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        @test sign_oracle(SpinorBEC.SpatialZeemanTerm).predicate(psi, ws)
    end
end
