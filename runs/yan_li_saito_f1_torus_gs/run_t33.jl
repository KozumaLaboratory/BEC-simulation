import CUDA
using SpinorBEC

println("=== T33 ITP execution: yan_li_saito_f1_torus_gs ===")
println("Start time: ", Dates.now())
t_start = time()

try
    run_yaml("runs/yan_li_saito_f1_torus_gs/config.yaml"; base_dir="runs", verbose=true)
    println("run_yaml COMPLETED successfully")
catch e
    println("run_yaml THREW EXCEPTION:")
    println(typeof(e))
    println(sprint(showerror, e))
    println("Backtrace:")
    println(sprint(show, stacktrace(catch_backtrace())))
end

t_end = time()
println("Wall time: ", round(t_end - t_start; digits=1), " s")
println("=== END T33 ===")
