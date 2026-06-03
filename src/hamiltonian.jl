# --- Hamiltonian subsystem umbrella ---
#
# Interaction kernels + scalar potentials + integrator primitives. Files
# group by topic and rely on foundation types being already in scope.
#
#   interactions/{interactions,spin_mixing,singlet_pair,tensor_interaction}
#       — c0/c1 contact + spin-mixing + S=0 singlet-pair + general-F tensor
#   interactions/ddi/{qtensor,convolution,rotation} + ddi.jl + ddi_padded.jl
#       — k-space DDI Q-tensor + 6-FFT convolution + Euler 5-stage spinor
#         rotation + zero-padded DDI for non-periodic geometries
#   interactions/lhy/{phi_one_reg,polar_contact,polar_dipolar,fm_contact,
#                     fm_dipolar,icosahedral,modes_round45,dispatch}
#       — closed-form spinor LHY tables for various spin phases
#   interactions/{losses,absorbing_boundary} — dipolar relaxation + ABC
#   dynamics/{sinatra_helpers,utils_resolution_sinatra}
#       — TWA validity checks + resolution suggestion utilities
#   potentials/{potentials,zeeman,raman,optics,laser_potential,
#                optical_trap,light_shift}
#       — trap evaluators + Zeeman + Raman coupling + Gaussian-beam optics
#         + dipole trap + AC Stark / light shift
#   integrator/{propagators,yoshida,split_step_kernels,split_step,
#                split_step_composers}
#       — kinetic/potential primitives, adaptive Yoshida driver,
#         Coriolis/shear/DDI GPU kernels, top-level split_step!,
#         Yoshida/Suzuki/Blanes-Moan composers

# Interactions.
include("hamiltonian/interactions/interactions.jl")
include("hamiltonian/interactions/spin_mixing.jl")
include("hamiltonian/interactions/singlet_pair.jl")
include("hamiltonian/interactions/tensor_interaction.jl")
include("hamiltonian/interactions/ddi/qtensor.jl")
include("hamiltonian/interactions/ddi/convolution.jl")
include("hamiltonian/interactions/ddi/rotation.jl")
include("hamiltonian/interactions/ddi.jl")
include("hamiltonian/interactions/ddi_padded.jl")
include("hamiltonian/interactions/lhy/phi_one_reg.jl")
include("hamiltonian/interactions/lhy/polar_contact.jl")
include("hamiltonian/interactions/lhy/polar_dipolar.jl")
include("hamiltonian/interactions/lhy/fm_contact.jl")
include("hamiltonian/interactions/lhy/fm_dipolar.jl")
include("hamiltonian/interactions/lhy/icosahedral.jl")
include("hamiltonian/interactions/lhy/modes_round45.jl")
include("dynamics/sinatra_helpers.jl")
include("dynamics/utils_resolution_sinatra.jl")
include("hamiltonian/interactions/lhy/dispatch.jl")
include("hamiltonian/interactions/losses.jl")
include("hamiltonian/interactions/absorbing_boundary.jl")

# Potentials.
include("hamiltonian/potentials/potentials.jl")
include("hamiltonian/potentials/zeeman.jl")
include("hamiltonian/potentials/raman.jl")
include("hamiltonian/potentials/optics.jl")  # Must precede laser_potential (defines OpticalBeam)
include("hamiltonian/potentials/laser_potential.jl")
include("hamiltonian/potentials/optical_trap.jl")
include("hamiltonian/potentials/light_shift.jl")

# HamTerm protocol (sign-bug-proof architecture, Phase 1).
# See `docs/conventions/sign_bug_proof_architecture.md`.
include("hamiltonian/terms/base.jl")
include("hamiltonian/terms/zeeman_z.jl")
include("hamiltonian/terms/zeeman_transverse.jl")
include("hamiltonian/terms/coriolis.jl")

# Integrators.
include("hamiltonian/integrator/propagators.jl")
include("hamiltonian/integrator/yoshida.jl")
include("hamiltonian/integrator/split_step_kernels.jl")
include("hamiltonian/integrator/dealias.jl")
include("hamiltonian/integrator/split_step.jl")
include("hamiltonian/integrator/split_step_composers.jl")
include("hamiltonian/integrator/combined_spin_step.jl")
include("hamiltonian/integrator/force_gradient.jl")
include("hamiltonian/integrator/adaptive.jl")

# Rotating-basis (Klaus-regime) propagators + integrators. Cross-layer
# dispersal of the former src/rotating_basis/ vertical-slice subsystem.
include("hamiltonian/integrator/rotating_basis_propagators.jl")
include("hamiltonian/integrator/rotating_basis_integrators.jl")

# TDHFB local-approximation engine (channel kernel + HF / Δ kernels +
# voxel-local BdG Strang step + energy functional). YAML pipeline integration
# is deferred (see hamiltonian/tdhfb.jl docstring).
include("hamiltonian/tdhfb.jl")
