using CUDA
using SpinorBEC
result = run_yaml("runs/eu151_matsui_edh/configs/matsui_edh_baseline.yaml")
println("=== run_yaml COMPLETE ===")
@show typeof(result)
@show result
