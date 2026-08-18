#!/usr/bin/env julia
#
# Flux-closure DDI identity — an EXACT, F-generic anchor on the dipolar
# normalization and on the ε_dd bookkeeping.
#
# For any fully polarized, divergence-free magnetization M = μ_tot ρ n̂ (the
# flux-closure texture: spins circulating azimuthally along a torus, ∇·M = 0
# pointwise), k·M_k = 0 kills the transverse part of the dipolar kernel and only
# the −δ_αβ/3 trace piece survives:
#
#     E_ddi = −(c_dd/6) ∫|f|² dr = −(a_dd/a_s) E_s = −ε_dd E_s
#
# with a_dd = μ₀ μ_tot² m/(12πℏ²) built from the TOTAL moment μ_tot = g_F F μ_B.
# This is Eq. (S7) of Yan–Li–Saito 2026 (arXiv:2605.11670), derived there for a
# specific torus ansatz; it is in fact ansatz-independent, exact, and scale-free.
#
# WHAT THIS GATE HOLDS (name the property, don't imply more):
#   * the DDI prefactor convention `c_dd = μ₀(g_F μ_B)²` — no 4π
#   * that the F² comes from the spin OPERATORS and not from c_dd
#     (the historical Bug-3 was exactly an F²/36 factor here)
#   * the ε_dd bookkeeping: total moment in a_dd, per-unit-spin moment in c_dd
#   * `c₀ = 4π(a_s/a_ho)N`, since the gate is a RATIO of the two couplings
# WHAT IT DOES NOT HOLD:
#   * the transverse (k̂_α k̂_β) part of the kernel, which cancels identically for
#     this state. The negative control below is what exercises that part: the
#     same density with spins uniformly along z has ∇·M ≠ 0 and must NOT return
#     −ε_dd. Without it, a kernel that had lost its transverse term entirely
#     would still pass.
#
# The identity is exact on the discrete grid (the pointwise cancellation
# survives sampling), so the tolerance is roundoff, not truncation — a 1 %
# deviation here means a real prefactor error, not a resolution artifact.

using SpinorBEC
using Test

const _FC_BOX = 12.0

"Torus density r^(2λ) exp(−r²/σr² − z²/σz²) carrying either the flux-closure
texture exp(−i S_z φ)|m_y=+F⟩ or (negative control) a uniform |m=+F⟩_z."
function _fc_psi(grid::Grid{3}, F::Int; lam=1.5, sr=1.0, sz=0.87, texture::Symbol)
    n_pts = grid.config.n_points
    D = 2F + 1
    psi = zeros(ComplexF64, n_pts..., D)
    c_base = exp(-1im * (π / 2) * Matrix(spin_matrices(F).Fy))[:, 1]
    @inbounds for I in CartesianIndices(n_pts)
        x, y, z = grid.x[1][I[1]], grid.x[2][I[2]], grid.x[3][I[3]]
        r2 = x^2 + y^2
        amp = sqrt(r2^lam * exp(-r2 / sr^2 - z^2 / sz^2))
        phi = atan(y, x)
        for c in 1:D
            m = F - (c - 1)
            psi[I, c] = if texture === :flux_closure
                amp * c_base[c] * cis(-m * (phi + π / 2))
            else
                amp * (c == 1 ? 1.0 + 0.0im : 0.0im)
            end
        end
    end
    psi ./ sqrt(sum(abs2, psi) * cell_volume(grid))
end

"E_ddi / E_contact for `atom_base` re-tuned to the requested ε_dd."
function _fc_ratio(atom_base::AtomSpecies; eps_dd::Float64, n::Int, texture::Symbol,
    padding::Bool=true, N_atoms::Int=15000, omega_ref::Float64=100.0)
    F = atom_base.F
    a_s = SpinorBEC.compute_a_dd(atom_base) / eps_dd
    atom = AtomSpecies(atom_base.name, atom_base.mass, F, a_s, 0.0,
        atom_base.mu_mag, atom_base.g_F)
    a_ho = sqrt(SpinorBEC.Units.HBAR / (atom.mass * omega_ref))
    c0 = 4π * (a_s / a_ho) * N_atoms
    c_dd = SpinorBEC.compute_c_dd_dimless(atom; N_atoms=N_atoms, omega_ref=omega_ref)
    grid = make_grid(GridConfig{3}((n, n, n), (_FC_BOX, _FC_BOX, _FC_BOX)))
    ws = make_workspace(;
        grid, atom,
        interactions=InteractionParams(Dict(0 => c0)),
        zeeman=ZeemanParams(0.0, 0.0), potential=NoPotential(),
        sim_params=SimParams(; dt=1e-4, n_steps=1),
        enable_ddi=true, c_dd=c_dd, secular_ddi=false,
        ddi_padding=padding, ddi_trunc_radius=-1.0,
        psi_init=_fc_psi(grid, F; texture=texture),
    )
    e = energy_decomposition(ws)
    e.ddi / e.density
end

@testset "flux-closure DDI identity E_ddi/E_s = -eps_dd" begin
    # F=1 and F=6 (the production spin), both sides of eps_dd = 1, two grids.
    # F-independence of the ratio IS the paper's "results are qualitatively
    # independent of F" claim at the level of this identity.
    @testset "F=$(atom.F) eps_dd=$eps n=$n" for atom in (Eu151_f1_effective, Eu151),
        eps in (1.2, 0.5402), n in (32, 48)

        @test _fc_ratio(atom; eps_dd=eps, n=n, texture=:flux_closure) ≈ -eps rtol = 1e-8
    end

    # Negative control: the SAME density with spins uniformly along z has
    # div M != 0, so the transverse part of the kernel contributes and the
    # identity must break. A gate whose probe cannot fail measures nothing.
    @testset "negative control (uniform z polarization) must NOT satisfy it" begin
        for atom in (Eu151_f1_effective, Eu151)
            r = _fc_ratio(atom; eps_dd=1.2, n=32, texture=:uniform_z)
            @test !isapprox(r, -1.2; rtol=0.05)
            @test r > 0            # oblate cloud polarized along z: side-by-side, repulsive
        end
    end

    # The identity is a property of the state, not of the periodic-image
    # treatment, so it must survive the bare periodic kernel — but only to the
    # periodic-image error, which for THIS state is 3.75e-7 and is *identical* at
    # n = 32, 48 and 64 (measured). Resolution-flat is the signature of
    # wrap-around rather than truncation, and it is this small only because a
    # flux-closure texture carries no net dipole moment, so the images couple
    # weakly — a polarized cloud pays the documented 2-5 % instead. Tightening
    # this to 1e-8 fails; loosening it past 1e-5 would stop distinguishing image
    # error from a prefactor bug.
    @testset "holds unpadded to the periodic-image error, not better" begin
        for n in (32, 48, 64)
            r = _fc_ratio(Eu151; eps_dd=1.2, n=n, texture=:flux_closure, padding=false)
            @test r ≈ -1.2 rtol = 1e-5
            @test !isapprox(r, -1.2; rtol=1e-9)   # the image error is real, not zero
        end
    end
end
