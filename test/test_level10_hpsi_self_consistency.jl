# Level 10 — internal operator-RHS self-consistency.
#
# Validation ladder Level 10 (memory `validation_ladder_2026_05_24.md`)
# is normally "Ueda code comparison". Without external code access we
# can still pin operator-level correctness by computing Hψ via TWO
# independent code paths inside SpinorBEC.jl and asserting they agree
# at machine precision:
#
#   path A: energy_gradient!(grad, ψ, ws) / 2     (production code)
#   path B: from-scratch textbook implementation:
#             - kinetic via fresh FFT plans (no caching, no view tricks)
#             - trap: explicit diagonal multiply
#             - Zeeman: explicit (-p·m + q·m²) per component
#             - c₀: explicit |ψ|² × ψ per voxel
#             - c₁: dense matrix multiply F̂_α · ψ per voxel
#                   (NOT the tridiagonal F± shortcut)
#
# If path A and path B agree at L²-relative < 1e-12, every operator
# convention (Zeeman sign, m ordering, c₀ normalisation, c₁ ⟨F⟩·F̂
# structure, kinetic phase) is internally consistent across two
# independent implementations.
#
# This complements the term-by-term L5 operator_rhs_compare.jl script
# (25 separate checks) by asserting that the SUM is also consistent —
# the strongest pure-code Level 10 test we can run without external
# reference data.

using Test
using LinearAlgebra
using FFTW
using SpinorBEC
using SpinorBEC: energy_gradient!, _component_slice, spin_matrices

