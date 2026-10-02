# Probe an earlier handoff to the already-requested residual polish when a
# unit-step predicted decrease cannot be represented in the current energy.
# julia --project=. bench/residual_polish_handoff.jl candidate label [grid_n]
using SpinorBEC
source = read("src/solvers/lbfgs/driver.jl", String)
@assert !occursin("polish_completed", source) "Historical probe: use energy_solver_ab.jl for the production handoff"
needle = "        # Backtracking-Armijo line search from the natural L-BFGS step α=1."
@assert occursin(needle, source)
probe = replace(
    source,
    needle =>
        """
        if residual_polish && isfinite(E) && slope < 0 && E + slope == E
            last_step = step
            println("POLISH_HANDOFF step=", step, " residual=", grad_norm, " slope=", slope, " lbfgs_seconds=", elapsed_s(t_start))
            flush(stdout)
            break
        end

""" * needle,
)
Base.include_string(SpinorBEC, probe, "residual_polish_handoff_probe.jl")
include("energy_solver_ab.jl")
