using CUDA
using SpinorBEC
cfg = load_config("/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml")
println("Config steps: ", length(cfg.steps))
atom = SpinorBEC.resolve_atom(:Eu151_f1_effective)
@assert atom.F == 1 "Expected F=1, got $(atom.F)"
println("Atom: ", atom.name, " F=", atom.F, " a_s=", atom.a_s, " mu=", atom.mu_mag)
println("CUDA functional: ", CUDA.functional())
@assert CUDA.functional() "CUDA not functional — cannot proceed with backend=gpu"
println("PRECONDITION_OK")
