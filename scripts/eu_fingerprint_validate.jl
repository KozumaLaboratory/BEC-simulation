# Measure spinor_fingerprint discriminators on KNOWN state_zoo imprints AND run
# the candidate phase classifier on each, so thresholds are set from data and we
# can PROVE distinguishable textures get distinct labels (no collapsing).
#
#   julia --project=. scripts/eu_fingerprint_validate.jl
#
# F=6 Eu, 32³ box=12 (phase-diagram texture scale). No solving — imprints carry
# the canonical texture by construction.

using SpinorBEC, Printf

include(joinpath(@__DIR__, "eu_phase_classifier.jl"))   # classify_spinor_phase

grid = make_grid(GridConfig((32, 32, 32), (12.0, 12.0, 12.0)))
sys = SpinSystem(6)

# (imprint state, expected phase family) — the classifier must recover each.
states = [
    (:polar, "polar"), (:cyclic, "cyclic"), (:biaxial_nematic, "biaxial_nematic"),
    (:antiferromagnetic, "antiferromagnetic"),
    (:m_plus_F, "ferromagnetic"), (:uniform, "?"), (:spin_coherent, "ferromagnetic"),
    (:flower, "flower"), (:radial_spin_vortex, "radial_spin_vortex"),
    (:chiral_spin_vortex, "chiral_spin_vortex"), (:polar_core_vortex, "polar_core_vortex"),
    (:skyrmion, "skyrmion"), (:spin_helix, "spin_helix"),
    (:magnetic_domain, "modulated"), (:vortex_lattice, "modulated"),
    (:domain_wall, "modulated"), (:axial_spin_texture, "?"),
]

@printf("%-20s %5s %5s %6s %6s %6s %6s %-14s %-16s\n",
    "state", "mF", "coh", "fluxcl", "chiral", "spinmd", "densmd", "inert", "→ CLASSIFIED")
println("-"^110)
for (st, _exp) in states
    psi = try
        init_psi(grid, sys; state=st)
    catch e
        @printf("%-20s  <init failed>\n", st);
        continue
    end
    fp = spinor_fingerprint(ComplexF64.(psi), grid, 6)
    label = classify_spinor_phase(fp)
    @printf("%-20s %5.2f %5.2f %6.3f %6.3f %6.3f %6.3f %-14s %-16s\n",
        st, fp.mF, fp.coh, fp.fluxclosure, fp.chirality,
        fp.spin_mod, fp.dens_mod, String(fp.inert), label)
end
