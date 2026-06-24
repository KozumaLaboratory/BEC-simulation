# Identify the PHASE of a converged GS rigorously, beyond the ⟨F⟩-only label.
# Extracts the bulk spinor (peak-density voxel + density-weighted average) and
# runs the polyhedral / Majorana classifier (σ_S fingerprint vs canonical inert
# spinors: polar / FM / cyclic / biaxial_nematic / I_h). For F=6 the phase IS the
# Majorana-star point group, not the magnetisation.
#
# Env: CG_IN=figs/truegs_conv/truegs_state.jld2
#   julia --project=. scripts/eu_classify_gs.jl

using SpinorBEC: load_state, classify_polyhedral, polyhedral_fingerprint,
    majorana_stars, eu151_preset
using LinearAlgebra: norm
using Printf

const IN = get(ENV, "CG_IN", "figs/truegs_conv/truegs_state.jld2")
st = load_state(IN)
psi = Array{ComplexF64}(st.psi)
D = size(psi, 4); F = (D - 1) ÷ 2
NX = size(psi, 1)

dens = dropdims(sum(abs2, psi; dims=4); dims=4)
pk = argmax(dens)                                  # peak-density voxel
zeta_peak = ComplexF64[psi[pk, c] for c in 1:D]
zeta_peak ./= norm(zeta_peak)

# density-weighted average spinor (coherent bulk order)
zeta_avg = zeros(ComplexF64, D)
@inbounds for I in CartesianIndices(dens), c in 1:D
    zeta_avg[c] += psi[I, c] * dens[I]
end
zeta_avg ./= norm(zeta_avg)

@printf("classify GS: %s  grid=%d^3  F=%d\n", IN, NX, F)
for (name, z) in (("peak-density spinor", zeta_peak), ("density-weighted avg", zeta_avg))
    r = classify_polyhedral(z, F)
    @printf("\n[%s]\n  best=%s  score=%.4f\n", name, r.best, r.score)
    print("  distances: ")
    for (lab, d) in sort(collect(r.candidate_distances); by=x -> x[2])
        @printf("%s=%.3f  ", lab, d)
    end
    println()
    stars = majorana_stars(z, F)
    @printf("  Majorana stars (%d): ", length(stars))
    for s in stars
        @printf("(%.2f%+.2fi) ", real(s), imag(s))
    end
    println()
end
println("\nNOTE: small score ⇒ close to that canonical inert phase; large/:unknown ⇒")
println("textured/mixed (not a clean inert spinor). Peak vs avg differing ⇒ spatial texture.")
