# Precompile workload for the Fig. 4B production path.
#
# A sysimage only removes JIT for the methods its workload actually exercises,
# so this runs the REAL thing: `run_yaml` on the campaign's own config with the
# step counts cut to the bone. Same blocks — B ramp, padded DDI, the 3-step
# pipeline, the analyzers, the JLD2 save — so the
# specialisations PackageCompiler captures are the ones the campaign pays for.
#
# Writing a hand-rolled `find_ground_state` call instead would capture a
# *similar* path and miss `parse_pipeline` / `_step_dispatch!` / the save, which
# is where a good part of the first-point cost lives.
#
# CPU BACKEND, deliberately, and this is a real limit rather than a choice.
# Tracing the GPU path kills the build outright:
#
#     LLVM ERROR: Cannot select: intrinsic %llvm.nvvm.read.ptx.sreg.envreg2
#
# PackageCompiler compiles the traced code for the host target, and CUDA kernels
# captured in the trace are NVVM/PTX. So this image can carry the host-side
# specialisations — YAML, schema, `parse_pipeline`, `_step_dispatch!`, the
# analyzers, the JLD2 save, and the CPU-typed solver path — but NOT the
# CuArray-parameterised `make_workspace` / `find_ground_state` / `split_step!`,
# which will still JIT at runtime. Measure the saving; do not assume it.

using SpinorBEC
using YAML

const SRC = joinpath(@__DIR__, "..", "runs", "matsui_fig4b", "fig4b_scan_n35k_n32.yaml")

d = YAML.load_file(SRC)
d["defaults"]["backend"] = "cpu"
for st in d["pipeline"]
    for (_, blk) in st
        blk isa AbstractDict && haskey(blk, "backend") && (blk["backend"] = "cpu")
        blk isa AbstractDict && haskey(blk, "grid") && (blk["grid"]["n"] = [16, 16, 16])
    end
end

# Two scan points: one populates the GS stage cache, the second exercises the
# reuse branch, and both are in the production code path.
for axes in values(d["scan"])
    axes isa AbstractDict || continue
    for (_, v) in axes
        v isa AbstractDict && haskey(v, "from") &&
            (v["to"] = Float64(v["from"]) + Float64(v["step"]))
    end
end

for st in d["pipeline"]
    if haskey(st, "ground_state")
        st["ground_state"]["n_steps"] = 8
        st["ground_state"]["tol"] = 1e-3
    elseif haskey(st, "dynamics")
        dt = Float64(st["dynamics"]["dt"])
        st["dynamics"]["duration"] = 8 * dt
        haskey(st["dynamics"], "save") && (st["dynamics"]["save"]["every"] = 4)
        # The ramp's own duration must stay inside the shortened run or the B
        # block resolves to a different waveform type than production uses.
        b = get(st["dynamics"], "B", nothing)
        if b isa AbstractDict && b["Bz"] isa AbstractDict
            b["Bz"]["duration"] = 4 * dt
        end
    end
end

dir = mktempdir()
cfg = joinpath(dir, "sysimage_warmup.yaml")
YAML.write_file(cfg, d)

withenv("SPINORBEC_STORE" => joinpath(dir, "store"),
    "SPINORBEC_STAGE_CACHE" => "1") do
    run_yaml(cfg; verbose=false)
end

@info "workload done (CPU backend; the CuArray specialisations are NOT in this image)"
