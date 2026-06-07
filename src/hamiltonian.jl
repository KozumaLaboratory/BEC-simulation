# --- Hamiltonian subsystem umbrella ---
#
# Coefficient algebra + per-term kernels + integrator primitives. Files
# group by term or shared role; foundation types must already be in scope.
#
#   coefficients.jl
#       — c↔g coefficient algebra (c0/c1 contact, tensor channels, TDHFB,
#         Bogoliubov); shared by all contact-family terms
#   shared/{rotation,spin_rotation}.jl
#       — Euler 5-stage spinor rotation + rotation cache (used by DDI
#         propagator and spin_mixing); spatially uniform spin rotation
#         (used by Raman propagator, transverse Zeeman, and rotating basis)
#   terms/contact/{spin_mixing,singlet_pair,tensor_interaction}
#       — c0/c1 contact + S=0 singlet-pair + general-F tensor
#   terms/ddi/{qtensor,convolution} + apply_ddi_step + ddi_term + ddi_padded
#       — k-space DDI Q-tensor + 6-FFT convolution + Euler 5-stage spinor
#         rotation + zero-padded DDI for non-periodic geometries
#   terms/lhy/{phi_one_reg,polar_contact,polar_dipolar,fm_contact,
#              fm_dipolar,icosahedral,modes_round45,dispatch}
#       — closed-form spinor LHY tables for various spin phases
#   terms/loss/{losses} + loss_term — dipolar relaxation + ABC
#   dynamics/{sinatra_helpers,utils_resolution_sinatra}
#       — TWA validity checks + resolution suggestion utilities
#   terms/trap/{evaluate_potential} + trap_term
#       — trap evaluators and potential application
#   terms/zeeman/{accessors,zeeman_builders} + zeeman_term
#       — Zeeman accessors, builders, and HamTerm
#   terms/raman/{raman} + raman_term; shared/spin_rotation for uniform rotation
#       — Raman coupling + spatially uniform spin rotation
#   optics/{optics,laser_potential,optical_trap}
#       — Gaussian-beam optics + dipole trap builders (not HamTerms)
#   terms/light_shift/{light_shift_builders} + light_shift_term
#       — AC Stark / light shift
#   integrator/{propagators,yoshida,split_step_kernels,split_step,
#                split_step_composers,absorbing_boundary}
#       — kinetic/potential primitives, adaptive Yoshida driver,
#         Coriolis/shear/DDI GPU kernels, top-level split_step!,
#         Yoshida/Suzuki/Blanes-Moan composers, absorbing boundary condition

# Coefficient algebra (shared by contact family, TDHFB, Bogoliubov).
include("hamiltonian/coefficients.jl")
include("hamiltonian/terms/contact/spin_mixing.jl")
include("hamiltonian/terms/contact/singlet_pair.jl")
include("hamiltonian/terms/contact/tensor_interaction.jl")
include("hamiltonian/terms/ddi/qtensor.jl")
include("hamiltonian/terms/ddi/convolution.jl")
include("hamiltonian/shared/rotation.jl")
include("hamiltonian/terms/ddi/apply_ddi_step.jl")
include("hamiltonian/terms/ddi/ddi_padded.jl")
include("hamiltonian/terms/lhy/phi_one_reg.jl")
include("hamiltonian/terms/lhy/polar_contact.jl")
include("hamiltonian/terms/lhy/polar_dipolar.jl")
include("hamiltonian/terms/lhy/fm_contact.jl")
include("hamiltonian/terms/lhy/fm_dipolar.jl")
include("hamiltonian/terms/lhy/icosahedral.jl")
include("hamiltonian/terms/lhy/modes_round45.jl")
include("dynamics/sinatra_helpers.jl")
include("dynamics/utils_resolution_sinatra.jl")
include("hamiltonian/terms/lhy/dispatch.jl")
include("hamiltonian/terms/loss/losses.jl")
include("hamiltonian/integrator/absorbing_boundary.jl")

# Potentials / builders.
include("hamiltonian/terms/trap/evaluate_potential.jl")
include("hamiltonian/terms/zeeman/accessors.jl")
include("hamiltonian/terms/zeeman/zeeman_builders.jl")
include("hamiltonian/shared/spin_rotation.jl")
include("hamiltonian/terms/raman/raman.jl")
include("hamiltonian/optics/optics.jl")  # Must precede laser_potential (defines OpticalBeam)
include("hamiltonian/optics/laser_potential.jl")
include("hamiltonian/optics/optical_trap.jl")
include("hamiltonian/terms/light_shift/light_shift_builders.jl")

# HamTerm protocol (sign-bug-proof architecture, Phase 1).
# See `docs/conventions/sign_bug_proof_architecture.md`.
include("hamiltonian/terms/base.jl")
include("hamiltonian/terms/zeeman/zeeman.jl")        # LinearZeemanZ + TransverseZeeman + MagneticGradient
include("hamiltonian/terms/coriolis.jl")
include("hamiltonian/terms/kinetic.jl")
include("hamiltonian/terms/trap/trap.jl")
include("hamiltonian/terms/contact/contact.jl")       # DensityC0 + SpinC1 + Tensor
include("hamiltonian/terms/ddi/ddi_term.jl")
include("hamiltonian/terms/lhy/lhy_term.jl")
include("hamiltonian/terms/raman/raman_term.jl")
include("hamiltonian/terms/light_shift/light_shift_term.jl")
include("hamiltonian/terms/loss/loss_term.jl")
include("hamiltonian/terms/registry.jl")

# Integrators.
include("hamiltonian/integrator/propagators.jl")
include("hamiltonian/integrator/yoshida.jl")
include("hamiltonian/integrator/split_step_kernels.jl")
include("hamiltonian/integrator/dealias.jl")
include("hamiltonian/integrator/split_step.jl")
include("hamiltonian/integrator/split_step_composers.jl")
include("hamiltonian/integrator/combined_spin_step.jl")
include("hamiltonian/integrator/adaptive.jl")

# Rotating-basis (Klaus-regime) propagators + integrators. Cross-layer
# dispersal of the former src/rotating_basis/ vertical-slice subsystem.
include("hamiltonian/integrator/rotating_basis_propagators.jl")
include("hamiltonian/integrator/rotating_basis_integrators.jl")

# TDHFB local-approximation engine (channel kernel + HF / Δ kernels +
# voxel-local BdG Strang step + energy functional). YAML pipeline integration
# is deferred (see hamiltonian/tdhfb.jl docstring).
include("hamiltonian/tdhfb.jl")
