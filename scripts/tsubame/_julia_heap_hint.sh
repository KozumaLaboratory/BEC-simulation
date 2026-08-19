# Derive `--heap-size-hint` from what the JOB was granted, not from the node.
#
# Sourced, not copied. Sets `HEAP_HINT_FLAG` (ready to interpolate into a julia
# command line) and `HEAP_HINT_SRC` (where the number came from).
#
# WHY. Julia sizes its GC heap target from the machine's PHYSICAL memory and
# never looks at the cgroup the batch job is confined to. On TSUBAME 4 that gap
# is enormous, and it is measured rather than reasoned (2026-08-19, #345):
#
#   node r18n9              755 GB physical, 384 cores   (`qhost -h r18n9`)
#   a cpu_16 job is granted  36.8 GB          (m_mem_free 2.3G, consumable, x16)
#   the Klaus smoke needs     1.12 GB working set  (/usr/bin/time -v, locally)
#   what it actually reached 36.9 GB          (`qacct -j 8445105`, ru_maxrss)
#   what happened            SIGKILL at 55 s  (exit 137)
#
# i.e. ~35 GB of uncollected garbage, because nothing in the process had any
# reason to collect: Julia saw 755 GB. The SAME configuration had failed
# differently an hour earlier — job 8444494, SIGSEGV inside FFTW's threaded
# spawn loop after 3m14s — and TWO FAILURE MODES FROM ONE CONFIGURATION is the
# signature of resource exhaustion rather than a deterministic bug. That is what
# turned the diagnosis away from FFTW, which the stack trace pointed at and
# which was the wrong lead.
#
# NOT the fix for a run that genuinely needs the memory. This makes the GC
# collect at a level the job is allowed to hold; a working set that really
# exceeds the grant still needs a bigger resource class. The point is that a
# 1.1 GB job should not die at 36.8 GB.
#
# The derivation NAMES ITS SOURCE and the caller echoes it, because a heap hint
# computed from a guess and a heap hint computed from the cgroup print the same
# kind of number. If `HEAP_HINT_SRC` says `slots-fallback`, the cgroup files
# were unreadable and the value rests on `_MEM_PER_SLOT_GB` being right for this
# queue — which is a constant read off one job's `hard_resource_list`, not
# something the scheduler told us.

# Per-slot memory for the cpu_* classes, read off `qstat -j`'s
# `hard_resource_list: cpu_16=1,h_rt=1800,m_mem_free=2.3G,njobs=1`. Only used
# when the cgroup cannot be read.
_MEM_PER_SLOT_GB="${SPINORBEC_MEM_PER_SLOT_GB:-2.3}"

# Fraction of the grant to aim the GC at. Not tuned: the process holds code
# images, thread stacks and FFTW plans OUTSIDE the Julia heap, and the hint is a
# target the GC steers toward rather than a hard ceiling, so aiming at the full
# grant would still be killed.
_HEAP_HINT_FRACTION="${SPINORBEC_HEAP_HINT_FRACTION:-0.6}"

_derive_julia_heap_hint() {
    local bytes="" src=""

    if [ -r /sys/fs/cgroup/memory.max ]; then
        bytes="$(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
        src="cgroup-v2"
    elif [ -r /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        bytes="$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)"
        src="cgroup-v1"
    fi

    # `max`, empty, or non-numeric is NOT a limit. Neither is cgroup v1's
    # "unlimited" sentinel (a number near 2^63) — treating it as a grant would
    # hand back exactly the 755 GB figure this file exists to stop using.
    case "$bytes" in
        '' | max | *[!0-9]*) bytes="" ;;
    esac
    if [ -n "$bytes" ] && [ "$bytes" -gt 1099511627776 ]; then
        bytes=""      # > 1 TiB: the node, not the job
    fi

    if [ -z "$bytes" ]; then
        src="slots-fallback(${NSLOTS:-1}x${_MEM_PER_SLOT_GB}G)"
        bytes="$(awk -v n="${NSLOTS:-1}" -v g="$_MEM_PER_SLOT_GB" \
            'BEGIN { printf "%d", n * g * 1024 * 1024 * 1024 }')"
    fi

    HEAP_HINT_BYTES="$(awk -v b="$bytes" -v f="$_HEAP_HINT_FRACTION" \
        'BEGIN { printf "%d", b * f }')"
    HEAP_HINT_SRC="$src (grant $(awk -v b="$bytes" \
        'BEGIN { printf "%.1f", b / 1073741824 }') GiB, hint $(awk -v b="$HEAP_HINT_BYTES" \
        'BEGIN { printf "%.1f", b / 1073741824 }') GiB)"
    HEAP_HINT_FLAG="--heap-size-hint=$HEAP_HINT_BYTES"
}

_derive_julia_heap_hint
