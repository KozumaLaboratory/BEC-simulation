#$ -cwd
#$ -N mdamplong
#$ -l cpu_16=1
#$ -l h_rt=10:00:00
#$ -j y
set -eu
cd /gs/fs/tga-kozuma-kouhi/uk07267/spgpe_evap
export JULIA_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.julia
/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia --project=. scripts/kz/mdamp_long.jl
