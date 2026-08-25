# Host budget: is every limit DERIVED, is a refusal reachable, and is this the
# only place that answers "how many cpus may I use?"
#
# The third question is the one CLAUDE.md commitment 11 is about. A new single
# source of truth that leaves the old spelling legal does not replace it, it
# joins it — measured over 411 fix commits in this repo, that is exactly what
# separated the migrations that held (`Units.bfield_to_p`, gated) from the ones
# that rotted (`COUPLING_TOL`, 7 : 121, whose docstring said the old form was
# "kept available for legacy call sites"). So the gate ships here, in the same
# commit as the thing it protects.

using Test
using SpinorBEC
include(joinpath(@__DIR__, "helpers", "calibrated_scan.jl"))

const _HB_ROOT = dirname(@__DIR__)

@testset "host budget" begin
    @testset "every term is derived, and says from where" begin
        b = detect_host_budget()
        @test b.cpu_threads >= 1
        @test b.memory_bytes > 0
        # Provenance is not decoration: a report that cannot name the file it
        # read cannot be checked, and an unnameable number is a magic number
        # wearing a struct field.
        @test !isempty(b.cpu_origin)
        @test !isempty(b.memory_origin)
        @test b.cpu_source in (:slurm, :uge, :pbs, :cgroup, :affinity, :override)
        @test b.memory_source in (:slurm, :uge, :cgroup, :memavailable, :override)
    end

    @testset "the affinity reader agrees with the kernel's own answer" begin
        # A cross-check with an independent implementation of the same question.
        # `nproc` (no --all) reports the affinity mask, which is the quantity
        # host_budget claims to read; if the two ever disagree, the parser of
        # Cpus_allowed_list is wrong and every derived count is wrong with it.
        if Sys.islinux() && Sys.which("nproc") !== nothing
            withenv("SPINORBEC_HOST_CPUS" => nothing,
                "SLURM_CPUS_PER_TASK" => nothing, "SLURM_JOB_CPUS_PER_NODE" => nothing,
                "NSLOTS" => nothing, "PBS_NCPUS" => nothing, "PBS_NP" => nothing) do
                b = detect_host_budget()
                if b.cpu_source === :affinity
                    @test b.cpu_threads == parse(Int, readchomp(`nproc`))
                end
            end
        end
    end

    @testset "a stated value is never reported as a measured one" begin
        withenv("SPINORBEC_HOST_CPUS" => "3") do
            b = detect_host_budget()
            @test b.cpu_threads == 3
            @test b.cpu_source === :override      # not :affinity, not :cgroup
        end
        withenv("SPINORBEC_HOST_MEMORY_BYTES" => string(4 * 2^30)) do
            b = detect_host_budget()
            @test b.memory_bytes == 4 * 2^30
            @test b.memory_source === :override
        end
    end

    @testset "refusal is reachable, and is not a default" begin
        # The failure this guards: filling an unreadable quantity with a
        # plausible number, so a budget nobody measured reads as one that is
        # safe. If this testset ever passes vacuously the discipline is gone.
        withenv("SPINORBEC_HOST_CPUS" => "not-a-number") do
            @test_throws BlindBudget detect_host_budget()
        end
        withenv("SLURM_CPUS_PER_TASK" => "lots") do
            @test_throws BlindBudget detect_host_budget()
        end
        err = try
            withenv("SPINORBEC_HOST_CPUS" => "x") do
                detect_host_budget()
            end
        catch e
            e
        end
        @test err isa BlindBudget
        @test occursin("Refusing to substitute a default", sprint(showerror, err))
    end

    @testset "the scheduler's grant outranks the machine" begin
        # On a cluster node the hardware count describes somebody else's job.
        withenv("SPINORBEC_HOST_CPUS" => nothing, "SLURM_CPUS_PER_TASK" => "2") do
            b = detect_host_budget()
            @test b.cpu_threads == 2
            @test b.cpu_source === :slurm
            @test occursin("SLURM_CPUS_PER_TASK", b.cpu_origin)
        end
        # NSLOTS — UGE, which is what TSUBAME runs
        withenv("SPINORBEC_HOST_CPUS" => nothing, "SLURM_CPUS_PER_TASK" => nothing,
            "NSLOTS" => "4") do
            b = detect_host_budget()
            @test b.cpu_threads == 4
            @test b.cpu_source === :uge
        end
        # SLURM_JOB_CPUS_PER_NODE arrives as "72(x2)" on a multi-node grant.
        withenv("SPINORBEC_HOST_CPUS" => nothing, "SLURM_CPUS_PER_TASK" => nothing,
            "NSLOTS" => nothing, "SLURM_JOB_CPUS_PER_NODE" => "72(x2)") do
            @test detect_host_budget().cpu_threads == 72
        end
    end

    # Every literal below was COPIED OUT OF a real TSUBAME job's environment
    # (job 8492405, cpu_4, node r18n6). The unit tests that shipped first set
    # NSLOTS by hand and were green while the memory rung was 65x wrong on that
    # same machine, because nothing local exports SGE_HGR_m_mem_free and nothing
    # local runs cgroup v1. A fixture invented from the documentation would have
    # reproduced exactly that blindness, so these are transcribed, not imagined.
    @testset "the UGE memory grant is read (measured on job 8492405)" begin
        @test SpinorBEC._parse_suffixed_bytes("9.200G") == round(Int, 9.2 * 1024^3)
        @test SpinorBEC._parse_suffixed_bytes("4096M") == 4096 * 1024^2
        @test SpinorBEC._parse_suffixed_bytes("2g") == 2_000_000_000   # lowercase: decimal
        @test SpinorBEC._parse_suffixed_bytes("512") == 512
        @test SpinorBEC._parse_suffixed_bytes("lots") === nothing

        withenv("SPINORBEC_HOST_MEMORY_BYTES" => nothing,
            "SLURM_MEM_PER_NODE" => nothing, "SLURM_MEM_PER_CPU" => nothing,
            "SGE_HGR_m_mem_free" => "9.200G", "NSLOTS" => "4") do
            b = detect_host_budget()
            @test b.memory_source === :uge
            @test b.memory_bytes == round(Int, 9.2 * 1024^3)
            @test b.cpu_threads == 4
            # The defect this replaces: the ceiling was MemAvailable for the
            # whole node. Whatever this host's MemAvailable is, the grant must
            # win over it.
            @test b.memory_bytes < something(SpinorBEC._meminfo_bytes("MemTotal"), typemax(Int))
        end
        # Set but unparseable is a refusal, not a fallthrough to the node total.
        withenv("SGE_HGR_m_mem_free" => "nine gigs") do
            @test_throws BlindBudget detect_host_budget()
        end
    end

    @testset "cgroup v1 is read, not just v2" begin
        # TSUBAME's compute nodes are v1: /proc/self/cgroup lines look like
        # `13:memory:/AGE/8492405.1/master`, with no `0::` line at all. The
        # v2-only reader found no limit there and said nothing about it.
        @test hasmethod(SpinorBEC._cgroup_dirs, Tuple{String})
        src = read(joinpath(_HB_ROOT, "src", "workflow", "io", "host_budget.jl"), String)
        # v1 spellings must appear beside their v2 counterparts, or the file has
        # silently regressed to one hierarchy.
        for v1 in ("memory.limit_in_bytes", "cpu.cfs_quota_us", "cpu.cfs_period_us",
            "memory.max_usage_in_bytes", "memory.usage_in_bytes")
            @test occursin(v1, src)
        end
        # Whatever hierarchy this host runs, asking for a controller must not throw.
        @test SpinorBEC._cgroup_dirs("memory") isa Vector{String}
        @test SpinorBEC._cgroup_dirs("cpu") isa Vector{String}
    end

    @testset "MemoryHigh is never emitted" begin
        # Measured 2026-08-24: MemoryHigh below MemoryMax with swap forbidden
        # does not kill, it LIVELOCKS — memory.events read `high 2560, max 0,
        # oom_kill 0` with the process pinned at the cap making no progress. A
        # job that hangs forever is worse than one that dies, so the property is
        # the ABSENCE of a knob and absence is what has to be gated.
        b = detect_host_budget()
        props = budget_scope_properties(b)
        @test !any(p -> occursin("MemoryHigh", p), props)
        if b.swap_containable
            @test "MemorySwapMax=0" in props
            @test any(p -> startswith(p, "MemoryMax="), props)
            @test "CPUWeight=1" in props
        end
    end

    @testset "the planner follows the derived thread count" begin
        withenv("SPINORBEC_HOST_CPUS" => "1") do
            @test detect_host_budget().fft_plan === :measure
        end
        withenv("SPINORBEC_HOST_CPUS" => "8") do
            b = detect_host_budget()
            @test b.fft_plan === :estimate       # #407: threaded MEASURE blows up
            @test "SPINORBEC_FFT_PLAN=estimate" in budget_env(b)
            @test "JULIA_NUM_THREADS=8" in budget_env(b)
        end
    end

    # ── SSoT gate ────────────────────────────────────────────────────────
    #
    # `Sys.CPU_THREADS` reports the MACHINE. On a TSUBAME node allotted 16 cpus
    # of 384 it is wrong by 24×, which is the same misreading #407 chased for a
    # day. host_budget.jl is now the one place allowed to touch it — as a named,
    # noted last-resort fallback — and this makes the next new caller red.
    @testset "no machine-wide cpu count outside host_budget" begin
        allowed = Set([
            # declares the fallback, and labels it machine-wide in the note it
            # attaches to the returned budget
            "src/workflow/io/host_budget.jl",
            # #407's probe prints julia / cpuinfo / affinity SIDE BY SIDE; the
            # disagreement between them is the measurement, so the machine-wide
            # read is the point rather than a bug
            "scripts/klaus2022/fftw_thread_probe.jl",
        ])

        # Comments are stripped so prose ABOUT the defect does not read as the
        # defect. The stripper also cuts a `#` inside a string literal, which can
        # only ever NARROW what the gate sees — stated because a narrowing
        # approximation is the kind that hides a defect rather than inventing one.
        function code_text(rel)
            buf = IOBuffer()
            for line in eachline(joinpath(_HB_ROOT, rel))
                startswith(strip(line), "#") && continue
                i = findfirst('#', line)
                println(buf, i === nothing ? line : line[1:prevind(line, i)])
            end
            String(take!(buf))
        end

        corpus = String[]
        for sub in ("src", "test", "scripts", "bench", "ext")
            dir = joinpath(_HB_ROOT, sub)
            isdir(dir) && append!(corpus, tree_files(dir))
        end

        # Assembled from halves so THIS file does not contain the literal it
        # hunts for. The first run of this gate flagged itself, which was the
        # right answer to the wrong question: the fix is to stop being a match,
        # not to add an exception. An allowlist entry here would have been a
        # permanent hole in the one file guaranteed to be read by anyone
        # changing the rule.
        needle = "Sys." * "CPU_THREADS"

        hits = calibrated_scan(
            corpus;
            match=rel -> occursin(needle, code_text(rel)),
            # POSITIVE: the declaration site. If the extractor breaks, this stops
            # matching and the scan throws instead of reporting a clean tree.
            present="src/workflow/io/host_budget.jl",
            # NEGATIVE: runtests.jl names Sys.CPU_THREADS in a COMMENT explaining
            # why it no longer calls it. Choosing it here is what proves the
            # comment stripping works — a negative control that merely lacks the
            # string would have proved nothing about the interesting case.
            absent="test/runtests.jl",
        )

        stray = setdiff(Set(hits), allowed)
        @test isempty(stray)
        isempty(stray) || @info(
            "New machine-wide CPU count. Use `detect_host_budget().cpu_threads`, " *
                "which reads the affinity mask or the scheduler's grant; add the file " *
                "to `allowed` here only if reading the machine is the actual intent.",
            stray)

        # And the allowlist may not outlive its files.
        for a in allowed
            @test isfile(joinpath(_HB_ROOT, a))
        end
    end
end
