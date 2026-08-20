#!/bin/bash
# TSUBAME (UGE) submit: the unit-scale energy-damping growth probe.
#
#   qsub -g tga-kozuma-kouhi -N eu334_edprobe -l h_rt=2:00:00 \
#     -v ED_NSTEP=25000 scripts/eu334/submit_ed_probe.sh
#
# `-o` must name an EXISTING directory or the job never starts.
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/
source "${EU334_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/eu334}/scripts/eu334/_preamble.sh"

export ED_NSTEP="${ED_NSTEP:-25000}"

"$SPINORBEC_TSUBAME_JULIA" --project=. scripts/eu334/ed_growth_probe.jl
