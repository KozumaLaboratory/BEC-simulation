# Why does FFTW with 16 threads need 36.9 GB at 48³ and 1.15 GB at 128³? (#407)
#
# MEASURED, and consistent, and unexplained (PR #405, TSUBAME cpu_16, one commit):
#
#   48³  16 threads → 36.9 GB  → SIGKILL       48³  1 thread →  1.08 GB, 343 s
#   128³ 16 threads →  1.15 GB → 575 s         128³ 1 thread →  1.06 GB, 1803 s
#
# A 19× larger problem using 32× less memory at the same thread count is not a
# size effect, so the axis is wrong. This probe sweeps the axes that could
# actually carry it, ONE PROCESS PER POINT — `ru_maxrss` is a high-water mark, so
# two sizes in one process report the larger twice and the peak's LOCATION, which
# is the whole question, is exactly what gets lost.
#
# The four axes, and what each would mean:
#
#   FACTORISATION, not size. 48 = 2⁴·3 and 128 = 2⁷. FFTW's planner searches a
#     much larger space for a mixed-radix length, and each candidate carries
#     per-thread scratch. If RSS tracks the radix and not `n`, "19× bigger, 32×
#     smaller" stops being a paradox and becomes arithmetic. This is the
#     hypothesis #407 did NOT list and it is the cheapest to kill.
#   PLANNER EFFORT. `MEASURE` allocates and times candidate plans; `ESTIMATE`
#     allocates almost nothing. If the blow-up is `MEASURE`-only, the workaround
#     is a planner flag rather than a thread count.
#   VISIBLE CPUs. #407's own hypothesis: the node has 384 cores, the job is
#     allotted 16, and a library sizing its scratch from `/proc/cpuinfo` rather
#     than the cgroup would over-allocate by 24×. `taskset` narrows the visible
#     set; if that fixes it, the hypothesis is confirmed. The probe prints all
#     three counts so the arm is interpretable even if it does not.
#   THREAD COUNT itself, swept rather than assumed binary.
#
# Env:
#   FP_N=48                grid edge (cubic, complex, in-place)
#   FP_THREADS=1           FFTW threads
#   FP_FLAGS=measure       measure | estimate | patient
#   FP_SPINORBEC=0         1 ⇒ also load SpinorBEC and plan the way it does,
#                          which separates "FFTW does this" from "our use of it does"
#
# One line of output per process, `PROBE` prefixed, so the sweep is a grep.

using FFTW
using Printf

const N = parse(Int, get(ENV, "FP_N", "48"))
const THREADS = parse(Int, get(ENV, "FP_THREADS", "1"))
const FLAGS = lowercase(get(ENV, "FP_FLAGS", "measure"))

"Largest prime factor of `n` — the one number that separates 48 from 128."
function max_prime_factor(n::Int)
    m, best = n, 1
    d = 2
    while d * d <= m
        while m % d == 0
            best = max(best, d)
            m ÷= d
        end
        d += 1
    end
    max(best, m)
end

"`taskset -pc` prints `pid's current affinity list: 0-15,32` — count the members."
function parse_affinity(s::AbstractString)
    lst = strip(split(s, ':')[end])
    total = 0
    for part in split(lst, ',')
        isempty(strip(part)) && continue
        if occursin('-', part)
            a, b = parse.(Int, split(part, '-'))
            total += b - a + 1
        else
            total += 1
        end
    end
    total
end

"""How many CPUs each of the three answers thinks there are.

They disagree, and the disagreement IS #407's hypothesis: `/proc/cpuinfo` is the
node (384), the affinity mask is the allocation (16), and a library that sizes
per-thread scratch from the first will over-allocate by 24×."""
function cpu_counts()
    cpuinfo = try
        count(l -> startswith(l, "processor"), readlines("/proc/cpuinfo"))
    catch
        -1
    end
    affinity = try
        parse_affinity(read(`taskset -pc $(Libc.getpid())`, String))
    catch
        -1
    end
    (; julia=Sys.CPU_THREADS, cpuinfo, affinity)
end

flagbits = FLAGS == "estimate" ? FFTW.ESTIMATE :
           FLAGS == "patient" ? FFTW.PATIENT : FFTW.MEASURE

FFTW.set_num_threads(THREADS)
cc = cpu_counts()
rss0 = Sys.maxrss() / 2^30

a = zeros(ComplexF64, N, N, N)
t0 = time()
p = plan_fft!(a; flags=flagbits)
t_plan = time() - t0
t0 = time()
p * a
t_exec = time() - t0
rss = Sys.maxrss() / 2^30

@printf("PROBE n=%-4d maxprime=%-3d threads=%-3d got=%-3d flags=%-8s plan=%8.2fs exec=%7.3fs rss=%7.3fGB rss0=%6.3fGB cpu(julia/cpuinfo/affinity)=%d/%d/%d\n",
    N, max_prime_factor(N), THREADS, FFTW.get_num_threads(), FLAGS,
    t_plan, t_exec, rss, rss0, cc.julia, cc.cpuinfo, cc.affinity)
flush(stdout)

# Deliberately NOT loading SpinorBEC here. The point of this probe is to say
# whether plain FFTW reproduces the pathology at all; loading the package adds a
# JIT cascade and its own allocations to every row and would make the RSS column
# unreadable. The package's own plan builder is measured by a separate
# invocation in `submit_fftw_probe.sh`, so the two questions stay separable.
