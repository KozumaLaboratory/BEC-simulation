# --- Initialization subsystem umbrella ---
#
# Atom data, ψ initialisation, workspace assembly, Thomas-Fermi profile,
# named state-zoo builders, and noise injection.
#
#   atoms             — Li7 / Na23 / Eu151 / ... + ATOM_REGISTRY
#   state_dispatch    — init_psi(state=:..., init_state_params=...)
#   make_workspace    — Workspace factory + _rebuild_workspace
#   thomas_fermi      — thomas_fermi_density + init_psi_thomas_fermi(_textured)
#   state_zoo         — 22 init_psi_<name> wrappers
#   thermal_noise     — bec_critical_temperature + add_thermal_seed(!) +
#                       add_white_noise! (IID Gaussian primitive)
#   vacuum_noise      — add_vacuum_noise (TWA-grade Wigner sampling)
#   presets           — Preset struct + eu151_preset (frozen atom/grid/
#                       interactions bundle for sweep scripts and tests)
#
# Note: foundation/binary_state.jl is loaded here (rather than from
# src/foundation.jl) because BinaryCouplings/BinaryState depend on
# Workspace, which is built in make_workspace.jl above; keeping the binary
# types loaded after Workspace satisfies that ordering.

include("initialization/atoms.jl")
include("initialization/state_dispatch.jl")
include("initialization/make_workspace.jl")
include("initialization/thomas_fermi.jl")
include("initialization/state_zoo.jl")
include("../foundation/binary_state.jl")
include("initialization/thermal_noise.jl")
include("initialization/vacuum_noise.jl")
include("initialization/presets.jl")
