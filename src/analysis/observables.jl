# --- Observable extraction umbrella ---
#
# 546-line monolithic implementation split into 5 sub-modules
# (2026-05-11 Round 7 refactor):
#
#   observables/density_spin.jl   — total/component density, norm,
#                                    magnetization, spin density vector
#   observables/pair_amplitudes.jl — singlet A_00, channel A_SM,
#                                    integrated pair amplitude spectrum
#   observables/nematic.jl        — rank-2 nematic tensor eigenvalues +
#                                    biaxiality parameter
#   observables/multipole.jl      — rank-k multipole order parameters,
#                                    per-q spectrum, density-weighted avg
#   observables/structure.jl      — FFT structure factor + density
#                                    modulation contrast
#
# Public API is unchanged from pre-refactor; this umbrella exports
# nothing of its own — each sub-file owns its own exports.

include("observables/density_spin.jl")
include("observables/pair_amplitudes.jl")
include("observables/nematic.jl")
include("observables/multipole.jl")
include("observables/structure.jl")
