# test/oracles/test_physics_aware_sign_oracles.jl
#
# Physics-aware directional sign oracles for the high-risk GS-phase
# terms: SpinC1, DDI, LHY, Tensor. Closes the per-term gap exposed by
# the 2026-06-04 PM honest assessment — pre-existing oracles for these
# 4 terms were `sign(E) = sign(c)` formula tautologies (E = c·X² with
# X² ≥ 0 by construction → no actual physics is being tested).
#
# Each test below picks a state at which the term's sign produces a
# *distinguishable* observable, with an analytical anchor. A future
# sign-flip in any of these terms breaks at least one test loudly.
#
# DESIGN CRITERIA (per session honesty checklist):
#   - Real physics observable, not a tautology.
#   - Analytical anchor (FM limit ⟨|F|²⟩=F², prolate < oblate for c_dd > 0,
#     ∫n^{5/2} convex in n, polar |A|²=1 vs FM |A|²=0).
#   - Symmetry-breaker in initial state where needed (spin-coherent θ=π/4).
#   - Fast (each test < 5 s) so they can live in CI fast tier.

using Test
using FFTW
using SpinorBEC
using SpinorBEC:
    SpinC1Term, DDITerm, LHYTerm, TensorTerm, RamanTerm, RamanCoupling,
    apply_step!, energy_contribution, spin_density_vector, sign_oracle, cell_volume
using Random

# ============================================================================
# (1) SpinC1Term:  c1<0 → FM (⟨|F|²⟩→F²),  c1>0 → polar (⟨|F|²⟩→0)
# ============================================================================
#
# The canonical c1 sign test. Starting from a spin-coherent state at
# θ=π/4 (symmetry-broken, neither pure polar nor pure stretched),
# ITP under c1-only must drive ⟨|F|²⟩ in the direction picked by sign(c1).
# Other terms (Bz, q, c0, DDI, LHY, trap) are all zero.

@testset "Physics-aware sign oracle: SpinC1Term" begin
    function _c1_ws(c1::Float64)
        grid = make_grid(GridConfig((16,), (8.0,)))
        ip = InteractionParams(Dict(0 => 0.0, 1 => c1))
        zp = ZeemanParams(0.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
        return make_workspace(;
            grid, atom=Rb87, interactions=ip, zeeman=zp,
            sim_params=sp, fft_flags=FFTW.ESTIMATE,
        )
    end

    function _F_sq_per_n(psi, ws)
        N = ndims(psi) - 1
        fx, fy, fz = spin_density_vector(psi, ws.spin_matrices, N)
        dV = cell_volume(ws.grid)
        F_sq_total = (sum(fx .^ 2) + sum(fy .^ 2) + sum(fz .^ 2)) * dV
        n_total = sum(SpinorBEC.total_density(psi, N)) * dV
        return F_sq_total / max(n_total^2, 1e-30)
    end

    F2 = 1.0  # F=1 for Rb87 → F² = 1

    @testset "c1 < 0 ⇒ FM (⟨|F|²⟩→F²)" begin
        ws = _c1_ws(-1.0)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:spin_coherent, init_theta=π / 4)
        for _ in 1:1000
            apply_step!(SpinC1Term(-1.0), psi, 0.01, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        F_sq_norm = _F_sq_per_n(psi, ws)
        @info "SpinC1 c1<0 final ⟨|F|²⟩/⟨n⟩²" F_sq_norm F2
        @test F_sq_norm > 0.7 * F2  # close to FM limit
    end

    @testset "c1 > 0 ⇒ polar (⟨|F|²⟩→0)" begin
        ws = _c1_ws(+1.0)
        sys = SpinSystem(1)
        psi = init_psi(ws.grid, sys; state=:spin_coherent, init_theta=π / 4)
        for _ in 1:1000
            apply_step!(SpinC1Term(+1.0), psi, 0.01, true, ws)
            psi ./= sqrt(sum(abs2, psi) * cell_volume(ws.grid))
        end
        F_sq_norm = _F_sq_per_n(psi, ws)
        @info "SpinC1 c1>0 final ⟨|F|²⟩/⟨n⟩²" F_sq_norm
        @test F_sq_norm < 0.3 * F2  # close to polar limit
    end
end

# ============================================================================
# (2) DDITerm:  c_dd > 0 ⇒ E_DDI(prolate) < E_DDI(oblate)
# ============================================================================
#
# Pure energy compare on two crafted states with the SAME total norm:
# - Prolate: Gaussian elongated along the polarization axis z
# - Oblate: Gaussian elongated in the perpendicular plane (xy)
# Both fully +F polarized (all density in m=+F slot).
# For c_dd > 0 (head-to-tail dipolar attraction along polarization axis),
# prolate is favorable → E_DDI(prolate) < E_DDI(oblate).
# No ITP — this is a pure forward energy evaluation.

@testset "Physics-aware sign oracle: DDITerm" begin
    function _make_polarized_gaussian(grid, sys, σ_x, σ_y, σ_z)
        D = sys.n_components
        n_pts = grid.config.n_points
        psi = zeros(ComplexF64, n_pts..., D)
        # Polarize +F (m=+F is component 1 in our convention)
        for I in CartesianIndices(n_pts)
            x = grid.x[1][I[1]]
            y = grid.x[2][I[2]]
            z = grid.x[3][I[3]]
            psi[I, 1] = exp(-x^2 / (2σ_x^2) - y^2 / (2σ_y^2) - z^2 / (2σ_z^2))
        end
        psi ./= sqrt(sum(abs2, psi) * cell_volume(grid))
        return psi
    end

    grid = make_grid(GridConfig((24, 24, 24), (8.0, 8.0, 8.0)))
    ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0))
    zp = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, zeeman=zp,
        enable_ddi=true, c_dd=1.0, secular_ddi=true,  # c_dd>0
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )

    sys = SpinSystem(1)
    psi_prolate = _make_polarized_gaussian(grid, sys, 0.8, 0.8, 1.6)
    psi_oblate = _make_polarized_gaussian(grid, sys, 1.6, 1.6, 0.8)

    copyto!(ws.state.psi, psi_prolate)
    E_prolate = energy_contribution(DDITerm(), psi_prolate, ws)

    copyto!(ws.state.psi, psi_oblate)
    E_oblate = energy_contribution(DDITerm(), psi_oblate, ws)

    @info "DDI energy compare (c_dd>0, +F polarized)" E_prolate E_oblate
    @test E_prolate < E_oblate
