import CUDA
using SpinorBEC
using Printf

flush(stdout)
println("=== T35 ITP start ===")
t0 = time()

try
    run_yaml("/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml")
    elapsed = time() - t0
    @printf("ITP done in %.1f s\n", elapsed)
    println("=== T35 ITP end ===")
catch e
    elapsed = time() - t0
    println("run_yaml THREW EXCEPTION after ", round(elapsed; digits=1), " s:")
    println(typeof(e))
    println(sprint(showerror, e))
    println("Backtrace:")
    println(sprint(show, stacktrace(catch_backtrace())))
    println("=== T35 ITP FAILED ===")
    rethrow(e)
end
