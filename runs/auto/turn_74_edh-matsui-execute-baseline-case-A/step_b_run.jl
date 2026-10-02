using CUDA
using SpinorBEC
result = run_experiment("runs/eu151_matsui_edh/configs/matsui_edh_baseline.experiment.jl")
println("=== run_experiment COMPLETE ===")
@show typeof(result)
@show result