end

# ============================================================================
# (3) LHYTerm:  c_lhy > 0 ⇒ E_LHY(peaked) > E_LHY(flat)
# ============================================================================
#
# E_LHY = (2/5)·c_lhy·∫ n^{5/2} dV. Since n^{5/2} is convex in n,
# for the same total norm ∫n dV the peaked (high-density-locally)
# state has higher ∫n^{5/2} than the flat state. For c_lhy > 0,
# peaked is energetically more costly. No ITP — pure energy compare.

@testset "Physics-aware sign oracle: LHYTerm" begin
    grid = make_grid(GridConfig((32,), (16.0,)))
    ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0); c_lhy=1.0)
    zp = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, zeeman=zp,
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )

    sys = SpinSystem(1)
    D = sys.n_components
    n_pts = grid.config.n_points

    # Peaked Gaussian (narrow width)
    psi_peaked = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        psi_peaked[I, 2] = exp(-x^2 / (2 * 0.5^2))  # m=0 component, narrow
    end
    psi_peaked ./= sqrt(sum(abs2, psi_peaked) * cell_volume(grid))

    # Flat top — wide Gaussian
    psi_flat = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        psi_flat[I, 2] = exp(-x^2 / (2 * 3.0^2))  # m=0, wide
    end
    psi_flat ./= sqrt(sum(abs2, psi_flat) * cell_volume(grid))

    copyto!(ws.state.psi, psi_peaked)
    E_peaked = energy_contribution(LHYTerm(), psi_peaked, ws)

    copyto!(ws.state.psi, psi_flat)
    E_flat = energy_contribution(LHYTerm(), psi_flat, ws)

    @info "LHY energy compare (c_lhy>0, same norm)" E_peaked E_flat
    @test E_peaked > E_flat
    @test E_peaked > 0  # c_lhy > 0 → positive energy
end

# ============================================================================
# (4) TensorTerm (c2):  E_pair(polar) > E_pair(FM) for c2 > 0
# ============================================================================
#
# Singlet-pair channel S=0. For F=1:
#   polar state ψ = (0, 1, 0)        → A ∝ ψ_-1·ψ_+1 - ψ_0²/2 = -1/2 → |A|²=1/4
#   FM stretched ψ = (1, 0, 0)        → A = 0
# For c2 > 0 (polar singlet repulsion), E_pair(polar) > 0, E_pair(FM) = 0.
# Sign-check: their difference is positive.

