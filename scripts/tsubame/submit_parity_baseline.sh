#!/bin/bash
#$ -cwd
#$ -l gpu_1=1
#$ -l h_rt=4:00:00
#$ -N pbase
#$ -o /gs/fs/tga-kozuma-kouhi/uk07267/logs/
#$ -e /gs/fs/tga-kozuma-kouhi/uk07267/logs/
# WHICH commit moved psi?
#
# Measured (job 8338837): within a side the GPU is bit-reproducible — before_r1
# == before_r2 and after_r1 == after_r2, psi hash included — so the across-side
# difference is NOT GPU noise. It is real, and the cutover put it there.
# Energies agree to 1e-14 on config_smoke but differ by up to 9.0e-5 (rel
# 8.5e-6) on config_c1kappa_preview_B10, and psi hashes differ nearly
# everywhere.
#
# THE MISSING POSITIVE CONTROL. The bisect walk starts at the FIRST cutover
# commit, so `origin/main` — the value every verdict is measured against — was
# never run through this probe. Its "GOOD" hash came from a different harness
# (the parity job, two checkouts, its own store layout). If the two harnesses
# disagree for a reason that has nothing to do with the cutover, every "MOVED"
# in the walk is an artifact of the instrument and means nothing.
#
# So: run origin/main and the first cutover commit through the IDENTICAL probe,
# back to back, in one job. origin/main must reproduce 4ef90c4b7d0f4145 or the
# bisect is measuring the harness.
#
# The oracle is point_020's psi hash on
# config_c1kappa_preview_B10, which showed the largest energy difference:
#     GOOD (pre-cutover) = 4ef90c4b7d0f4145
#     BAD  (HEAD)        = c196cb3dce860f34
# Deterministic within a side, so a single run per commit decides it.
set -u
export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/gs/fs/tga-kozuma-kouhi/shared/.julia}"
JULIA=/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia
ROOT=/gs/fs/tga-kozuma-kouhi/uk07267
W=$ROOT/parity_baseline
CFG=runs/eu_gs_phase_c1_B_kappa/config_c1kappa_preview_B10.yaml
GOOD_HASH=4ef90c4b7d0f4145

echo "host=$(hostname) date=$(date)"
nvidia-smi --query-gpu=name --format=csv,noheader | head -1

[ -d "$W" ] || git clone -q $ROOT/bec-ddi-conv "$W"
cd "$W"
git fetch -q $ROOT/bec-ddi-conv '+refs/remotes/origin/*:refs/remotes/origin/*' 2>/dev/null || true

probe () {   # $1 = commit ; echoes "<sha> <hash>"
    local c=$1
    git checkout -q "$c" -- . 2>/dev/null
    git checkout -q "$c" 2>/dev/null
    local store=$ROOT/baseline_store
    rm -rf "$store"
    local h
    h=$(SPINORBEC_STORE=$store $JULIA --project=. -e '
        import CUDA
        using SpinorBEC, JLD2, SHA
        try
            run_yaml(ARGS[1]; verbose=false)
        catch e
            println("THREW ", sprint(showerror, e)); exit(0)
        end
        p = joinpath(get(ENV,"SPINORBEC_STORE","runs"))
        for (root,_,fs) in walkdir(p), f in fs
            f == "point_020.jld2" || continue
            d = JLD2.load(joinpath(root,f))
            psi = get(d, "psi", nothing)
            psi === nothing && continue
            println("HASH ", bytes2hex(sha256(reinterpret(UInt8, vec(ComplexF64.(psi)))))[1:16])
        end' "$CFG" 2>&1 | grep -E '^HASH|^THREW' | head -1)
    echo "$(git rev-parse --short HEAD) ${h:-NO_OUTPUT}"
}

# Walk the range oldest-first and stop at the first commit whose hash differs
# from the pre-cutover one. Linear rather than binary: 20 commits at ~8 min is
# under the walltime, and a linear walk also shows whether the difference
# appears once and stays, or flickers — which a bisect would hide.
echo "### BASELINE: origin/main itself, through the IDENTICAL probe."
for c in $(git rev-parse origin/main) $(git rev-list --reverse origin/main..origin/feat/model-resolved-physics | head -1); do
    line=$(probe "$c")
    sha=${line%% *}; hash=${line##* }
    subj=$(git log -1 --format=%s "$c" | cut -c1-58)
    if [ "$hash" = "$GOOD_HASH" ]; then verdict=SAME; else verdict="MOVED"; fi
    printf 'BISECT %-9s %-6s %-18s %s\n' "$sha" "$verdict" "$hash" "$subj"
done

echo "ALL DONE $(date)"
