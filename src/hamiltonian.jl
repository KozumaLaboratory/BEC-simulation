# --- Hamiltonian subsystem umbrella ---
#
# Coefficient algebra + per-term kernels + integrator primitives. Files
# group by term or shared role; foundation types must already be in scope.
#
#   coefficients.jl
#       — c↔g coefficient algebra (c0/c1 contact, tensor channels, TDHFB,
#         Bogoliubov); shared by all contact-family terms
#   terms/contact/{spin_mixing,singlet_pair,tensor_interaction}
#       — c0/c1 contact + S=0 singlet-pair + general-F tensor
#   terms/ddi/{qtensor,convolution} + rotation + apply_ddi_step + ddi_term
#       + ddi_padded
#       — k-space DDI Q-tensor + 6-FFT convolution + DDI Euler 5-stage
#         spinor rotation (the rotation cache is borrowed by spin_mixing) +
#         zero-padded DDI for non-periodic geometries.
#         The spatially-uniform spin rotation primitive
#         (apply_uniform_spin_rotation!, used by transverse Zeeman / Raman /
#         rotating basis) lives in foundation/spinor_utils/uniform_rotation.jl.
#   terms/lhy/{phi_one_reg,polar_contact,polar_dipolar,fm_contact,
#              fm_dipolar,icosahedral,modes_round45,dispatch,full_bdg}
#       — closed-form spinor LHY tables for various spin phases, plus the
#         general-spinor BdG zero-point integral (full_bdg) they gate
#   terms/loss (engine + LossTerm) — dipolar relaxation + ABC
#   terms/trap/{evaluate_potential} + trap_term
#       — trap evaluators and potential application
#   terms/zeeman (accessors + builders + ZeemanTerm) + magnetic_gradient
#       — Zeeman accessors, builders, and HamTerm
#   terms/raman (engine + RamanTerm)
#       — Raman coupling (uniform spin rotation from foundation)
#   terms/trap/{laser_potential,optical_trap}
#       — dipole-trap potentials built on foundation's Gaussian-beam model
#         (OpticalBeam in foundation/optics.jl); these are AbstractPotentials,
#         not HamTerms
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
include("hamiltonian/terms/ddi/rotation.jl")
include("hamiltonian/terms/ddi/apply_ddi_step.jl")
include("hamiltonian/terms/ddi/ddi_padded.jl")
include("hamiltonian/terms/lhy/phi_one_reg.jl")
include("hamiltonian/terms/lhy/polar_contact.jl")
include("hamiltonian/terms/lhy/polar_dipolar.jl")
include("hamiltonian/terms/lhy/fm_contact.jl")
include("hamiltonian/terms/lhy/fm_dipolar.jl")
include("hamiltonian/terms/lhy/icosahedral.jl")
include("hamiltonian/terms/lhy/modes_round45.jl")
include("hamiltonian/terms/lhy/dispatch.jl")
include("hamiltonian/terms/lhy/full_bdg.jl")
include("hamiltonian/terms/lhy/spatial_spin_step.jl")
include("hamiltonian/terms/lhy/spatial.jl")
include("hamiltonian/integrator/absorbing_boundary.jl")

# Potentials / builders. Dipole-trap potentials build on the Gaussian-beam
# model (OpticalBeam) defined in foundation/optics.jl.
include("hamiltonian/terms/trap/evaluate_potential.jl")
include("hamiltonian/terms/trap/laser_potential.jl")   # LaserBeamPotential (full Gaussian-beam dipole trap)
include("hamiltonian/terms/trap/optical_trap.jl")       # GaussianBeam + CrossedDipoleTrap
include("hamiltonian/terms/light_shift/light_shift_builders.jl")

# HamTerm protocol (sign-bug-proof architecture, Phase 1).
# See `docs/conventions/sign_bug_proof_architecture.md`.
include("hamiltonian/terms/base.jl")
include("hamiltonian/terms/zeeman.jl")               # accessors + builders + ZeemanTerm
include("hamiltonian/terms/magnetic_gradient.jl")    # MagneticGradientTerm (spin-independent tilt)
include("hamiltonian/terms/spatial_zeeman.jl")       # SpatialZeemanField + per-voxel kernel (arbitrary B(r))
include("hamiltonian/terms/coriolis.jl")
include("hamiltonian/terms/kinetic.jl")
include("hamiltonian/terms/trap/trap.jl")
include("hamiltonian/terms/contact/contact.jl")       # DensityC0 + SpinC1 + Tensor
include("hamiltonian/terms/ddi/ddi_term.jl")
include("hamiltonian/terms/lhy/lhy_term.jl")
include("hamiltonian/terms/raman.jl")                # engine + RamanTerm
include("hamiltonian/terms/light_shift/light_shift_term.jl")
include("hamiltonian/terms/loss.jl")                 # engine + LossTerm
include("hamiltonian/terms/registry.jl")

# Integrators.
include("hamiltonian/integrator/propagators.jl")
include("hamiltonian/integrator/yoshida.jl")
include("hamiltonian/integrator/split_step_kernels.jl")
include("hamiltonian/integrator/dealias.jl")
include("hamiltonian/integrator/spin_chain.jl")
include("hamiltonian/integrator/split_step.jl")
include("hamiltonian/integrator/split_step_composers.jl")
include("hamiltonian/integrator/rk4ip.jl")  # 4th-order RK in the interaction picture
include("hamiltonian/integrator/combined_spin_step.jl")
include("hamiltonian/integrator/adaptive.jl")

# TDHFB local-approximation engine (channel kernel + HF / Δ kernels +
# voxel-local BdG Strang step + energy functional). YAML pipeline integration
# is deferred (see hamiltonian/tdhfb.jl docstring).
include("hamiltonian/tdhfb.jl")