@testset "Physics-aware sign oracle: TensorTerm (c2)" begin
    grid = make_grid(GridConfig((16,), (8.0,)))
    ip = InteractionParams(Dict(0 => 0.0, 1 => 0.0, 2 => 1.0))  # c2 > 0
    zp = ZeemanParams(0.0, 0.0)
    sp = SimParams(; dt=0.01, n_steps=1, imaginary_time=true)
    ws = make_workspace(;
        grid, atom=Rb87, interactions=ip, zeeman=zp,
        sim_params=sp, fft_flags=FFTW.ESTIMATE,
    )

    sys = SpinSystem(1)
    D = sys.n_components
    n_pts = grid.config.n_points

    # Polar: only m=0 populated (component index for m=0 at F=1 is c=2)
    psi_polar = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        psi_polar[I, 2] = exp(-x^2 / 2)  # m=0
    end
    psi_polar ./= sqrt(sum(abs2, psi_polar) * cell_volume(grid))

    # FM stretched +F: only m=+F populated (c=1)
    psi_fm = zeros(ComplexF64, n_pts..., D)
    for I in CartesianIndices(n_pts)
        x = grid.x[1][I[1]]
        psi_fm[I, 1] = exp(-x^2 / 2)  # m=+F
    end
    psi_fm ./= sqrt(sum(abs2, psi_fm) * cell_volume(grid))

    copyto!(ws.state.psi, psi_polar)
    E_polar = energy_contribution(TensorTerm(), psi_polar, ws)

    copyto!(ws.state.psi, psi_fm)
    E_fm = energy_contribution(TensorTerm(), psi_fm, ws)

    @info "Tensor (c2>0) energy compare" E_polar E_fm
    @test E_polar > 0  # c2 > 0 + polar → positive E_pair
    @test abs(E_fm) < 1e-10  # FM stretched has zero singlet amplitude
    @test E_polar > E_fm
end

# ============================================================================
# (5) RamanTerm:  +δ → ⟨F_z⟩ < 0  (energy δ·⟨F_z⟩ minimised by ITP)
# ============================================================================
#
# RamanTerm's gradient face was a declared no-op until 2026-07-31, so the previous in-term
# sign_oracle was the placeholder `predicate=true` — it could not detect a
# δ-sign flip in the PROPAGATOR (apply_raman_step!), the face production
# actually runs. Here we anchor on the propagator: ITP under H = δ·F_z (Ω=0,
# k=0) from a transverse (⟨F_z⟩=0) start drives ⟨F_z⟩ to the sign opposite to
# δ. This also gives the now-real sign_oracle predicate teeth.

@testset "Physics-aware sign oracle: RamanTerm (+δ ⇒ ⟨F_z⟩ < 0)" begin
    grid = make_grid(GridConfig((8,), (8.0,)))
    dV = cell_volume(grid)
    for δ in (0.8, -0.8)
        raman = RamanCoupling{1}(0.0, δ, (0.0,))   # pure δ·F_z propagator
        ws = make_workspace(; grid, atom=Rb87,
            interactions=InteractionParams(Dict(0 => 0.0, 1 => 0.0)),
            zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
            raman=raman,
            sim_params=SimParams(; dt=0.01, n_steps=1, imaginary_time=true),
            fft_flags=FFTW.ESTIMATE)
        # transverse start: equal weight on m=+1,0,−1 ⇒ ⟨F_z⟩ = 0 initially.
        psi = zeros(ComplexF64, 8, 3)
        for i in 1:8
            g = exp(-0.1 * (i - 4.5)^2)
            psi[i, :] .= g / sqrt(3)
        end
        psi ./= sqrt(sum(abs2, psi) * dV)
        for _ in 1:600
            apply_step!(RamanTerm(), psi, 0.01, true, ws)
            psi ./= sqrt(sum(abs2, psi) * dV)
        end
        _, _, fz = spin_density_vector(psi, ws.spin_matrices, ndims(psi) - 1)
        fzsum = sum(fz) * dV
        @test sign(fzsum) == -sign(δ)
        @test sign_oracle(RamanTerm).predicate(psi, ws)
    end
end
