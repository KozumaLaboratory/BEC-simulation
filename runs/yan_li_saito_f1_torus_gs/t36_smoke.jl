using SpinorBEC
cfg = load_config("/home/suzume/workspace/BEC-simulation/runs/yan_li_saito_f1_torus_gs/config.yaml")
println("Config steps: ", length(cfg.steps))
step1 = cfg.steps[1]
println("Step 1 type: ", typeof(step1))
println("Step 1 params keys: ", keys(step1.params))
if haskey(step1.params, "zeeman")
    println("Internal zeeman: ", step1.params["zeeman"])
else
    println("No internal zeeman (will use defaults p=q=0)")
end
println("LOAD_CONFIG_OK")
