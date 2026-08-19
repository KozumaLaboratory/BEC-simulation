# Generate the convergence + bistability cells for issue #336 from config.yaml.
#
# One source of truth for the physics: every cell is config.yaml with exactly
# one axis changed, so a cell can never silently disagree with the production
# config about c_total / c_dd / c_lhy. The cells are written to disk rather
# than built in memory so each is inspectable and `run_yaml` content-addresses
# it independently.
#
#   grid convergence : n = 64, 96, 128 at box 6      (dx halves)
#   box  convergence : box = 6, 8 at fixed dx        (n scales with box)
#   bistability      : the cigar seed at the production cell
#
# The cigar is the paper's OTHER branch (Fig. 3): spin uniformly along z, no
# spin winding. At B=0 the paper reports the torus as the ground state; running
# both seeds from the same cell and comparing energies is what establishes
# that here, rather than trusting whichever one ITP happened to find.

using YAML

const HERE = @__DIR__
const CELLS = joinpath(HERE, "cells")
mkpath(CELLS)

base = YAML.load_file(joinpath(HERE, "config.yaml"))

function cell(name; n=nothing, box=nothing, seed=nothing, n_steps=nothing)
    d = deepcopy(base)
    mixin = d["mixins"]["saito_li_droplet"]
    step = d["pipeline"][1]["ground_state"]
    n === nothing || (mixin["grid"]["n"] = [n, n, n])
    box === nothing || (mixin["grid"]["box"] = [box, box, box])
    n_steps === nothing || (step["n_steps"] = n_steps)
    if seed == :cigar
        # Uniform spin along +z, no winding: the Fig. 3(a) branch.
        step["initial_state"] = "m_plus_F"
        delete!(step, "init_state_params")
    end
    path = joinpath(CELLS, "$(name).yaml")
    YAML.write_file(path, d)
    println("wrote ", relpath(path, dirname(dirname(HERE))))
    path
end

cell("torus_n64_box6"; n=64, box=6)
cell("torus_n96_box6"; n=96, box=6)
cell("torus_n128_box6"; n=128, box=6)

# Box convergence at ~fixed dx. box 6 / n 64 is dx = 0.0732 um; box 8 needs
# n = 64*8/6 = 85.3 -> 88 (dx = 0.0709 um) so the box grows while the
# resolution does not, which is the point of the test.
cell("torus_n88_box8"; n=88, box=8)

# Bistability: the Fig. 3 cigar branch from the same cell. 96³ rather than 128³
# because the comparison is between the two SEEDS, so both must be at the same
# resolution and 96³ is where the torus is already grid-converged.
cell("cigar_n96_box6"; n=96, box=6, seed=:cigar)