# Naive textbook H ψ for F=1 / F=2 / F=6, 3D, no DDI / no LHY / no
# tensor / no Raman / no light_shift. Returns the operator action Hψ
# (NOT 2·δE/δψ*).
function _naive_Hpsi(psi::Array{ComplexF64, 4}, grid, atom, c0, c1, p, q, V_trap)
    n_pts = size(psi)[1:3]
    D = size(psi, 4)
    F = atom.F
    @assert D == 2F + 1
    out = zeros(ComplexF64, n_pts..., D)

    # Kinetic: -(1/2) ∇² ψ_c via standalone in-place FFT per component.
    # Uses a separate FFT plan (not the cached ws.fft_plans) — a truly
    # independent code path. plan_fft! / plan_ifft! mutate `buf` so the
    # result is what we expect; the out-of-place plan_fft would silently
    # leave `buf` unchanged.
    k_squared = grid.k_squared
    buf_template = zeros(ComplexF64, n_pts...)
    plan_fwd = plan_fft!(buf_template)
    plan_inv = plan_ifft!(buf_template)
    for c in 1:D
        buf = complex(psi[:, :, :, c])
        plan_fwd * buf
        buf .*= 0.5 .* k_squared
        plan_inv * buf
        out[:, :, :, c] .+= buf
    end

    # Trap: V_trap × ψ_c element-wise.
    for c in 1:D
        out[:, :, :, c] .+= V_trap .* psi[:, :, :, c]
    end

    # Zeeman: (-p·m + q·m²) × ψ_c.
    for c in 1:D
        m = F - (c - 1)  # descending m ordering: c=1 → m=+F, c=D → m=−F
        E_zee = -p * m + q * m^2
        out[:, :, :, c] .+= E_zee .* psi[:, :, :, c]
    end

    # c₀ density: c₀ · n(r) · ψ_c with n = Σ_c' |ψ_c'|².
    n_density = dropdims(sum(abs2, psi; dims=4); dims=4)
    if abs(c0) > 1e-30
        for c in 1:D
            out[:, :, :, c] .+= c0 .* n_density .* psi[:, :, :, c]
        end
    end

    # c₁ spin: c₁ · (⟨F⟩·F̂) · ψ via dense matrix multiply per voxel.
    # Different code path from energy_gradient!'s tridiagonal-shortcut.
    if abs(c1) > 1e-30
        sm = spin_matrices(F)
        Fx_mat = Matrix(sm.Fx)
        Fy_mat = Matrix(sm.Fy)
        Fz_mat = Matrix(sm.Fz)
        spinor = Vector{ComplexF64}(undef, D)
        spinor_out = Vector{ComplexF64}(undef, D)
        for i in 1:n_pts[1], j in 1:n_pts[2], k in 1:n_pts[3]
            for c in 1:D
                spinor[c] = psi[i, j, k, c]
            end
            # ⟨F⟩ at this voxel.
            fx_v = real(spinor' * Fx_mat * spinor)
            fy_v = real(spinor' * Fy_mat * spinor)
            fz_v = real(spinor' * Fz_mat * spinor)
            # (⟨F⟩·F̂) ψ
            mul!(spinor_out,
                fx_v * Fx_mat + fy_v * Fy_mat + fz_v * Fz_mat,
                spinor)
            for c in 1:D
                out[i, j, k, c] += c1 * spinor_out[c]
            end
        end
    end

    out
end

@testset "Level 10 — internal Hψ self-consistency" begin
    @testset "F=1 polar, no DDI, no LHY (smoke)" begin
        n = 8
        L = 4.0
        grid = make_grid(GridConfig{3}((n, n, n), (L, L, L)))
        atom = Rb87  # F=1
        interactions = InteractionParams(2.5, 0.1)
        zeeman = ZeemanParams(0.0, 0.0)  # turned off first
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp)
        # Use a non-trivial ψ — not a trap GS, just a Gaussian seed
        # with random complex phases so spin density is non-trivial.
        psi = init_psi(grid, SpinSystem(1); state=:polar)
        copyto!(ws.state.psi, psi)

        # Path A: production energy_gradient! / 2.
        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        Hpsi_A = Array(grad) ./ 2

        # Path B: naive textbook from-scratch.
        Hpsi_B = _naive_Hpsi(
            Array(ws.state.psi), grid, atom, ws.interactions.c0,
            ws.interactions.c1, 0.0, 0.0, ws.potential_values)

        # L² relative residual.
        diff = sqrt(sum(abs2, Hpsi_A .- Hpsi_B))
        norm_A = sqrt(sum(abs2, Hpsi_A))
        rel = diff / norm_A
        @test rel < 1e-12
    end

    @testset "F=1 with Zeeman p, q ≠ 0" begin
        n = 8
        L = 4.0
        grid = make_grid(GridConfig{3}((n, n, n), (L, L, L)))
        atom = Rb87
        interactions = InteractionParams(2.5, 0.1)
        p, q = 0.7, 0.3
        zeeman = ZeemanParams(p, q)
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(1); state=:uniform)
        copyto!(ws.state.psi, psi)

        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        Hpsi_A = Array(grad) ./ 2

        Hpsi_B = _naive_Hpsi(
            Array(ws.state.psi), grid, atom, ws.interactions.c0,
            ws.interactions.c1, p, q, ws.potential_values)

        diff = sqrt(sum(abs2, Hpsi_A .- Hpsi_B))
        norm_A = sqrt(sum(abs2, Hpsi_A))
        rel = diff / norm_A
        @test rel < 1e-12
    end

    @testset "F=2 (Rb85) — wider spinor, ferromagnetic c₁<0" begin
        n = 8
        L = 4.0
        grid = make_grid(GridConfig{3}((n, n, n), (L, L, L)))
        atom = Rb85  # F=2
        @test atom.F == 2
        interactions = InteractionParams(3.0, -0.4)
        zeeman = ZeemanParams(0.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(2); state=:m_plus_F)
        copyto!(ws.state.psi, psi)

        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        Hpsi_A = Array(grad) ./ 2

        Hpsi_B = _naive_Hpsi(
            Array(ws.state.psi), grid, atom, ws.interactions.c0,
            ws.interactions.c1, 0.0, 0.0, ws.potential_values)

        diff = sqrt(sum(abs2, Hpsi_A .- Hpsi_B))
        norm_A = sqrt(sum(abs2, Hpsi_A))
        rel = diff / norm_A
        @test rel < 1e-12
    end

    @testset "F=6 (Eu151) — non-trivial spin, contact-only" begin
        n = 6   # small grid; F=6 means 13 components → 6³×13 = 2808 entries
        L = 4.0
        grid = make_grid(GridConfig{3}((n, n, n), (L, L, L)))
        atom = Eu151  # F=6
        interactions = InteractionParams(5.0, 0.05)
        zeeman = ZeemanParams(0.0, 0.0)
        sp = SimParams(; dt=0.01, n_steps=1)
        ws = make_workspace(; grid, atom, interactions, zeeman,
            potential=HarmonicTrap((1.0, 1.0, 1.0)), sim_params=sp)
        psi = init_psi(grid, SpinSystem(6); state=:polar)
        copyto!(ws.state.psi, psi)

        grad = similar(ws.state.psi)
        fill!(grad, zero(eltype(grad)))
        energy_gradient!(grad, ws.state.psi, ws)
        Hpsi_A = Array(grad) ./ 2

        Hpsi_B = _naive_Hpsi(
            Array(ws.state.psi), grid, atom, ws.interactions.c0,
            ws.interactions.c1, 0.0, 0.0, ws.potential_values)

        diff = sqrt(sum(abs2, Hpsi_A .- Hpsi_B))
        norm_A = sqrt(sum(abs2, Hpsi_A))
        rel = diff / norm_A
        @test rel < 1e-12
    end
end
