# Hierarchical, data-driven phase classifier for a spinor_fingerprint.
#
# Uses the FULL fingerprint so distinguishable textures get distinct labels
# (thresholds set from scripts/eu_fingerprint_validate.jl on known imprints):
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

function classify_spinor_phase(fp;
    coh_uniform::Float64=0.95, coh_flower::Float64=0.35,
    fc_flux::Float64=0.45, fc_div::Float64=0.70,
    chi_chiral::Float64=0.10, chi_skyrmion::Float64=0.50,
    mF_mag::Float64=0.30, mod_thresh::Float64=0.30,
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
    # 2. spatially uniform bulk → point group by σ_S (rotation-invariant)
    if coh >= coh_uniform
        if iscore < inert_tol
            return inert === :FM ? "ferromagnetic" : String(inert)
        end
        return mF < mF_mag ? "nematic_unresolved" : "ferromagnetic"
    end
    # 3. spatially textured, magnetised
    if mF < mF_mag
        return "polar_core_vortex"
    elseif χ >= chi_skyrmion && fc > fc_div
        return "skyrmion"
    elseif χ >= chi_chiral
        return "chiral_spin_vortex"
    elseif coh < coh_flower && fc < fc_flux
        return "flower"                     # strongly-textured flux-closure
    elseif fc > fc_div
        return "radial_spin_vortex"
    else
        return "ferromagnetic_textured"     # textured FM, not cleanly flower/radial
    end
end
