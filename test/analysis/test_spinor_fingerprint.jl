# Oracle for the flux-closure metric and the spinor fingerprint, on
# ANALYTICALLY-KNOWN spin textures (known input → known output, no GS solve).
# Each is a ferromagnetic Gaussian cloud (|F|=F) with a prescribed local spin
# direction n̂(r):
#
#   uniform   n̂ = ẑ            ∇·F = 0   (g≈1 ⇒ flux N/A: no texture)
#   azimuthal n̂ = φ̂ = (−y,x)/ρ  ∇·F = 0   ← the flux-closure low-end (expect ≈0)
#   radial    n̂ = ρ̂ = ( x,y)/ρ  ∇·F = 2/ρ (expect HIGH; a divergent texture)
#
# azimuthal vs radial is the decisive pair: identical construction, only the spin
# azimuth offset differs (φ̂ vs ρ̂) ⇒ ∇·F=0 vs ∇·F≠0. A correct metric reads ≈0 on
# azimuthal and ≫0 on radial.

using Test
using SpinorBEC
using SpinorBEC: make_grid, GridConfig, spin_matrices, _spin_expectation_fields,
    flux_closure_fraction, spinor_coherence, spinor_fingerprint
using LinearAlgebra: norm

const F = 1
const NX = 32
const BOX = 24.0
const D = 2F + 1
const GRID = make_grid(GridConfig((NX, NX, NX), (BOX, BOX, BOX)))
const SM = spin_matrices(F)
const DX = BOX / NX

ry_col(θ) = exp(-1im * θ * Matrix(SM.Fy))[:, 1]      # Ry(θ)|m=F⟩

function coherent_spinor(cθ, φ)                        # Rz(φ) Ry(θ) |m=F⟩
    [cθ[c] * cis(-(F - (c - 1)) * φ) for c in 1:D]
end

function build_texture(kind)
    psi = zeros(ComplexF64, NX, NX, NX, D)
    xs = collect(GRID.x[1]);
    ys = collect(GRID.x[2]);
    zs = collect(GRID.x[3])
    w = BOX / 5
    cz = ry_col(π / 2)                                 # in-plane θ=π/2
    z0 = ry_col(0.0)                                   # along +z
    @inbounds for k in 1:NX, j in 1:NX, i in 1:NX
        x = xs[i];
        y = ys[j];
        z = zs[k]
        g = exp(-(x^2 + y^2 + z^2) / (2w^2))
        sp = if kind === :uniform
            z0
        elseif kind === :azimuthal                     # n̂ = φ̂  → ∇·F = 0
            coherent_spinor(cz, atan(y, x) + π / 2)
        elseif kind === :radial                        # n̂ = ρ̂  → ∇·F = 2/ρ
            coherent_spinor(cz, atan(y, x))
        else
            error("unknown $kind")
        end
        for c in 1:D
            psi[i, j, k, c] = g * sp[c]
        end
    end
    psi
end

flux_of(psi) =
    let (fx, fy, fz) = _spin_expectation_fields(psi, GRID)
        flux_closure_fraction(fx, fy, fz, DX)
    end

@testset "spinor fingerprint" begin
    @testset "flux-closure metric on analytic textures" begin
        az = flux_of(build_texture(:azimuthal))
        rad = flux_of(build_texture(:radial))
        # On a flux-closure texture the metric reads its discretization floor
        # (~0.10 at this grid; a real converged GS goes well below — the PR's
        # Flower hit 0.059). The decisive, resolution-robust property is the
        # SEPARATION from a divergent texture.
        @test az < 0.15                       # flux-closure low regime
        @test rad > 5 * az                    # ≫ on a known divergent texture (≈0.95)
    end

    @testset "named builders: flower is flux-closure, radial is not" begin
        # The named seeds must REALISE the physics they are documented as:
        # :flower → n̂=φ̂ (∇·F=0, flux-closure); :radial_spin_vortex → n̂=ρ̂
        # (∇·F=2/ρ, divergent). This pins the weak-field Eu GS default seed
        # to its validated texture and guards against the historical
        # fl_vortex mislabel (a radial texture named "flower vortex").
        sys = SpinSystem(F)
        flower = flux_of(init_psi(GRID, sys; state=:flower))
        radial = flux_of(init_psi(GRID, sys; state=:radial_spin_vortex))
        @test flower < 0.25                   # flux-closure (below 0.577 floor)
        @test radial > 3 * flower             # radial is a divergent texture
    end

    @testset "coherence: uniform vs textured" begin
        @test spinor_coherence(build_texture(:uniform), GRID) > 0.95   # ~1 uniform
        @test spinor_coherence(build_texture(:azimuthal), GRID) < 0.7  # textured
    end

    @testset "fingerprint NamedTuple is well-formed" begin
        fp = spinor_fingerprint(build_texture(:uniform), GRID, F)
        @test fp.mF ≈ 1.0 atol = 1e-6         # fully ferromagnetic bulk spinor
        @test fp.coh > 0.95
        @test isfinite(fp.Jz)
        @test length(fp.winding) == D
        @test haskey(fp, :sigma) && haskey(fp, :inert)
    end
end
