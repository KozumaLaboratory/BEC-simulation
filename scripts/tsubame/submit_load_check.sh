#!/bin/bash
#$ -cwd
#$ -l cpu_4=1
#$ -l h_rt=0:15:00
#$ -N load_check
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
source "${SPINORBEC_BENCH_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/bec-gapbench}/scripts/tsubame/_preamble.sh"
#
# Does the package LOAD? A syntax error in src/ makes every other job on the
# branch a precompile failure, and a submit script that only runs a bench will
# report it as the bench failing. Cheap, and it must pass before anything else is
# submitted.
$JULIA --project=. -e 'using SpinorBEC; println("LOADED ok  knobs=", length(SpinorBEC.ACCURACY_KNOBS))' 2>&1
echo "load_rc=$?"
# NOT `| tail`. This is a GATE, and a tail cuts the exception header — which has
# already turned a depot fault into a phantom regression once. It also breaks the
# exit code: `$?` after a pipe is the TAIL's status, so a failing gate reported 0.
$JULIA --project=. -e 'using Test; using SpinorBEC; include("test/workflow/validation/test_accuracy_knobs.jl")' 2>&1
echo "test_rc=$?"
# The preflight gate belongs here rather than only in the tier: it is CPU-only and
# under a second, and it sits in front of every ground state — a cheap gate nobody
# runs before submitting is the same as no gate.
$JULIA --project=. -e 'using Test; using SpinorBEC; include("test/workflow/validation/test_ground_state_preflight.jl")' 2>&1
echo "preflight_rc=$?"
echo "ALL DONE $(date)"
