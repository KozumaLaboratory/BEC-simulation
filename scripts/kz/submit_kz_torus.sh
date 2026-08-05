#$ -cwd
#$ -N kztorus
#$ -l cpu_16=1
#$ -l h_rt=4:00:00
#$ -j y
set -eu
PROOT=/gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
OUT=/gs/fs/tga-kozuma-kouhi/uk07267/runs/kz_toroidal
cd "$PROOT"
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
export SPINORBEC_FIGS_ROOT="$OUT"
MODE="${SBEC_MODE:-smoke}"
echo "[kztorus] host=$(hostname) mode=$MODE"
echo "[kztorus] md5=$(md5sum docs/guides/figures/kz_toroidal_winding.jl | cut -d' ' -f1)"
git status --porcelain | head -5
/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia --project=. \
    docs/guides/figures/kz_toroidal_winding.jl "$MODE"
