#!/usr/bin/env julia
# `bench/ab_driver.sh` body: one Eu-151 F=6 24³ +DDI L-BFGS solve to a reachable
# tolerance, reported as driver rows.
#
# Kept OUTSIDE the checked-out tree when driving an A/B, so both arms run the
# same body — otherwise the body is part of what is being compared.
#
# Two reps per invocation, because the solve is deterministic WITHIN a process
# and varies BETWEEN them: the FFTW plan chosen at startup changes the rounding
# and the trajectory diverges. So a rep inside one process measures timing
# noise, and a new process is what samples the real spread. Both are printed;
# the report groups them.

using SpinorBEC
using Printf

include(joinpath(@__DIR__, "eu151_params.jl"))

const TOL = 1.0e-6
const REPS = parse(Int, get(ENV, "SBEC_AB_REPS", "2"))

row(metric, value) = @printf("{\"metric\":\"%s\",\"value\":%.10g}\n", metric, value)

function cell()
    grid = make_grid(GridConfig((24, 24, 24), (12.0, 12.0, 12.0)))
    (;
        grid, atom=AtomSpecies("Eu151", 1.0, 6, EU_a_s_dl, 0.0),
        interactions=interaction_params_from_constraint(;
            c_total=EU_c_total, c1_ratio=0.05, F=6),
        zeeman=ZeemanParams(EU_p_weak, 0.0),
        potential=HarmonicTrap((1.0, 1.0, EU_λ_z)),
        enable_ddi=true, c_dd=EU_c_dd, backend=CPUBackend(),
        initial_state=:m_plus_F, verbose=false,
    )
end

function main()
    c = cell()
    find_ground_state_lbfgs(; c..., n_steps=3, tol=0.0)     # compile
    for _ in 1:REPS
        r = nothing
        t = @elapsed (r = find_ground_state_lbfgs(; c..., n_steps=4000, tol=TOL))
        it = max(r.last_step, 1)
        row("wall_s", t)
        row("iters", r.last_step)
        row("ms_per_it", 1000t / it)
        row("evals_per_it", r.n_line_search_evals / it)
        # Printed so a speedup can never be a different answer: if these move,
        # the arms are not solving the same problem.
        row("energy", r.energy)
        row("grad_norm", r.grad_norm)
        flush(stdout)
    end
end

main()
