#!/bin/bash
# 64^3 long-time ENDPOINT ensemble — closes `edh-longtime-endpoint-ordering-unresolved`.
#
# WHAT IT ANSWERS, and nothing else: at a 100 omega_ref^-1 hold, does the static
# weakened trap beat no-intervention AT THE ENDPOINT? The PEAK ordering is already
# established (static 0.49081 > rotating 0.40102 > baseline 0.37973, gaps 35-100x
# the seed scatter) and no result here can move it.
#
# WHY AN ENSEMBLE AND NOT A FINER GRID. 64^3 IS the refined grid. What is missing
# is n: the static arm's endpoint moves 34.2 % between two seeds while its peak
# stays identical to five decimals. A third resolution would answer a question
# nobody asked.
#
# SIZING, fixed before launch (do not re-fit it afterwards):
#   measured static endpoint sd = 0.0658 (n = 2, one degree of freedom)
#   difference of means vs the single baseline point = 0.0750
#   SE_diff = sd * sqrt(2/n)  =>  n = 7 reaches 2 sigma, n = 8 gives margin
#   FEWER THAN 7 PER ARM CANNOT ANSWER THE QUESTION. Do not run a cheaper version.
#
# REJECTION CRITERION, fixed before launch:
#   ESTABLISHED      |mean(static) - mean(baseline)| >= 2 * SE_diff, with the sd
#                    POOLED FROM THESE RUNS, not the n = 2 estimate above.
#   NOT ESTABLISHED  otherwise. The ledger row stays `open`, the measured SE is
#                    reported, and if the pooled sd is much larger than 0.0658 we
#                    say what n it would need instead of quietly declaring a
#                    trend.
#
# COST, so nobody launches this without seeing it: 20 arms x cpu_16 x ~5 h actual
# / 8 h reserved = 0.060 * 20 * (0.7*5 + 0.1*8) = ~5.2 points. On 2026-08-21 the
# group balance was 19.24, i.e. this is ~27 % of it, with another session
# spending concurrently. It was NOT launched on that date for exactly that
# reason. Check `t4-user-info group point` before submitting.
#
# ONE ARM PER TASK. A shard that dies on walltime must not take completed
# neighbours with it, and `run_yaml` already skips finished points on re-run, so
# a resubmit costs only what actually failed.
#
# Submit (from the TSUBAME worktree root):
#   qsub -g tga-kozuma-kouhi -t 1-20 scripts/submit_lt64_endpoint_ensemble.sh
# Smoke first — ONE arm, short wall, and EXPECT IT TO BE KILLED at 20 min:
#   qsub -g tga-kozuma-kouhi -t 1-1 -l h_rt=0:20:00 \
#        scripts/submit_lt64_endpoint_ensemble.sh
#   There is no --smoke flag. `cli.jl launch` takes [<batch>] <run_name> and
#   `run_yaml` takes no point selection; a first draft of this script invoked
#   both with flags that do not exist. A short-wall kill is the smoke: it proves
#   the config compiles, the 64^3 grid allocates and the first snapshots land. It
#   does NOT prove an arm finishes — the local 64^3 arms ran 3.8-4.9 h.
#
#$ -cwd
#$ -N lt64_ens
#$ -l cpu_16=1
#$ -l h_rt=8:00:00
#$ -j y
#$ -o logs/tsubame/lt64_ens.$TASK_ID.log
set -euo pipefail

REPO="${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}"
JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"
export JULIA_DEPOT_PATH="${SPINORBEC_TSUBAME_DEPOT:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"

# TSUBAME 4 HAS NO `julia` MODULEFILE. `module load julia` fails and
# `tsubame_setup.sh` swallows it, so point at the binary and check it exists here
# rather than discovering the absence three hours into a job array.
[ -x "$JULIA" ] || { echo "no julia at $JULIA"; exit 1; }
cd "$REPO"

# TASK_ID -> ONE config. 8 baseline + 8 static + 4 rotating = 20.
# One arm per file because `run_yaml` has no point selection: it runs a whole
# `scan:` and skips points already on disk, so a seed scan cannot be split
# across array tasks.
T="${SGE_TASK_ID:-1}"
DIR=runs/klaus_quench_long_time_ensemble
# Built group by group. `ls a* b* c*` sorts ALL matches together, which would
# put `rotating` before `static` alphabetically and silently contradict the
# 1-8 / 9-16 / 17-20 mapping documented above. Every arm still runs either way —
# but a log line naming the wrong arm is how a result gets attributed to the
# wrong one.
CFGS=()
for arm in baseline static rotating; do
    for f in "$DIR"/lt64_ens_${arm}_s*.yaml; do CFGS+=("$f"); done
done

# The count is asserted, not assumed. A glob that matched 19 files would run a
# silently smaller ensemble and n < 7 cannot answer the question at all.
[ "${#CFGS[@]}" -eq 20 ] || { echo "expected 20 configs, found ${#CFGS[@]}"; exit 1; }
[ "$T" -ge 1 ] && [ "$T" -le 20 ] || { echo "task $T is outside 1-20"; exit 1; }

CFG_PATH="${CFGS[$((T - 1))]}"
echo "task $T -> $CFG_PATH   ($(date -Is))"
mkdir -p logs/tsubame

# `run_yaml` is resumable: it skips any point already on disk, so resubmitting
# after a walltime kill re-runs only what did not finish. There is no --smoke and
# no --only-point; see README.md in the config directory.
set +e
"$JULIA" --project=. -e 'using SpinorBEC; run_yaml(ARGS[1])' "$CFG_PATH"
RC=$?
set -e
echo "task $T rc=$RC   ($(date -Is))"
exit $RC
