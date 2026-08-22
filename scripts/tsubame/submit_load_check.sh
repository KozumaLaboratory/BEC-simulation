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
WORST=0

$JULIA --project=. -e 'using SpinorBEC; println("LOADED ok  knobs=", length(SpinorBEC.ACCURACY_KNOBS))' 2>&1
load_rc=$?; echo "load_rc=$load_rc"; [ "$load_rc" -eq 0 ] || WORST=$load_rc
# NOT `| tail`. This is a GATE, and a tail cuts the exception header — which has
# already turned a depot fault into a phantom regression once. It also breaks the
# exit code: `$?` after a pipe is the TAIL's status, so a failing gate reported 0.
$JULIA --project=. -e 'using Test; using SpinorBEC; include("test/workflow/validation/test_accuracy_knobs.jl")' 2>&1
test_rc=$?; echo "test_rc=$test_rc"; [ "$test_rc" -eq 0 ] || WORST=$test_rc
# The preflight gate belongs here rather than only in the tier: it is CPU-only and
# under a second, and it sits in front of every ground state — a cheap gate nobody
# runs before submitting is the same as no gate.
$JULIA --project=. -e 'using Test; using SpinorBEC; include("test/workflow/validation/test_ground_state_preflight.jl")' 2>&1
preflight_rc=$?; echo "preflight_rc=$preflight_rc"; [ "$preflight_rc" -eq 0 ] || WORST=$preflight_rc

echo "ALL DONE $(date)  worst_rc=$WORST"
# EVERY stage runs (a load failure and a gate failure are different diagnoses and
# both are wanted in one job), but the JOB's status is the worst of them. Ending
# on `echo` reported exit_status 0 for a failed gate, which is the shape that
# covered two failures with GREENs on 2026-08-08.
exit "$WORST"
