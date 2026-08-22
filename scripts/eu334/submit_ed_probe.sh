#!/bin/bash
# TSUBAME (UGE) submit: the unit-scale energy-damping growth probe.
#
#   qsub -g tga-kozuma-kouhi -N eu334_edprobe -l h_rt=2:00:00 \
#     -v ED_NSTEP=25000 scripts/eu334/submit_ed_probe.sh
#
# `-o` must name an EXISTING directory or the job never starts.
#
# cpu_16, not gpu_1. This probe is 24^3 — 13,824 points, 3 or 13 components —
# and it never calls a CUDA path: `ed_growth_probe.jl` does not `import CUDA`, so
# the extension is not even loaded and every arm has always run on the CPU of
# whatever node it landed on. A `gpu_1` reservation bought nothing and was
# ~7x the point cost of the CPU class it was actually using. Measured locally
# 2026-08-22: 400 steps in ~30 s, so the default 25000 steps is ~30 min per arm
# and two arms fit inside h_rt with room.
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=4:00:00
#$ -j y
#$ -o logs/tsubame/
# Declared here, one line from the `-l cpu_16=1` above, so the reservation and
# the claim cannot drift apart. The preamble asserts CUDA by default because a
# GPU job falling back to CPU looks like a slow queue; this probe has no CUDA
# path to fall back FROM.
export EU334_NO_GPU=1
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"

export ED_NSTEP="${ED_NSTEP:-25000}"
export ED_ATOM="${ED_ATOM:-rb87}"
export ED_CDD="${ED_CDD:-0.0}"
# #418's last suspect: production's reservoir corner, and the seed.
export ED_MU="${ED_MU:-3.0}"
export ED_T="${ED_T:-1.0}"
export ED_SEED="${ED_SEED:-vacuum}"
# 0 = fixed mu (every arm so far). >0 ramps MU -> that value across the run.
export ED_MU_RAMP="${ED_MU_RAMP:-0.0}"
# The last axis: scale. Defaults are the 24^3 box 10 every arm so far used.
export ED_N="${ED_N:-24}"
export ED_BOX="${ED_BOX:-10.0}"
# Noise-stream offset, so the F=6 + DDI arm can be run as an ensemble.
export ED_SEED0="${ED_SEED0:-90000}"

"$SPINORBEC_TSUBAME_JULIA" --project=. scripts/eu334/ed_growth_probe.jl
