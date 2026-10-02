using CUDA
using SpinorBEC
using Printf

flush(stdout)
println("=== T37 ITP start ===")
t0 = time()
run_experiment("/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.experiment.jl")
elapsed = time() - t0
@printf("ITP done in %.1f s\n", elapsed)
println("=== T37 ITP end ===")
flush(stdout)
