# Gates for the ungated physics-duplication clusters the 2026-06-07
# redundancy audit upheld as drift-risks. Each cluster is an independent
# production statement of a convention (a sign / orientation / spinor)
# that AGREES with its reference today but had no test pinning it — so a
# drift in either copy would pass silently. Per the freeze discipline we
# GATE (pin the copy to its reference), NOT consolidate: removing a copy
# risks deleting an independent statement, and the dumb-vs-production
# oracle independence (#3) must never drop below two implementations.
#
# Each gate is directional / parity and red-checkable: flip the copy's
# convention and the gate turns red.

using Test
using LinearAlgebra
using SpinorBEC

_fidelity(a, b) =
    abs(dot(vec(ComplexF64.(a)), vec(ComplexF64.(b)))) /
    (norm(vec(a)) * norm(vec(b)) + eps())

@testset "redundancy drift-risk gates (2026-06-07 audit)" begin

    # (c) Manuscript figure spinors vs the analysis SSoT. paper3_canonical_states
    # hand-writes each ζ inline; canonical_polyhedral_spinor(F) is the SSoT
    # (consumed by the phase classifier + Lemma-1 tests). A sign flip in the
    # manuscript copy alone (e.g. F=3 O:A_2 → O:A_1) would emit wrong figure
    # physics with no failing test. Pin them.
    @testset "(c) manuscript canonical spinors == SSoT" begin
        states = SpinorBEC.paper3_canonical_states()
        ssot_F = (2, 3, 4, 6, 8, 10, 12)
        seen = Int[]
        for (F, label, _desc, z) in states
            F in ssot_F || continue
            push!(seen, F)
            ssot = SpinorBEC.canonical_polyhedral_spinor(F)
            @testset "F=$F ($label)" begin
                @test length(z) == length(ssot)
                @test _fidelity(z, ssot) > 1 - 1e-10   # identical up to global phase
            end
        end
        for F in ssot_F
            @test F in seen   # every SSoT state is emitted by the figure
        end
    end

    # (d) init_psi state builders vs the polyhedral classifier's candidate
    # spinors. The classifier validates ζ against its OWN candidate set; if an
    # init_psi builder drifts from the candidate it is matched against, no test
    # catches it (their test universes are disjoint). Pin the F=6 cyclic and
    # biaxial members the audit flagged.
    @testset "(d) init_psi F=6 == polyhedral candidates" begin
        grid = make_grid(GridConfig{3}((4, 4, 4), (6.0, 6.0, 6.0)))
        sys = SpinSystem(6)
        cands = SpinorBEC.polyhedral_candidate_spinors(6)
        for (state, key) in ((:cyclic, :cyclic), (:biaxial_nematic, :biaxial_nematic))
            psi = init_psi(grid, sys; state=state)
            spinor = vec(psi[1, 1, 1, :])
            @testset "$state" begin
                @test haskey(cands, key)
                @test _fidelity(spinor, cands[key]) > 1 - 1e-8
            end
        end
    end

    # (a) Vortex-charge sign. extract_vortex_lines_per_m runs its own CCW
    # plaquette winding sum (charge = round(Δ/2π)); the gated sibling
    # winding_number_field uses the same convention but nothing pins the
    # vortex_extraction copy. A +1 vortex (e^{+iθ}) must extract charge +1,
    # e^{-iθ} → −1.
    @testset "(a) vortex_extraction charge sign matches winding" begin
        grid = make_grid(GridConfig{3}((16, 16, 4), (8.0, 8.0, 4.0)))
        sys = SpinSystem(1)
        D = 3
        function _vortex(sign)
            psi = zeros(ComplexF64, 16, 16, 4, D)
            for ix in 1:16, iy in 1:16, iz in 1:4
                x = grid.x[1][ix]
                y = grid.x[2][iy]
                g = exp(-(x^2 + y^2) / 4)
                psi[ix, iy, iz, 1] = (x + sign * im * y) * g  # winding = sign
            end
            psi
        end
        # out[key] = Vector of (; charge::Int, points) vortex lines.
        _charges(out) = Int[ln.charge for (_k, lines) in out for ln in lines]
        out_p = extract_vortex_lines_per_m(_vortex(+1), grid)
        out_m = extract_vortex_lines_per_m(_vortex(-1), grid)
        @test any(==(+1), _charges(out_p))
        @test !any(==(-1), _charges(out_p))
        @test any(==(-1), _charges(out_m))
        @test !any(==(+1), _charges(out_m))
    end

    # (b) monopole_charge_3d handedness. The density is
    # q = (1/4π) n̂·(∂n̂×∂n̂); its only tests use uniform textures where all
    # derivatives vanish, so a cross-product handedness flip leaves q≡0 and
    # passes. A pure hedgehog n̂=r̂ puts the whole charge at the unresolved
    # singular core (sum(q)≈0 at every resolution — verified), so instead we
    # pin the LOCAL handedness with a smooth charge-neutral texture
    # n̂ ∝ (s·x, ±s·y, 1+s·z): the central-block q is a clean definite-sign
    # signal (~±0.03), and swapping the y-gradient sign (left-handed) negates
    # it exactly. Pins the current (Berry-consistent) orientation convention.
    @testset "(b) monopole_charge_3d handedness" begin
        npts, L, s = 16, 8.0, 0.25
        grid = make_grid(GridConfig{3}((npts, npts, npts), (L, L, L)))
        function _tex(handed)
            psi = zeros(ComplexF64, npts, npts, npts, 3)
            for ix in 1:npts, iy in 1:npts, iz in 1:npts
                x = grid.x[1][ix]
                y = grid.x[2][iy]
                z = grid.x[3][iz]
                v = (s * x, handed * s * y, 1.0 + s * z)
                n = sqrt(sum(abs2, v))
                nz = v[3] / n
                θ = acos(clamp(nz, -1, 1))
                φ = atan(v[2], v[1])
                psi[ix, iy, iz, 1] = exp(-im * φ) * (1 + cos(θ)) / 2
                psi[ix, iy, iz, 2] = sin(θ) / sqrt(2)
                psi[ix, iy, iz, 3] = exp(im * φ) * (1 - cos(θ)) / 2
            end
            psi
        end
        c = npts ÷ 2
        blk = (c - 2):(c + 2)
        q_r = monopole_charge_3d(_tex(+1), grid)
        q_l = monopole_charge_3d(_tex(-1), grid)
        @test sum(q_r[blk, blk, blk]) > 0.01    # right-handed texture: q > 0
        @test sum(q_l[blk, blk, blk]) < -0.01   # handedness flip negates it
    end

    # (e) spin_texture_xy hand-rebuilds Fx/Fy from scratch instead of the
    # shared spin matrices; its only test asserts Fz>0, never Fx/Fy. Pin the
    # transverse orientation: an m=+F + m=+F−1 superposition with a real
    # relative phase has ⟨Fx⟩>0, ⟨Fy⟩=0; with an i relative phase ⟨Fy⟩>0,
    # ⟨Fx⟩=0.
    @testset "(e) spin_texture_xy Fx/Fy orientation" begin
        F = 1
        D = 2F + 1
        Nx, Ny, Nz = 6, 6, 2
        function _dyn(phase)
            ψ = zeros(ComplexF64, Nx, Ny, Nz, D)
            for ix in 1:Nx, iy in 1:Ny, iz in 1:Nz
                ψ[ix, iy, iz, 1] = 0.8          # m=+1
                ψ[ix, iy, iz, 2] = 0.6 * phase  # m=0
            end
            ψ ./= sqrt(sum(abs2, ψ))
            Dict{Symbol, Any}(
                :times => [0.0], :psi_snapshots => [ψ],
                :Lz => [0.0], :Fz => [0.0],
            )
        end
        res_x = SpinorBEC.spin_texture_xy(_dyn(1.0 + 0im); frame_idxs=[1])
        res_y = SpinorBEC.spin_texture_xy(_dyn(im); frame_idxs=[1])
        @test sum(res_x.Fx[:, :, 1]) > 1e-6      # real phase ⇒ ⟨Fx⟩ > 0
        @test abs(sum(res_x.Fy[:, :, 1])) < 1e-8 # and ⟨Fy⟩ ≈ 0
        @test sum(res_y.Fy[:, :, 1]) > 1e-6      # i phase ⇒ ⟨Fy⟩ > 0
        @test abs(sum(res_y.Fx[:, :, 1])) < 1e-8 # and ⟨Fx⟩ ≈ 0
    end
end
