# Run a scan config and print every point's energy and psi hash. No filtering,
# no comparison logic — the caller diffs the rows.
import CUDA
using SpinorBEC, JLD2, SHA, Printf
cfg, tag = ARGS[1], ARGS[2]
try
    run_yaml(cfg; verbose=false)
catch e
    println("THREW ", sprint(showerror, e))
    exit(1)
end
store = get(ENV, "SPINORBEC_STORE", "runs")
for (root, _, files) in walkdir(store), f in sort(files)
    endswith(f, ".jld2") || continue
    d = try
        JLD2.load(joinpath(root, f))
    catch
        continue
    end
    psi = get(d, "psi", nothing)
    h = psi === nothing ? "-" : bytes2hex(sha256(reinterpret(UInt8, vec(ComplexF64.(psi)))))[1:16]
    @printf("SCAN %-16s %-18s E=%.17g conv=%s psi=%s\n",
        tag, f, Float64(get(d, "energy", NaN)), string(get(d, "converged", "-")), h)
end
