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

# The long-lived klaus2022 campaign worktree, not the scratch one #407 was run
# from — that one was removed after the campaign.
ROOT="${FP_ROOT:-/gs/fs/tga-kozuma-kouhi/uk07267/klaus2022}"
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
# JULIA -t IS AN AXIS, and leaving it out is what made the first pass of this
# probe report a flat 0.27 GB everywhere. The failing configuration in
# `submit_stripes.sh`'s table is `julia -t 16` WITH FFTW at 16; its own control
# row holds `julia -t 16` fixed and moves only FFTW. A probe run at `-t 1`
# therefore never visits the corner, and its uniform null is a statement about
# a configuration nobody ran.
JTLIST="${FP_JT_LIST:-1 16}"

for jt in $JTLIST; do
 for fl in $FLAGLIST; do
  for th in $THREADS; do
    for n in $SIZES; do
      # A row that dies (SIGKILL on RSS) must be VISIBLE as a dead row, not as a
      # gap — `|| echo` turns the OOM into a datum instead of into silence, and
      # the sweep continues.
      FP_N=$n FP_THREADS=$th FP_FLAGS=$fl \
        "$JULIA" -t $jt --project=. scripts/klaus2022/fftw_thread_probe.jl \
        || echo "PROBE jt=$jt n=$n threads=$th flags=$fl DIED rc=$?"
    done
  done
 done
done

# The taskset arm: #407's own hypothesis, tested directly. If narrowing the
# VISIBLE cpu set (without changing the allocation, which is already 16) fixes
# the 48³ × 16 case, the library is reading the node and not the cgroup.
#
# THE MASK MUST COME FROM THE JOB, not be assumed to start at 0. The first pass
# passed `-c 0-15` and every row DIED, because UGE had given this job CPUs
# `32-47,224-239` — `taskset` onto CPUs outside the allowed set fails outright.
# That is why the rows printed DIED rather than a number, and it is why they are
# not evidence about the hypothesis either way.
MASK="$(taskset -pc $$ 2>/dev/null | awk -F': ' '{print $2}')"
HALFMASK="$(echo "$MASK" | tr ',' '\n' | head -1)"
echo "=== taskset arm (full mask=$MASK, narrowed to $HALFMASK) ==="
for n in 48 96 128; do
  FP_N=$n FP_THREADS=16 FP_FLAGS=measure \
    taskset -c "$HALFMASK" "$JULIA" -t 16 --project=. scripts/klaus2022/fftw_thread_probe.jl \
    || echo "PROBE-TASKSET n=$n DIED rc=$?"
done

# And the package's own plan builder at the two ends, to separate "FFTW does
# this" from "our use of FFTW does this". Loading SpinorBEC is kept out of the
# sweep above so its JIT and allocations do not pollute the RSS column.
echo "=== SpinorBEC make_fft_plans arm ==="
for n in 48 128; do
  for th in 1 16; do
    FP_N=$n FP_THREADS=$th "$JULIA" -t 16 --project=. -e '
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

# THE STAGE BISECT, at the corner that actually died. `make_fft_plans` above is
# innocent, so the 36.9 GB enters somewhere further down the scalar-eGPE path —
# and "somewhere" is not a mechanism. This walks the stages the smoke walks and
# prints RSS after each, so the jump has a line number. Run at BOTH FFTW thread
# counts with `julia -t 16` fixed, which is the submit script's own control.
#
# The grid is 48×48×24 over box (16,16,8) — the smoke's ACTUAL grid, not a cube.
# The 48³ in #407's table is shorthand and this probe should not inherit it.
echo "=== scalar-eGPE stage bisect (julia -t 16, the corner that died) ==="
for th in 1 16; do
  FP_THREADS=$th "$JULIA" -t 16 --project=. -e '
    using FFTW, Printf, SpinorBEC
    th = parse(Int, ENV["FP_THREADS"]); FFTW.set_num_threads(th)
    rss(tag) = @printf("PROBE-STAGE fftw=%-3d %-22s rss=%7.3fGB\n", th, tag, Sys.maxrss()/2^30)
    rss("after-load")
    grid = make_grid(GridConfig((48,48,24), (16.0,16.0,8.0))); rss("make_grid")
    V = [0.5*(x^2+y^2+2.6^2*z^2) for x in grid.x[1], y in grid.x[2], z in grid.x[3]]
    rss("V_trap")
    ws = SpinorBEC.make_scalar_ws(grid, V; g_contact=1.0e3, c_dd=1.0e3, F=8.0,
                                  gamma_lhy=0.0); rss("make_scalar_ws")
    ws.psi .= 1.0 .+ 0im; ws.psi ./= sqrt(sum(abs2, ws.psi)*prod(grid.dx))
    SpinorBEC.find_ground_state_scalar!(ws, 50, 0.004; B_hat=(sin(0.61),0.0,cos(0.61)))
    rss("find_ground_state x50")
    for _ in 1:50; SpinorBEC.split_step_scalar!(ws, 0.004, 0.0, t->(sin(0.61),0.0,cos(0.61))); end
    rss("split_step x50")
  ' || echo "PROBE-STAGE fftw=$th DIED rc=$?"
done

echo "=== done $(date) ==="
