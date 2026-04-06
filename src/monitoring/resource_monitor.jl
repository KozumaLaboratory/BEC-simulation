# Resource monitoring (CPU, RAM, GPU)

using Printf

mutable struct ResourceMonitor
    enabled::Bool
    cpu_usage::Vector{Float64}
    ram_usage::Vector{Float64}
    gpu_available::Bool
    gpu_usage::Vector{Float64}
    gpu_memory::Vector{Float64}
    last_check::Float64
end

function ResourceMonitor(; enabled::Bool=true)
    gpu_available = check_gpu_available()
    ResourceMonitor(
        enabled,
        Float64[],
        Float64[],
        gpu_available,
        Float64[],
        Float64[],
        time()
    )
end

function check_gpu_available()
    try
        # Try to detect CUDA
        if isdefined(Main, :CUDA) && Main.CUDA.functional()
            return true
        end
    catch
    end
    false
end

function get_cpu_usage()
    # Simple CPU usage estimate via /proc/stat (Linux)
    if Sys.islinux()
        try
            stat1 = read("/proc/stat", String)
            sleep(0.1)
            stat2 = read("/proc/stat", String)

            parse_cpu_line(line) = parse.(Int, split(split(line)[2:end]))

            cpu1 = parse_cpu_line(split(stat1, '\n')[1])
            cpu2 = parse_cpu_line(split(stat2, '\n')[1])

            total1 = sum(cpu1)
            total2 = sum(cpu2)
            idle1 = cpu1[4]
            idle2 = cpu2[4]

            total_diff = total2 - total1
            idle_diff = idle2 - idle1

            usage = (1.0 - idle_diff / total_diff) * 100
            return clamp(usage, 0.0, 100.0)
        catch
            return 0.0
        end
    else
        return 0.0
    end
end

function get_ram_usage()
    # Get current process memory usage
    try
        if Sys.islinux()
            pid = getpid()
            status = read("/proc/$pid/status", String)
            for line in split(status, '\n')
                if startswith(line, "VmRSS:")
                    # Parse memory in kB
                    mem_kb = parse(Int, split(line)[2])
                    return mem_kb / 1024  # Convert to MB
                end
            end
        end
    catch
    end

    # Fallback: use Julia's memory estimate
    return Base.gc_live_bytes() / 1e6  # MB
end

function get_total_ram()
    if Sys.islinux()
        try
            meminfo = read("/proc/meminfo", String)
            for line in split(meminfo, '\n')
                if startswith(line, "MemTotal:")
                    mem_kb = parse(Int, split(line)[2])
                    return mem_kb / 1024  # MB
                end
            end
        catch
        end
    end
    return 0.0
end

function get_gpu_usage()
    # Placeholder for GPU monitoring
    # Would need CUDA.jl integration for real implementation
    if isdefined(Main, :CUDA) && Main.CUDA.functional()
        try
            device = Main.CUDA.device()
            mem_free = Main.CUDA.available_memory() / 1e9  # GB
            mem_total = Main.CUDA.total_memory() / 1e9     # GB
            mem_used = mem_total - mem_free
            mem_pct = (mem_used / mem_total) * 100

            return (
                usage = 0.0,  # Would need nvidia-smi parsing
                memory_used = mem_used,
                memory_total = mem_total,
                memory_pct = mem_pct
            )
        catch
        end
    end

    return (usage=0.0, memory_used=0.0, memory_total=0.0, memory_pct=0.0)
end

function update!(monitor::ResourceMonitor)
    !monitor.enabled && return

    # Throttle updates (at most once per second)
    t_now = time()
    if t_now - monitor.last_check < 1.0
        return
    end
    monitor.last_check = t_now

    # Update CPU
    cpu = get_cpu_usage()
    push!(monitor.cpu_usage, cpu)
    if length(monitor.cpu_usage) > 60  # Keep last 60 samples
        popfirst!(monitor.cpu_usage)
    end

    # Update RAM
    ram = get_ram_usage()
    push!(monitor.ram_usage, ram)
    if length(monitor.ram_usage) > 60
        popfirst!(monitor.ram_usage)
    end

    # Update GPU if available
    if monitor.gpu_available
        gpu_info = get_gpu_usage()
        push!(monitor.gpu_usage, gpu_info.usage)
        push!(monitor.gpu_memory, gpu_info.memory_pct)

        if length(monitor.gpu_usage) > 60
            popfirst!(monitor.gpu_usage)
        end
        if length(monitor.gpu_memory) > 60
            popfirst!(monitor.gpu_memory)
        end
    end
end

function format_resources(monitor::ResourceMonitor)
    !monitor.enabled && return ""

    parts = String[]

    # CPU
    if !isempty(monitor.cpu_usage)
        cpu = monitor.cpu_usage[end]
        push!(parts, @sprintf("CPU: %.0f%%", cpu))
    end

    # RAM
    if !isempty(monitor.ram_usage)
        ram_mb = monitor.ram_usage[end]
        total_mb = get_total_ram()
        if total_mb > 0
            push!(parts, @sprintf("RAM: %.0f/%.0f MB", ram_mb, total_mb))
        else
            push!(parts, @sprintf("RAM: %.0f MB", ram_mb))
        end
    end

    # GPU
    if monitor.gpu_available && !isempty(monitor.gpu_memory)
        gpu_mem_pct = monitor.gpu_memory[end]
        push!(parts, @sprintf("GPU Mem: %.0f%%", gpu_mem_pct))
    end

    join(parts, " | ")
end
