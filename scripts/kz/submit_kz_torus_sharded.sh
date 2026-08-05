#!/bin/bash
# Sharded toroidal-SPGPE Kibble-Zurek run. One process per shard, strided over
# trajectories; threads would race on the package's global scratch buffers.
#
# EVERY name-forming variable must appear in EVERY output path. Six jobs once
# wrote to gam_${MD}_${i}.log with gamma absent from it, so three rates
# overwrote one file per setting and only the last-started survived. The raw
# CSVs carried gamma in their tag and were intact, which is the only reason the
# run was recoverable.
#
#   qsub -g <group> -o <dir>/uge.log \
#        -v SBEC_GAMMA=0.03,SBEC_MD=full,SBEC_NTRAJ=160 submit_kz_torus_sharded.sh
#$ -cwd
#$ -N kzprod
#$ -l cpu_16=1
#$ -l h_rt=20:00:00
#$ -j y
set -eu
PROOT=/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
OUT=/gs/fs/tga-kozuma-kouhi/uk07267/runs/kz_toroidal
cd "$PROOT"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export SPINORBEC_FIGS_ROOT="$OUT"
export JULIA_NUM_THREADS=1
export SBEC_SPAN="${SBEC_SPAN:-0}"
MD="${SBEC_MD:-nd}"
NTRAJ="${SBEC_NTRAJ:-1000}"
NSHARD=16
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
echo "[kzprod] host=$(hostname) md=$MD ntraj=$NTRAJ shards=$NSHARD"
# Refuse a dirty tree. provenance records what the job READ; it cannot know
# whether that is what the submitter INTENDED. Twice in one day an rsync had not
# landed — once the remote spgpe.jl matched neither the commit nor what I believed
# I had sent, once measurement_provenance.jl was a formatter revision behind — and
# both were caught only by comparing md5s by hand.
#
# This is only enforceable because the tree is now synced with
# scripts/kz/sync_tsubame.sh (git fetch + reset --hard) rather than by rsyncing
# individual files, which left it permanently dirty. A gate that every run
# overrides is worse than no gate, so the sync method had to change first.
git fetch -q origin 2>/dev/null || true
DIRTY=$(git status --porcelain | wc -l)
BEHIND=$(git rev-list --count HEAD..origin/HEAD 2>/dev/null || echo 0)
echo "[kzprod] HEAD=$(git rev-parse --short HEAD) dirty=$DIRTY behind=$BEHIND"
git status --porcelain | head -20
if [ "${SBEC_ALLOW_DIRTY:-0}" != "1" ] && [ "$DIRTY" -ne 0 ]; then
    echo "[kzprod] FAIL: $DIRTY uncommitted change(s). A measurement from an"
    echo "[kzprod]       unrecorded tree cannot be reproduced. Commit, or set"
    echo "[kzprod]       SBEC_ALLOW_DIRTY=1 to say the mismatch is deliberate."
    exit 1
fi
echo "[kzprod] md5=$(md5sum docs/guides/figures/kz_toroidal_winding.jl | cut -d' ' -f1)"
pids=""
for i in $(seq 1 $NSHARD); do
    "$JULIA" --project=. docs/guides/figures/kz_toroidal_winding.jl \
        "gam${i}of${NSHARD}:${SBEC_GAMMA}:${MD}:${NTRAJ}${SBEC_L:+:L${SBEC_L}}" > "$OUT/gam${SBEC_GAMMA}_${MD}_L${SBEC_L:-200}_${i}.log" 2>&1 &
    pids="$pids $!"
done
fail=0
for p in $pids; do wait "$p" || fail=$((fail+1)); done
echo "[kzprod] shards done, failures=$fail"
ls -l "$OUT"/kz_torus_*${MD}_s*of${NSHARD}_raw.csv | wc -l
[ "$fail" -eq 0 ] || { echo "[kzprod] FAIL"; exit 1; }
echo "[kzprod] PASS"
