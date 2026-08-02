# Build a sysimage for the Fig. 4B production path.
#
#   julia --project=. scripts/build_sysimage_matsui.jl [output.so]
#
# Why a third one. `build_sysimage.jl` targets the rotating-basis F=1 API and
# `build_sysimage_full.jl` the M0/M1/M2 F=6 LBFGS cascade; neither exercises the
# split-step `run_yaml` path the Matsui campaign runs, and a sysimage only
# removes JIT for methods its workload touched. Measured, that JIT is **277 s of
# a 528 s job** (`docs/validation/where_the_campaign_time_goes.md`), so it is the
# largest single item left — but the saving is an estimate until this is built
# and timed, which is the whole point of this script.
#
# Must run on a GPU node: the workload uses `CUDABackend`, and the
# specialisations worth capturing are the CuArray ones.

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
Pkg.add("PackageCompiler")

using PackageCompiler

const OUTPUT = length(ARGS) >= 1 ? ARGS[1] :
               joinpath(@__DIR__, "..", "spinor_sysimage_matsui.so")
const WORKLOAD = joinpath(@__DIR__, "_sysimage_precompile_matsui.jl")

isfile(WORKLOAD) || error("missing workload: $WORKLOAD")

@info "Building the Fig. 4B sysimage" output = OUTPUT workload = WORKLOAD
@info "Expect 30-60 minutes. The workload is a real 2-point run_yaml at 32^3."

create_sysimage(
    [:SpinorBEC];
    sysimage_path=OUTPUT,
    precompile_execution_file=WORKLOAD,
)

println("\nbuilt: $OUTPUT")
println("use:   julia --project=. --sysimage=$OUTPUT <script>")
println("\nThen time it against the 528.5 s baseline (UGE 8318964.15) — the")
println("claim to test is that it removes most of the 277 s first-point JIT and")
println("the ~115 s of startup, NOT that it makes a step faster.")
