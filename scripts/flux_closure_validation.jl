# Validate the flux-closure metric ‖∇·F‖/‖∇F‖ on ANALYTICALLY-KNOWN spin textures
# (known input → known output, collapse-free — no GS solve). Each is a fully
# ferromagnetic cloud (|F|=F) with a prescribed local spin direction n̂(r):
#
#   uniform   n̂ = ẑ            ∇·F = 0   (but g≈1 ⇒ N/A: no texture to test)
#   azimuthal n̂ = φ̂ = (−y,x)/ρ  ∇·F = 0   ← THE flux-closure low-end (expect ≈0)
#   radial    n̂ = ρ̂ = ( x,y)/ρ  ∇·F = 2/ρ (expect HIGH ~0.9; this is :fl_vortex)
#   hedgehog  n̂ = r̂            ∇·F = 2/r (expect HIGH; 3D monopole)
#
# The pair (azimuthal vs radial) is the decisive test: identical construction,
# only the spin azimuth offset differs (φ̂ vs ρ̂), giving ∇·F=0 vs ∇·F≠0. A correct
# metric must read ≈0 on azimuthal and ≫0 on radial.
#
# This is the controlled complement to eu_flower_reference.jl (a real c1<0 FM+DDI
# GS, which dipolar-collapses without LHY at ≥32³ — see logs/flower_ref_32_full).
#
# Env: FX_GRID=40  FX_BOX=24.0
#   julia --project=. scripts/flux_closure_validation.jl

import SpinorBEC
using SpinorBEC: eu151_preset, spin_matrices
using LinearAlgebra: norm
using Printf
include(joinpath(@__DIR__, "phase_fingerprint_lib.jl"))

const F   = 6
const NX  = parse(Int, get(ENV, "FX_GRID", "40"))
const BOX = parse(Float64, get(ENV, "FX_BOX", "24.0"))
const GRID = eu151_preset(; n_pts=(NX, NX, NX), box=(BOX, BOX, BOX),
    trap_ratios=(1.0, 1.0, 1.0)).grid
const CTX = fp_context(GRID; box=BOX, F=F)
const SM  = spin_matrices(F)
const D   = 2F + 1

# spinor pointing along (θ,φ): Rz(φ) Ry(θ) |m=+F⟩  (same primitive as state_dispatch)
ry_col(θ) = exp(-1im * θ * Matrix(SM.Fy))[:, 1]
function coherent_spinor!(out, cθ, θ, φ)            # cθ = ry_col(θ), reused
    @inbounds for c in 1:D
        m = F - (c - 1)
        out[c] = cθ[c] * cis(-m * φ)
    end
    out
end

# Gaussian envelope so |F| is gated like a real cloud (avoid r→0 / edge artefacts)
function build(kind)
    psi = zeros(ComplexF64, NX, NX, NX, D)
    xs = collect(GRID.x[1]); ys = collect(GRID.x[2]); zs = collect(GRID.x[3])
    w = BOX / 5
    cz = ry_col(π / 2)                                # in-plane (θ=π/2) reused
    z0 = ry_col(0.0)                                  # along +z
    tmp = Vector{ComplexF64}(undef, D)
    @inbounds for k in 1:NX, j in 1:NX, i in 1:NX
        x = xs[i]; y = ys[j]; z = zs[k]
        g = exp(-(x^2 + y^2 + z^2) / (2w^2))
        ρ = hypot(x, y); r = sqrt(x^2 + y^2 + z^2)
        if kind === :uniform
            sp = z0
        elseif kind === :azimuthal                   # n̂ = φ̂  → ∇·F = 0
            sp = coherent_spinor!(tmp, cz, π / 2, atan(y, x) + π / 2)
        elseif kind === :radial                      # n̂ = ρ̂  → ∇·F = 2/ρ
            sp = coherent_spinor!(tmp, cz, π / 2, atan(y, x))
        elseif kind === :hedgehog                    # n̂ = r̂  → ∇·F = 2/r
            θp = r > 1e-9 ? acos(clamp(z / r, -1, 1)) : 0.0
            sp = coherent_spinor!(tmp, ry_col(θp), θp, atan(y, x))
        else
            error("unknown $kind")
        end
        for c in 1:D
            psi[i, j, k, c] = g * sp[c]
        end
    end
    psi
end

@printf("flux-closure metric validation on analytic textures  (grid %d^3, box %.1f)\n", NX, BOX)
@printf("%-10s %8s %8s %10s   %s\n", "texture", "|F|/F", "g", "flux-clo", "expected")
exp_map = (uniform="~0.577 density-grad floor", azimuthal="≈0  flux-closure",
    radial="HIGH ~0.9", hedgehog="HIGH")
results = NamedTuple[]
for kind in (:uniform, :azimuthal, :radial, :hedgehog)
    psi = build(kind)
    fp = fingerprint(CTX, psi)
    fc = isnan(fp.fluxclosure) ? NaN : fp.fluxclosure
    push!(results, (; kind, fp.mF, fp.coh, fc))
    @printf("%-10s %8.3f %8.3f %10s   %s\n", kind, fp.mF, fp.coh,
        isnan(fc) ? "N/A" : @sprintf("%.4f", fc), getfield(exp_map, kind))
end

println("\n--- verdict ---")
az = results[findfirst(r -> r.kind === :azimuthal, results)]
rad = results[findfirst(r -> r.kind === :radial, results)]
uni = results[findfirst(r -> r.kind === :uniform, results)]
@printf("density-gradient floor (uniform spin dir): flux=%.3f — a magnetised cloud's\n", uni.fc)
@printf("  baseline from ∇n alone; a TRUE flux-closure texture must read BELOW it.\n")
ok_low = az.fc < 0.10
ok_disc = rad.fc > 4 * max(az.fc, 1e-6)
@printf("azimuthal (∇·F=0): flux=%.4f  %s\n", az.fc, ok_low ? "✓ low-end CONFIRMED" : "✗ too high")
@printf("radial    (∇·F≠0): flux=%.4f  (%.0f× azimuthal)  %s\n", rad.fc,
    rad.fc / max(az.fc, 1e-6), ok_disc ? "✓ discriminates" : "✗ no separation")
println(ok_low && ok_disc ?
    "METRIC VALIDATED: reads ≈0 on a known flux-closure, ≫0 on a known divergent texture." :
    "METRIC NEEDS REVIEW.")
