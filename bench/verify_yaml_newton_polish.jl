# Verify the YAML `ground_state.newton_polish` knob: schema accepts it and it
# tightens the gradient floor end-to-end (1D scalar harmonic, CPU).
using SpinorBEC

yaml(polish) = """
pipeline:
  - ground_state:
      method: lbfgs
      atom: Rb87
      grid: {n: 128, box: 16.0}
      interactions: {c0: 0.0, c1: 0.0}
      potential: {omega: 1.0}
      n_steps: 500
      tol: 1.0e-12
      initial_state: polar
      newton_polish: $(polish)
"""

function write_cfg(polish)
    path = tempname() * ".yaml"
    open(io -> print(io, yaml(polish)), path, "w")
    path
end

# 1) schema must accept newton_polish (no :error / unknown-key)
p_true = write_cfg(true)
issues = inspect_config(p_true)
ws = issues.warnings
bad = filter(w -> w.severity in (:error, :block), ws)
np = filter(w -> occursin("newton_polish", string(w)), ws)
println("inspect_config: ", length(ws), " warnings, ", length(bad), " error/block, ",
    length(np), " mention newton_polish")
for b in vcat(bad, np)
    println("   ", b)
end

# 2) both variants must run end-to-end through the YAML pipeline. The verbose
# LBFGS/Newton log prints the gradient progression; newton_polish=true appends
# a Newton-CG pass (only emitted when the flag actually reaches the solver).
for polish in (false, true)
    println("\n========== newton_polish=$polish ==========")
    r = run_config(load_config(write_cfg(polish)))
    println("RESULT newton_polish=$polish  E=$(r.ground_state_energy)  converged=$(r.ground_state_converged)")
end
println("DONE")
