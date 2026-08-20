#!/bin/bash
# TSUBAME (UGE) submit: the FFTW thread × grid RSS sweep for #407.
#
#   qsub -g tga-kozuma-kouhi -N fftwprobe scripts/klaus2022/submit_fftw_probe.sh
#
# cpu_16, because the ANOMALY IS THE ALLOCATION: 16 cores of a 384-core node is
# exactly the configuration where a library reading /proc/cpuinfo instead of the
# cgroup over-allocates by 24×. Running this on a whole node would remove the
# very asymmetry being measured.
#$ -cwd
#$ -l cpu_16=1
#$ -l h_rt=2:00:00
#$ -j y
#$ -o logs/tsubame/
set -euo pipefail

ROOT="${FP_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/iss408}"
export SPINORBEC_TSUBAME_JULIA="${SPINORBEC_TSUBAME_JULIA:-/gs/fs/tga-kozuma-kouhi/shared/.juliaup/bin/julia}"
JULIA="$SPINORBEC_TSUBAME_JULIA"
export JULIA_DEPOT_PATH="${T4_TMPDIR:-/tmp}/.julia:/gs/fs/tga-kozuma-kouhi/shared/.julia"
export JULIAUP_DEPOT_PATH=/gs/fs/tga-kozuma-kouhi/shared/.juliaup
cd "$ROOT"
mkdir -p logs/tsubame

echo "host=$(hostname) date=$(date) pwd=$(pwd)"
echo "commit=$(git rev-parse --short HEAD)"
echo "nproc=$(nproc)  /proc/cpuinfo=$(grep -c ^processor /proc/cpuinfo)  affinity=$(taskset -pc $$ 2>/dev/null || echo n/a)"
echo "NSLOTS=${NSLOTS:-unset}  OMP_NUM_THREADS=${OMP_NUM_THREADS:-unset}"

# ONE PROCESS PER POINT. `ru_maxrss` is a high-water mark, so two sizes in one
# process report the larger twice — and WHERE the peak sits is the question.
#
# The size list is chosen by FACTORISATION, not by a uniform stride:
#   64,128 = 2^k          (pure power of two, the "cheap" end of #405's table)
#   48,96  = 2^k·3        (the size that died)
#   80     = 2^4·5
#   54     = 2·3^3        (mixed radix, small)
#   50     = 2·5^2
#   98     = 2·7^2        (largest prime factor 7 — FFTW's worst supported radix)
# If RSS tracks the largest prime factor rather than n, "19× bigger, 32× less
# memory" is arithmetic and not a paradox.
SIZES="${FP_SIZES:-48 50 54 64 80 96 98 128}"
THREADS="${FP_THREAD_LIST:-1 4 16}"
FLAGLIST="${FP_FLAG_LIST:-measure estimate}"

for fl in $FLAGLIST; do
  for th in $THREADS; do
    for n in $SIZES; do
      # A row that dies (SIGKILL on RSS) must be VISIBLE as a dead row, not as a
      # gap — `|| echo` turns the OOM into a datum instead of into silence, and
      # the sweep continues.
      FP_N=$n FP_THREADS=$th FP_FLAGS=$fl \
        "$JULIA" --project=. scripts/klaus2022/fftw_thread_probe.jl \
        || echo "PROBE n=$n threads=$th flags=$fl DIED rc=$?"
    done
  done
done

# The taskset arm: #407's own hypothesis, tested directly. If narrowing the
# VISIBLE cpu set (without changing the allocation, which is already 16) fixes
# the 48³ × 16 case, the library is reading the node and not the cgroup.
echo "=== taskset arm (visible CPUs forced to 16) ==="
for n in 48 96 128; do
  FP_N=$n FP_THREADS=16 FP_FLAGS=measure \
    taskset -c 0-15 "$JULIA" --project=. scripts/klaus2022/fftw_thread_probe.jl \
    || echo "PROBE-TASKSET n=$n DIED rc=$?"
done

# And the package's own plan builder at the two ends, to separate "FFTW does
# this" from "our use of FFTW does this". Loading SpinorBEC is kept out of the
# sweep above so its JIT and allocations do not pollute the RSS column.
echo "=== SpinorBEC make_fft_plans arm ==="
for n in 48 128; do
  for th in 1 16; do
    FP_N=$n FP_THREADS=$th "$JULIA" --project=. -e '
      using FFTW, Printf, SpinorBEC
      n  = parse(Int, ENV["FP_N"]); th = parse(Int, ENV["FP_THREADS"])
      FFTW.set_num_threads(th)
      rss0 = Sys.maxrss()/2^30
      grid = make_grid(GridConfig((n,n,n), (24.0,24.0,24.0)))
      t0 = time(); plans = make_fft_plans(grid.config.n_points); t = time()-t0
      @printf("PROBE-SB n=%-4d threads=%-3d make_fft_plans=%8.2fs rss=%7.3fGB (after-load %6.3fGB)\n",
              n, th, t, Sys.maxrss()/2^30, rss0)
    ' || echo "PROBE-SB n=$n threads=$th DIED rc=$?"
  done
done

echo "=== done $(date) ==="
