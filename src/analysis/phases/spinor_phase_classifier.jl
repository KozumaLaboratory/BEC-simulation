# Hierarchical, data-driven phase classifier for a spinor_fingerprint.
#
# Uses the FULL fingerprint so distinguishable textures get distinct labels
# (thresholds set on known state_zoo imprints; the setting run is pinned by
# test/analysis/test_spinor_phase_classifier.jl):
#   modulation (structure factor)  → stripe / domain / lattice  ("modulated")
#   uniform bulk (coherence≈1)     → σ_S point group: polar / cyclic /
#                                     biaxial_nematic / I_h / ferromagnetic
#   textured, magnetised           → flux-closure & chirality & winding split:
#       ⟨F⟩≈0 core            → polar_core_vortex
#       |χ| large & divergent → skyrmion
#       |χ| ≠ 0               → chiral_spin_vortex
#       ∇·F ≈ 0 (fc small)    → flower           (flux-closure)
#       ∇·F large (fc big)    → radial_spin_vortex
#       else                  → ferromagnetic_textured
#
# Thresholds (validated 2026-07-24 on 32³ imprints): flower fc≈0.12, radial
# fc≈0.94, baseline 0.577; CSV χ≈0.24, skyrmion χ≈0.70; uniform coh=1.0,
# textures coh≤0.77.

export classify_spinor_phase

function classify_spinor_phase(fp;
    coh_texture::Float64=0.65,          # spinor coherence g: <0.65 = genuine spatial
    #   texture (validated imprints 0.12–0.51); ≥0.65 = uniform-DIRECTION / canting
    #   (mid-field canting continuum measured at 0.86–0.97). THIS gate is what stops
    #   the canting continuum being mislabelled a vortex/radial texture.
    fc_flux::Float64=0.45, fc_div::Float64=0.70,
    chi_chiral::Float64=0.10, chi_skyrmion::Float64=0.50,
    mF_mag::Float64=0.30, mF_fm::Float64=0.50, mod_thresh::Float64=0.30,
    inert_tol::Float64=1.0e-3,
)
    coh = fp.coh
    mF = fp.mF
    fc = fp.fluxclosure
    χ = abs(fp.chirality)
    smod = fp.spin_mod
    dmod = fp.dens_mod
    inert = fp.inert
    iscore = fp.inert_score

    # 1. strong periodic modulation (structure-factor peak) → stripe/domain/lattice
    if max(smod, dmod) > mod_thresh
        return "modulated"
    end
    # 2. spinor nearly uniform (coh≥coh_texture) ⇒ uniform-direction / CANTING, NOT a
    #    spatial texture — even if fluxclosure>0.577 (that comes from ∇n of a partial
    #    magnetisation, not a vortex). Classify by σ_S point group, else by magnitude.
    if coh >= coh_texture
        if iscore < inert_tol
            return inert === :FM ? "ferromagnetic" : String(inert)
        end
        return mF >= mF_fm ? "ferromagnetic" : "nematic_unresolved"   # canting continuum
    end
    # 3. genuinely spatially-textured spinor (coh<coh_texture): name the texture
    if mF < mF_mag
        return "polar_core_vortex"
    elseif χ >= chi_skyrmion && fc > fc_div
        return "skyrmion"
    elseif χ >= chi_chiral
        return "chiral_spin_vortex"
    elseif fc < fc_flux
        return "flower"                     # flux-closure, ∇·F≈0
    elseif fc > fc_div
        return "radial_spin_vortex"         # divergent
    else
        return "ferromagnetic_textured"
    end
end
