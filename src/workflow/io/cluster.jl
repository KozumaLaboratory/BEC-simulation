# Cluster / deployment helpers — extracted from sbatch / supervised_run
# inline `julia -e` heredocs so heredocs collapse to ≤2 lines each.
#
# The boundary: any logic that used to live as a multi-line `julia -e`
# block inside `scripts/*.sbatch` or `scripts/*.sh` belongs here. The
# shell scripts call a single library function; the function carries the
# behaviour, the .sh carries the env setup.

export clear_stale_checkpoints!, report_cuda_state, cuda_preflight_check

"""
    clear_stale_checkpoints!(exp::Experiment) -> Bool

If `<exp.outdir>/.checkpoints/` exists, log + remove it. Used by the
`supervised_run.sh` retry loop so a fresh attempt doesn't resume from a
partially-corrupted checkpoint produced by the previous crash. Returns
`true` if a directory was removed.
"""
function clear_stale_checkpoints!(exp::Experiment)
    ckpt = joinpath(outdir(exp), ".checkpoints")
    if isdir(ckpt)
        @info "removing stale checkpoint dir" ckpt
        rm(ckpt; recursive=true, force=true)
        return true
    end
    return false
end

"""
    report_cuda_state(io=stdout)

Print the active CUDA device name, compute capability, and memory
usage in the format the sbatch scripts previously emitted inline.
Falls back to a "CUDA not loaded" notice when the SpinorBECCUDAExt
extension isn't active (i.e. `using CUDA` hasn't been called).
"""
function report_cuda_state(io::IO=stdout)
    println(io, "--- CUDA state ---")
    for line in cuda_state_lines()
        println(io, "  ", line)
    end
    return nothing
end

"""
    cuda_preflight_check(; smoke_config=nothing, io=stdout) -> Bool

Pre-flight check for a cluster session: reports CUDA state, optionally
runs a single config through `run_config` as a smoke test. Returns
`true` if all checks pass.

`smoke_config` is the path to a tiny YAML (e.g. `runs/option_gamma_micro/config.yaml`);
when `nothing`, the smoke step is skipped. The previous
`scripts/tsubame/preflight.sh` inlined the equivalent of:

    julia -e 'using SpinorBEC, CUDA; ... cuda_preflight_check(smoke_config="runs/option_gamma_micro/config.yaml")'
"""
function cuda_preflight_check(;
    smoke_config::Union{Nothing, AbstractString}=nothing,
    io::IO=stdout,
)
    report_cuda_state(io)
    if smoke_config !== nothing
        println(io, "\n--- Smoke test: $smoke_config ---")
        config = load_config(String(smoke_config))
        @time run_config(config; verbose=false)
        println(io, "✅ smoke test passed")
    end
    println(io, "\n✅ preflight passed")
    return true
end
