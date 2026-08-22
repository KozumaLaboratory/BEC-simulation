#!/bin/bash
# TSUBAME (UGE) submit for one `runs/saito_li_torus/cells/*.yaml` resolution cell.
#
# #376: `torus_n128_box6.yaml` was generated and never run — the local attempt
# was abandoned when a parallel session had half the GPU and it thrashed. It was
# not "tried and passed", it is absent.
#
# WHY 128³ NEEDS THIS RATHER THAN THE LOCAL CARD. One psi vector at 128³ × D=13
# in ComplexF64 is 0.41 GiB, and L-BFGS keeps 2m of them: at the default m=10
# that is 8.12 GiB of history alone, before psi, the gradient, the FFT plans and
# the DDI buffers. On a 16 GB card that is not workable; on TSUBAME's H100 it is
# comfortable at the DEFAULT m, which is what matters — the other three cells in
# this convergence set ran at the default, and changing the solver's memory for
# one point of a four-point line makes the fourth point answer a different
# question.
#
# WHAT THIS CELL CAN AND CANNOT DO. The three existing cells agree on E to seven
# digits (−1.5754124 / −1.5754124 / −1.5754118). A fourth point is corroboration.
# It is NOT the evidence for the state — #336 rests on the flux-closure identity
# (0.23 %) and the published-profile match (1.3 %), because at cancellation ratio
# R = 0.0167 an ITP answer can be grid-independent to 0.4 % and box-independent
# to 2 % while being 44 % wrong (`test/oracles/test_itp_dt_limited_advisory.jl`).
# A convergence scan is not a correctness argument here and must not be quoted as
# one.
#
# Submit:
#   qsub -g tga-kozuma-kouhi -v CELL=runs/saito_li_torus/cells/torus_n128_box6.yaml \
#        scripts/submit_saito_torus_cell.sh
#
#$ -cwd
#$ -N saito_cell
#$ -l gpu_1=1
#$ -l h_rt=12:00:00
#$ -j y
#$ -o logs/tsubame/saito_cell.$JOB_ID.log
set -euo pipefail

REPO="${SPINORBEC_TSUBAME_PROJECT_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/BEC-simulation}"
cd "$REPO"
mkdir -p logs/tsubame

export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"

source scripts/tsubame_setup.sh
# Re-arm unconditionally: a submit script must not depend on the internals of a
# file it sources.
set -euo pipefail

CELL="${CELL:?CELL=<path to a cells/*.yaml> is required}"
[ -f "$CELL" ] || { echo "FATAL: cell not found: $CELL" >&2; exit 1; }
echo "cell: $CELL"

WALL_S="${WALL_S:-43200}"                      # must match -l h_rt
BUDGET_S=$(( WALL_S * 85 / 100 ))
echo "walltime: h_rt=${WALL_S}s, self-interrupt at ${BUDGET_S}s"

JOBREC="logs/tsubame/jobrec.${JOB_ID:-local}.saito.tsv"
printf "started\t%s\tjob=%s\thost=%s\tcell=%s\n" \
    "$(date -Is)" "${JOB_ID:-none}" "$(hostname)" "$CELL" >> "$JOBREC"

set +e
timeout --signal=INT --kill-after=120 "$BUDGET_S" \
    "$JULIA" --project=. -e '
    import CUDA          # BEFORE `using SpinorBEC` — loads the CUDA extension
    using SpinorBEC
    cfg = ARGS[1]
    r = inspect_config(cfg)
    for w in r.warnings
        println("inspect[", w.severity, "] ", w.title)
    end
    blockers = filter(w -> w.severity === :error, r.warnings)
    if !isempty(blockers)
        for w in blockers
            println("BLOCKING: ", w.title, " — ", w.message)
        end
        error("pre-flight found $(length(blockers)) :error warning(s) — refusing to launch")
    end
    println("GPU: ", CUDA.name(CUDA.device()),
        "  free/total GiB: ", round.(CUDA.available_memory() / 2^30; digits=2), "/",
        round(CUDA.total_memory() / 2^30; digits=2))
    run_yaml(cfg)
' "$CELL"

RC=$?
set -e

case "$RC" in
    0)   OUTCOME="completed" ;;
    124) OUTCOME="self_interrupted_at_budget" ;;
    137) OUTCOME="killed_after_interrupt_ignored" ;;
    *)   OUTCOME="failed_rc_$RC" ;;
esac
printf "finished\t%s\trc=%s\toutcome=%s\tcell=%s\n" \
    "$(date -Is)" "$RC" "$OUTCOME" "$CELL" >> "$JOBREC"
echo "[$(date +%H:%M:%S)] $OUTCOME (rc=$RC): $CELL"
[ "$RC" -eq 0 ] || [ "$RC" -eq 124 ] || exit "$RC"
